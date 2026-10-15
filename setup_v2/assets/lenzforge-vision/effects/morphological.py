"""
Morphological operations for LenzForge backend v2

Provides 4 types of morphological image processing.
"""
import cv2
import numpy as np
from .base import Effect


class ErodeDilateEffect(Effect):
    """
    Erode and Dilate Effect
    
    Morphological erosion and dilation operations.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'operation', str, 'erode',
            'Operation: erode or dilate'
        )
        self._add_parameter(
            'kernel_shape', str, 'rect',
            'Kernel shape: rect, ellipse, or cross'
        )
        self._add_parameter(
            'kernel_size', int, 5, 1, 50,
            'Kernel size'
        )
        self._add_parameter(
            'iterations', int, 1, 1, 10,
            'Number of iterations'
        )
    
    def _get_kernel(self, shape: str, size: int):
        """Get morphological kernel"""
        if shape == 'ellipse':
            return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (size, size))
        elif shape == 'cross':
            return cv2.getStructuringElement(cv2.MORPH_CROSS, (size, size))
        else:  # rect
            return cv2.getStructuringElement(cv2.MORPH_RECT, (size, size))
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        operation = self.get_parameter('operation')
        kernel_shape = self.get_parameter('kernel_shape')
        kernel_size = self.get_parameter('kernel_size')
        iterations = self.get_parameter('iterations')
        
        kernel = self._get_kernel(kernel_shape, kernel_size)
        
        if operation == 'dilate':
            return cv2.dilate(frame, kernel, iterations=iterations)
        else:  # erode
            return cv2.erode(frame, kernel, iterations=iterations)
    
    @classmethod
    def get_category(cls) -> str:
        return "Morphological"
    
    @classmethod
    def get_description(cls) -> str:
        return "Erode or dilate image features"


class OpenCloseEffect(Effect):
    """
    Open and Close Effect
    
    Morphological opening (erode then dilate) and closing (dilate then erode).
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'operation', str, 'open',
            'Operation: open or close'
        )
        self._add_parameter(
            'kernel_shape', str, 'ellipse',
            'Kernel shape: rect, ellipse, or cross'
        )
        self._add_parameter(
            'kernel_size', int, 5, 1, 50,
            'Kernel size'
        )
    
    def _get_kernel(self, shape: str, size: int):
        """Get morphological kernel"""
        if shape == 'ellipse':
            return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (size, size))
        elif shape == 'cross':
            return cv2.getStructuringElement(cv2.MORPH_CROSS, (size, size))
        else:  # rect
            return cv2.getStructuringElement(cv2.MORPH_RECT, (size, size))
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        operation = self.get_parameter('operation')
        kernel_shape = self.get_parameter('kernel_shape')
        kernel_size = self.get_parameter('kernel_size')
        
        kernel = self._get_kernel(kernel_shape, kernel_size)
        
        if operation == 'close':
            return cv2.morphologyEx(frame, cv2.MORPH_CLOSE, kernel)
        else:  # open
            return cv2.morphologyEx(frame, cv2.MORPH_OPEN, kernel)
    
    @classmethod
    def get_category(cls) -> str:
        return "Morphological"
    
    @classmethod
    def get_description(cls) -> str:
        return "Opening (removes noise) or closing (fills holes)"


class MorphologicalGradientEffect(Effect):
    """
    Morphological Gradient Effect
    
    Difference between dilation and erosion.
    Highlights edges.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'kernel_size', int, 5, 1, 50,
            'Kernel size'
        )
        self._add_parameter(
            'kernel_shape', str, 'rect',
            'Kernel shape: rect, ellipse, or cross'
        )
    
    def _get_kernel(self, shape: str, size: int):
        """Get morphological kernel"""
        if shape == 'ellipse':
            return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (size, size))
        elif shape == 'cross':
            return cv2.getStructuringElement(cv2.MORPH_CROSS, (size, size))
        else:  # rect
            return cv2.getStructuringElement(cv2.MORPH_RECT, (size, size))
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        kernel_size = self.get_parameter('kernel_size')
        kernel_shape = self.get_parameter('kernel_shape')
        
        kernel = self._get_kernel(kernel_shape, kernel_size)
        
        return cv2.morphologyEx(frame, cv2.MORPH_GRADIENT, kernel)
    
    @classmethod
    def get_category(cls) -> str:
        return "Morphological"
    
    @classmethod
    def get_description(cls) -> str:
        return "Morphological gradient (edge highlighting)"


class TopHatBlackHatEffect(Effect):
    """
    Top Hat and Black Hat Effect
    
    Top Hat: difference between input and opening (light features)
    Black Hat: difference between closing and input (dark features)
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'operation', str, 'tophat',
            'Operation: tophat or blackhat'
        )
        self._add_parameter(
            'kernel_size', int, 9, 1, 50,
            'Kernel size'
        )
        self._add_parameter(
            'kernel_shape', str, 'rect',
            'Kernel shape: rect, ellipse, or cross'
        )
    
    def _get_kernel(self, shape: str, size: int):
        """Get morphological kernel"""
        if shape == 'ellipse':
            return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (size, size))
        elif shape == 'cross':
            return cv2.getStructuringElement(cv2.MORPH_CROSS, (size, size))
        else:  # rect
            return cv2.getStructuringElement(cv2.MORPH_RECT, (size, size))
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        operation = self.get_parameter('operation')
        kernel_size = self.get_parameter('kernel_size')
        kernel_shape = self.get_parameter('kernel_shape')
        
        kernel = self._get_kernel(kernel_shape, kernel_size)
        
        if operation == 'blackhat':
            return cv2.morphologyEx(frame, cv2.MORPH_BLACKHAT, kernel)
        else:  # tophat
            return cv2.morphologyEx(frame, cv2.MORPH_TOPHAT, kernel)
    
    @classmethod
    def get_category(cls) -> str:
        return "Morphological"
    
    @classmethod
    def get_description(cls) -> str:
        return "Top Hat (light features) or Black Hat (dark features)"
