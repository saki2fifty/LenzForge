"""
Edge Detection effects for LenzForge backend v2

Provides 4 types of edge detection algorithms.
"""
import cv2
import numpy as np
from .base import Effect


class CannyEdgeEffect(Effect):
    """
    Canny Edge Detection

    Multi-stage algorithm for detecting edges.
    Most popular edge detection method.
    """

    def _register_parameters(self):
        self._add_parameter(
            'threshold1', int, 100, 0, 255,
            'First threshold for hysteresis'
        )
        self._add_parameter(
            'threshold2', int, 200, 0, 255,
            'Second threshold for hysteresis'
        )
        self._add_parameter(
            'aperture_size', int, 3, 3, 7,
            'Sobel kernel aperture size (3, 5, or 7)'
        )
        self._add_parameter(
            'l2_gradient', bool, False,
            'Use L2 norm for gradient (more accurate but slower)'
        )
        self._add_parameter(
            'colorize', bool, False,
            'Output white edges on black background'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        threshold1 = self.get_parameter('threshold1')
        threshold2 = self.get_parameter('threshold2')
        aperture_size = self.get_parameter('aperture_size')
        l2_gradient = self.get_parameter('l2_gradient')
        colorize = self.get_parameter('colorize')

        # Ensure aperture size is odd and in valid range
        aperture_size = max(3, min(7, aperture_size))
        if aperture_size % 2 == 0:
            aperture_size += 1

        # Convert to grayscale
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # Apply Canny
        edges = cv2.Canny(
            gray,
            threshold1,
            threshold2,
            apertureSize=aperture_size,
            L2gradient=l2_gradient
        )

        if colorize:
            # Return as BGR
            return cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)
        else:
            # Invert and return as BGR
            edges_inv = cv2.bitwise_not(edges)
            return cv2.cvtColor(edges_inv, cv2.COLOR_GRAY2BGR)

    @classmethod
    def get_category(cls) -> str:
        return "Edge Detection"

    @classmethod
    def get_description(cls) -> str:
        return "Canny edge detection with adjustable thresholds"


class SobelEdgeEffect(Effect):
    """
    Sobel Edge Detection

    Uses Sobel operators to find edges.
    Can detect horizontal, vertical, or both.
    """

    def _register_parameters(self):
        self._add_parameter(
            'direction', str, 'both',
            'Direction: x, y, or both'
        )
        self._add_parameter(
            'kernel_size', int, 3, 1, 31,
            'Sobel kernel size (1, 3, 5, 7, etc.)'
        )
        self._add_parameter(
            'scale', float, 1.0, 0.1, 10.0,
            'Scale factor for computed derivative'
        )
        self._add_parameter(
            'delta', int, 0, -255, 255,
            'Delta value added to results'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        direction = self.get_parameter('direction')
        kernel_size = self.get_parameter('kernel_size')
        scale = self.get_parameter('scale')
        delta = self.get_parameter('delta')

        # Ensure kernel size is odd
        if kernel_size > 1 and kernel_size % 2 == 0:
            kernel_size += 1
        kernel_size = max(1, min(31, kernel_size))

        # Convert to grayscale
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        if direction == 'x':
            sobel = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=kernel_size, scale=scale, delta=delta)
        elif direction == 'y':
            sobel = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=kernel_size, scale=scale, delta=delta)
        else:  # both
            sobel_x = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=kernel_size, scale=scale, delta=delta)
            sobel_y = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=kernel_size, scale=scale, delta=delta)
            sobel = cv2.magnitude(sobel_x, sobel_y)

        # Convert back to uint8
        sobel = np.absolute(sobel)
        sobel = np.clip(sobel, 0, 255).astype(np.uint8)

        return cv2.cvtColor(sobel, cv2.COLOR_GRAY2BGR)

    @classmethod
    def get_category(cls) -> str:
        return "Edge Detection"

    @classmethod
    def get_description(cls) -> str:
        return "Sobel edge detection with directional control"


class LaplacianEdgeEffect(Effect):
    """
    Laplacian Edge Detection

    Detects regions of rapid intensity change.
    Good for finding edges in all directions.
    """

    def _register_parameters(self):
        self._add_parameter(
            'kernel_size', int, 3, 1, 31,
            'Laplacian kernel size (1, 3, 5, 7, etc.)'
        )
        self._add_parameter(
            'scale', float, 1.0, 0.1, 10.0,
            'Scale factor for computed derivative'
        )
        self._add_parameter(
            'delta', int, 0, -255, 255,
            'Delta value added to results'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        kernel_size = self.get_parameter('kernel_size')
        scale = self.get_parameter('scale')
        delta = self.get_parameter('delta')

        # Ensure kernel size is odd
        if kernel_size > 1 and kernel_size % 2 == 0:
            kernel_size += 1
        kernel_size = max(1, min(31, kernel_size))

        # Convert to grayscale
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # Apply Laplacian
        laplacian = cv2.Laplacian(
            gray,
            cv2.CV_64F,
            ksize=kernel_size,
            scale=scale,
            delta=delta
        )

        # Convert back to uint8
        laplacian = np.absolute(laplacian)
        laplacian = np.clip(laplacian, 0, 255).astype(np.uint8)

        return cv2.cvtColor(laplacian, cv2.COLOR_GRAY2BGR)

    @classmethod
    def get_category(cls) -> str:
        return "Edge Detection"

    @classmethod
    def get_description(cls) -> str:
        return "Laplacian edge detection for all directions"


class ScharrEdgeEffect(Effect):
    """
    Scharr Edge Detection

    More accurate than Sobel for small kernels.
    Uses optimized 3x3 kernels.
    """

    def _register_parameters(self):
        self._add_parameter(
            'direction', str, 'both',
            'Direction: x, y, or both'
        )
        self._add_parameter(
            'scale', float, 1.0, 0.1, 10.0,
            'Scale factor for computed derivative'
        )
        self._add_parameter(
            'delta', int, 0, -255, 255,
            'Delta value added to results'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        direction = self.get_parameter('direction')
        scale = self.get_parameter('scale')
        delta = self.get_parameter('delta')

        # Convert to grayscale
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        if direction == 'x':
            scharr = cv2.Scharr(gray, cv2.CV_64F, 1, 0, scale=scale, delta=delta)
        elif direction == 'y':
            scharr = cv2.Scharr(gray, cv2.CV_64F, 0, 1, scale=scale, delta=delta)
        else:  # both
            scharr_x = cv2.Scharr(gray, cv2.CV_64F, 1, 0, scale=scale, delta=delta)
            scharr_y = cv2.Scharr(gray, cv2.CV_64F, 0, 1, scale=scale, delta=delta)
            scharr = cv2.magnitude(scharr_x, scharr_y)

        # Convert back to uint8
        scharr = np.absolute(scharr)
        scharr = np.clip(scharr, 0, 255).astype(np.uint8)

        return cv2.cvtColor(scharr, cv2.COLOR_GRAY2BGR)

    @classmethod
    def get_category(cls) -> str:
        return "Edge Detection"

    @classmethod
    def get_description(cls) -> str:
        return "Scharr edge detection (more accurate than Sobel for 3x3)"
