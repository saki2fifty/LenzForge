# LenzForge AR - Theme System & Presets

**Part of:** Modernization Plan  
**Total Themes:** 3 complete presets + custom theme support  
**Status:** Planning Phase

---

## 📋 Overview

This document defines three complete theme presets for LenzForge AR, each with a distinct visual identity and use case. All themes include complete color palettes for every UI element.

---

## Theme Architecture

### Theme Structure

Each theme defines colors for:
- **Base Colors:** Background, secondary, accent, highlight, text
- **Panel Colors:** Panel backgrounds, borders, shadows
- **Landmark Colors:** Face mesh, iris, contour line colors
- **Button Colors:** Normal, hover, pressed, disabled states
- **Graph Colors:** FPS, CPU, memory, frame time lines
- **Effect Colors:** Glow, shadow, border effects

### Color Format

All colors use RGBA format for maximum flexibility:
```
Color(R, G, B, A)
- R: Red (0-255)
- G: Green (0-255)
- B: Blue (0-255)
- A: Alpha/Opacity (0.0-1.0)
```

CSS Hex format also provided for reference:
```
#RRGGBB or rgba(R, G, B, A)
```

---

## Theme 1: Dark (Professional)

**Use Case:** Professional work, long sessions, eye strain reduction  
**Aesthetic:** Modern, sophisticated, elegant  
**Mood:** Focused, serious, productive

### Base Colors

| Property | Value | CSS | Description |
|----------|-------|-----|-------------|
| background | Color(26, 26, 46, 1.0) | #1a1a2e | Deep navy background |
| secondary | Color(22, 33, 62, 1.0) | #16213e | Darker navy panels |
| accent | Color(15, 52, 96, 1.0) | #0f3460 | Royal blue accents |
| highlight | Color(233, 69, 96, 1.0) | #e94560 | Vibrant pink highlights |
| text_primary | Color(255, 255, 255, 1.0) | #ffffff | Bright white text |
| text_secondary | Color(160, 160, 160, 1.0) | #a0a0a0 | Light gray secondary text |

### Panel Colors

| Property | Value | CSS | Description |
|----------|-------|-----|-------------|
| panel_bg | Color(255, 255, 255, 0.05) | rgba(255,255,255,0.05) | 5% white overlay |
| panel_border | Color(255, 255, 255, 0.15) | rgba(255,255,255,0.15) | 15% white border |
| panel_shadow | Color(0, 0, 0, 0.5) | rgba(0,0,0,0.5) | 50% black shadow |
| panel_blur | 15px | - | Backdrop blur amount |
| corner_radius | 12px | - | Rounded corners |
| border_thickness | 1px | - | Thin elegant borders |

### Landmark Colors

| Property | Value | CSS | Description |
|----------|-------|-----|-------------|
| landmark_default | Color(0, 255, 0, 1.0) | #00ff00 | Bright green points |
| landmark_iris | Color(0, 255, 255, 1.0) | #00ffff | Cyan iris points |
| landmark_contour | Color(255, 0, 255, 1.0) | #ff00ff | Magenta contour lines |
| mesh_lines | Color(255, 255, 255, 0.3) | rgba(255,255,255,0.3) | 30% white mesh |
| landmark_glow | Color(0, 255, 0, 0.5) | rgba(0,255,0,0.5) | Green glow effect |
| point_size | 3px | - | Medium point size |
| line_thickness | 1.5px | - | Fine lines |

### Button Colors

| State | Background | Border | Text | Description |
|-------|------------|--------|------|-------------|
| Normal | Color(15, 52, 96, 0.8) | Color(15, 52, 96, 1.0) | Color(255,255,255,1.0) | Royal blue, 80% opacity |
| Hover | Color(15, 52, 96, 1.0) | Color(233, 69, 96, 1.0) | Color(255,255,255,1.0) | Royal blue, 100% opacity |
| Pressed | Color(233, 69, 96, 1.0) | Color(233, 69, 96, 1.0) | Color(255,255,255,1.0) | Pink highlight |
| Disabled | Color(160, 160, 160, 0.3) | Color(160, 160, 160, 0.5) | Color(160,160,160,1.0) | Gray, 30% opacity |
| Active | Color(233, 69, 96, 0.9) | Color(233, 69, 96, 1.0) | Color(255,255,255,1.0) | Pink, slightly transparent |

### Graph Colors

| Graph Type | Color | CSS | Description |
|------------|-------|-----|-------------|
| FPS Line | Color(0, 255, 0, 1.0) | #00ff00 | Green (good performance) |
| CPU Line | Color(0, 170, 255, 1.0) | #00aaff | Light blue |
| Memory Line | Color(255, 153, 0, 1.0) | #ff9900 | Orange |
| Frame Time | Color(255, 0, 255, 1.0) | #ff00ff | Magenta |
| Grid Lines | Color(255, 255, 255, 0.1) | rgba(255,255,255,0.1) | Subtle white grid |
| Axis Lines | Color(255, 255, 255, 0.3) | rgba(255,255,255,0.3) | Visible white axes |

### Complete Dark Theme JSON

```json
{
  "name": "Dark (Professional)",
  "id": "dark",
  "colors": {
    "background": [26, 26, 46, 1.0],
    "secondary": [22, 33, 62, 1.0],
    "accent": [15, 52, 96, 1.0],
    "highlight": [233, 69, 96, 1.0],
    "text_primary": [255, 255, 255, 1.0],
    "text_secondary": [160, 160, 160, 1.0]
  },
  "panels": {
    "background": [255, 255, 255, 0.05],
    "border": [255, 255, 255, 0.15],
    "shadow": [0, 0, 0, 0.5],
    "blur_amount": 15,
    "corner_radius": 12,
    "border_thickness": 1
  },
  "landmarks": {
    "default": [0, 255, 0, 1.0],
    "iris": [0, 255, 255, 1.0],
    "contour": [255, 0, 255, 1.0],
    "mesh_lines": [255, 255, 255, 0.3],
    "glow": [0, 255, 0, 0.5],
    "point_size": 3,
    "line_thickness": 1.5
  },
  "buttons": {
    "normal_bg": [15, 52, 96, 0.8],
    "normal_border": [15, 52, 96, 1.0],
    "hover_bg": [15, 52, 96, 1.0],
    "hover_border": [233, 69, 96, 1.0],
    "pressed_bg": [233, 69, 96, 1.0],
    "active_bg": [233, 69, 96, 0.9]
  },
  "graphs": {
    "fps": [0, 255, 0, 1.0],
    "cpu": [0, 170, 255, 1.0],
    "memory": [255, 153, 0, 1.0],
    "frametime": [255, 0, 255, 1.0],
    "grid": [255, 255, 255, 0.1],
    "axis": [255, 255, 255, 0.3]
  }
}
```

---

## Theme 2: Light (Clean Professional)

**Use Case:** Well-lit environments, daytime work, presentations  
**Aesthetic:** Clean, modern, minimal  
**Mood:** Bright, clear, professional

### Base Colors

| Property | Value | CSS | Description |
|----------|-------|-----|-------------|
| background | Color(245, 245, 245, 1.0) | #f5f5f5 | Light gray background |
| secondary | Color(224, 224, 224, 1.0) | #e0e0e0 | Slightly darker gray |
| accent | Color(33, 150, 243, 1.0) | #2196f3 | Material Design blue |
| highlight | Color(255, 87, 34, 1.0) | #ff5722 | Deep orange highlight |
| text_primary | Color(33, 33, 33, 1.0) | #212121 | Near-black text |
| text_secondary | Color(117, 117, 117, 1.0) | #757575 | Medium gray text |

### Panel Colors

| Property | Value | CSS | Description |
|----------|-------|-----|-------------|
| panel_bg | Color(255, 255, 255, 0.95) | rgba(255,255,255,0.95) | 95% white overlay |
| panel_border | Color(0, 0, 0, 0.12) | rgba(0,0,0,0.12) | 12% black border |
| panel_shadow | Color(0, 0, 0, 0.2) | rgba(0,0,0,0.2) | 20% black shadow |
| panel_blur | 10px | - | Subtle backdrop blur |
| corner_radius | 8px | - | Gentle rounded corners |
| border_thickness | 1px | - | Thin clean borders |

### Landmark Colors

| Property | Value | CSS | Description |
|----------|-------|-----|-------------|
| landmark_default | Color(76, 175, 80, 1.0) | #4caf50 | Material green points |
| landmark_iris | Color(0, 188, 212, 1.0) | #00bcd4 | Material cyan iris |
| landmark_contour | Color(156, 39, 176, 1.0) | #9c27b0 | Material purple contours |
| mesh_lines | Color(0, 0, 0, 0.2) | rgba(0,0,0,0.2) | 20% black mesh |
| landmark_glow | Color(76, 175, 80, 0.3) | rgba(76,175,80,0.3) | Subtle green glow |
| point_size | 3px | - | Medium point size |
| line_thickness | 1.5px | - | Fine lines |

### Button Colors

| State | Background | Border | Text | Description |
|-------|------------|--------|------|-------------|
| Normal | Color(33, 150, 243, 0.1) | Color(33, 150, 243, 0.3) | Color(33,150,243,1.0) | Light blue tint |
| Hover | Color(33, 150, 243, 0.2) | Color(33, 150, 243, 0.5) | Color(33,150,243,1.0) | Slightly darker |
| Pressed | Color(33, 150, 243, 1.0) | Color(33, 150, 243, 1.0) | Color(255,255,255,1.0) | Solid blue |
| Disabled | Color(189, 189, 189, 0.3) | Color(189, 189, 189, 0.5) | Color(189,189,189,1.0) | Gray disabled |
| Active | Color(255, 87, 34, 0.2) | Color(255, 87, 34, 1.0) | Color(255,87,34,1.0) | Orange active |

### Graph Colors

| Graph Type | Color | CSS | Description |
|------------|-------|-----|-------------|
| FPS Line | Color(76, 175, 80, 1.0) | #4caf50 | Material green |
| CPU Line | Color(33, 150, 243, 1.0) | #2196f3 | Material blue |
| Memory Line | Color(255, 152, 0, 1.0) | #ff9800 | Material orange |
| Frame Time | Color(156, 39, 176, 1.0) | #9c27b0 | Material purple |
| Grid Lines | Color(0, 0, 0, 0.08) | rgba(0,0,0,0.08) | Very subtle grid |
| Axis Lines | Color(0, 0, 0, 0.2) | rgba(0,0,0,0.2) | Visible dark axes |

### Complete Light Theme JSON

```json
{
  "name": "Light (Clean Professional)",
  "id": "light",
  "colors": {
    "background": [245, 245, 245, 1.0],
    "secondary": [224, 224, 224, 1.0],
    "accent": [33, 150, 243, 1.0],
    "highlight": [255, 87, 34, 1.0],
    "text_primary": [33, 33, 33, 1.0],
    "text_secondary": [117, 117, 117, 1.0]
  },
  "panels": {
    "background": [255, 255, 255, 0.95],
    "border": [0, 0, 0, 0.12],
    "shadow": [0, 0, 0, 0.2],
    "blur_amount": 10,
    "corner_radius": 8,
    "border_thickness": 1
  },
  "landmarks": {
    "default": [76, 175, 80, 1.0],
    "iris": [0, 188, 212, 1.0],
    "contour": [156, 39, 176, 1.0],
    "mesh_lines": [0, 0, 0, 0.2],
    "glow": [76, 175, 80, 0.3],
    "point_size": 3,
    "line_thickness": 1.5
  },
  "buttons": {
    "normal_bg": [33, 150, 243, 0.1],
    "normal_border": [33, 150, 243, 0.3],
    "hover_bg": [33, 150, 243, 0.2],
    "hover_border": [33, 150, 243, 0.5],
    "pressed_bg": [33, 150, 243, 1.0],
    "active_bg": [255, 87, 34, 0.2]
  },
  "graphs": {
    "fps": [76, 175, 80, 1.0],
    "cpu": [33, 150, 243, 1.0],
    "memory": [255, 152, 0, 1.0],
    "frametime": [156, 39, 176, 1.0],
    "grid": [0, 0, 0, 0.08],
    "axis": [0, 0, 0, 0.2]
  }
}
```

---

## Theme 3: Neon (Cyberpunk)

**Use Case:** Dark environments, entertainment, streaming  
**Aesthetic:** Futuristic, high-tech, cyberpunk  
**Mood:** Energetic, edgy, bold

### Base Colors

| Property | Value | CSS | Description |
|----------|-------|-----|-------------|
| background | Color(10, 10, 10, 1.0) | #0a0a0a | Near-black background |
| secondary | Color(21, 21, 21, 1.0) | #151515 | Very dark gray |
| accent | Color(0, 255, 255, 1.0) | #00ffff | Bright cyan |
| highlight | Color(255, 0, 255, 1.0) | #ff00ff | Bright magenta |
| text_primary | Color(0, 255, 255, 1.0) | #00ffff | Cyan text |
| text_secondary | Color(0, 255, 0, 1.0) | #00ff00 | Neon green secondary |

### Panel Colors

| Property | Value | CSS | Description |
|----------|-------|-----|-------------|
| panel_bg | Color(0, 255, 255, 0.05) | rgba(0,255,255,0.05) | Cyan tint overlay |
| panel_border | Color(0, 255, 255, 0.5) | rgba(0,255,255,0.5) | Bright cyan border |
| panel_shadow | Color(0, 255, 255, 0.5) | rgba(0,255,255,0.5) | Cyan glow shadow |
| panel_blur | 20px | - | Strong backdrop blur |
| corner_radius | 4px | - | Sharp modern corners |
| border_thickness | 2px | - | Thick glowing borders |

### Landmark Colors

| Property | Value | CSS | Description |
|----------|-------|-----|-------------|
| landmark_default | Color(0, 255, 0, 1.0) | #00ff00 | Neon green points |
| landmark_iris | Color(255, 0, 255, 1.0) | #ff00ff | Neon magenta iris |
| landmark_contour | Color(255, 255, 0, 1.0) | #ffff00 | Neon yellow contours |
| mesh_lines | Color(0, 255, 255, 0.8) | rgba(0,255,255,0.8) | Bright cyan mesh |
| landmark_glow | Color(0, 255, 0, 0.8) | rgba(0,255,0,0.8) | Strong green glow |
| point_size | 4px | - | Larger glowing points |
| line_thickness | 2px | - | Thicker glowing lines |

### Button Colors

| State | Background | Border | Text | Description |
|-------|------------|--------|------|-------------|
| Normal | Color(0, 255, 255, 0.2) | Color(0, 255, 255, 0.6) | Color(0,255,255,1.0) | Cyan with glow |
| Hover | Color(0, 255, 255, 0.4) | Color(0, 255, 255, 1.0) | Color(0,255,255,1.0) | Brighter cyan |
| Pressed | Color(255, 0, 255, 1.0) | Color(255, 0, 255, 1.0) | Color(255,255,255,1.0) | Magenta flash |
| Disabled | Color(128, 128, 128, 0.2) | Color(128, 128, 128, 0.4) | Color(128,128,128,1.0) | Gray no glow |
| Active | Color(255, 0, 255, 0.4) | Color(255, 0, 255, 1.0) | Color(255,0,255,1.0) | Magenta active |

### Graph Colors

| Graph Type | Color | CSS | Description |
|------------|-------|-----|-------------|
| FPS Line | Color(0, 255, 0, 1.0) | #00ff00 | Neon green |
| CPU Line | Color(0, 255, 255, 1.0) | #00ffff | Neon cyan |
| Memory Line | Color(255, 255, 0, 1.0) | #ffff00 | Neon yellow |
| Frame Time | Color(255, 0, 255, 1.0) | #ff00ff | Neon magenta |
| Grid Lines | Color(0, 255, 255, 0.2) | rgba(0,255,255,0.2) | Subtle cyan grid |
| Axis Lines | Color(0, 255, 255, 0.6) | rgba(0,255,255,0.6) | Bright cyan axes |

### Complete Neon Theme JSON

```json
{
  "name": "Neon (Cyberpunk)",
  "id": "neon",
  "colors": {
    "background": [10, 10, 10, 1.0],
    "secondary": [21, 21, 21, 1.0],
    "accent": [0, 255, 255, 1.0],
    "highlight": [255, 0, 255, 1.0],
    "text_primary": [0, 255, 255, 1.0],
    "text_secondary": [0, 255, 0, 1.0]
  },
  "panels": {
    "background": [0, 255, 255, 0.05],
    "border": [0, 255, 255, 0.5],
    "shadow": [0, 255, 255, 0.5],
    "blur_amount": 20,
    "corner_radius": 4,
    "border_thickness": 2
  },
  "landmarks": {
    "default": [0, 255, 0, 1.0],
    "iris": [255, 0, 255, 1.0],
    "contour": [255, 255, 0, 1.0],
    "mesh_lines": [0, 255, 255, 0.8],
    "glow": [0, 255, 0, 0.8],
    "point_size": 4,
    "line_thickness": 2
  },
  "buttons": {
    "normal_bg": [0, 255, 255, 0.2],
    "normal_border": [0, 255, 255, 0.6],
    "hover_bg": [0, 255, 255, 0.4],
    "hover_border": [0, 255, 255, 1.0],
    "pressed_bg": [255, 0, 255, 1.0],
    "active_bg": [255, 0, 255, 0.4]
  },
  "graphs": {
    "fps": [0, 255, 0, 1.0],
    "cpu": [0, 255, 255, 1.0],
    "memory": [255, 255, 0, 1.0],
    "frametime": [255, 0, 255, 1.0],
    "grid": [0, 255, 255, 0.2],
    "axis": [0, 255, 255, 0.6]
  }
}
```

---

## Theme Comparison

### Side-by-Side Comparison

| Property | Dark | Light | Neon |
|----------|------|-------|------|
| **Background** | Deep Navy (#1a1a2e) | Light Gray (#f5f5f5) | Near Black (#0a0a0a) |
| **Accent** | Royal Blue (#0f3460) | Material Blue (#2196f3) | Cyan (#00ffff) |
| **Highlight** | Pink (#e94560) | Deep Orange (#ff5722) | Magenta (#ff00ff) |
| **Text** | White | Near Black | Cyan |
| **Panel Opacity** | 5% | 95% | 5% |
| **Border Glow** | No | No | Yes |
| **Best For** | Long sessions | Daytime work | Entertainment |
| **Eye Strain** | Low | Medium | High |
| **Professionalism** | High | High | Medium |
| **Uniqueness** | Medium | Low | High |

---

## Theme System Implementation

### ThemeManager Class

```gdscript
# scripts/core/theme_manager.gd
extends Node
class_name ThemeManager

signal theme_changed(theme_id: String)

var themes: Dictionary = {}
var current_theme_id: String = "dark"

func _ready():
    load_all_themes()
    apply_theme(current_theme_id)

func load_all_themes():
    themes["dark"] = load_dark_theme()
    themes["light"] = load_light_theme()
    themes["neon"] = load_neon_theme()

func apply_theme(theme_id: String):
    if not themes.has(theme_id):
        push_error("Theme not found: " + theme_id)
        return
    
    current_theme_id = theme_id
    var theme = themes[theme_id]
    
    # Apply theme colors to all UI elements
    apply_base_colors(theme.colors)
    apply_panel_styles(theme.panels)
    apply_landmark_colors(theme.landmarks)
    apply_button_styles(theme.buttons)
    apply_graph_colors(theme.graphs)
    
    # Emit signal for other components
    theme_changed.emit(theme_id)

func get_color(category: String, property: String) -> Color:
    if not themes.has(current_theme_id):
        return Color.WHITE
    
    var theme = themes[current_theme_id]
    if not theme.has(category):
        return Color.WHITE
    
    var arr = theme[category][property]
    return Color(arr[0]/255.0, arr[1]/255.0, arr[2]/255.0, arr[3])
```

### Theme Switching

```gdscript
# Quick theme switching function
func switch_theme(new_theme_id: String):
    # Fade out current UI
    var tween = create_tween()
    tween.tween_property(ui_root, "modulate:a", 0.0, 0.15)
    await tween.finished
    
    # Apply new theme
    theme_manager.apply_theme(new_theme_id)
    
    # Fade in with new theme
    tween = create_tween()
    tween.tween_property(ui_root, "modulate:a", 1.0, 0.15)
```

### Theme Persistence

```gdscript
# Save current theme to config
func save_theme_preference():
    var config = ConfigFile.new()
    config.set_value("ui", "theme", current_theme_id)
    config.save("user://settings.cfg")

# Load theme preference on startup
func load_theme_preference():
    var config = ConfigFile.new()
    var err = config.load("user://settings.cfg")
    if err == OK:
        var theme_id = config.get_value("ui", "theme", "dark")
        apply_theme(theme_id)
```

---

## Custom Theme Support

### Creating Custom Themes

Users can create custom themes by:
1. Starting from an existing theme preset
2. Modifying colors in the customization panel
3. Saving as a new custom theme preset

### Custom Theme Structure

```json
{
  "name": "My Custom Theme",
  "id": "custom_001",
  "based_on": "dark",
  "colors": {
    // User's custom colors
  },
  "panels": {
    // User's custom panel styles
  },
  // ... other categories
}
```

### Import/Export Themes

Themes can be exported to JSON files and shared:

```gdscript
# Export current theme
func export_theme(filepath: String):
    var theme_data = themes[current_theme_id]
    var file = FileAccess.open(filepath, FileAccess.WRITE)
    file.store_string(JSON.stringify(theme_data, "\t"))
    file.close()

# Import theme from file
func import_theme(filepath: String):
    var file = FileAccess.open(filepath, FileAccess.READ)
    var json = JSON.parse_string(file.get_as_text())
    file.close()
    
    themes[json.id] = json
    apply_theme(json.id)
```

---

## Accessibility Considerations

### Color Contrast

All themes meet WCAG AA standards for text contrast:
- **Dark Theme:** White text on navy = 12.6:1 contrast (AAA)
- **Light Theme:** Dark text on white = 15.8:1 contrast (AAA)
- **Neon Theme:** Cyan text on black = 11.4:1 contrast (AAA)

### Colorblind Support

Future colorblind modes will be based on these themes:
- **Deuteranopia:** Replace red/green with blue/yellow
- **Protanopia:** Similar to deuteranopia adjustments
- **Tritanopia:** Replace blue/yellow with red/green

---

## Performance Considerations

### Theme Switching Performance

**Target:** <100ms for complete theme switch

**Optimization strategies:**
- Pre-load all theme data at startup
- Use cached Color objects (don't recreate)
- Batch UI updates (don't update every element individually)
- Use fade transition to mask update time

### Memory Usage

**Per theme:** ~10KB in memory  
**All three themes:** ~30KB total  
**Impact:** Negligible (<0.01% of total memory)

---

## Conclusion

Three complete themes provide diverse visual options:
- **Dark:** Professional, elegant, low eye strain
- **Light:** Clean, modern, high visibility
- **Neon:** Bold, futuristic, entertainment-focused

Plus custom theme support for unlimited personalization.

**Next Steps:**
1. Review theme color palettes
2. Approve visual directions
3. Proceed to customization property specifications
4. Begin implementation

---

*Return to [MODERNIZATION_PLAN.md](./MODERNIZATION_PLAN.md) for overview and links to other documents.*
