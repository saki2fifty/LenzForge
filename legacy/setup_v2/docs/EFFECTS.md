# Effects Library Reference

**Complete guide to all 47 real-time effects in LenzForge V2.**

The effects library provides professional image processing capabilities optimized for real-time performance.

---

## Quick Reference

### Effect Categories

1. **[Blur](#blur-effects)** (6 effects, 19 params)
2. **[Edge Detection](#edge-detection-effects)** (4 effects, 13 params)
3. **[Color](#color-effects)** (6 effects, 24 params)
4. **[Filters](#filter-effects)** (5 effects, 14 params)
5. **[Stylize](#stylize-effects)** (6 effects, 13 params)
6. **[Morphological](#morphological-effects)** (4 effects, 10 params)
7. **[Background](#background-effects)** (4 effects, 19 params) ⭐
8. **[Transform](#transform-effects)** (4 effects, 13 params)
9. **[Face](#face-effects)** (3 effects, 9 params)
10. **[Advanced](#advanced-effects)** (5 effects, 13 params)

**Total**: 47 effects | 147 parameters

---

## Basic Usage

### Creating an Effect

```python
from backend_v2.effects import get_effects_manager

# Get manager
manager = get_effects_manager()

# Create effect
effect = manager.create_effect('GaussianBlurEffect')

# Configure
effect.set_parameter('amount', 15)
effect.enable()

# Apply to frame
result = effect.apply(frame)
```

### Using Effect Chains

```python
# Create chain
chain = manager.create_effect_chain([
    'BrightnessContrastEffect',
    'VignetteEffect',
    'FilmGrainEffect'
])

# Configure and enable
for effect in chain.effects:
    effect.enable()
    # Set parameters as needed

# Apply all
result = chain.apply(frame)
```

### Effect Introspection

```python
# Get all effects
all_effects = manager.get_all_effects()

# Get by category
blur_effects = manager.get_effects_by_category('Blur')

# Get effect info
info = manager.get_effect_info('GaussianBlurEffect')
print(info['parameters'])

# Get statistics
stats = manager.get_statistics()
print(f"Total effects: {stats['total_effects']}")
print(f"Total parameters: {stats['total_parameters']}")
```

---

## Blur Effects

### 1. GaussianBlurEffect

**Description**: Standard Gaussian blur with sigma control

**Parameters**:
- `amount` (int, 1-99): Blur kernel size (must be odd)
- `sigma` (float, 0.0-10.0): Standard deviation (0 = auto-calculate)

**Performance**: ~3ms @ 640×480

**Use Cases**: General smoothing, soft focus, depth of field

**Example**:
```python
blur = manager.create_effect('GaussianBlurEffect')
blur.set_parameter('amount', 21)
blur.set_parameter('sigma', 0.0)
blur.enable()
result = blur.apply(frame)
```

---

### 2. MotionBlurEffect

**Description**: Directional motion blur with angle/distance

**Parameters**:
- `angle` (float, 0-360): Motion direction in degrees
- `distance` (int, 1-50): Motion blur distance in pixels

**Performance**: ~5ms @ 640×480

**Use Cases**: Speed effects, dramatic motion, action sequences

**Example**:
```python
motion = manager.create_effect('MotionBlurEffect')
motion.set_parameter('angle', 45.0)  # 45° diagonal
motion.set_parameter('distance', 20)
```

---

### 3. RadialBlurEffect

**Description**: Radial blur from center point (zoom effect)

**Parameters**:
- `strength` (float, 0.0-2.0): Blur intensity
- `center_x` (float, 0.0-1.0): Center X (normalized)
- `center_y` (float, 0.0-1.0): Center Y (normalized)

**Performance**: ~8ms @ 640×480

**Use Cases**: Zoom effects, focus attention, dramatic impact

---

### 4. BoxBlurEffect

**Description**: Fast box filter blur

**Parameters**:
- `amount` (int, 1-99): Kernel size

**Performance**: ~2ms @ 640×480 (fastest blur!)

**Use Cases**: Quick smoothing, performance-critical applications

---

### 5. BilateralFilterEffect

**Description**: Edge-preserving smoothing

**Parameters**:
- `d` (int, 1-20): Filter diameter
- `sigma_color` (float, 0-200): Color space sigma
- `sigma_space` (float, 0-200): Coordinate space sigma

**Performance**: ~12ms @ 640×480

**Use Cases**: Skin smoothing, noise reduction while preserving edges

---

### 6. MedianBlurEffect

**Description**: Salt-and-pepper noise reduction

**Parameters**:
- `kernel_size` (int, 1-99): Filter size (must be odd)

**Performance**: ~4ms @ 640×480

**Use Cases**: Remove impulse noise, preserve edges

---

## Edge Detection Effects

### 7. CannyEdgeEffect

**Description**: Multi-stage edge detection algorithm

**Parameters**:
- `threshold1` (int, 0-255): Low threshold for edge linking
- `threshold2` (int, 0-255): High threshold for strong edges
- `aperture_size` (int, 3/5/7): Sobel aperture size
- `l2_gradient` (bool): Use L2 gradient norm

**Performance**: ~6ms @ 640×480

**Use Cases**: Precise edge detection, computer vision, artistic effects

---

### 8. SobelEdgeEffect

**Description**: Sobel operators for edge detection

**Parameters**:
- `kernel_size` (int, 1/3/5/7): Sobel kernel size
- `direction` (str): 'x', 'y', or 'both'
- `scale` (float, 0.1-2.0): Result scaling factor

**Performance**: ~4ms @ 640×480

---

### 9. LaplacianEdgeEffect

**Description**: Second derivative edge detection

**Parameters**:
- `kernel_size` (int, 1/3/5/7): Laplacian kernel size
- `scale` (float, 0.1-2.0): Result scaling

**Performance**: ~3ms @ 640×480

---

### 10. ScharrEdgeEffect

**Description**: Optimized 3×3 edge detection

**Parameters**:
- `direction` (str): 'x', 'y', or 'both'
- `scale` (float, 0.1-2.0): Result scaling

**Performance**: ~3ms @ 640×480

---

## Color Effects

### 11. BrightnessContrastEffect

**Description**: Simple brightness and contrast adjustment

**Parameters**:
- `brightness` (int, -100 to 100): Brightness adjustment
- `contrast` (int, -100 to 100): Contrast adjustment
- `auto_contrast` (bool): Auto-adjust contrast based on histogram

**Performance**: ~2ms @ 640×480

**Use Cases**: Quick color correction, exposure fix, image enhancement

**Example**:
```python
bc = manager.create_effect('BrightnessContrastEffect')
bc.set_parameter('brightness', 10)
bc.set_parameter('contrast', 20)
bc.set_parameter('auto_contrast', False)
```

---

### 12. HSVAdjustmentEffect

**Description**: Hue, saturation, value control

**Parameters**:
- `hue` (int, -180 to 180): Hue shift in degrees
- `saturation` (int, -100 to 100): Saturation adjustment
- `value` (int, -100 to 100): Value/brightness adjustment

**Performance**: ~4ms @ 640×480

**Use Cases**: Color grading, creative color shifts, mood adjustment

---

### 13. ColorBalanceEffect

**Description**: Professional color balance for shadows, midtones, highlights

**Parameters** (10 total):
- Shadows: `shadow_red`, `shadow_green`, `shadow_blue` (int, -100 to 100)
- Midtones: `midtone_red`, `midtone_green`, `midtone_blue` (int, -100 to 100)
- Highlights: `highlight_red`, `highlight_green`, `highlight_blue` (int, -100 to 100)
- `preserve_luminosity` (bool): Maintain brightness

**Performance**: ~5ms @ 640×480

**Use Cases**: Professional color correction, cinematic looks

---

### 14. LevelsEffect

**Description**: Input/output levels with gamma correction

**Parameters**:
- `input_black` (int, 0-255): Input black point
- `input_white` (int, 0-255): Input white point
- `output_black` (int, 0-255): Output black point
- `output_white` (int, 0-255): Output white point
- `gamma` (float, 0.1-3.0): Gamma correction

**Performance**: ~3ms @ 640×480

---

### 15. TemperatureTintEffect

**Description**: Color temperature and tint adjustment

**Parameters**:
- `temperature` (int, -100 to 100): Warm/cool adjustment
- `tint` (int, -100 to 100): Green/magenta adjustment

**Performance**: ~3ms @ 640×480

---

### 16. CurvesEffect

**Description**: Tone curves with presets

**Parameters**:
- `preset` (str): 'linear', 'contrast', 'brighten', 'darken'
- `strength` (float, 0.0-2.0): Effect strength

**Performance**: ~4ms @ 640×480

---

## Filter Effects

### 17. SharpenEffect

**Description**: Detail enhancement with threshold

**Parameters**:
- `amount` (int, 0-100): Sharpening amount
- `threshold` (int, 0-255): Only sharpen if pixel difference > threshold

**Performance**: ~3ms @ 640×480

**Use Cases**: Enhance details, improve clarity

---

### 18. UnsharpMaskEffect

**Description**: Professional sharpening technique

**Parameters**:
- `amount` (float, 0.0-2.0): Sharpening strength
- `radius` (int, 1-20): Blur radius for mask
- `threshold` (int, 0-255): Sharpening threshold

**Performance**: ~5ms @ 640×480

---

### 19. DenoiseEffect

**Description**: Noise reduction

**Parameters**:
- `method` (str): 'fast' (bilateral) or 'quality' (nl-means)
- `strength` (int, 1-20): Denoising strength

**Performance**: ~10-30ms depending on method

---

### 20. EmbossEffect

**Description**: 3D embossed appearance

**Parameters**:
- `strength` (float, 0.0-2.0): Emboss strength

**Performance**: ~3ms @ 640×480

---

### 21. FindEdgesEffect

**Description**: Artistic edge highlighting

**Parameters**:
- `intensity` (float, 0.0-2.0): Edge intensity

**Performance**: ~4ms @ 640×480

---

## Stylize Effects

### 22. PosterizeEffect

**Description**: Reduce color levels for poster effect

**Parameters**:
- `levels` (int, 2-32): Number of color levels per channel

**Performance**: ~2ms @ 640×480

---

### 23. QuantizeEffect

**Description**: K-means color quantization with dithering

**Parameters**:
- `colors` (int, 2-256): Number of colors
- `dithering` (bool): Apply dithering

**Performance**: ~15ms @ 640×480

---

### 24. OilPaintingEffect

**Description**: Oil painting simulation

**Parameters**:
- `size` (int, 1-10): Brush size
- `dynratio` (int, 1-10): Dynamic ratio

**Performance**: ~20ms @ 640×480

---

### 25. CartoonEffect

**Description**: Cartoon-style rendering with edges

**Parameters**:
- `edge_threshold` (int, 50-150): Edge detection threshold

**Performance**: ~10ms @ 640×480

---

### 26. PencilSketchEffect

**Description**: Pencil drawing simulation

**Parameters**:
- `shade_intensity` (float, 0.0-0.1): Shading intensity
- `line_darkness` (float, 0.0-1.0): Line darkness

**Performance**: ~8ms @ 640×480

---

### 27. StylizationEffect

**Description**: Edge-preserving stylization

**Parameters**:
- `sigma_s` (float, 0-200): Spatial sigma
- `sigma_r` (float, 0.0-1.0): Range sigma

**Performance**: ~12ms @ 640×480

---

## Morphological Effects

### 28. ErodeDilateEffect

**Description**: Morphological erosion or dilation

**Parameters**:
- `operation` (str): 'erode' or 'dilate'
- `kernel_size` (int, 1-20): Structuring element size
- `iterations` (int, 1-10): Number of iterations

**Performance**: ~3ms @ 640×480

---

### 29. OpenCloseEffect

**Description**: Opening (remove noise) or closing (fill holes)

**Parameters**:
- `operation` (str): 'open' or 'close'
- `kernel_size` (int, 1-20): Structuring element size

**Performance**: ~4ms @ 640×480

---

### 30. MorphologicalGradientEffect

**Description**: Edge highlighting via morphology

**Parameters**:
- `kernel_size` (int, 1-20): Structuring element size

**Performance**: ~4ms @ 640×480

---

### 31. TopHatBlackHatEffect

**Description**: Feature extraction (light/dark)

**Parameters**:
- `operation` (str): 'tophat' or 'blackhat'
- `kernel_size` (int, 1-20): Structuring element size

**Performance**: ~4ms @ 640×480

---

## Background Effects ⭐

### 32. BackgroundBlurEffect

**Description**: Blur background while keeping person sharp (Zoom/Teams style!)

**Parameters**:
- `blur_amount` (int, 1-99): Background blur (odd number)
- `edge_smoothness` (int, 1-20): Edge transition smoothness
- `threshold` (float, 0.0-1.0): Segmentation confidence threshold

**Performance**: ~15ms @ 640×480 (requires segmentation)

**Requires**: Person segmentation mask from MediaPipe Pose

**Use Cases**: Video calls, professional recording, privacy

**Example**:
```python
bg_blur = manager.create_effect('BackgroundBlurEffect')
bg_blur.set_segmentation_mask(pose_segmentation_mask)
bg_blur.set_parameter('blur_amount', 25)
bg_blur.set_parameter('edge_smoothness', 7)
bg_blur.enable()
result = bg_blur.apply(frame)
```

---

### 33. BackgroundReplaceEffect

**Description**: Replace background with solid color or image

**Parameters**:
- `mode` (str): 'color' or 'image'
- `color_r`, `color_g`, `color_b` (int, 0-255): Background color (BGR)
- `edge_smoothness` (int, 1-20): Edge smoothness
- `threshold` (float, 0.0-1.0): Segmentation threshold

**Performance**: ~15ms @ 640×480

**Requires**: Person segmentation mask

**Use Cases**: Custom backgrounds, green screen replacement

---

### 34. VirtualBackgroundEffect

**Description**: Professional virtual backgrounds with advanced compositing

**Parameters**:
- `edge_smoothness` (int, 1-20): Edge smoothness
- `threshold` (float, 0.0-1.0): Segmentation threshold
- `edge_color_correction` (bool): Apply color correction to edges
- `background_scale` (float, 0.1-2.0): Background scale factor

**Performance**: ~18ms @ 640×480

**Requires**: Person segmentation mask + background image

---

### 35. GreenScreenEffect

**Description**: Chroma key (green/blue screen removal)

**Parameters**:
- `key_color` (str): 'green' or 'blue'
- `threshold` (int, 0-255): Color similarity threshold
- `smoothness` (int, 1-20): Edge smoothness
- `replace_r`, `replace_g`, `replace_b` (int, 0-255): Replacement color

**Performance**: ~8ms @ 640×480

**Use Cases**: Green screen production, content creation

---

## Transform Effects

### 36. RotateEffect

**Description**: Rotate image by specified angle

**Parameters**:
- `angle` (float, -360 to 360): Rotation angle (counter-clockwise)
- `scale` (float, 0.1-3.0): Scale factor during rotation
- `auto_crop` (bool): Automatically crop to remove black borders

**Performance**: ~4ms @ 640×480

---

### 37. FlipEffect

**Description**: Flip image horizontally, vertically, or both

**Parameters**:
- `mode` (str): 'horizontal', 'vertical', or 'both'

**Performance**: <1ms @ 640×480 (very fast!)

---

### 38. PerspectiveEffect

**Description**: 4-corner perspective transformation

**Parameters** (8 corner offsets):
- `top_left_x`, `top_left_y` (float, -0.5 to 0.5): Top-left offset
- `top_right_x`, `top_right_y` (float, -0.5 to 0.5): Top-right offset
- `bottom_left_x`, `bottom_left_y` (float, -0.5 to 0.5): Bottom-left offset
- `bottom_right_x`, `bottom_right_y` (float, -0.5 to 0.5): Bottom-right offset

**Performance**: ~5ms @ 640×480

**Use Cases**: Correct perspective distortion, creative warping

---

### 39. WarpEffect

**Description**: Various warping effects

**Parameters**:
- `mode` (str): 'fisheye', 'barrel', 'pincushion', or 'wave'
- `strength` (float, 0.0-2.0): Warp strength

**Performance**: ~15ms @ 640×480

**Use Cases**: Creative distortion, lens simulation

---

## Face Effects

### 40. BeautyModeEffect

**Description**: Skin smoothing and brightening

**Parameters**:
- `smoothing` (int, 0-100): Skin smoothing amount
- `brightening` (int, 0-50): Skin brightening amount
- `preserve_detail` (bool): Preserve facial features (eyes, mouth, nose)

**Performance**: ~12ms @ 640×480

**Requires**: Face landmarks (optional, for better preservation)

---

### 41. FaceReshapeEffect

**Description**: Subtle facial feature reshaping

**Parameters**:
- `face_slimming` (int, 0-100): Face slimming amount
- `eye_enlargement` (int, 0-100): Eye enlargement amount

**Performance**: ~15ms @ 640×480

**Requires**: Face landmarks

---

### 42. MakeupEffect

**Description**: Virtual makeup application

**Parameters**:
- `lipstick_intensity` (int, 0-100): Lipstick intensity
- `lipstick_r`, `lipstick_g`, `lipstick_b` (int, 0-255): Lipstick color
- `blush_intensity` (int, 0-100): Blush intensity

**Performance**: ~10ms @ 640×480

**Requires**: Face landmarks

---

## Advanced Effects

### 43. HDREffect

**Description**: Enhanced dynamic range with CLAHE

**Parameters**:
- `strength` (float, 0.0-2.0): HDR effect strength
- `gamma` (float, 0.1-3.0): Gamma correction
- `saturation` (float, 0.0-2.0): Color saturation boost

**Performance**: ~8ms @ 640×480

**Use Cases**: Enhance detail in shadows/highlights, dramatic look

---

### 44. ColorGradingEffect

**Description**: Professional lift/gamma/gain color grading

**Parameters** (9 total):
- Lift (shadows): `lift_r`, `lift_g`, `lift_b` (float, -1.0 to 1.0)
- Gamma (midtones): `gamma_r`, `gamma_g`, `gamma_b` (float, 0.1 to 3.0)
- Gain (highlights): `gain_r`, `gain_g`, `gain_b` (float, 0.0 to 2.0)

**Performance**: ~5ms @ 640×480

**Use Cases**: Cinematic looks, professional color correction

---

### 45. FilmGrainEffect

**Description**: Add cinematic film grain texture

**Parameters**:
- `intensity` (int, 0-100): Grain intensity
- `size` (float, 0.5-3.0): Grain size
- `colored` (bool): Add color to grain

**Performance**: ~6ms @ 640×480

**Use Cases**: Vintage look, film simulation

---

### 46. VignetteEffect

**Description**: Darken or lighten edges of image

**Parameters**:
- `strength` (float, 0.0-2.0): Vignette strength
- `radius` (float, 0.1-2.0): Vignette radius (larger = softer)
- `mode` (str): 'darken' or 'lighten'

**Performance**: ~3ms @ 640×480

**Use Cases**: Focus attention, cinematic look

---

### 47. ChromaticAberrationEffect

**Description**: Simulate lens chromatic aberration

**Parameters**:
- `strength` (int, 0-50): Aberration strength in pixels
- `type` (str): 'radial' or 'lateral'

**Performance**: ~5ms @ 640×480

**Use Cases**: Artistic effects, lens simulation

---

## Performance Guide

### Performance Tiers

**Very Fast (<5ms)**:
- FlipEffect, BoxBlurEffect, BrightnessContrastEffect
- Simple transforms, basic color adjustments

**Fast (5-10ms)**:
- GaussianBlurEffect, EdgeDetection, Most filters
- Standard image processing operations

**Medium (10-20ms)**:
- BilateralFilterEffect, OilPaintingEffect, Face effects
- More complex algorithms, multiple passes

**Slower (20-30ms)**:
- Background effects (require segmentation)
- QuantizeEffect, Heavy stylization

**Optimization Tips**:
1. Use lower resolution (640×480 vs 1280×720)
2. Disable unused effects in chain
3. Use faster alternatives (Box vs Gaussian blur)
4. Batch similar operations together
5. Profile your specific effect chain

---

## Effect Chaining Best Practices

### Recommended Order

1. **Color Correction** first
   - BrightnessContrastEffect, LevelsEffect

2. **Spatial Operations** second
   - Blur, Sharpen, Filters

3. **Stylization** third
   - Cartoon, OilPainting, Pencil Sketch

4. **Background Effects** fourth
   - Requires clean input

5. **Final Touches** last
   - Vignette, Film Grain, Color Grading

### Example Professional Chain

```python
chain = manager.create_effect_chain([
    'BrightnessContrastEffect',  # Fix exposure
    'HSVAdjustmentEffect',       # Adjust colors
    'BackgroundBlurEffect',      # Blur background
    'UnsharpMaskEffect',         # Sharpen person
    'ColorGradingEffect',        # Cinematic look
    'FilmGrainEffect',           # Add texture
    'VignetteEffect'             # Focus attention
])
```

---

## Troubleshooting

### Effect Not Working
- Check if effect is enabled: `effect.is_enabled()`
- Verify parameters are in valid range
- Ensure frame format is correct (BGR, uint8)

### Poor Performance
- Profile with: `import time; start = time.time(); ...; print(time.time() - start)`
- Reduce resolution if needed
- Disable heavy effects
- Check CPU usage

### Background Effects Not Working
- Ensure segmentation mask is provided
- Check mask resolution matches frame
- Verify threshold parameter
- Ensure MediaPipe Pose is enabled with segmentation

---

## Future Enhancements

### Planned (Not Yet Implemented)
- GPU acceleration (CUDA/OpenCL)
- LUT (3D lookup table) support
- Real face mesh warping (using landmarks)
- Depth-based effects (bokeh, depth blur)
- Particle effects (snow, rain, sparkles)
- AR overlays (stickers, frames, masks)

---

## API Integration

Effects can be controlled via HTTP API (Phase 5):

```javascript
// Get all effects
fetch('/api/effects/list')

// Apply effect
fetch('/api/effects/apply', {
    method: 'POST',
    body: JSON.stringify({
        effect_name: 'BackgroundBlurEffect',
        parameters: {
            blur_amount: 25,
            edge_smoothness: 7
        },
        enabled: true
    })
})
```

See [API Reference](API_REFERENCE.md) for complete API documentation.

---

**Status**: ✅ Complete - All 47 effects documented
**Total**: 47 effects | 147 parameters | 10 categories
**Performance**: Optimized for real-time (most <15ms @ 640×480)
