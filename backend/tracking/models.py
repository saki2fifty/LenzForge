"""Versioned model library with atomic downloads and validated local imports."""
import hashlib
import json
import os
from pathlib import Path
import re
import threading
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[2]
MAX_BYTES = 100 * 1024 * 1024
DEFAULTS = {'face': 'face_landmarker', 'hand': 'hand_landmarker', 'pose': 'pose_landmarker_lite'}
# Official float16 version 1 bundles, retrieved from Google's model listings.
OFFICIAL = {
    'face_landmarker': ('face', 'Face · standard', 3758596, '64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff'),
    'hand_landmarker': ('hand', 'Hands · full', 7819105, 'fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1'),
    'pose_landmarker_lite': ('pose', 'Pose · Lite', 5777746, '59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a'),
    'pose_landmarker_full': ('pose', 'Pose · Full', 9398198, '5134a3aad27a58b93da0088d431f366da362b44e3ccfbe3462b3827a839011b1'),
    'pose_landmarker_heavy': ('pose', 'Pose · Heavy', 30664242, '64437af838a65d18e5ba7a0d39b465540069bc8aae8308de3e318aad31fcbc7b'),
}


def validate_bundle(path, kind):
    """Check task type, archive limits and CPU executability before publishing."""
    expected = {'face': {'face_detector.tflite', 'face_landmarks_detector.tflite'},
                'hand': {'hand_detector.tflite', 'hand_landmarks_detector.tflite'},
                'pose': {'pose_detector.tflite', 'pose_landmarks_detector.tflite'}}
    if kind not in expected:
        raise ValueError('Choose face, hand, or pose')
    try:
        with zipfile.ZipFile(path) as bundle:
            if not expected[kind].issubset(bundle.namelist()):
                raise ValueError(f'This is not a compatible {kind} Landmarker .task bundle')
            if sum(entry.file_size for entry in bundle.infolist()) > MAX_BYTES:
                raise ValueError('Expanded model exceeds 100 MB')
    except zipfile.BadZipFile as exc:
        raise ValueError('Import a complete MediaPipe Landmarker .task bundle') from exc
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision
    import mediapipe as mp
    import numpy as np
    task_type = {'face': vision.FaceLandmarker, 'hand': vision.HandLandmarker, 'pose': vision.PoseLandmarker}[kind]
    options_type = {'face': vision.FaceLandmarkerOptions, 'hand': vision.HandLandmarkerOptions, 'pose': vision.PoseLandmarkerOptions}[kind]
    options = options_type(base_options=python.BaseOptions(model_asset_path=str(path)), running_mode=vision.RunningMode.IMAGE)
    if kind == 'face':
        options.output_face_blendshapes = True
        options.output_facial_transformation_matrixes = True
    with task_type.create_from_options(options) as task:
        task.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.zeros((256, 256, 3), dtype=np.uint8)))


class ModelLibrary:
    def __init__(self, directory=None):
        self.directory = Path(directory or os.environ.get('LENZFORGE_MODELS', ROOT / 'models'))
        self.lock = threading.RLock()
        self.job = {'state': 'idle'}
        self.thread = None
        self.verified = {}
        self.custom = {}
        index = self.directory / 'library.json'
        if index.is_file():
            try:
                for key, item in json.loads(index.read_text(encoding='utf-8')).items():
                    if (re.fullmatch(r'(face|hand|pose)-[0-9a-f]{64}', key)
                            and item.get('kind') == key.split('-')[0]
                            and item.get('sha256') == key.split('-')[1]):
                        self.custom[key] = item
            except (ValueError, TypeError, AttributeError):
                pass

    def entries(self):
        result = {key: {'kind': value[0], 'label': value[1], 'bytes': value[2], 'sha256': value[3],
                        'official': True, 'url': f'https://storage.googleapis.com/mediapipe-models/{value[0]}_landmarker/{key}/float16/1/{key}.task'}
                  for key, value in OFFICIAL.items()}
        result.update(self.custom)
        return result

    def snapshot(self):
        with self.lock:
            models = []
            for key, item in self.entries().items():
                path = self.directory / (key + '.task')
                installed = path.is_file() and path.stat().st_size == item['bytes']
                models.append({**item, 'id': key, 'installed': installed})
            return {'models': models, 'job': self.job.copy()}

    def resolve(self, key, kind):
        with self.lock:
            item = self.entries().get(key) if isinstance(key, str) else None
            if not item or item['kind'] != kind:
                raise ValueError(f'Choose a compatible {kind} model')
            path = self.directory / (key + '.task')
            if not path.is_file():
                raise ValueError(f"Download {item['label']} before applying it")
            stamp = (path.stat().st_mtime_ns, path.stat().st_size)
            if self.verified.get(key) != stamp:
                if hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
                    raise ValueError(f"{item['label']} failed verification; download it again")
                self.verified[key] = stamp
            return path

    def _begin(self, key, label):
        if self.thread and self.thread.is_alive():
            raise RuntimeError('A model download or import is already running')
        self.directory.mkdir(parents=True, exist_ok=True)
        self.job = {'state': 'downloading', 'id': key, 'label': label, 'received': 0, 'total': 0, 'error': None}

    def download(self, key):
        with self.lock:
            item = self.entries().get(key) if isinstance(key, str) else None
            if not item or not item.get('official'):
                raise ValueError('Choose an official model to download')
            self._begin(key, item['label'])
            self.thread = threading.Thread(target=self._download, args=(key, item), daemon=True, name='LenzForge-Model-Download')
            self.thread.start()
            return self.job.copy()

    def _download(self, key, item):
        temporary = self.directory / (uuid.uuid4().hex + '.partial')
        try:
            request = urllib.request.Request(item['url'], headers={'User-Agent': 'LenzForge-Models'})
            digest = hashlib.sha256()
            received = 0
            with urllib.request.urlopen(request, timeout=30) as response, temporary.open('wb') as output:
                with self.lock: self.job['total'] = item['bytes']
                while block := response.read(256 * 1024):
                    received += len(block)
                    if received > item['bytes']: raise ValueError('Model download exceeds its expected size')
                    output.write(block)
                    digest.update(block)
                    with self.lock: self.job['received'] = received
            if received != item['bytes'] or digest.hexdigest() != item['sha256']:
                raise ValueError('Model checksum mismatch; existing models were kept')
            temporary.replace(self.directory / (key + '.task'))
            with self.lock: self.job['state'] = 'ready'
        except Exception as exc:
            with self.lock: self.job.update(state='error', error=str(exc)[:300])
        finally:
            temporary.unlink(missing_ok=True)

    def import_stream(self, source, kind, filename):
        if kind not in DEFAULTS or not filename.lower().endswith('.task'):
            raise ValueError('Choose a task type and a compatible .task file')
        label = Path(filename.replace('\\', '/')).name
        label = ''.join(c for c in label if c.isprintable())[:80]
        with self.lock:
            self._begin('import', label)
            temporary = self.directory / (uuid.uuid4().hex + '.partial')
            try:
                digest, received = hashlib.sha256(), 0
                with temporary.open('wb') as output:
                    while block := source.read(256 * 1024):
                        received += len(block)
                        if received > MAX_BYTES: raise ValueError('Model exceeds 100 MB')
                        digest.update(block)
                        output.write(block)
                self.job.update(state='validating', received=received, total=received)
                key = kind + '-' + digest.hexdigest()
                self.thread = threading.Thread(target=self._import, args=(temporary, key, kind, label, received), daemon=True,
                                               name='LenzForge-Model-Import')
                self.thread.start()
            except Exception:
                temporary.unlink(missing_ok=True)
                self.job['state'] = 'error'
                raise
            return self.job.copy()

    def _import(self, temporary, key, kind, label, size):
        try:
            validate_bundle(temporary, kind)
            with self.lock:
                updated = {**self.custom, key: {'kind': kind, 'label': label, 'bytes': size, 'sha256': key.split('-')[1], 'official': False}}
                index = self.directory / 'library.json.partial'
                index.write_text(json.dumps(updated, indent=2), encoding='utf-8')
                temporary.replace(self.directory / (key + '.task'))
                index.replace(self.directory / 'library.json')
                self.custom = updated
                self.job.update(state='ready', id=key)
        except Exception as exc:
            with self.lock: self.job.update(state='error', error=str(exc).splitlines()[0][:300])
        finally:
            temporary.unlink(missing_ok=True)


library = ModelLibrary()
