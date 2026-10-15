import subprocess
import pytest
from capture import enumerator


def test_windows_discovery_helper_returns_unique_device_identities():
    # Safe on CI with no webcam: enumeration never activates capture devices.
    devices = enumerator.enumerate_cameras()
    assert [camera.id for camera in devices] == list(range(len(devices)))
    assert all(camera.name and camera.device_id for camera in devices)
    assert len({camera.device_id for camera in devices}) == len(devices)


def test_discovery_timeout_has_bounded_wait(monkeypatch):
    def timeout(*args, **kwargs):
        assert kwargs['timeout'] == 5
        raise subprocess.TimeoutExpired(args[0], 5)
    monkeypatch.setattr(subprocess, 'run', timeout)
    with pytest.raises(RuntimeError, match='timed out'):
        enumerator.enumerate_cameras()
