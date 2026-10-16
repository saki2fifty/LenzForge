"""Responsive CPU/GPU selection: CPU stays live while the browser warms up."""
import logging
import queue
import statistics
import threading
import time

from pipeline.web_processor import WebProcessor
from tracking.browser_tracker import BrowserTracker

LOG = logging.getLogger(__name__)


def fallback_message(error):
    text = str(error)
    if isinstance(error, TimeoutError):
        return 'GPU worker stopped responding. Apply settings to retry.'
    if 'close frame' in text:
        return 'GPU browser disconnected. Apply settings to retry.'
    if 'INTERNAL:' in text:
        return 'The browser could not start the selected GPU models. Apply settings to retry.'
    return text.splitlines()[0][:240] if text else type(error).__name__


class TrackingEngine:
    def __init__(self, config, features):
        self.config, self.features = config, features.copy()
        self.cpu = WebProcessor(config)
        for name, enabled in features.items():
            if enabled:
                self.cpu.enable_tracking(name, True)
        self.gpu = None
        self._candidate = None
        self._cancel = threading.Event()
        self._sample = queue.Queue(maxsize=1)
        self._lock = threading.Lock()
        self._thread = None
        self._cleanup_threads = []
        self.model_ms = 0.0
        self._status = {'requested_backend': config.backend, 'active_backend': 'cpu',
                        'phase': 'ready', 'fallback_reason': None, 'renderer': None, 'comparison': None}
        if config.backend != 'cpu' and any(features.values()):
            self._status['phase'] = 'calibrating_cpu' if config.backend == 'auto' else 'starting_gpu'
            self._thread = threading.Thread(target=self._prepare_gpu, daemon=True, name='LenzForge-GPU-Warmup')
            self._thread.start()

    def _set_status(self, **values):
        with self._lock:
            self._status = {**self._status, **values}

    def status(self):
        with self._lock:
            return self._status.copy()

    def _prepare_gpu(self):
        task = None
        try:
            cpu_baseline = []
            if self.config.backend == 'auto':
                # Establish CPU cost before starting another inference engine.
                # Otherwise GPU warmup can slow CPU and bias Auto toward GPU.
                while len(cpu_baseline) < 24 and not self._cancel.is_set():
                    try:
                        _, cpu_ms, detected = self._sample.get(timeout=.1)
                    except queue.Empty:
                        continue
                    if (self.features.get('face') or self.features.get('iris')) and not detected:
                        self._set_status(phase='waiting_for_face')
                        continue
                    self._set_status(phase='calibrating_cpu')
                    cpu_baseline.append(cpu_ms)
                if self._cancel.is_set():
                    return
            self._set_status(phase='starting_gpu')
            task = BrowserTracker(self.config, self.features, self._cancel)
            self._set_status(phase='warming_gpu', renderer=task.renderer)
            samples = []
            face_seen = False
            # CPU keeps publishing while models compile and GPU timing settles.
            # Prefer frames where CPU has found a face so detection-only work
            # doesn't choose a delegate for a different, much cheaper workload.
            count = 0
            while count < 24 and not self._cancel.is_set():
                try:
                    rgb, cpu_ms, detected = self._sample.get(timeout=.1)
                except queue.Empty:
                    continue
                if self.features.get('face') or self.features.get('iris'):
                    if not detected and self.config.backend == 'auto':
                        self._set_status(phase='waiting_for_face')
                        continue
                    face_seen = face_seen or detected
                self._set_status(phase='warming_gpu')
                start = time.perf_counter()
                task.process(rgb, timeout=BrowserTracker.START_TIMEOUT)
                elapsed = (time.perf_counter() - start) * 1000
                if count >= 8:
                    samples.append(elapsed)
                count += 1
                if self.config.backend == 'gpu' and count >= 8:
                    break
            if self._cancel.is_set():
                return
            comparison = None
            use_gpu = True
            if self.config.backend == 'auto':
                cpu_ms = statistics.median(cpu_baseline[8:])
                gpu_ms = statistics.median(samples)
                # A small margin avoids switching for measurement noise. The
                # GPU figure includes the bridge and result conversion costs.
                use_gpu = gpu_ms < cpu_ms * .95
                comparison = {'cpu_p50_ms': round(cpu_ms, 3), 'gpu_p50_ms': round(gpu_ms, 3),
                              'samples': len(samples), 'selected': 'gpu' if use_gpu else 'cpu',
                              'face_seen': face_seen}
            if use_gpu:
                with self._lock:
                    if not self._cancel.is_set():
                        self._candidate = task
                        task = None
                        self._status = {**self._status, 'phase': 'gpu_ready', 'comparison': comparison}
            else:
                self._set_status(phase='ready', comparison=comparison)
        except Exception as exc:
            if not self._cancel.is_set():
                LOG.warning('GPU tracking unavailable; using CPU: %s', exc)
                self._set_status(phase='ready', fallback_reason=fallback_message(exc))
        finally:
            if task:
                task.close()

    def process(self, rgb):
        with self._lock:
            if self._candidate is not None:
                self.gpu, self._candidate = self._candidate, None
                self._status = {**self._status, 'active_backend': 'gpu', 'phase': 'ready'}
        if self.gpu:
            try:
                result = self.gpu.process(rgb)
                self.model_ms = self.gpu.inference_ms
                return result
            except Exception as exc:
                if self._cancel.is_set():
                    return {}
                failed, self.gpu = self.gpu, None
                self._set_status(active_backend='cpu', phase='ready', fallback_reason=fallback_message(exc))
                LOG.warning('GPU tracking failed; switched to CPU: %s', exc)
                closer = threading.Thread(target=failed.close, daemon=True, name='LenzForge-GPU-Cleanup')
                closer.start()
                self._cleanup_threads.append(closer)
        start = time.perf_counter()
        result = self.cpu.process(rgb, is_rgb=True)
        self.model_ms = (time.perf_counter() - start) * 1000
        if self._thread and self._thread.is_alive():
            try:
                self._sample.get_nowait()
            except queue.Empty:
                pass
            self._sample.put_nowait((rgb, self.model_ms, bool(result.get('face') or result.get('iris'))))
        return result

    def cancel(self):
        self._cancel.set()

    def close(self):
        self.cancel()
        if self._thread:
            self._thread.join(timeout=8)
        with self._lock:
            candidate, self._candidate = self._candidate, None
        for task in (candidate, self.gpu):
            if task:
                task.close()
        self.gpu = None
        self.cpu.cleanup()
        for closer in self._cleanup_threads:
            closer.join(timeout=5)
