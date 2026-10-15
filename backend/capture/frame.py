"""Immutable camera frame with color conversion performed only by consumers."""
import threading
import cv2
import numpy as np


class VideoFrame:
    def __init__(self, data, width, height, pixel_format='BGR'):
        self.width, self.height = width, height
        self.pixel_format = pixel_format
        self.data = data
        if pixel_format == 'NV12':
            if data.dtype != np.uint8 or data.size != width * height * 3 // 2 or not data.flags.c_contiguous:
                raise ValueError('Native NV12 frame size or layout changed')
            self.data = data.reshape(height * 3 // 2, width)
        elif pixel_format != 'BGR' or data.shape != (height, width, 3):
            raise ValueError('BGR frame size or layout changed')
        self._bgr = self.data if pixel_format == 'BGR' else None
        self._lock = threading.Lock()

    def nv12_planes(self):
        pixels = self.width * self.height
        view = memoryview(self.data).cast('B')
        return view[:pixels], view[pixels:]

    def to_bgr(self):
        with self._lock:
            if self._bgr is None:
                self._bgr = cv2.cvtColor(self.data, cv2.COLOR_YUV2BGR_NV12)
            return self._bgr

    def tracking_rgb(self, width, height):
        if self.pixel_format == 'NV12':
            y = self.data[:self.height]
            uv = self.data[self.height:].reshape(self.height // 2, self.width // 2, 2)
            if width != self.width or height != self.height:
                y = cv2.resize(y, (width, height), interpolation=cv2.INTER_AREA)
                uv = cv2.resize(uv, (width // 2, height // 2), interpolation=cv2.INTER_AREA)
            return cv2.cvtColorTwoPlane(y, uv, cv2.COLOR_YUV2RGB_NV12)
        frame = self.data
        if width != self.width or height != self.height:
            frame = cv2.resize(frame, (width, height), interpolation=cv2.INTER_AREA)
        return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
