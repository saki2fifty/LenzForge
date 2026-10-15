"""
Advanced effects for LenzForge backend v2

Provides 5 types of advanced cinematic effects.
"""
import cv2
import numpy as np
from .base import Effect


class HDREffect(Effect):
    """
    HDR (High Dynamic Range) Effect

    Enhance dynamic range and detail in highlights and shadows.
    """

    def _register_parameters(self):
        self._add_parameter(
            'strength', float, 0.5, 0.0, 2.0,
            'HDR effect strength'
        )
        self._add_parameter(
            'gamma', float, 1.0, 0.1, 3.0,
            'Gamma correction'
        )
        self._add_parameter(
            'saturation', float, 1.2, 0.0, 2.0,
            'Color saturation boost'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        strength = self.get_parameter('strength')
        gamma = self.get_parameter('gamma')
        saturation = self.get_parameter('saturation')

        # Convert to float
        result = frame.astype(np.float32) / 255.0

        # Apply tone mapping
        result = np.power(result, gamma)

        # Boost local contrast
        lab = cv2.cvtColor((result * 255).astype(np.uint8), cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)

        # CLAHE on L channel
        clahe = cv2.createCLAHE(clipLimit=2.0 * strength, tileGridSize=(8, 8))
        l = clahe.apply(l)

        lab = cv2.merge([l, a, b])
        result = cv2.cvtColor(lab, cv2.COLOR_LAB2BGR).astype(np.float32) / 255.0

        # Boost saturation
        if saturation != 1.0:
            hsv = cv2.cvtColor((result * 255).astype(np.uint8), cv2.COLOR_BGR2HSV).astype(np.float32)
            hsv[:, :, 1] = np.clip(hsv[:, :, 1] * saturation, 0, 255)
            result = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR).astype(np.float32) / 255.0

        return np.clip(result * 255, 0, 255).astype(np.uint8)

    @classmethod
    def get_category(cls) -> str:
        return "Advanced"

    @classmethod
    def get_description(cls) -> str:
        return "HDR effect with enhanced dynamic range"


class ColorGradingEffect(Effect):
    """
    Color Grading Effect

    Professional color grading with lift, gamma, gain controls.
    """

    def _register_parameters(self):
        # Lift (shadows)
        self._add_parameter('lift_r', float, 0.0, -1.0, 1.0, 'Lift red (shadows)')
        self._add_parameter('lift_g', float, 0.0, -1.0, 1.0, 'Lift green (shadows)')
        self._add_parameter('lift_b', float, 0.0, -1.0, 1.0, 'Lift blue (shadows)')

        # Gamma (midtones)
        self._add_parameter('gamma_r', float, 1.0, 0.1, 3.0, 'Gamma red (midtones)')
        self._add_parameter('gamma_g', float, 1.0, 0.1, 3.0, 'Gamma green (midtones)')
        self._add_parameter('gamma_b', float, 1.0, 0.1, 3.0, 'Gamma blue (midtones)')

        # Gain (highlights)
        self._add_parameter('gain_r', float, 1.0, 0.0, 2.0, 'Gain red (highlights)')
        self._add_parameter('gain_g', float, 1.0, 0.0, 2.0, 'Gain green (highlights)')
        self._add_parameter('gain_b', float, 1.0, 0.0, 2.0, 'Gain blue (highlights)')

    def apply(self, frame: np.ndarray) -> np.ndarray:
        result = frame.astype(np.float32) / 255.0

        # Split channels
        b, g, r = cv2.split(result)

        # Get parameters
        lift = [self.get_parameter(f'lift_{c}') for c in ['b', 'g', 'r']]
        gamma = [self.get_parameter(f'gamma_{c}') for c in ['b', 'g', 'r']]
        gain = [self.get_parameter(f'gain_{c}') for c in ['b', 'g', 'r']]

        channels = [b, g, r]
        result_channels = []

        for i, ch in enumerate(channels):
            # Apply lift (add to shadows)
            ch = ch + lift[i] * (1.0 - ch)

            # Apply gamma (power curve for midtones)
            ch = np.power(np.clip(ch, 0, 1), 1.0 / gamma[i])

            # Apply gain (multiply highlights)
            ch = ch * gain[i]

            result_channels.append(np.clip(ch, 0, 1))

        result = cv2.merge(result_channels)
        return (result * 255).astype(np.uint8)

    @classmethod
    def get_category(cls) -> str:
        return "Advanced"

    @classmethod
    def get_description(cls) -> str:
        return "Professional color grading (lift, gamma, gain)"


class FilmGrainEffect(Effect):
    """
    Film Grain Effect

    Add cinematic film grain texture.
    """

    def _register_parameters(self):
        self._add_parameter(
            'intensity', int, 20, 0, 100,
            'Grain intensity (0-100)'
        )
        self._add_parameter(
            'size', float, 1.0, 0.5, 3.0,
            'Grain size'
        )
        self._add_parameter(
            'colored', bool, False,
            'Add color to grain'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        intensity = self.get_parameter('intensity')
        size = self.get_parameter('size')
        colored = self.get_parameter('colored')

        if intensity == 0:
            return frame

        h, w = frame.shape[:2]

        # Create grain
        if colored:
            grain = np.random.randn(h, w, 3) * intensity
        else:
            grain = np.random.randn(h, w) * intensity
            grain = np.stack([grain] * 3, axis=2)

        # Scale grain
        if size != 1.0:
            scaled_h = int(h / size)
            scaled_w = int(w / size)
            grain_small = cv2.resize(grain, (scaled_w, scaled_h))
            grain = cv2.resize(grain_small, (w, h))

        # Apply grain
        result = frame.astype(np.float32) + grain

        return np.clip(result, 0, 255).astype(np.uint8)

    @classmethod
    def get_category(cls) -> str:
        return "Advanced"

    @classmethod
    def get_description(cls) -> str:
        return "Add cinematic film grain"


class VignetteEffect(Effect):
    """
    Vignette Effect

    Darken or lighten edges of image.
    """

    def _register_parameters(self):
        self._add_parameter(
            'strength', float, 0.5, 0.0, 2.0,
            'Vignette strength'
        )
        self._add_parameter(
            'radius', float, 0.8, 0.1, 2.0,
            'Vignette radius (larger = softer)'
        )
        self._add_parameter(
            'mode', str, 'darken',
            'Mode: darken or lighten'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        strength = self.get_parameter('strength')
        radius = self.get_parameter('radius')
        mode = self.get_parameter('mode')

        if strength == 0:
            return frame

        h, w = frame.shape[:2]

        # Create vignette mask
        center_x, center_y = w // 2, h // 2

        Y, X = np.ogrid[:h, :w]
        dist_from_center = np.sqrt((X - center_x)**2 + (Y - center_y)**2)

        max_dist = np.sqrt(center_x**2 + center_y**2)
        dist_normalized = dist_from_center / max_dist

        # Create falloff
        mask = 1.0 - np.clip((dist_normalized - radius) / (1.0 - radius), 0, 1)
        mask = np.power(mask, 2)  # Smooth falloff

        # Apply vignette
        if mode == 'lighten':
            mask = 1.0 - mask

        # Adjust strength
        mask = 1.0 - (1.0 - mask) * strength
        mask = np.stack([mask] * 3, axis=2)

        result = (frame.astype(np.float32) * mask).astype(np.uint8)

        return result

    @classmethod
    def get_category(cls) -> str:
        return "Advanced"

    @classmethod
    def get_description(cls) -> str:
        return "Add vignette effect (darken/lighten edges)"


class ChromaticAberrationEffect(Effect):
    """
    Chromatic Aberration Effect

    Simulate lens chromatic aberration.
    """

    def _register_parameters(self):
        self._add_parameter(
            'strength', int, 5, 0, 50,
            'Aberration strength (pixels)'
        )
        self._add_parameter(
            'type', str, 'radial',
            'Type: radial or lateral'
        )

    def apply(self, frame: np.ndarray) -> np.ndarray:
        strength = self.get_parameter('strength')
        aberration_type = self.get_parameter('type')

        if strength == 0:
            return frame

        h, w = frame.shape[:2]
        b, g, r = cv2.split(frame)

        if aberration_type == 'lateral':
            # Lateral (horizontal) chromatic aberration
            # Shift red and blue channels horizontally
            M_r = np.float32([[1, 0, strength], [0, 1, 0]])
            M_b = np.float32([[1, 0, -strength], [0, 1, 0]])

            r_shifted = cv2.warpAffine(r, M_r, (w, h))
            b_shifted = cv2.warpAffine(b, M_b, (w, h))

            result = cv2.merge([b_shifted, g, r_shifted])

        else:  # radial
            # Radial chromatic aberration
            center_x, center_y = w // 2, h // 2

            # Scale channels differently from center
            scale_r = 1.0 + strength / 1000.0
            scale_b = 1.0 - strength / 1000.0

            M_r = cv2.getRotationMatrix2D((center_x, center_y), 0, scale_r)
            M_b = cv2.getRotationMatrix2D((center_x, center_y), 0, scale_b)

            r_scaled = cv2.warpAffine(r, M_r, (w, h))
            b_scaled = cv2.warpAffine(b, M_b, (w, h))

            result = cv2.merge([b_scaled, g, r_scaled])

        return result

    @classmethod
    def get_category(cls) -> str:
        return "Advanced"

    @classmethod
    def get_description(cls) -> str:
        return "Simulate lens chromatic aberration"
