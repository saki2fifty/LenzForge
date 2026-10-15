"""
Face-specific effects for LenzForge backend v2

Provides 3 types of face enhancement effects.
Requires face landmarks from MediaPipe.
"""
import cv2
import numpy as np
from typing import Optional, List, Tuple
from .base import Effect


class BeautyModeEffect(Effect):
    """
    Beauty Mode Effect

    Smooths skin while preserving facial features.
    """

    def __init__(self):
        super().__init__()
        self.face_landmarks: Optional[List[Tuple[float, float]]] = None

    def _register_parameters(self):
        self._add_parameter(
            'smoothing', int, 50, 0, 100,
            'Skin smoothing amount (0-100)'
        )
        self._add_parameter(
            'brightening', int, 10, 0, 50,
            'Skin brightening amount (0-50)'
        )
        self._add_parameter(
            'preserve_detail', bool, True,
            'Preserve facial features (eyes, mouth, nose)'
        )

    def set_face_landmarks(self, landmarks: List[Tuple[float, float]]):
        """Set face landmarks for processing"""
        self.face_landmarks = landmarks

    def apply(self, frame: np.ndarray) -> np.ndarray:
        smoothing = self.get_parameter('smoothing')
        brightening = self.get_parameter('brightening')
        preserve_detail = self.get_parameter('preserve_detail')

        if smoothing == 0 and brightening == 0:
            return frame

        # Apply bilateral filter for skin smoothing
        if smoothing > 0:
            d = int(5 + smoothing / 10)
            sigma_color = 20 + smoothing * 2
            sigma_space = 20 + smoothing * 2
            smoothed = cv2.bilateralFilter(frame, d, sigma_color, sigma_space)

            if preserve_detail and self.face_landmarks:
                # Create mask to preserve facial features
                h, w = frame.shape[:2]
                mask = np.ones((h, w), dtype=np.uint8) * 255

                # Mark areas to preserve (eyes, mouth) - simplified
                # In production, would use specific landmark indices
                for x, y in self.face_landmarks[:68]:  # First 68 are contour
                    cv2.circle(mask, (int(x * w), int(y * h)), 5, 0, -1)

                mask = cv2.GaussianBlur(mask, (21, 21), 0).astype(np.float32) / 255.0
                mask_3ch = np.stack([mask] * 3, axis=2)

                result = (smoothed * mask_3ch + frame * (1 - mask_3ch)).astype(np.uint8)
            else:
                result = smoothed
        else:
            result = frame.copy()

        # Apply brightening
        if brightening > 0:
            result = cv2.convertScaleAbs(result, alpha=1.0, beta=brightening)

        return result

    @classmethod
    def get_category(cls) -> str:
        return "Face"

    @classmethod
    def get_description(cls) -> str:
        return "Beauty mode with skin smoothing and brightening"


class FaceReshapeEffect(Effect):
    """
    Face Reshape Effect

    Subtly reshape facial features.
    """

    def __init__(self):
        super().__init__()
        self.face_landmarks: Optional[List[Tuple[float, float]]] = None

    def _register_parameters(self):
        self._add_parameter(
            'face_slimming', int, 0, 0, 100,
            'Face slimming amount (0-100)'
        )
        self._add_parameter(
            'eye_enlargement', int, 0, 0, 100,
            'Eye enlargement amount (0-100)'
        )

    def set_face_landmarks(self, landmarks: List[Tuple[float, float]]):
        """Set face landmarks for processing"""
        self.face_landmarks = landmarks

    def apply(self, frame: np.ndarray) -> np.ndarray:
        if self.face_landmarks is None:
            return frame

        slimming = self.get_parameter('face_slimming')
        eye_enlarge = self.get_parameter('eye_enlargement')

        if slimming == 0 and eye_enlarge == 0:
            return frame

        h, w = frame.shape[:2]
        result = frame.copy()

        # This is a simplified version
        # Production would use proper mesh warping based on landmarks

        if slimming > 0:
            # Create a subtle pincushion effect for face slimming
            center_x, center_y = w // 2, h // 2
            strength = -slimming / 500.0

            map_x = np.zeros((h, w), dtype=np.float32)
            map_y = np.zeros((h, w), dtype=np.float32)

            for y in range(h):
                for x in range(w):
                    dx = x - center_x
                    dy = y - center_y
                    r = np.sqrt(dx**2 + dy**2)

                    if r == 0:
                        map_x[y, x] = x
                        map_y[y, x] = y
                        continue

                    max_r = np.sqrt(center_x**2 + center_y**2)
                    r_norm = r / max_r
                    r_new = r_norm * (1.0 + strength * r_norm**2)
                    r_new = r_new * max_r

                    scale = r_new / r if r > 0 else 0
                    map_x[y, x] = center_x + dx * scale
                    map_y[y, x] = center_y + dy * scale

            result = cv2.remap(result, map_x, map_y, cv2.INTER_LINEAR)

        return result

    @classmethod
    def get_category(cls) -> str:
        return "Face"

    @classmethod
    def get_description(cls) -> str:
        return "Subtly reshape facial features"


class MakeupEffect(Effect):
    """
    Makeup Effect

    Apply virtual makeup (simplified version).
    """

    def __init__(self):
        super().__init__()
        self.face_landmarks: Optional[List[Tuple[float, float]]] = None

    def _register_parameters(self):
        self._add_parameter(
            'lipstick_intensity', int, 0, 0, 100,
            'Lipstick intensity (0-100)'
        )
        self._add_parameter(
            'lipstick_r', int, 200, 0, 255,
            'Lipstick red value'
        )
        self._add_parameter(
            'lipstick_g', int, 50, 0, 255,
            'Lipstick green value'
        )
        self._add_parameter(
            'lipstick_b', int, 50, 0, 255,
            'Lipstick blue value'
        )
        self._add_parameter(
            'blush_intensity', int, 0, 0, 100,
            'Blush intensity (0-100)'
        )

    def set_face_landmarks(self, landmarks: List[Tuple[float, float]]):
        """Set face landmarks for processing"""
        self.face_landmarks = landmarks

    def apply(self, frame: np.ndarray) -> np.ndarray:
        if self.face_landmarks is None:
            return frame

        lipstick_intensity = self.get_parameter('lipstick_intensity')
        blush_intensity = self.get_parameter('blush_intensity')

        if lipstick_intensity == 0 and blush_intensity == 0:
            return frame

        h, w = frame.shape[:2]
        result = frame.copy()

        # This is a highly simplified version
        # Production would use proper landmark-based masking

        if lipstick_intensity > 0:
            lipstick_r = self.get_parameter('lipstick_r')
            lipstick_g = self.get_parameter('lipstick_g')
            lipstick_b = self.get_parameter('lipstick_b')

            # Create lipstick color overlay
            lipstick_color = np.array([lipstick_b, lipstick_g, lipstick_r], dtype=np.uint8)
            overlay = np.full_like(frame, lipstick_color)

            # Create mask for lip region (simplified - would use landmarks in production)
            mask = np.zeros((h, w), dtype=np.float32)

            if len(self.face_landmarks) > 60:
                # Approximate lip center (would use specific indices in production)
                lip_points = [(int(x * w), int(y * h)) for x, y in self.face_landmarks[48:68]]
                if lip_points:
                    cv2.fillPoly(mask, [np.array(lip_points)], 1.0)
                    mask = cv2.GaussianBlur(mask, (15, 15), 0)

            # Apply lipstick
            alpha = (lipstick_intensity / 100.0) * mask
            alpha_3ch = np.stack([alpha] * 3, axis=2)
            result = (result * (1 - alpha_3ch) + overlay * alpha_3ch).astype(np.uint8)

        # Blush would be implemented similarly

        return result

    @classmethod
    def get_category(cls) -> str:
        return "Face"

    @classmethod
    def get_description(cls) -> str:
        return "Apply virtual makeup (lipstick, blush, etc.)"
