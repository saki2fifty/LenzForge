"""
Transform effects for LenzForge backend v2

Provides 4 types of geometric transformation effects.
"""
import cv2
import numpy as np
from .base import Effect


class RotateEffect(Effect):
    """
    Rotate Effect

    Rotate image by specified angle.
    """

    def _register_parameters(self):
        self._add_parameter(
            'angle', float, 0.0, -360.0, 360.0,
            'Rotation angle in degrees (counter-clockwise)'
        )
        self._add_parameter(
            'scale', float, 1.0, 0.1, 3.0,
            'Scale factor during rotation'
        )
        self._add_parameter(
            'auto_crop', bool, False,
            'Automatically crop to remove black borders'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        angle = self.get_parameter('angle')
        scale = self.get_parameter('scale')
        auto_crop = self.get_parameter('auto_crop')

        h, w = frame.shape[:2]
        center = (w // 2, h // 2)

        # Get rotation matrix
        M = cv2.getRotationMatrix2D(center, angle, scale)

        # Calculate new image dimensions if needed
        if auto_crop:
            # Calculate bounding box of rotated image
            cos = np.abs(M[0, 0])
            sin = np.abs(M[0, 1])

            new_w = int((h * sin) + (w * cos))
            new_h = int((h * cos) + (w * sin))

            # Adjust transformation matrix
            M[0, 2] += (new_w / 2) - center[0]
            M[1, 2] += (new_h / 2) - center[1]

            result = cv2.warpAffine(frame, M, (new_w, new_h))
        else:
            result = cv2.warpAffine(frame, M, (w, h))

        return result

    @classmethod
    def get_category(cls) -> str:
        return "Transform"

    @classmethod
    def get_description(cls) -> str:
        return "Rotate image by specified angle"


class FlipEffect(Effect):
    """
    Flip Effect

    Flip image horizontally, vertically, or both.
    """

    def _register_parameters(self):
        self._add_parameter(
            'mode', str, 'horizontal',
            'Flip mode: horizontal, vertical, or both'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        mode = self.get_parameter('mode')

        if mode == 'vertical':
            return cv2.flip(frame, 0)
        elif mode == 'both':
            return cv2.flip(frame, -1)
        else:  # horizontal
            return cv2.flip(frame, 1)

    @classmethod
    def get_category(cls) -> str:
        return "Transform"

    @classmethod
    def get_description(cls) -> str:
        return "Flip image horizontally or vertically"


class PerspectiveEffect(Effect):
    """
    Perspective Transform Effect

    Apply perspective transformation to simulate camera angle changes.
    """

    def _register_parameters(self):
        self._add_parameter(
            'top_left_x', float, 0.0, -0.5, 0.5,
            'Top-left corner X offset (normalized)'
        )
        self._add_parameter(
            'top_left_y', float, 0.0, -0.5, 0.5,
            'Top-left corner Y offset (normalized)'
        )
        self._add_parameter(
            'top_right_x', float, 0.0, -0.5, 0.5,
            'Top-right corner X offset (normalized)'
        )
        self._add_parameter(
            'top_right_y', float, 0.0, -0.5, 0.5,
            'Top-right corner Y offset (normalized)'
        )
        self._add_parameter(
            'bottom_left_x', float, 0.0, -0.5, 0.5,
            'Bottom-left corner X offset (normalized)'
        )
        self._add_parameter(
            'bottom_left_y', float, 0.0, -0.5, 0.5,
            'Bottom-left corner Y offset (normalized)'
        )
        self._add_parameter(
            'bottom_right_x', float, 0.0, -0.5, 0.5,
            'Bottom-right corner X offset (normalized)'
        )
        self._add_parameter(
            'bottom_right_y', float, 0.0, -0.5, 0.5,
            'Bottom-right corner Y offset (normalized)'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        h, w = frame.shape[:2]

        # Get corner offsets
        tl_x = self.get_parameter('top_left_x') * w
        tl_y = self.get_parameter('top_left_y') * h
        tr_x = self.get_parameter('top_right_x') * w
        tr_y = self.get_parameter('top_right_y') * h
        bl_x = self.get_parameter('bottom_left_x') * w
        bl_y = self.get_parameter('bottom_left_y') * h
        br_x = self.get_parameter('bottom_right_x') * w
        br_y = self.get_parameter('bottom_right_y') * h

        # Source points (original corners)
        src_pts = np.float32([[0, 0], [w, 0], [0, h], [w, h]])

        # Destination points (transformed corners)
        dst_pts = np.float32([
            [0 + tl_x, 0 + tl_y],
            [w + tr_x, 0 + tr_y],
            [0 + bl_x, h + bl_y],
            [w + br_x, h + br_y]
        ])

        # Get perspective transform matrix
        M = cv2.getPerspectiveTransform(src_pts, dst_pts)

        # Apply transformation
        result = cv2.warpPerspective(frame, M, (w, h))

        return result

    @classmethod
    def get_category(cls) -> str:
        return "Transform"

    @classmethod
    def get_description(cls) -> str:
        return "Apply perspective transformation"


class WarpEffect(Effect):
    """
    Warp Effect

    Apply various warping effects (fisheye, barrel, pincushion).
    """

    def _register_parameters(self):
        self._add_parameter(
            'mode', str, 'fisheye',
            'Warp mode: fisheye, barrel, pincushion, or wave'
        )
        self._add_parameter(
            'strength', float, 0.5, 0.0, 2.0,
            'Warp strength'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        mode = self.get_parameter('mode')
        strength = self.get_parameter('strength')

        h, w = frame.shape[:2]

        if mode == 'wave':
            # Wave distortion
            map_x = np.zeros((h, w), dtype=np.float32)
            map_y = np.zeros((h, w), dtype=np.float32)

            for y in range(h):
                for x in range(w):
                    map_x[y, x] = x + strength * 10 * np.sin(2 * np.pi * y / 30)
                    map_y[y, x] = y + strength * 10 * np.sin(2 * np.pi * x / 30)

            result = cv2.remap(frame, map_x, map_y, cv2.INTER_LINEAR)

        else:
            # Radial distortion (fisheye, barrel, pincushion)
            center_x, center_y = w // 2, h // 2

            map_x = np.zeros((h, w), dtype=np.float32)
            map_y = np.zeros((h, w), dtype=np.float32)

            for y in range(h):
                for x in range(w):
                    # Distance from center
                    dx = x - center_x
                    dy = y - center_y
                    r = np.sqrt(dx**2 + dy**2)

                    if r == 0:
                        map_x[y, x] = x
                        map_y[y, x] = y
                        continue

                    # Normalize
                    max_r = np.sqrt(center_x**2 + center_y**2)
                    r_norm = r / max_r

                    # Apply distortion
                    if mode == 'fisheye':
                        r_new = r_norm ** (1.0 + strength)
                    elif mode == 'barrel':
                        r_new = r_norm * (1.0 + strength * r_norm**2)
                    else:  # pincushion
                        r_new = r_norm * (1.0 - strength * r_norm**2)

                    # Convert back
                    r_new = r_new * max_r
                    scale = r_new / r if r > 0 else 0

                    map_x[y, x] = center_x + dx * scale
                    map_y[y, x] = center_y + dy * scale

            result = cv2.remap(frame, map_x, map_y, cv2.INTER_LINEAR)

        return result

    @classmethod
    def get_category(cls) -> str:
        return "Transform"

    @classmethod
    def get_description(cls) -> str:
        return "Apply warping effects (fisheye, barrel, pincushion, wave)"
