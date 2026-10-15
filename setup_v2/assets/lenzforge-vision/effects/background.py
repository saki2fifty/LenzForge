"""
Background effects for LenzForge backend v2

Provides 4 types of background manipulation effects.
Requires person segmentation from MediaPipe or similar.
"""
import cv2
import numpy as np
from typing import Optional
from .base import Effect


class BackgroundBlurEffect(Effect):
    """
    Background Blur Effect
    
    Blur background while keeping person sharp (like Zoom/Teams).
    Requires person segmentation mask.
    """
    
    def __init__(self):
        super().__init__()
        self.segmentation_mask: Optional[np.ndarray] = None
    
    def _register_parameters(self):
        self._add_parameter(
            'blur_amount', int, 21, 1, 99,
            'Background blur amount (odd number)'
        )
        self._add_parameter(
            'edge_smoothness', int, 5, 1, 20,
            'Edge smoothness between person and background'
        )
        self._add_parameter(
            'threshold', float, 0.5, 0.0, 1.0,
            'Segmentation confidence threshold'
        )
    
    def set_segmentation_mask(self, mask: np.ndarray):
        """Set segmentation mask from MediaPipe or other source"""
        self.segmentation_mask = mask
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        blur_amount = self.get_parameter('blur_amount')
        edge_smoothness = self.get_parameter('edge_smoothness')
        threshold = self.get_parameter('threshold')
        
        # Ensure blur amount is odd
        if blur_amount % 2 == 0:
            blur_amount += 1
        
        # If no segmentation mask, return original
        if self.segmentation_mask is None:
            return frame
        
        # Resize mask to frame size if needed
        mask = self.segmentation_mask
        if mask.shape[:2] != frame.shape[:2]:
            mask = cv2.resize(mask, (frame.shape[1], frame.shape[0]))
        
        # Threshold mask
        _, binary_mask = cv2.threshold(
            (mask * 255).astype(np.uint8),
            int(threshold * 255),
            255,
            cv2.THRESH_BINARY
        )
        
        # Smooth mask edges
        mask_smooth = cv2.GaussianBlur(
            binary_mask,
            (edge_smoothness * 2 + 1, edge_smoothness * 2 + 1),
            0
        ).astype(np.float32) / 255.0
        
        # Blur entire frame
        blurred = cv2.GaussianBlur(frame, (blur_amount, blur_amount), 0)
        
        # Expand mask to 3 channels
        mask_3ch = np.stack([mask_smooth] * 3, axis=2)
        
        # Composite: person (sharp) over blurred background
        result = (frame * mask_3ch + blurred * (1 - mask_3ch)).astype(np.uint8)
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Background"
    
    @classmethod
    def get_description(cls) -> str:
        return "Blur background while keeping person sharp (requires segmentation)"


class BackgroundReplaceEffect(Effect):
    """
    Background Replace Effect
    
    Replace background with solid color or image.
    """
    
    def __init__(self):
        super().__init__()
        self.segmentation_mask: Optional[np.ndarray] = None
        self.background_image: Optional[np.ndarray] = None
    
    def _register_parameters(self):
        self._add_parameter(
            'mode', str, 'color',
            'Mode: color or image'
        )
        self._add_parameter(
            'color_r', int, 0, 0, 255,
            'Background color red (0-255)'
        )
        self._add_parameter(
            'color_g', int, 177, 0, 255,
            'Background color green (0-255)'
        )
        self._add_parameter(
            'color_b', int, 64, 0, 255,
            'Background color blue (0-255)'
        )
        self._add_parameter(
            'edge_smoothness', int, 5, 1, 20,
            'Edge smoothness'
        )
        self._add_parameter(
            'threshold', float, 0.5, 0.0, 1.0,
            'Segmentation confidence threshold'
        )
    
    def set_segmentation_mask(self, mask: np.ndarray):
        """Set segmentation mask"""
        self.segmentation_mask = mask
    
    def set_background_image(self, image: np.ndarray):
        """Set replacement background image"""
        self.background_image = image
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        mode = self.get_parameter('mode')
        color_r = self.get_parameter('color_r')
        color_g = self.get_parameter('color_g')
        color_b = self.get_parameter('color_b')
        edge_smoothness = self.get_parameter('edge_smoothness')
        threshold = self.get_parameter('threshold')
        
        # If no segmentation mask, return original
        if self.segmentation_mask is None:
            return frame
        
        # Prepare mask
        mask = self.segmentation_mask
        if mask.shape[:2] != frame.shape[:2]:
            mask = cv2.resize(mask, (frame.shape[1], frame.shape[0]))
        
        _, binary_mask = cv2.threshold(
            (mask * 255).astype(np.uint8),
            int(threshold * 255),
            255,
            cv2.THRESH_BINARY
        )
        
        mask_smooth = cv2.GaussianBlur(
            binary_mask,
            (edge_smoothness * 2 + 1, edge_smoothness * 2 + 1),
            0
        ).astype(np.float32) / 255.0
        
        # Create background
        if mode == 'image' and self.background_image is not None:
            background = cv2.resize(
                self.background_image,
                (frame.shape[1], frame.shape[0])
            )
        else:
            # Solid color background (BGR)
            background = np.full_like(frame, (color_b, color_g, color_r))
        
        # Composite
        mask_3ch = np.stack([mask_smooth] * 3, axis=2)
        result = (frame * mask_3ch + background * (1 - mask_3ch)).astype(np.uint8)
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Background"
    
    @classmethod
    def get_description(cls) -> str:
        return "Replace background with color or image"


class VirtualBackgroundEffect(Effect):
    """
    Virtual Background Effect
    
    Apply virtual backgrounds with advanced compositing.
    """
    
    def __init__(self):
        super().__init__()
        self.segmentation_mask: Optional[np.ndarray] = None
        self.background_image: Optional[np.ndarray] = None
    
    def _register_parameters(self):
        self._add_parameter(
            'edge_smoothness', int, 7, 1, 20,
            'Edge smoothness'
        )
        self._add_parameter(
            'threshold', float, 0.6, 0.0, 1.0,
            'Segmentation confidence threshold'
        )
        self._add_parameter(
            'edge_color_correction', bool, True,
            'Apply color correction to edges'
        )
        self._add_parameter(
            'background_scale', float, 1.0, 0.1, 2.0,
            'Background scale factor'
        )
    
    def set_segmentation_mask(self, mask: np.ndarray):
        """Set segmentation mask"""
        self.segmentation_mask = mask
    
    def set_background_image(self, image: np.ndarray):
        """Set virtual background image"""
        self.background_image = image
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        edge_smoothness = self.get_parameter('edge_smoothness')
        threshold = self.get_parameter('threshold')
        color_correction = self.get_parameter('edge_color_correction')
        bg_scale = self.get_parameter('background_scale')
        
        if self.segmentation_mask is None or self.background_image is None:
            return frame
        
        # Prepare mask
        mask = self.segmentation_mask
        if mask.shape[:2] != frame.shape[:2]:
            mask = cv2.resize(mask, (frame.shape[1], frame.shape[0]))
        
        _, binary_mask = cv2.threshold(
            (mask * 255).astype(np.uint8),
            int(threshold * 255),
            255,
            cv2.THRESH_BINARY
        )
        
        # Advanced edge smoothing
        mask_smooth = cv2.GaussianBlur(
            binary_mask,
            (edge_smoothness * 2 + 1, edge_smoothness * 2 + 1),
            0
        ).astype(np.float32) / 255.0
        
        # Scale and center background
        h, w = frame.shape[:2]
        bg_h, bg_w = self.background_image.shape[:2]
        new_w = int(bg_w * bg_scale)
        new_h = int(bg_h * bg_scale)
        
        background = cv2.resize(self.background_image, (new_w, new_h))
        
        # Center crop to frame size
        start_x = max(0, (new_w - w) // 2)
        start_y = max(0, (new_h - h) // 2)
        background = background[start_y:start_y+h, start_x:start_x+w]
        
        if background.shape[:2] != (h, w):
            background = cv2.resize(background, (w, h))
        
        # Color correction at edges
        if color_correction:
            # Sample background color near person
            edge_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))
            dilated = cv2.dilate(binary_mask, edge_kernel)
            edge_region = dilated - binary_mask
            
            if edge_region.sum() > 0:
                # Get average background color near person
                bg_color = background[edge_region > 0].mean(axis=0)
                # Slightly adjust frame colors near edges
                edge_mask_3ch = np.stack([edge_region] * 3, axis=2).astype(np.float32) / 255.0
                frame = (frame * (1 - edge_mask_3ch * 0.1) + 
                        bg_color * (edge_mask_3ch * 0.1)).astype(np.uint8)
        
        # Composite
        mask_3ch = np.stack([mask_smooth] * 3, axis=2)
        result = (frame * mask_3ch + background * (1 - mask_3ch)).astype(np.uint8)
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Background"
    
    @classmethod
    def get_description(cls) -> str:
        return "Professional virtual background with advanced compositing"


class GreenScreenEffect(Effect):
    """
    Green Screen (Chroma Key) Effect
    
    Remove green/blue screen background.
    """
    
    def _register_parameters(self):
        self._add_parameter(
            'key_color', str, 'green',
            'Key color: green or blue'
        )
        self._add_parameter(
            'threshold', int, 50, 0, 255,
            'Color similarity threshold'
        )
        self._add_parameter(
            'smoothness', int, 5, 1, 20,
            'Edge smoothness'
        )
        self._add_parameter(
            'replace_r', int, 0, 0, 255,
            'Replacement color red'
        )
        self._add_parameter(
            'replace_g', int, 0, 0, 255,
            'Replacement color green'
        )
        self._add_parameter(
            'replace_b', int, 0, 0, 255,
            'Replacement color blue'
        )
    
    def apply(self, frame: np.ndarray) -> np.ndarray:
        key_color = self.get_parameter('key_color')
        threshold = self.get_parameter('threshold')
        smoothness = self.get_parameter('smoothness')
        replace_r = self.get_parameter('replace_r')
        replace_g = self.get_parameter('replace_g')
        replace_b = self.get_parameter('replace_b')
        
        # Convert to HSV for better color detection
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        
        # Define color range
        if key_color == 'blue':
            # Blue range in HSV
            lower = np.array([100, 50, 50])
            upper = np.array([130, 255, 255])
        else:  # green
            # Green range in HSV
            lower = np.array([40, 40, 40])
            upper = np.array([80, 255, 255])
        
        # Create mask
        mask = cv2.inRange(hsv, lower, upper)
        
        # Invert mask (we want to keep non-green areas)
        mask_inv = cv2.bitwise_not(mask)
        
        # Smooth edges
        mask_smooth = cv2.GaussianBlur(
            mask_inv,
            (smoothness * 2 + 1, smoothness * 2 + 1),
            0
        ).astype(np.float32) / 255.0
        
        # Create replacement background
        replacement = np.full_like(frame, (replace_b, replace_g, replace_r))
        
        # Composite
        mask_3ch = np.stack([mask_smooth] * 3, axis=2)
        result = (frame * mask_3ch + replacement * (1 - mask_3ch)).astype(np.uint8)
        
        return result
    
    @classmethod
    def get_category(cls) -> str:
        return "Background"
    
    @classmethod
    def get_description(cls) -> str:
        return "Remove green/blue screen background (chroma key)"
