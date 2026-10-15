# LenzForge AR - Per-Element Customization Matrix

**Part of:** Modernization Plan  
**Total Properties:** 200+ customizable properties across 6 major categories  
**Status:** Planning Phase

---

## 📋 Overview

This document catalogs **every customizable property** for every UI element in LenzForge AR. Users can adjust these properties through the customization panel, save them as presets, and have them persist across sessions.

---

## Customization Categories

1. [Panel Customization (20 properties)](#1-panel-customization)
2. [Landmark Customization (17 properties)](#2-landmark-customization)
3. [Text Customization (13 properties)](#3-text-customization)
4. [Button Customization (15 properties)](#4-button-customization)
5. [Video Customization (15 properties)](#5-video-customization)
6. [Graph Customization (20 properties)](#6-graph-customization)

**Total: 100 base properties × multiple instances = 200+ total customizable properties**

---

## 1. Panel Customization

Controls for all UI panels (Left Panel, Right Panel, Top Bar, Bottom Bar, Popups).

### 1.1 Background Properties (5 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **background_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Panel background color |
| **background_opacity** | Float | 0.0 - 1.0 | 0.05 (Dark/Neon), 0.95 (Light) | Overall panel transparency |
| **background_image** | Texture | null or file path | null | Optional background image |
| **background_tiling** | Enum | stretch, tile, center | stretch | How background image is displayed |
| **background_blur** | Float | 0.0 - 30.0 | 15.0 | Backdrop blur amount (glassmorphism) |

### 1.2 Border Properties (5 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **border_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Border color |
| **border_thickness** | Float | 0.0 - 10.0 | 1.0 | Border width in pixels |
| **border_style** | Enum | solid, dashed, dotted, double | solid | Border line style |
| **border_dash_length** | Float | 1.0 - 20.0 | 5.0 | Dash length (if dashed/dotted) |
| **border_dash_gap** | Float | 1.0 - 20.0 | 3.0 | Gap between dashes |

### 1.3 Corner Properties (2 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **corner_radius** | Float | 0.0 - 30.0 | 12.0 | Border radius for rounded corners |
| **corner_style** | Enum | rounded, beveled, notched | rounded | Corner shape style |

### 1.4 Padding Properties (4 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **padding_top** | Float | 0.0 - 50.0 | 10.0 | Internal spacing from top edge |
| **padding_right** | Float | 0.0 - 50.0 | 10.0 | Internal spacing from right edge |
| **padding_bottom** | Float | 0.0 - 50.0 | 10.0 | Internal spacing from bottom edge |
| **padding_left** | Float | 0.0 - 50.0 | 10.0 | Internal spacing from left edge |

### 1.5 Margin Properties (4 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **margin_top** | Float | 0.0 - 50.0 | 5.0 | External spacing from top |
| **margin_right** | Float | 0.0 - 50.0 | 5.0 | External spacing from right |
| **margin_bottom** | Float | 0.0 - 50.0 | 5.0 | External spacing from bottom |
| **margin_left** | Float | 0.0 - 50.0 | 5.0 | External spacing from left |

**Total Panel Properties: 20**

**Applied to:** Left Panel, Right Panel, Top Bar, Bottom Bar, Popup Windows (5 instances) = **100 properties**

---

## 2. Landmark Customization

Controls for the 478 face mesh landmarks and 20 iris landmarks.

### 2.1 Point Appearance (8 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **point_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Landmark point color |
| **point_size** | Float | 1.0 - 20.0 | 3.0 | Point diameter in pixels |
| **point_shape** | Enum | circle, square, diamond, cross | circle | Point shape |
| **point_opacity** | Float | 0.0 - 1.0 | 1.0 | Point transparency |
| **fill_enabled** | Boolean | true/false | true | Fill points with color |
| **outline_enabled** | Boolean | true/false | false | Draw outline around points |
| **outline_color** | Color (RGBA) | 0-255, 0.0-1.0 | Color.BLACK | Outline color |
| **outline_thickness** | Float | 0.5 - 5.0 | 1.0 | Outline width in pixels |

### 2.2 Line/Mesh Appearance (4 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **line_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Mesh connection line color |
| **line_thickness** | Float | 0.5 - 10.0 | 1.5 | Line width in pixels |
| **line_opacity** | Float | 0.0 - 1.0 | 0.3 | Line transparency |
| **mesh_style** | Enum | full, partial, contour_only | full | Which connections to draw |

### 2.3 Glow Effect (3 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **glow_enabled** | Boolean | true/false | false | Enable glow effect |
| **glow_color** | Color (RGBA) | 0-255, 0.0-1.0 | Same as point_color | Glow color |
| **glow_intensity** | Float | 0.0 - 5.0 | 1.0 | Glow brightness/size |

### 2.4 Animation (2 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **animation_enabled** | Boolean | true/false | false | Enable pulse/animation |
| **animation_speed** | Float | 0.0 - 5.0 | 1.0 | Animation speed multiplier |

**Total Landmark Properties: 17**

**Applied to:** Face Mesh (478), Left Iris (20), Right Iris (20), Face Contours (multiple groups) = **~80+ properties per landmark type**

*(Note: Properties are per-group, not per-landmark, so this is manageable)*

---

## 3. Text Customization

Controls for all text elements throughout the UI.

### 3.1 Font Properties (4 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **font_family** | String/Enum | System fonts or custom | "Roboto" | Font typeface |
| **font_size** | Float | 8.0 - 72.0 | 14.0 | Font size in points |
| **font_weight** | Enum | thin, light, normal, bold, black | normal | Font weight/boldness |
| **font_style** | Enum | normal, italic, oblique | normal | Font style |

### 3.2 Color Properties (3 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **text_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Main text color |
| **text_opacity** | Float | 0.0 - 1.0 | 1.0 | Text transparency |
| **text_shadow_color** | Color (RGBA) | 0-255, 0.0-1.0 | Color.BLACK | Text shadow/outline color |

### 3.3 Spacing Properties (3 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **letter_spacing** | Float | -5.0 - 10.0 | 0.0 | Space between letters (px) |
| **line_height** | Float | 0.5 - 3.0 | 1.2 | Line height multiplier |
| **word_spacing** | Float | -5.0 - 10.0 | 0.0 | Space between words (px) |

### 3.4 Effects (3 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **shadow_enabled** | Boolean | true/false | false | Enable text shadow |
| **shadow_offset_x** | Float | -10.0 - 10.0 | 1.0 | Shadow horizontal offset |
| **shadow_offset_y** | Float | -10.0 - 10.0 | 1.0 | Shadow vertical offset |

**Total Text Properties: 13**

**Applied to:** Titles, Labels, Values, Tooltips, Buttons (many instances) = **100+ text elements**

---

## 4. Button Customization

Controls for all interactive buttons and controls.

### 4.1 Normal State (5 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **normal_bg_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Background when idle |
| **normal_border_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Border when idle |
| **normal_text_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Text when idle |
| **normal_icon_color** | Color (RGBA) | 0-255, 0.0-1.0 | Same as text | Icon tint when idle |
| **normal_opacity** | Float | 0.0 - 1.0 | 1.0 | Overall button opacity |

### 4.2 Hover State (5 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **hover_bg_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Background when hovered |
| **hover_border_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Border when hovered |
| **hover_text_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Text when hovered |
| **hover_scale** | Float | 0.8 - 1.2 | 1.05 | Size scale on hover |
| **hover_glow** | Float | 0.0 - 5.0 | 0.0 | Glow intensity on hover |

### 4.3 Pressed/Active States (3 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **pressed_bg_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Background when clicked |
| **active_bg_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Background when active/selected |
| **disabled_opacity** | Float | 0.0 - 1.0 | 0.3 | Opacity when disabled |

### 4.4 Animation & Shape (2 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **transition_duration** | Float | 0.0 - 1.0 | 0.2 | Animation duration (seconds) |
| **corner_radius** | Float | 0.0 - 30.0 | 6.0 | Button corner roundness |

**Total Button Properties: 15**

**Applied to:** ~50 buttons throughout the UI = **750 total button properties**

---

## 5. Video Customization

Controls for the AR video feed display and processing.

### 5.1 Color Adjustments (7 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **brightness** | Float | -1.0 - 1.0 | 0.0 | Brightness adjustment |
| **contrast** | Float | 0.0 - 3.0 | 1.0 | Contrast multiplier |
| **saturation** | Float | 0.0 - 3.0 | 1.0 | Color saturation |
| **hue_shift** | Float | -180.0 - 180.0 | 0.0 | Hue rotation (degrees) |
| **exposure** | Float | -3.0 - 3.0 | 0.0 | Exposure adjustment (stops) |
| **gamma** | Float | 0.5 - 3.0 | 1.0 | Gamma correction |
| **temperature** | Float | -100.0 - 100.0 | 0.0 | Color temperature (warm/cool) |

### 5.2 Filter Effects (5 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **sharpness** | Float | 0.0 - 2.0 | 1.0 | Sharpness multiplier |
| **blur_amount** | Float | 0.0 - 20.0 | 0.0 | Gaussian blur radius |
| **denoise_strength** | Float | 0.0 - 1.0 | 0.0 | Noise reduction amount |
| **vignette_amount** | Float | 0.0 - 1.0 | 0.0 | Edge darkening amount |
| **vignette_softness** | Float | 0.0 - 1.0 | 0.5 | Vignette edge softness |

### 5.3 Display Properties (3 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **border_color** | Color (RGBA) | 0-255, 0.0-1.0 | Color.TRANSPARENT | Video border color |
| **border_thickness** | Float | 0.0 - 10.0 | 0.0 | Video border width |
| **aspect_ratio_mode** | Enum | fit, fill, stretch | fit | How video fills area |

**Total Video Properties: 15**

---

## 6. Graph Customization

Controls for performance graphs (FPS, CPU, Memory, Frame Time).

### 6.1 Line Properties (5 properties per graph type)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **line_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Graph line color |
| **line_thickness** | Float | 0.5 - 5.0 | 2.0 | Line width in pixels |
| **line_style** | Enum | solid, dashed, dotted | solid | Line drawing style |
| **area_fill** | Boolean | true/false | true | Fill area under line |
| **area_fill_opacity** | Float | 0.0 - 1.0 | 0.3 | Area fill transparency |

### 6.2 Background & Grid (5 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **background_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Graph background |
| **grid_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Grid line color |
| **grid_thickness** | Float | 0.5 - 3.0 | 1.0 | Grid line width |
| **grid_divisions_x** | Int | 4 - 20 | 10 | Horizontal grid lines |
| **grid_divisions_y** | Int | 4 - 20 | 6 | Vertical grid lines |

### 6.3 Axes & Labels (5 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **axis_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Axis line color |
| **axis_thickness** | Float | 0.5 - 3.0 | 1.5 | Axis line width |
| **label_color** | Color (RGBA) | 0-255, 0.0-1.0 | Theme-specific | Label text color |
| **label_font_size** | Float | 8.0 - 20.0 | 10.0 | Label text size |
| **show_values** | Boolean | true/false | true | Show numeric values |

### 6.4 Data & Scaling (5 properties)

| Property | Type | Range | Default | Description |
|----------|------|-------|---------|-------------|
| **time_range** | Float | 10.0 - 300.0 | 60.0 | Time window (seconds) |
| **update_frequency** | Float | 0.1 - 2.0 | 0.5 | Update interval (seconds) |
| **auto_scale** | Boolean | true/false | true | Auto-scale Y axis |
| **y_min** | Float | varies | 0.0 | Minimum Y value (if not auto) |
| **y_max** | Float | varies | 100.0 | Maximum Y value (if not auto) |

**Total Graph Properties: 20 per graph type**

**Applied to:** FPS, CPU, Memory, Frame Time (4 graphs) = **80 graph properties**

---

## Total Customization Count

### By Category

| Category | Properties per Instance | Instances | Total |
|----------|------------------------|-----------|-------|
| Panels | 20 | 5 | 100 |
| Landmarks | 17 | 4 groups | 68 |
| Text | 13 | ~10 styles | 130 |
| Buttons | 15 | ~20 buttons | 300 |
| Video | 15 | 1 | 15 |
| Graphs | 20 | 4 | 80 |
| **TOTAL** | - | - | **693** |

### Practical Customization Scope

While there are technically 693+ individual properties, many share common values:
- **Unique properties requiring UI controls:** ~120
- **Instance-specific overrides:** Available on demand
- **Most commonly adjusted:** ~50 properties

---

## Customization UI Organization

### Settings Panel Structure

```
Settings Panel (Right Panel)
├── Theme Selection
│   ├── Dark / Light / Neon (preset buttons)
│   └── Custom (dropdown with saved presets)
├── Quick Adjustments (collapsible sections)
│   ├── 🎨 Colors
│   │   ├── Primary Color Picker
│   │   ├── Accent Color Picker
│   │   └── Highlight Color Picker
│   ├── 📏 Layout
│   │   ├── Panel Sizes (sliders)
│   │   ├── Padding (linked or individual)
│   │   └── Spacing (sliders)
│   ├── 🎥 Video
│   │   ├── Brightness/Contrast (sliders)
│   │   ├── Saturation/Hue (sliders)
│   │   └── Filters (toggles + sliders)
│   └── 📍 Landmarks
│       ├── Colors (per-group pickers)
│       ├── Sizes (sliders)
│       └── Effects (toggles + sliders)
├── Advanced Customization
│   ├── Panels (detailed controls)
│   ├── Text (font settings)
│   ├── Buttons (state colors)
│   └── Graphs (line styles)
└── Presets
    ├── Save Current (button)
    ├── Load Preset (dropdown)
    ├── Export to File (button)
    └── Import from File (button)
```

---

## Settings Persistence Structure

### JSON Configuration File

```json
{
  "version": "1.0.0",
  "last_modified": "2025-11-08T15:30:00Z",
  "current_theme": "dark",
  
  "panels": {
    "left": {
      "background_color": [255, 255, 255, 0.05],
      "border_color": [255, 255, 255, 0.15],
      "corner_radius": 12.0,
      "padding_top": 10.0,
      "padding_right": 10.0,
      "padding_bottom": 10.0,
      "padding_left": 10.0,
      // ... all 20 properties
    },
    "right": { /* same structure */ },
    "top": { /* same structure */ },
    "bottom": { /* same structure */ }
  },
  
  "landmarks": {
    "face_mesh": {
      "point_color": [0, 255, 0, 1.0],
      "point_size": 3.0,
      "line_color": [255, 255, 255, 0.3],
      "glow_enabled": false,
      // ... all 17 properties
    },
    "iris_left": { /* same structure */ },
    "iris_right": { /* same structure */ },
    "contours": { /* same structure */ }
  },
  
  "video": {
    "brightness": 0.0,
    "contrast": 1.0,
    "saturation": 1.0,
    // ... all 15 properties
  },
  
  "graphs": {
    "fps": {
      "line_color": [0, 255, 0, 1.0],
      "line_thickness": 2.0,
      "area_fill": true,
      // ... all 20 properties
    },
    "cpu": { /* same structure */ },
    "memory": { /* same structure */ },
    "frametime": { /* same structure */ }
  },
  
  "text_styles": {
    "heading": { /* 13 properties */ },
    "body": { /* 13 properties */ },
    "label": { /* 13 properties */ }
  },
  
  "button_styles": {
    "primary": { /* 15 properties */ },
    "secondary": { /* 15 properties */ }
  }
}
```

---

## Validation & Clamping

All property values must be validated and clamped to their allowed ranges.

### Validation Manager

```gdscript
extends Node
class_name ValidationManager

func validate_float(value: float, min_val: float, max_val: float) -> float:
    return clamp(value, min_val, max_val)

func validate_color(color: Array) -> Color:
    if color.size() != 4:
        return Color.WHITE
    return Color(
        clamp(color[0] / 255.0, 0.0, 1.0),
        clamp(color[1] / 255.0, 0.0, 1.0),
        clamp(color[2] / 255.0, 0.0, 1.0),
        clamp(color[3], 0.0, 1.0)
    )

func validate_enum(value: String, allowed: Array) -> String:
    if value in allowed:
        return value
    return allowed[0]  # Default to first option
```

---

## Real-Time Preview

All customization changes should preview in real-time (within 16ms/frame).

### Update Strategy

1. **User adjusts slider/picker** → Signal emitted
2. **CustomizationPanel** → Updates temporary setting
3. **ThemeManager/SettingsManager** → Applies change immediately
4. **Affected UI elements** → Update appearance
5. **User saves** → Writes to config file

### Performance Optimization

- Batch updates when possible (e.g., adjusting RGB at once)
- Use cached shader parameters for video adjustments
- Throttle rapid updates (max 60 updates/second)
- Only update visible elements

---

## Preset System

### Built-in Presets

1. **Dark (Professional)** - Navy/blue/pink
2. **Light (Clean)** - Gray/blue/orange
3. **Neon (Cyberpunk)** - Black/cyan/magenta
4. **High Contrast** - For accessibility
5. **Monochrome** - Grayscale theme

### Custom Presets

Users can:
- Save current settings as named preset
- Load saved presets instantly
- Export presets to JSON files
- Import presets from JSON files
- Share presets with other users
- Delete custom presets

---

## Keyboard Shortcuts for Customization

Quick access to customization features:

| Shortcut | Action |
|----------|--------|
| `Ctrl + ,` | Open Settings Panel |
| `Ctrl + T` | Toggle Themes (cycle) |
| `Ctrl + Shift + T` | Open Theme Picker |
| `Ctrl + R` | Reset to Theme Defaults |
| `Ctrl + S` | Save Current as Preset |
| `Ctrl + L` | Load Preset |
| `Ctrl + E` | Export Settings |
| `Ctrl + I` | Import Settings |

---

## Implementation Priority

### Phase 1: Core Properties (Must-Have)
- Panel colors and backgrounds
- Landmark colors and sizes
- Basic video adjustments
- Theme switching

### Phase 2: Styling Properties (Should-Have)
- Borders and corners
- Padding and margins
- Text styling
- Button states

### Phase 3: Advanced Properties (Nice-to-Have)
- Glow effects
- Animations
- Advanced filters
- Custom gradients

---

## Conclusion

This customization system provides **200+ properties** giving users complete control over:
- ✅ Every panel's appearance (colors, borders, spacing, effects)
- ✅ All landmark visualization (colors, sizes, glow, animation)
- ✅ Complete text styling (fonts, sizes, spacing, effects)
- ✅ All button states (normal, hover, pressed, disabled)
- ✅ Video display and processing (colors, filters, effects)
- ✅ Performance graphs (lines, fills, grids, axes)

With real-time preview, preset system, and settings persistence.

**Next Steps:**
1. Review customization scope
2. Approve property lists
3. Proceed to architecture and component design
4. Begin implementation

---

*Return to [MODERNIZATION_PLAN.md](./MODERNIZATION_PLAN.md) for overview and links to other documents.*
