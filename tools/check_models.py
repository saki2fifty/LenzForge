"""Exercise installed official models on CPU/GPU and validate a custom import."""
from dataclasses import replace
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
import capture  # Apply OpenCV thread limits before loading models.
import cv2
import matplotlib
from pipeline.tracking_config import TrackingConfig
from pipeline.web_processor import WebProcessor
from tracking.browser_tracker import BrowserTracker
from tracking.models import ModelLibrary, library, validate_bundle


def main():
    image = cv2.imread(str(Path(matplotlib.get_data_path()) / 'sample_data/grace_hopper.jpg'))
    rgb = cv2.cvtColor(cv2.resize(image, (512, 600)), cv2.COLOR_BGR2RGB)
    # The real download route uses the same background installer and checksum.
    library.download('pose_landmarker_full')
    library.thread.join(90)
    assert library.snapshot()['job']['state'] == 'ready', library.snapshot()['job']
    for kind, key in [('face','face_landmarker'), ('hand','hand_landmarker'),
                      ('pose','pose_landmarker_lite'), ('pose','pose_landmarker_full'), ('pose','pose_landmarker_heavy')]:
        path = library.resolve(key, kind)
        validate_bundle(path, kind)
        config = replace(TrackingConfig(backend='cpu'), **{kind+'_model': key})
        feature = 'hands' if kind == 'hand' else kind
        features = {name: name == feature for name in ('face','iris','hands','pose')}
        cpu = WebProcessor(config)
        cpu.enable_tracking(feature, True)
        try:
            result = cpu.process(rgb, is_rgb=True)
            if kind == 'face': assert len(result['face']) == 478
            if kind == 'pose': assert len(result['pose']) == 33
        finally: cpu.cleanup()
        gpu = BrowserTracker(config, features)
        try:
            for _ in range(4): result = gpu.process(rgb, timeout=25)
            if kind == 'face': assert len(result['face']) == 478
            if kind == 'pose': assert len(result['pose']) == 33
            print(f'{key}: native CPU and browser GPU passed; GPU task {gpu.inference_ms:.1f} ms', flush=True)
        finally: gpu.close()
    with tempfile.TemporaryDirectory(dir=ROOT/'artifacts', prefix='model-import-') as directory:
        imported = ModelLibrary(directory)
        with library.resolve('face_landmarker','face').open('rb') as source:
            imported.import_stream(source,'face','compatible-face.task')
        imported.thread.join(30)
        status = imported.snapshot()['job']
        assert status['state'] == 'ready', status
        assert ModelLibrary(directory).resolve(status['id'],'face').is_file()
    print('MODEL_LIBRARY: official downloads, all five CPU/GPU bundles, and persisted compatible import passed.')


if __name__ == '__main__': main()
