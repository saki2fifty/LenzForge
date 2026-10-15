"""Fast Windows device discovery without opening or interrupting any camera."""
from dataclasses import dataclass
import json
from pathlib import Path
import subprocess


@dataclass
class CameraInfo:
    id: int
    name: str
    device_id: str = ''
    backend: str = 'MSMF'


DEVICE_TOOL = Path(__file__).resolve().parents[1] / 'native' / 'camera_devices.exe'


def enumerate_cameras():
    if not DEVICE_TOOL.is_file():
        raise RuntimeError('Camera discovery is missing. Run Setup.ps1 -SkipInstall to build it.')
    try:
        result = subprocess.run([str(DEVICE_TOOL)], capture_output=True, text=True,
                                encoding='utf-8', timeout=5, creationflags=subprocess.CREATE_NO_WINDOW)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or 'Windows could not list cameras')
        return [CameraInfo(c['index'], c['name'], c['device_id']) for c in json.loads(result.stdout)]
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError('Windows camera discovery timed out. Check your camera drivers.') from exc
    except (OSError, ValueError, KeyError) as exc:
        raise RuntimeError('Camera discovery failed. Run Setup.ps1 -SkipInstall and try again.') from exc
