"""Compare warmed CPU inference and browser GPU round trips on identical frames.

Uses Matplotlib's public-domain portrait; never opens a camera or saves images.
"""
import argparse
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
import psutil
from pipeline.tracking_config import TrackingConfig
from pipeline.web_processor import WebProcessor
from tracking.browser_tracker import BrowserTracker


def measure(task, images, warmup, frames):
    elapsed, model, points = [], [], []
    stages = {}
    processes = [psutil.Process()]
    if isinstance(task, BrowserTracker):
        browser = psutil.Process(task.browser_process.pid)
        processes += [browser, *browser.children(recursive=True)]
    def cpu_seconds():
        total = 0
        for process in processes:
            try:
                usage = process.cpu_times()
                total += usage.user + usage.system
            except psutil.Error:
                pass
        return total
    for index in range(warmup + frames):
        if index == warmup:
            cpu_start = cpu_seconds()
        start = time.perf_counter()
        result = task.process(images[index % len(images)], is_rgb=True) if isinstance(task, WebProcessor) else task.process(images[index % len(images)], timeout=4.0)
        ms = (time.perf_counter() - start) * 1000
        if index >= warmup:
            elapsed.append(ms)
            model.append(getattr(task, 'inference_ms', ms))
            points.append(len(result.get('face', [])))
            for key, value in getattr(task, 'timings', {}).items(): stages.setdefault(key, []).append(value)
    def summary(values):
        return {name: round(float(value), 3) for name, value in
                [('mean_ms', np.mean(values)), ('p50_ms', np.median(values)), ('p95_ms', np.percentile(values, 95))]}
    return {'round_trip': summary(elapsed), 'model': summary(model), 'face_frames': points.count(478), 'frames': frames,
            'process_cpu_ms_per_frame': round((cpu_seconds() - cpu_start) * 1000 / frames, 3),
            'stages': {key: summary(values) for key, values in stages.items()}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frames', type=int, default=150)
    parser.add_argument('--warmup', type=int, default=25)
    parser.add_argument('--width', type=int, default=640)
    parser.add_argument('--height', type=int, default=360)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--landmarks-only', action='store_true')
    parser.add_argument('--browser-cpu', action='store_true', help='Also compare WASM CPU through the identical browser bridge')
    args = parser.parse_args()
    image = cv2.imread(str(Path(matplotlib.get_data_path()) / 'sample_data/grace_hopper.jpg'))
    scale = min(args.width / image.shape[1], args.height / image.shape[0])
    resized = cv2.resize(image, (round(image.shape[1] * scale), round(image.shape[0] * scale)))
    image = np.zeros((args.height, args.width, 3), dtype=np.uint8)
    left, top = (args.width - resized.shape[1]) // 2, (args.height - resized.shape[0]) // 2
    image[top:top + resized.shape[0], left:left + resized.shape[1]] = resized
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    height, width = image.shape[:2]
    images = [cv2.warpAffine(image, np.float32([[1, 0, i - 3], [0, 1, 0]]), (width, height)) for i in range(7)]
    config = TrackingConfig(blendshapes=not args.landmarks_only, face_transform=not args.landmarks_only)
    features = dict(face=True, iris=True, hands=False, pose=False)
    report = {'input': 'Matplotlib public-domain portrait with small deterministic translations',
              'width': width, 'height': height, 'warmup': args.warmup, 'settings': config.to_dict()}
    for name in (('cpu', 'browser_cpu', 'gpu', 'cpu_repeat') if args.browser_cpu else ('cpu', 'gpu', 'cpu_repeat')):
        start = time.perf_counter()
        task = BrowserTracker(config, features, delegate='CPU' if name == 'browser_cpu' else 'GPU') if name in ('gpu', 'browser_cpu') else WebProcessor(replace(config, backend='cpu'))
        try:
            if isinstance(task, WebProcessor):
                task.enable_tracking('face', True)
                task.enable_tracking('iris', True)
            report[name] = measure(task, images, args.warmup, args.frames)
            report[name]['startup_and_run_s'] = round(time.perf_counter() - start, 3)
            if isinstance(task, BrowserTracker):
                report[name]['renderer'] = task.renderer
            print(name, json.dumps(report[name]), flush=True)
        finally:
            task.close() if isinstance(task, BrowserTracker) else task.cleanup()
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
