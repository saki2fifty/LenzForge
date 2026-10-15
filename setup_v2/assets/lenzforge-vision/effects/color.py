"""
Color Adjustment effects for LenzForge backend v2

Provides 6 types of color manipulation effects.
"""
import cv2
import numpy as np
from .base import Effect


class BrightnessContrastEffect(Effect):
    """
    Brightness and Contrast Adjustment
    
    Simple but powerful color adjustments.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'brightness', int, 0, -100, 100,
            'Brightness adjustment (-100 to 100)'
        )
        self._add_parameter(
            'contrast', int, 0, -100, 100,
            'Contrast adjustment (-100 to 100)'
        )
        self._add_parameter(
            'auto_adjust', bool, False,
            'Auto-adjust brightness and contrast'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        brightness = self.get_parameter('brightness')
        contrast = self.get_parameter('contrast')
        auto_adjust = self.get_parameter('auto_adjust')
        
        if auto_adjust:
            # Auto-adjust using histogram equalization
            lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
            l, a, b = cv2.split(lab)
            l = cv2.equalizeHist(l)
            lab = cv2.merge([l, a, b])
            return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)
        else:
            # Manual adjustment
            alpha = 1.0 + (contrast / 100.0)  # Contrast
            beta = brightness  # Brightness
            
            return cv2.convertScaleAbs(frame, alpha=alpha, beta=beta)
    
    @classmethod
    def get_category(cls) -> str:
        return "Color"
    
    @classmethod
    def get_description(cls) -> str:
        return "Adjust brightness and contrast"


class HSVAdjustmentEffect(Effect):
    """
    HSV Color Space Adjustment
    
    Adjust hue, saturation, and value independently.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'hue_shift', int, 0, -180, 180,
            'Hue shift in degrees'
        )
        self._add_parameter(
            'saturation', int, 0, -100, 100,
            'Saturation adjustment'
        )
        self._add_parameter(
            'value', int, 0, -100, 100,
            'Value (brightness) adjustment'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        hue_shift = self.get_parameter('hue_shift')
        saturation = self.get_parameter('saturation')
        value = self.get_parameter('value')
        
        # Convert to HSV
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV).astype(np.float32)
        h, s, v = cv2.split(hsv)
        
        # Adjust hue (wrap around 0-180)
        h = (h + hue_shift) % 180
        
        # Adjust saturation
        s = np.clip(s * (1.0 + saturation / 100.0), 0, 255)
        
        # Adjust value
        v = np.clip(v + value, 0, 255)
        
        # Merge and convert back
        hsv = cv2.merge([h, s, v]).astype(np.uint8)
        return cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)
    
    @classmethod
    def get_category(cls) -> str:
        return "Color"
    
    @classmethod
    def get_description(cls) -> str:
        return "Adjust hue, saturation, and value in HSV color space"


class ColorBalanceEffect(Effect):
    """
    Color Balance Adjustment
    
    Adjust color balance in shadows, midtones, and highlights.
    """
    
    def _register_parameters(self):
        # Shadows
        self._add_parameter('shadow_r', int, 0, -100, 100, 'Shadow red adjustment')
        self._add_parameter('shadow_g', int, 0, -100, 100, 'Shadow green adjustment')
        self._add_parameter('shadow_b', int, 0, -100, 100, 'Shadow blue adjustment')
        
        # Midtones
        self._add_parameter('midtone_r', int, 0, -100, 100, 'Midtone red adjustment')
        self._add_parameter('midtone_g', int, 0, -100, 100, 'Midtone green adjustment')
        self._add_parameter('midtone_b', int, 0, -100, 100, 'Midtone blue adjustment')
        
        # Highlights
        self._add_parameter('highlight_r', int, 0, -100, 100, 'Highlight red adjustment')
        self._add_parameter('highlight_g', int, 0, -100, 100, 'Highlight green adjustment')
        self._add_parameter('highlight_b', int, 0, -100, 100, 'Highlight blue adjustment')
        
        self._add_parameter(
            'preserve_luminosity', bool, True,
            'Preserve luminosity when adjusting'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        result = frame.astype(np.float32)
        
        # Get parameters
        params = {
            'shadow': [self.get_parameter(f'shadow_{c}') for c in ['b', 'g', 'r']],
            'midtone': [self.get_parameter(f'midtone_{c}') for c in ['b', 'g', 'r']],
            'highlight': [self.get_parameter(f'highlight_{c}') for c in ['b', 'g', 'r']]
        }
        preserve_lum = self.get_parameter('preserve_luminosity')
        
        # Calculate luminosity if preserving
        if preserve_lum:
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY).astype(np.float32)
        
        # Apply color balance
        for c in range(3):
            channel = result[:, :, c]
            
            # Create masks for shadows, midtones, highlights
            shadows = np.clip(255 - channel, 0, 255) / 255.0
            highlights = channel / 255.0
            midtones = 1.0 - np.abs(channel - 127.5) / 127.5
            
            # Apply adjustments
            adjustment = (shadows * params['shadow'][c] +
                         midtones * params['midtone'][c] +
                         highlights * params['highlight'][c])
            
            result[:, :, c] = np.clip(channel + adjustment, 0, 255)
        
        # Restore luminosity if requested
        if preserve_lum:
            result_gray = cv2.cvtColor(result.astype(np.uint8), cv2.COLOR_BGR2GRAY).astype(np.float32)
            ratio = gray / (result_gray + 1e-6)
            for c in range(3):
                result[:, :, c] *= ratio
        
        return np.clip(result, 0, 255).astype(np.uint8)
    
    @classmethod
    def get_category(cls) -> str:
        return "Color"
    
    @classmethod
    def get_description(cls) -> str:
        return "Adjust color balance in shadows, midtones, and highlights"


class LevelsEffect(Effect):
    """
    Levels Adjustment
    
    Adjust input/output levels and gamma for each channel.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'input_black', int, 0, 0, 255,
            'Input black point'
        )
        self._add_parameter(
            'input_white', int, 255, 0, 255,
            'Input white point'
        )
        self._add_parameter(
            'gamma', float, 1.0, 0.1, 10.0,
            'Gamma adjustment'
        )
        self._add_parameter(
            'output_black', int, 0, 0, 255,
            'Output black point'
        )
        self._add_parameter(
            'output_white', int, 255, 0, 255,
            'Output white point'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        input_black = self.get_parameter('input_black')
        input_white = self.get_parameter('input_white')
        gamma = self.get_parameter('gamma')
        output_black = self.get_parameter('output_black')
        output_white = self.get_parameter('output_white')
        
        # Ensure input_white > input_black
        if input_white <= input_black:
            input_white = input_black + 1
        
        result = frame.astype(np.float32)
        
        # Input levels
        result = np.clip((result - input_black) / (input_white - input_black), 0, 1)
        
        # Gamma
        result = np.power(result, 1.0 / gamma)
        
        # Output levels
        result = result * (output_white - output_black) + output_black
        
        return np.clip(result, 0, 255).astype(np.uint8)
    
    @classmethod
    def get_category(cls) -> str:
        return "Color"
    
    @classmethod
    def get_description(cls) -> str:
        return "Adjust input/output levels and gamma"


class TemperatureTintEffect(Effect):
    """
    Temperature and Tint Adjustment
    
    Adjust color temperature (warm/cool) and tint (green/magenta).
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'temperature', int, 0, -100, 100,
            'Temperature: -100 (cool/blue) to +100 (warm/yellow)'
        )
        self._add_parameter(
            'tint', int, 0, -100, 100,
            'Tint: -100 (green) to +100 (magenta)'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        temperature = self.get_parameter('temperature')
        tint = self.get_parameter('tint')
        
        result = frame.astype(np.float32)
        
        # Apply temperature (affects blue and red)
        if temperature > 0:
            # Warm (increase red, decrease blue)
            result[:, :, 2] += temperature * 2.55  # Red
            result[:, :, 0] -= temperature * 2.55  # Blue
        else:
            # Cool (decrease red, increase blue)
            result[:, :, 2] += temperature * 2.55  # Red
            result[:, :, 0] -= temperature * 2.55  # Blue
        
        # Apply tint (affects green)
        if tint > 0:
            # Magenta (decrease green, increase red and blue slightly)
            result[:, :, 1] -= tint * 2.55  # Green
            result[:, :, 0] += tint * 1.27  # Blue
            result[:, :, 2] += tint * 1.27  # Red
        else:
            # Green (increase green, decrease red and blue slightly)
            result[:, :, 1] -= tint * 2.55  # Green
            result[:, :, 0] += tint * 1.27  # Blue
            result[:, :, 2] += tint * 1.27  # Red
        
        return np.clip(result, 0, 255).astype(np.uint8)
    
    @classmethod
    def get_category(cls) -> str:
        return "Color"
    
    @classmethod
    def get_description(cls) -> str:
        return "Adjust color temperature and tint"


class CurvesEffect(Effect):
    """
    Curves Adjustment
    
    Apply custom tone curves for color grading.
    Simplified version with preset curves.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'preset', str, 'linear',
            'Curve preset: linear, boost, fade, s_curve, inverse'
        )
        self._add_parameter(
            'strength', float, 1.0, 0.0, 2.0,
            'Strength of curve application'
        )
    
    def _get_curve(self, preset: str) -> np.ndarray:
        """Generate curve lookup table"""
        x = np.arange(256, dtype=np.float32)
        
        if preset == 'boost':
            # Boost shadows and highlights
            y = np.power(x / 255.0, 0.8) * 255.0
        elif preset == 'fade':
            # Fade/vintage look
            y = np.power(x / 255.0, 1.2) * 255.0
            y = np.clip(y + 20, 0, 255)
        elif preset == 's_curve':
            # S-curve for increased contrast
            y = 255.0 / (1.0 + np.exp(-0.05 * (x - 127.5)))
        elif preset == 'inverse':
            # Invert
            y = 255 - x
        else:  # linear
            y = x
        
        return np.clip(y, 0, 255).astype(np.uint8)
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        preset = self.get_parameter('preset')
        strength = self.get_parameter('strength')
        
        # Get curve
        curve = self._get_curve(preset)
        
        # Apply curve
        result = cv2.LUT(frame, curve)
        
        # Blend based on strength
        if strength < 1.0:
            result = cv2.addWeighted(frame, 1.0 - strength, result, strength, 0)
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Color"
    
    @classmethod
    def get_description(cls) -> str:
        return "Apply tone curves for color grading"
