"""Demand-driven person masks; capture and landmark inference never wait for these."""
import hashlib
import struct
import threading
import time
import urllib.request

import numpy as np

MODEL = 'selfie_segmenter_landscape.tflite'
MODEL_SHA = '490e9ea734313e0de10fa0cd9e3c6133e36ea4db2b7a49bde9ef019f72796b8e'
MODEL_URL = 'https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter_landscape/float16/1/' + MODEL
WIDTH, HEIGHT = 256, 144
MODELS = {
    'fast': (MODEL, MODEL_SHA, MODEL_URL, 256, 144),
    'balanced': ('selfie_segmenter.tflite', '191ac9529ae506ee0beefa6b2c945a172dab9d07d1e802a290a4e4038226658b',
                 'https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/1/selfie_segmenter.tflite', 256, 256),
}
HEADER = struct.Struct('<4sHHQQf')


def model_path(quality='fast'):
    from tracking.models import library
    name, digest, url, _, _ = MODELS[quality]
    path = library.directory / name
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == digest:
        return path
    temporary = path.with_suffix('.portrait-download')
    try:
        with urllib.request.urlopen(url, timeout=15) as response:
            data = response.read(1024 * 1024 + 1)
        if len(data) > 1024 * 1024 or hashlib.sha256(data).hexdigest() != digest:
            raise ValueError('Background model verification failed. Toggle blur to retry.')
        temporary.write_bytes(data)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)
    return path


class PersonSegmenter:
    def __init__(self, quality='fast'):
        import mediapipe as mp
        from mediapipe.tasks.python import BaseOptions, vision
        self.mp = mp
        self.width, self.height = MODELS[quality][3:]
        self.task = vision.ImageSegmenter.create_from_options(vision.ImageSegmenterOptions(
            base_options=BaseOptions(model_asset_path=str(model_path(quality))),
            output_category_mask=False, output_confidence_masks=True))

    def process(self, frame):
        rgb = frame.tracking_rgb(self.width, self.height)
        image = self.mp.Image(image_format=self.mp.ImageFormat.SRGB, data=rgb)
        masks = self.task.segment(image).confidence_masks
        # This pinned binary SelfieSegmenter exports one foreground channel.
        confidence = masks[-1].numpy_view()
        return np.clip(confidence * 255, 0, 255).astype(np.uint8).tobytes()

    def close(self):
        self.task.close()


class PortraitWorker:
    LEASE_SECONDS = 2.0

    def __init__(self, camera_getter, factory=PersonSegmenter):
        self.camera_getter, self.factory = camera_getter, factory
        self.lock = threading.Lock()
        self.thread = None
        self.wake = threading.Event()
        self.deadline = 0.0
        self.rate = 30
        self.quality = 'fast'
        self.generation = 0
        self.packet_generation = -1
        self.packet = None
        self.packet_source = ''
        self.state = 'Off'
        self.error = ''
        self.inference_ms = 0.0
        self.frames = 0

    def request(self, source, rate, quality='fast'):
        with self.lock:
            if quality != self.quality:
                self.quality = quality
                self.generation += 1
                self.packet = None
                self.error = ''
                self.wake.set()
            self.deadline = time.monotonic() + self.LEASE_SECONDS
            self.rate = rate
            if self.thread is None and not self.error:
                self.state = 'Preparing background blur…'
                self.thread = threading.Thread(target=self._run, name='LenzForge-Portrait', daemon=True)
                self.thread.start()
            packet = self.packet if source == self.packet_source and self.packet_generation == self.generation else None
            return packet, dict(state=self.state, error=self.error, inference_ms=self.inference_ms, frames=self.frames)

    def stop(self):
        with self.lock:
            self.deadline = 0
            self.generation += 1
            self.packet = None
            self.error = ''
        self.wake.set()

    def _run(self):
        task = None
        last_key = None
        task_quality = None
        try:
            from ipc.qpc import get_qpc_frequency
            frequency = get_qpc_frequency()
            while True:
                began = time.monotonic()
                with self.lock:
                    if began >= self.deadline: break
                    rate = self.rate
                    quality, generation = self.quality, self.generation
                if task_quality != quality:
                    if task: task.close(); task = None
                    task = self.factory(quality)
                    task_quality = quality
                    last_key = None
                width, height = MODELS[quality][3:]
                camera = self.camera_getter()
                frame = camera.wait_frame(timeout=0) if camera and camera.is_opened() else None
                if frame is not None:
                    key = (camera.video_buffer, frame[0], generation)
                    if key != last_key:
                        last_key = key
                        started = time.perf_counter()
                        mask = task.process(frame[2])
                        elapsed = (time.perf_counter()-started)*1000
                        if len(mask) != width*height: raise ValueError('Unexpected person mask dimensions.')
                        packet = HEADER.pack(b'MSK1', width, height, frame[1]*1000000//frequency, frame[0], elapsed) + mask
                        with self.lock:
                            if generation == self.generation and time.monotonic() < self.deadline and camera is self.camera_getter():
                                self.packet, self.packet_source = packet, key[0]
                                self.packet_generation = generation
                                self.inference_ms = elapsed
                                self.frames += 1
                                self.state = 'Background blur ready'
                else:
                    with self.lock:
                        self.packet = None
                        self.state = 'Start camera capture for background blur.'
                self.wake.wait(max(0,1/rate-(time.monotonic()-began)))
                self.wake.clear()
        except Exception as exc:
            with self.lock:
                self.error = str(exc).splitlines()[0][:220]
                self.state = 'Background blur unavailable. Toggle blur to retry.'
        finally:
            if task: task.close()
            with self.lock:
                self.packet = None
                self.packet_source = ''
                self.thread = None
                if not self.error: self.state = 'Off'
