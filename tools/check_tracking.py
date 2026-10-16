"""Exercise real browser GPU models, configuration, and crash fallback locally."""
from dataclasses import replace
import json
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ['MPLCONFIGDIR'] = str(ROOT / 'artifacts' / 'matplotlib')
import cv2
import matplotlib
import numpy as np
from pipeline.tracking_config import TrackingConfig
from tracking.browser_tracker import BrowserTracker
from tracking.engine import TrackingEngine


def main():
    image = cv2.imread(str(Path(matplotlib.get_data_path()) / 'sample_data/grace_hopper.jpg'))
    image = cv2.cvtColor(cv2.resize(image, (384, 450)), cv2.COLOR_BGR2RGB)
    config = TrackingConfig(backend='gpu')
    features = dict(face=True, iris=True, hands=False, pose=False)
    task = BrowserTracker(config, features)
    try:
        result = task.process(image, timeout=25)
        assert len(result['face']) == 478 and len(result['blendshapes']) == 52
        matrix = np.array(result['face_transform'])
        assert matrix.shape == (4, 4) and np.allclose(matrix[3], [0, 0, 0, 1], atol=.001), matrix
        task.configure(replace(config, num_faces=2, detection_confidence=0,
                               blendshapes=False, face_transform=False), features)
        result = task.process(image, timeout=25)
        assert len(result['face']) == 478 and 'blendshapes' not in result and 'face_transform' not in result
        all_features = dict(face=True, iris=True, hands=True, pose=True)
        task.configure(config, all_features)
        result = task.process(image, timeout=25)
        assert len(result['face']) == 478
        # Re-enable a closed task, exercising the ESM loader cache boundary.
        task.configure(config, dict(face=False, iris=False, hands=False, pose=False))
        task.configure(config, features)
        assert len(task.process(image, timeout=4)['face']) == 478
        print('GPU models, optional outputs, zero thresholds, and reconfiguration passed.', flush=True)
    finally:
        task.close()
    engine = TrackingEngine(config, features)
    try:
        deadline = time.monotonic() + 30
        cpu_during_startup = 0
        while time.monotonic() < deadline:
            result = engine.process(image)
            assert len(result.get('face', [])) == 478
            if engine.status()['active_backend'] == 'gpu':
                break
            cpu_during_startup += 1
        assert engine.status()['active_backend'] == 'gpu', engine.status()
        assert cpu_during_startup > 0
        engine.gpu.browser_process.terminate()
        engine.gpu.browser_process.wait(timeout=3)
        result = engine.process(image)
        assert engine.status()['active_backend'] == 'cpu' and engine.status()['fallback_reason']
        assert len(result['face']) == 478
        print('CPU stayed live during GPU startup; browser termination recovered to CPU.', flush=True)
    finally:
        engine.close()


if __name__ == '__main__':
    main()
