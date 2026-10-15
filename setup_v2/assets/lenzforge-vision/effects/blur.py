"""
Blur effects for LenzForge backend v2

Provides 6 types of blur effects with extensive parameter controls.
"""
import cv2
import numpy as np
from .base import Effect


class GaussianBlurEffect(Effect):
    """
    Gaussian Blur Effect
    
    Applies Gaussian blur using a Gaussian kernel.
    Most common blur type, good for general smoothing.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'amount', int, 5, 1, 100,
            'Blur amount (affects kernel size)'
        )
        self._add_parameter(
            'sigma_x', float, 0.0, 0.0, 10.0,
            'Gaussian kernel standard deviation in X (0 = auto)'
        )
        self._add_parameter(
            'sigma_y', float, 0.0, 0.0, 10.0,
            'Gaussian kernel standard deviation in Y (0 = auto)'
        )
        self._add_parameter(
            'iterations', int, 1, 1, 5,
            'Number of times to apply blur'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        amount = self.get_parameter('amount')
        sigma_x = self.get_parameter('sigma_x')
        sigma_y = self.get_parameter('sigma_y')
        iterations = self.get_parameter('iterations')
        
        ksize = amount if amount % 2 == 1 else amount + 1
        
        result = frame.copy()
        for _ in range(iterations):
            result = cv2.GaussianBlur(
                result, 
                (ksize, ksize), 
                sigmaX=sigma_x,
                sigmaY=sigma_y
            )
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Blur"
    
    @classmethod
    def get_description(cls) -> str:
        return "Gaussian blur with adjustable kernel size and standard deviation"


class MotionBlurEffect(Effect):
    """
    Motion Blur Effect
    
    Simulates motion blur in a specific direction.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'angle', float, 0.0, 0.0, 360.0,
            'Direction of motion in degrees'
        )
        self._add_parameter(
            'distance', int, 10, 1, 100,
            'Distance of motion in pixels'
        )
        self._add_parameter(
            'center_x', float, 0.5, 0.0, 1.0,
            'Center point X (normalized 0-1)'
        )
        self._add_parameter(
            'center_y', float, 0.5, 0.0, 1.0,
            'Center point Y (normalized 0-1)'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        angle = self.get_parameter('angle')
        distance = self.get_parameter('distance')
        
        kernel = np.zeros((distance, distance))
        kernel[int((distance-1)/2), :] = np.ones(distance)
        kernel = kernel / distance
        
        M = cv2.getRotationMatrix2D((distance/2, distance/2), angle, 1)
        kernel = cv2.warpAffine(kernel, M, (distance, distance))
        
        return cv2.filter2D(frame, -1, kernel)
    
    @classmethod
    def get_category(cls) -> str:
        return "Blur"
    
    @classmethod
    def get_description(cls) -> str:
        return "Motion blur effect in a specified direction"


class RadialBlurEffect(Effect):
    """
    Radial Blur Effect
    
    Applies blur radiating from a center point.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'center_x', float, 0.5, 0.0, 1.0,
            'Center point X (normalized 0-1)'
        )
        self._add_parameter(
            'center_y', float, 0.5, 0.0, 1.0,
            'Center point Y (normalized 0-1)'
        )
        self._add_parameter(
            'amount', int, 10, 1, 100,
            'Blur intensity'
        )
        self._add_parameter(
            'quality', str, 'medium', description='Quality: low/medium/high'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        h, w = frame.shape[:2]
        center_x = int(self.get_parameter('center_x') * w)
        center_y = int(self.get_parameter('center_y') * h)
        amount = self.get_parameter('amount')
        quality = self.get_parameter('quality')
        
        samples = {'low': 5, 'medium': 10, 'high': 20}.get(quality, 10)
        
        result = np.zeros_like(frame, dtype=np.float32)
        
        for i in range(samples):
            scale = 1.0 + (i / samples) * (amount / 100.0)
            M = cv2.getRotationMatrix2D((center_x, center_y), 0, scale)
            warped = cv2.warpAffine(frame, M, (w, h))
            result += warped.astype(np.float32)
        
        result = (result / samples).astype(np.uint8)
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Blur"
    
    @classmethod
    def get_description(cls) -> str:
        return "Radial blur emanating from a center point"


class BoxBlurEffect(Effect):
    """
    Box Blur Effect
    
    Simple averaging blur using box filter.
    Faster than Gaussian but less smooth.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'size', int, 5, 1, 50,
            'Box filter size'
        )
        self._add_parameter(
            'iterations', int, 1, 1, 10,
            'Number of times to apply blur'
        )
        self._add_parameter(
            'normalize', bool, True,
            'Normalize filter (preserve brightness)'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        size = self.get_parameter('size')
        iterations = self.get_parameter('iterations')
        normalize = self.get_parameter('normalize')
        
        result = frame.copy()
        for _ in range(iterations):
            result = cv2.boxFilter(
                result,
                -1,
                (size, size),
                normalize=normalize
            )
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Blur"
    
    @classmethod
    def get_description(cls) -> str:
        return "Fast box blur using simple averaging"


class BilateralFilterEffect(Effect):
    """
    Bilateral Filter Effect
    
    Edge-preserving smoothing filter.
    Reduces noise while keeping edges sharp.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'diameter', int, 9, 1, 50,
            'Diameter of pixel neighborhood'
        )
        self._add_parameter(
            'sigma_color', float, 75.0, 1.0, 200.0,
            'Filter sigma in color space'
        )
        self._add_parameter(
            'sigma_space', float, 75.0, 1.0, 200.0,
            'Filter sigma in coordinate space'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        diameter = self.get_parameter('diameter')
        sigma_color = self.get_parameter('sigma_color')
        sigma_space = self.get_parameter('sigma_space')
        
        return cv2.bilateralFilter(
            frame,
            diameter,
            sigma_color,
            sigma_space
        )
    
    @classmethod
    def get_category(cls) -> str:
        return "Blur"
    
    @classmethod
    def get_description(cls) -> str:
        return "Edge-preserving blur that maintains sharp boundaries"


class MedianBlurEffect(Effect):
    """
    Median Blur Effect
    
    Replaces each pixel with median of neighborhood.
    Excellent for removing salt-and-pepper noise.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'kernel_size', int, 5, 3, 31,
            'Kernel size (must be odd, 3/5/7/9/11/etc)'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        kernel_size = self.get_parameter('kernel_size')
        
        if kernel_size % 2 == 0:
            kernel_size += 1
        
        kernel_size = max(3, min(31, kernel_size))
        
        return cv2.medianBlur(frame, kernel_size)
    
    @classmethod
    def get_category(cls) -> str:
        return "Blur"
    
    @classmethod
    def get_description(cls) -> str:
        return "Median filter blur, excellent for noise reduction"
