"""
Effects package for backend v2

Complete effects library with 47 effects across 10 categories:
- Blur (6): Gaussian, Motion, Radial, Box, Bilateral, Median
- Edge Detection (4): Canny, Sobel, Laplacian, Scharr
- Color (6): Brightness/Contrast, HSV, Color Balance, Levels, Temp/Tint, Curves
- Filters (5): Sharpen, Unsharp Mask, Denoise, Emboss, Find Edges
- Stylize (6): Posterize, Quantize, Oil Painting, Cartoon, Pencil, Stylization
- Morphological (4): Erode/Dilate, Open/Close, Gradient, Top/Black Hat
- Background (4): Blur, Replace, Virtual, Green Screen
- Transform (4): Rotate, Flip, Perspective, Warp
- Face (3): Beauty Mode, Reshape, Makeup
- Advanced (5): HDR, Color Grading, Film Grain, Vignette, Chromatic Aberration
"""

from .base import Effect, EffectChain, EffectParameter
from .manager import EffectsManager, get_effects_manager

__all__ = [
    'Effect',
    'EffectChain',
    'EffectParameter',
    'EffectsManager',
    'get_effects_manager'
]
