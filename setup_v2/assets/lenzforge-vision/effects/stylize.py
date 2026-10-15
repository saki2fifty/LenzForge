"""
Stylize effects for LenzForge backend v2

Provides 6 types of artistic stylization effects.
"""
import cv2
import numpy as np
from .base import Effect


class PosterizeEffect(Effect):
    """
    Posterize Effect
    
    Reduce number of color levels for poster-like appearance.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'levels', int, 8, 2, 256,
            'Number of color levels (2-256)'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        levels = self.get_parameter('levels')
        
        # Posterize by quantizing color values
        div = 256 / levels
        result = (frame // div) * div
        
        return result.astype(np.uint8)
    
    @classmethod
    def get_category(cls) -> str:
        return "Stylize"
    
    @classmethod
    def get_description(cls) -> str:
        return "Reduce colors for poster-like effect"


class QuantizeEffect(Effect):
    """
    Quantize Effect
    
    Reduce color palette with optional dithering.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'colors', int, 16, 2, 256,
            'Number of colors in palette'
        )
        self._add_parameter(
            'dithering', str, 'none',
            'Dithering: none, floyd-steinberg, bayer'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        colors = self.get_parameter('colors')
        dithering = self.get_parameter('dithering')
        
        # Reshape for k-means
        pixels = frame.reshape((-1, 3)).astype(np.float32)
        
        # Use k-means to find color palette
        criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 100, 0.2)
        _, labels, palette = cv2.kmeans(
            pixels, colors, None, criteria, 10,
            cv2.KMEANS_RANDOM_CENTERS
        )
        
        # Map to palette
        result = palette[labels.flatten()].reshape(frame.shape).astype(np.uint8)
        
        # Apply dithering if requested
        if dithering == 'floyd-steinberg':
            # Simplified Floyd-Steinberg dithering
            result = result.astype(np.float32)
            h, w = result.shape[:2]
            for y in range(h - 1):
                for x in range(1, w - 1):
                    old_pixel = result[y, x].copy()
                    new_pixel = palette[labels[y * w + x][0]]
                    result[y, x] = new_pixel
                    error = old_pixel - new_pixel
                    result[y, x + 1] += error * 7 / 16
                    result[y + 1, x - 1] += error * 3 / 16
                    result[y + 1, x] += error * 5 / 16
                    result[y + 1, x + 1] += error * 1 / 16
            result = np.clip(result, 0, 255).astype(np.uint8)
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Stylize"
    
    @classmethod
    def get_description(cls) -> str:
        return "Quantize colors to limited palette"


class OilPaintingEffect(Effect):
    """
    Oil Painting Effect
    
    Simulate oil painting appearance.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'size', int, 7, 1, 20,
            'Brush size'
        )
        self._add_parameter(
            'dynamic_ratio', int, 1, 1, 10,
            'Dynamic ratio for color selection'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        size = self.get_parameter('size')
        dynRatio = self.get_parameter('dynamic_ratio')
        
        # OpenCV's xphoto module has oilPainting function
        # Fallback if not available: use bilateral filter + edge detection
        try:
            result = cv2.xphoto.oilPainting(frame, size, dynRatio)
        except:
            # Fallback: simulate with bilateral filter
            result = cv2.bilateralFilter(frame, size * 2, 75, 75)
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Stylize"
    
    @classmethod
    def get_description(cls) -> str:
        return "Simulate oil painting effect"


class CartoonEffect(Effect):
    """
    Cartoon Effect
    
    Create cartoon-like appearance with edges.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'sigma_space', int, 50, 1, 200,
            'Spatial sigma for bilateral filter'
        )
        self._add_parameter(
            'sigma_color', int, 50, 1, 200,
            'Color sigma for bilateral filter'
        )
        self._add_parameter(
            'edge_threshold1', int, 100, 0, 255,
            'First threshold for edge detection'
        )
        self._add_parameter(
            'edge_threshold2', int, 200, 0, 255,
            'Second threshold for edge detection'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        sigma_s = self.get_parameter('sigma_space')
        sigma_c = self.get_parameter('sigma_color')
        thresh1 = self.get_parameter('edge_threshold1')
        thresh2 = self.get_parameter('edge_threshold2')
        
        # Apply bilateral filter for smoothing
        smooth = cv2.bilateralFilter(frame, 9, sigma_c, sigma_s)
        
        # Detect edges
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, thresh1, thresh2)
        edges = cv2.bitwise_not(edges)
        edges = cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)
        
        # Combine smoothed image with edges
        result = cv2.bitwise_and(smooth, edges)
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Stylize"
    
    @classmethod
    def get_description(cls) -> str:
        return "Create cartoon-style effect"


class PencilSketchEffect(Effect):
    """
    Pencil Sketch Effect
    
    Simulate pencil drawing.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'sigma_space', int, 60, 1, 200,
            'Spatial sigma for detail enhancement'
        )
        self._add_parameter(
            'sigma_color', float, 0.07, 0.01, 1.0,
            'Color sigma for tonal adjustment'
        )
        self._add_parameter(
            'shade_factor', float, 0.02, 0.0, 1.0,
            'Shading factor (0 = sketch, 1 = shading)'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        sigma_s = self.get_parameter('sigma_space')
        sigma_c = self.get_parameter('sigma_color')
        shade = self.get_parameter('shade_factor')
        
        # OpenCV's pencilSketch
        gray_sketch, color_sketch = cv2.pencilSketch(
            frame,
            sigma_s=sigma_s,
            sigma_r=sigma_c,
            shade_factor=shade
        )
        
        # Return grayscale sketch as BGR
        return cv2.cvtColor(gray_sketch, cv2.COLOR_GRAY2BGR)
    
    @classmethod
    def get_category(cls) -> str:
        return "Stylize"
    
    @classmethod
    def get_description(cls) -> str:
        return "Create pencil sketch effect"


class StylizationEffect(Effect):
    """
    Stylization Effect
    
    Edge-preserving smoothing for artistic look.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'sigma_space', int, 60, 1, 200,
            'Spatial sigma'
        )
        self._add_parameter(
            'sigma_color', float, 0.45, 0.01, 1.0,
            'Color sigma'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        sigma_s = self.get_parameter('sigma_space')
        sigma_c = self.get_parameter('sigma_color')
        
        # Apply stylization
        result = cv2.stylization(frame, sigma_s=sigma_s, sigma_r=sigma_c)
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Stylize"
    
    @classmethod
    def get_description(cls) -> str:
        return "Apply artistic stylization"
