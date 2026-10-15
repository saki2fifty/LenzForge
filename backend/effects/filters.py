"""
Filter effects for LenzForge backend v2

Provides 5 types of filtering effects.
"""
import cv2
import numpy as np
from .base import Effect


class SharpenEffect(Effect):
    """
    Sharpen Effect

    Enhance edges and details in the image.
    """

    def _register_parameters(self):
        self._add_parameter(
            'amount', int, 100, 0, 500,
            'Sharpening amount (percentage)'
        )
        self._add_parameter(
            'radius', float, 1.0, 0.1, 10.0,
            'Radius of sharpening effect'
        )
        self._add_parameter(
            'threshold', int, 0, 0, 255,
            'Threshold to prevent over-sharpening'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        amount = self.get_parameter('amount') / 100.0
        radius = self.get_parameter('radius')
        threshold = self.get_parameter('threshold')

        # Create a Gaussian blur of the image
        blurred = cv2.GaussianBlur(frame, (0, 0), radius)

        # Sharpen = image + amount * (image - blurred)
        sharpened = cv2.addWeighted(frame, 1.0 + amount, blurred, -amount, 0)

        # Apply threshold if specified
        if threshold > 0:
            diff = cv2.absdiff(frame, sharpened)
            mask = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)
            _, mask = cv2.threshold(mask, threshold, 255, cv2.THRESH_BINARY)
            mask = cv2.cvtColor(mask, cv2.COLOR_GRAY2BGR) / 255.0
            sharpened = (sharpened * mask + frame * (1 - mask)).astype(np.uint8)

        return sharpened

    @classmethod
    def get_category(cls) -> str:
        return "Filters"

    @classmethod
    def get_description(cls) -> str:
        return "Sharpen image to enhance details"


class UnsharpMaskEffect(Effect):
    """
    Unsharp Mask Effect

    Professional sharpening technique.
    """

    def _register_parameters(self):
        self._add_parameter(
            'amount', int, 100, 0, 500,
            'Sharpening amount (percentage)'
        )
        self._add_parameter(
            'radius', float, 2.0, 0.1, 10.0,
            'Radius of unsharp mask'
        )
        self._add_parameter(
            'threshold', int, 3, 0, 255,
            'Threshold to avoid sharpening noise'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        amount = self.get_parameter('amount') / 100.0
        radius = self.get_parameter('radius')
        threshold = self.get_parameter('threshold')

        # Create Gaussian blur
        blurred = cv2.GaussianBlur(frame, (0, 0), radius)

        # Calculate sharpened
        sharpened = frame.astype(np.float32)
        blurred_float = blurred.astype(np.float32)

        # Only sharpen where difference exceeds threshold
        diff = sharpened - blurred_float
        mask = np.abs(diff) > threshold

        sharpened = sharpened + (diff * amount * mask)

        return np.clip(sharpened, 0, 255).astype(np.uint8)

    @classmethod
    def get_category(cls) -> str:
        return "Filters"

    @classmethod
    def get_description(cls) -> str:
        return "Unsharp mask for professional sharpening"


class DenoiseEffect(Effect):
    """
    Denoise Effect

    Remove noise while preserving details.
    """

    def _register_parameters(self):
        self._add_parameter(
            'method', str, 'fastNlMeans',
            'Method: fastNlMeans or bilateral'
        )
        self._add_parameter(
            'strength', int, 10, 1, 30,
            'Denoising strength'
        )
        self._add_parameter(
            'template_window_size', int, 7, 3, 21,
            'Template window size (odd, 3/5/7/etc)'
        )
        self._add_parameter(
            'search_window_size', int, 21, 7, 35,
            'Search window size (odd, 7/11/21/etc)'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        method = self.get_parameter('method')
        strength = self.get_parameter('strength')
        template_size = self.get_parameter('template_window_size')
        search_size = self.get_parameter('search_window_size')

        # Ensure sizes are odd
        template_size = template_size if template_size % 2 == 1 else template_size + 1
        search_size = search_size if search_size % 2 == 1 else search_size + 1

        if method == 'bilateral':
            return cv2.bilateralFilter(frame, 9, strength * 2, strength * 2)
        else:  # fastNlMeans
            return cv2.fastNlMeansDenoisingColored(
                frame,
                None,
                strength,
                strength,
                template_size,
                search_size
            )

    @classmethod
    def get_category(cls) -> str:
        return "Filters"

    @classmethod
    def get_description(cls) -> str:
        return "Remove noise while preserving image quality"


class EmbossEffect(Effect):
    """
    Emboss Effect

    Create embossed 3D appearance.
    """

    def _register_parameters(self):
        self._add_parameter(
            'strength', float, 1.0, 0.1, 10.0,
            'Emboss strength'
        )
        self._add_parameter(
            'angle', int, 45, 0, 360,
            'Emboss direction angle'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        strength = self.get_parameter('strength')
        angle = self.get_parameter('angle')

        # Convert angle to radians
        rad = np.radians(angle)

        # Create emboss kernel based on angle
        cos_a = np.cos(rad)
        sin_a = np.sin(rad)

        kernel = np.array([
            [-1 * sin_a - cos_a, -sin_a, sin_a - cos_a],
            [-cos_a, 0, cos_a],
            [sin_a - cos_a, sin_a, sin_a + cos_a]
        ]) * strength

        # Apply kernel
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        embossed = cv2.filter2D(gray, -1, kernel)

        # Normalize and add offset for visibility
        embossed = embossed.astype(np.float32)
        embossed = embossed + 128
        embossed = np.clip(embossed, 0, 255).astype(np.uint8)

        # Convert back to BGR
        return cv2.cvtColor(embossed, cv2.COLOR_GRAY2BGR)

    @classmethod
    def get_category(cls) -> str:
        return "Filters"

    @classmethod
    def get_description(cls) -> str:
        return "Create embossed 3D effect"


class FindEdgesEffect(Effect):
    """
    Find Edges Effect

    Simplified edge detection for artistic purposes.
    """

    def _register_parameters(self):
        self._add_parameter(
            'mode', str, 'all',
            'Mode: all, horizontal, vertical, diagonal'
        )
        self._add_parameter(
            'threshold', int, 50, 0, 255,
            'Edge detection threshold'
        )
        self._add_parameter(
            'invert', bool, False,
            'Invert edge colors'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        mode = self.get_parameter('mode')
        threshold = self.get_parameter('threshold')
        invert = self.get_parameter('invert')

        # Convert to grayscale
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # Apply appropriate kernel
        if mode == 'horizontal':
            kernel = np.array([[-1, -1, -1], [2, 2, 2], [-1, -1, -1]])
        elif mode == 'vertical':
            kernel = np.array([[-1, 2, -1], [-1, 2, -1], [-1, 2, -1]])
        elif mode == 'diagonal':
            kernel = np.array([[2, -1, -1], [-1, 2, -1], [-1, -1, 2]])
        else:  # all
            kernel = np.array([[-1, -1, -1], [-1, 8, -1], [-1, -1, -1]])

        # Apply kernel
        edges = cv2.filter2D(gray, -1, kernel)

        # Apply threshold
        _, edges = cv2.threshold(edges, threshold, 255, cv2.THRESH_BINARY)

        # Invert if requested
        if invert:
            edges = cv2.bitwise_not(edges)

        # Convert to BGR
        return cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)

    @classmethod
    def get_category(cls) -> str:
        return "Filters"

    @classmethod
    def get_description(cls) -> str:
        return "Find and highlight edges in the image"
