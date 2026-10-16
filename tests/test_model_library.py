import hashlib
import io
import threading

import pytest
from tracking import models


@pytest.fixture
def library(tmp_path, monkeypatch):
    data = b'test-versioned-model'
    monkeypatch.setattr(models, 'OFFICIAL', {'test': ('pose', 'Test pose', len(data), hashlib.sha256(data).hexdigest())})
    monkeypatch.setattr(models.urllib.request, 'urlopen', lambda *a, **k: io.BytesIO(data))
    return models.ModelLibrary(tmp_path)


def finish(library):
    library.thread.join(5)
    assert not library.thread.is_alive()
    return library.snapshot()['job']


def test_download_and_checksum(library):
    assert not library.snapshot()['models'][0]['installed']
    library.download('test')
    assert finish(library)['state'] == 'ready'
    assert library.snapshot()['models'][0]['installed']
    assert library.resolve('test', 'pose').read_bytes() == b'test-versioned-model'
    with pytest.raises(ValueError): library.resolve('test', 'face')
    with pytest.raises(ValueError): library.resolve('../test', 'pose')
    with pytest.raises(ValueError): library.download('https://other.invalid/model')
    library.resolve('test', 'pose').write_bytes(b'corrupt')
    with pytest.raises(ValueError, match='verification'): library.resolve('test', 'pose')


def test_failed_download_preserves_model(library, monkeypatch):
    library.download('test'); finish(library)
    path = library.resolve('test', 'pose')
    monkeypatch.setattr(models.urllib.request, 'urlopen', lambda *a, **k: io.BytesIO(b'wrong model bytes!!'))
    library.download('test')
    assert finish(library)['state'] == 'error'
    assert path.read_bytes() == b'test-versioned-model'
    assert not list(library.directory.glob('*.partial'))


def test_import_validation_and_restart(library, monkeypatch):
    observed = []
    monkeypatch.setattr(models, 'validate_bundle', lambda path, kind: observed.append((path.read_bytes(), kind)))
    library.import_stream(io.BytesIO(b'my bundle'), 'face', '../../name.task')
    job = finish(library)
    assert job['state'] == 'ready'
    assert observed == [(b'my bundle', 'face')]
    restored = models.ModelLibrary(library.directory)
    assert restored.resolve(job['id'], 'face').read_bytes() == b'my bundle'
    assert restored.custom[job['id']]['label'] == 'name.task'
    with pytest.raises(ValueError): restored.resolve(job['id'], 'pose')
    assert not (library.directory.parent / 'name.task').exists()


def test_import_rejects_wrong_bundle(library):
    library.import_stream(io.BytesIO(b'not a task'), 'face', 'broken.task')
    assert finish(library)['state'] == 'error'
    assert not library.custom and not list(library.directory.glob('*.partial'))
    with pytest.raises(ValueError): library.import_stream(io.BytesIO(b''), 'other', 'x.task')


def test_busy_download_does_not_spawn_another(library, monkeypatch):
    started, release = threading.Event(), threading.Event()
    def slow(*args, **kwargs):
        started.set()
        assert release.wait(3)
        return io.BytesIO(b'test-versioned-model')
    monkeypatch.setattr(models.urllib.request, 'urlopen', slow)
    library.download('test')
    assert started.wait(1)
    try:
        with pytest.raises(RuntimeError): library.download('test')
        assert library.snapshot()['job']['state'] == 'downloading'
    finally:
        release.set()
    assert finish(library)['state'] == 'ready'


def test_model_api_and_atomic_selection(library, monkeypatch):
    from server.app import create_app
    from server.routes import tracking
    from pipeline.tracking_config import get_tracking_config
    monkeypatch.setattr(tracking, 'library', library)
    monkeypatch.setattr(models, 'library', library)
    client = create_app({'TESTING': True}).test_client()
    before = get_tracking_config()
    assert client.post('/api/tracking/configure', json={'pose_model': 'test'}).status_code == 400
    assert get_tracking_config() == before
    assert client.post('/api/tracking/models/download', json={'id': 'test'}).status_code == 202
    finish(library)
    assert client.get('/api/tracking/models').json['models'][0]['installed']
    assert client.post('/api/tracking/configure', json={'pose_model': 'test'}).status_code == 200
    assert get_tracking_config()[0].pose_model == 'test'
    assert client.post('/api/tracking/configure', json={'face_model': 'test'}).status_code == 400
    assert client.post('/api/tracking/models/import?kind=face&name=bad.task', data=b'bad', content_type='application/octet-stream').status_code == 202
    assert finish(library)['state'] == 'error'
