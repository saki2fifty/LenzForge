# LenzForge AR - System Architecture & Components

**Part of:** Modernization Plan  
**Total New Files:** 50+ components  
**Status:** Planning Phase

---

## 📋 Overview

This document defines the system architecture for the modernized LenzForge AR, including all management classes, UI components, and their relationships.

---

## Architecture Principles

### 1. Manager Pattern
Central managers control major subsystems:
- **ThemeManager** - Theme loading and application
- **SettingsManager** - Settings persistence and validation
- **CustomizationManager** - Real-time customization controls
- **PresetManager** - User preset management
- **KeyboardManager** - Keyboard shortcut handling

### 2. Signal-Based Communication
Loose coupling through signals:
- Managers emit signals when state changes
- Components listen for relevant signals
- No direct dependencies between components

### 3. Source of Truth Pattern
Development workflow:
```
setup_v2/assets/lenzforge-ar/  (SOURCE - version controlled)
         ↓
    [Deploy Script]
         ↓
workspace_v2/LenzForge-AR/     (DEPLOYED - testing)
```

**Rule:** NEVER modify workspace_v2/ directly. Always work in setup_v2/assets/.

---

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         LenzForge AR                            │
│                      Main Application                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
┌───────▼───────┐ ┌─────▼─────┐ ┌───────▼────────┐
│  Core Managers  │ │ UI System │ │ Backend Bridge │
│                 │ │           │ │                │
│ • ThemeManager  │ │ • Panels  │ │ • VideoMgr     │
│ • SettingsMgr   │ │ • Buttons │ │ • LandmarkMgr  │
│ • PresetMgr     │ │ • Graphs  │ │ • RenderMgr    │
│ • KeyboardMgr   │ │ • Dialogs │ │ • GPUComp      │
└─────────────────┘ └───────────┘ └────────────────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
┌───────▼────────┐ ┌────▼────┐ ┌────────▼─────────┐
│ Settings Files │ │ Themes  │ │ User Presets     │
│ settings.cfg   │ │ *.json  │ │ presets/*.json   │
└────────────────┘ └─────────┘ └──────────────────┘
```

---

## Core Manager Classes

### 1. ThemeManager

**Location:** `scripts/core/theme_manager.gd`

**Responsibilities:**
- Load theme definitions (Dark, Light, Neon)
- Apply themes to all UI elements
- Handle theme switching with transitions
- Emit signals when theme changes

**Key Methods:**
```gdscript
class_name ThemeManager

signal theme_changed(theme_id: String)
signal theme_loading(progress: float)

func load_all_themes() -> void
func apply_theme(theme_id: String) -> void
func get_color(category: String, property: String) -> Color
func get_theme_property(property_path: String) -> Variant
func export_theme(theme_id: String, filepath: String) -> void
func import_theme(filepath: String) -> String
```

**Properties:**
- `themes: Dictionary` - All loaded themes
- `current_theme_id: String` - Current active theme
- `transition_duration: float` - Theme switch animation time

---

### 2. SettingsManager

**Location:** `scripts/core/settings_manager.gd`

**Responsibilities:**
- Load/save settings from/to config file
- Validate all setting values
- Provide settings to other components
- Handle settings migration between versions

**Key Methods:**
```gdscript
class_name SettingsManager

signal settings_loaded()
signal settings_saved()
signal setting_changed(category: String, key: String, value: Variant)

func load_settings() -> void
func save_settings() -> void
func get_setting(category: String, key: String, default: Variant) -> Variant
func set_setting(category: String, key: String, value: Variant) -> void
func reset_to_defaults() -> void
func validate_settings() -> bool
func export_settings(filepath: String) -> void
func import_settings(filepath: String) -> bool
```

**Settings File Structure:**
```
user://lenzforge/
├── settings.cfg           (Main settings)
├── themes/
│   ├── dark.json
│   ├── light.json
│   ├── neon.json
│   └── custom_*.json     (User custom themes)
└── presets/
    └── *.json            (User presets)
```

---

### 3. CustomizationManager

**Location:** `scripts/core/customization_manager.gd`

**Responsibilities:**
- Coordinate real-time customization updates
- Batch property changes for performance
- Preview changes before saving
- Track undo/redo stack

**Key Methods:**
```gdscript
class_name CustomizationManager

signal property_changed(target: String, property: String, value: Variant)
signal preview_started()
signal preview_ended()

func set_property(target: String, property: String, value: Variant) -> void
func batch_set_properties(changes: Dictionary) -> void
func preview_change(target: String, property: String, value: Variant) -> void
func commit_preview() -> void
func cancel_preview() -> void
func undo() -> void
func redo() -> void
```

---

### 4. PresetManager

**Location:** `scripts/core/preset_manager.gd`

**Responsibilities:**
- Save current settings as named preset
- Load presets
- Manage preset library
- Export/import preset files

**Key Methods:**
```gdscript
class_name PresetManager

signal preset_saved(preset_name: String)
signal preset_loaded(preset_name: String)
signal preset_deleted(preset_name: String)

func save_preset(preset_name: String, description: String) -> bool
func load_preset(preset_name: String) -> bool
func delete_preset(preset_name: String) -> bool
func get_all_presets() -> Array[String]
func get_preset_info(preset_name: String) -> Dictionary
func export_preset(preset_name: String, filepath: String) -> bool
func import_preset(filepath: String) -> String
```

---

### 5. KeyboardManager

**Location:** `scripts/core/keyboard_manager.gd`

**Responsibilities:**
- Register keyboard shortcuts
- Handle shortcut conflicts
- Allow user customization of shortcuts
- Provide shortcut hints in UI

**Key Methods:**
```gdscript
class_name KeyboardManager

signal shortcut_triggered(action: String)
signal shortcut_changed(action: String, new_shortcut: String)

func register_shortcut(action: String, default_key: String) -> void
func set_shortcut(action: String, key: String) -> bool
func get_shortcut(action: String) -> String
func handle_input(event: InputEvent) -> bool
func get_all_shortcuts() -> Dictionary
```

**Default Shortcuts:**
```
Ctrl+,           → Open Settings
Ctrl+T           → Cycle Themes
Ctrl+Shift+T     → Theme Picker
Ctrl+S           → Save Preset
Ctrl+L           → Load Preset
Ctrl+E           → Export Settings
Ctrl+I           → Import Settings
Ctrl+R           → Reset to Defaults
F11              → Toggle Fullscreen
Ctrl+H           → Toggle Left Panel
Ctrl+J           → Toggle Bottom Panel
Ctrl+K           → Toggle Right Panel
```

---

## UI Component Hierarchy

### Main Scene Structure

```
Main (Node)
├── ThemeManager (Node)
├── SettingsManager (Node)
├── CustomizationManager (Node)
├── PresetManager (Node)
├── KeyboardManager (Node)
├── BackendBridge (Node)
└── UIRoot (Control)
    ├── TopBar (Panel)
    │   ├── Logo (TextureRect)
    │   ├── QuickButtons (HBoxContainer)
    │   └── PerformanceIndicators (HBoxContainer)
    ├── MainContent (HBoxContainer)
    │   ├── LeftPanel (Panel)
    │   │   ├── LandmarkControls
    │   │   ├── EffectsPanel
    │   │   └── LayersPanel
    │   ├── CenterPanel (Panel)
    │   │   ├── VideoDisplay (TextureRect)
    │   │   └── LandmarkOverlay (Control)
    │   └── RightPanel (Panel)
    │       ├── ThemeSelector
    │       ├── CustomizationPanel
    │       └── PresetsPanel
    └── BottomBar (Panel)
        ├── FPSGraph (GraphPanel)
        ├── CPUGraph (GraphPanel)
        ├── MemoryGraph (GraphPanel)
        └── FrameTimeGraph (GraphPanel)
```

---

## Component File List

### Core Management (5 files)

1. `scripts/core/theme_manager.gd` - Theme system
2. `scripts/core/settings_manager.gd` - Settings persistence
3. `scripts/core/customization_manager.gd` - Real-time customization
4. `scripts/core/preset_manager.gd` - Preset management
5. `scripts/core/keyboard_manager.gd` - Keyboard shortcuts

### UI Base Components (8 files)

6. `scripts/ui/base/themed_panel.gd` - Base panel with theme support
7. `scripts/ui/base/themed_button.gd` - Base button with states
8. `scripts/ui/base/themed_label.gd` - Base label with theme
9. `scripts/ui/base/color_picker_control.gd` - Custom color picker
10. `scripts/ui/base/slider_with_value.gd` - Slider with numeric display
11. `scripts/ui/base/collapsible_section.gd` - Expandable section
12. `scripts/ui/base/dropdown_menu.gd` - Themed dropdown
13. `scripts/ui/base/tooltip_handler.gd` - Tooltip management

### Top Bar Components (5 files)

14. `scripts/ui/topbar/top_bar.gd` - Main top bar
15. `scripts/ui/topbar/quick_button.gd` - Icon button with tooltip
16. `scripts/ui/topbar/fps_indicator.gd` - Live FPS display
17. `scripts/ui/topbar/performance_badge.gd` - CPU/GPU indicators
18. `scripts/ui/topbar/logo_display.gd` - Animated logo

### Left Panel Components (6 files)

19. `scripts/ui/left_panel/left_panel.gd` - Main left panel
20. `scripts/ui/left_panel/landmark_group_control.gd` - Per-group controls
21. `scripts/ui/left_panel/landmark_color_picker.gd` - Color selection
22. `scripts/ui/left_panel/effects_panel.gd` - Effects toggles
23. `scripts/ui/left_panel/layer_manager.gd` - Layer visibility
24. `scripts/ui/left_panel/selection_tool.gd` - Landmark selection

### Center Panel Components (4 files)

25. `scripts/ui/center_panel/center_panel.gd` - Main center panel
26. `scripts/ui/center_panel/video_display.gd` - Video rendering
27. `scripts/ui/center_panel/landmark_overlay.gd` - Landmark rendering
28. `scripts/ui/center_panel/interaction_handler.gd` - Mouse/keyboard input

### Right Panel Components (8 files)

29. `scripts/ui/right_panel/right_panel.gd` - Main right panel
30. `scripts/ui/right_panel/theme_selector.gd` - Theme switcher
31. `scripts/ui/right_panel/customization_panel.gd` - Main customization UI
32. `scripts/ui/right_panel/panel_customizer.gd` - Panel property controls
33. `scripts/ui/right_panel/landmark_customizer.gd` - Landmark controls
34. `scripts/ui/right_panel/video_customizer.gd` - Video adjustment controls
35. `scripts/ui/right_panel/preset_manager_ui.gd` - Preset UI
36. `scripts/ui/right_panel/settings_search.gd` - Search functionality

### Bottom Bar Components (5 files)

37. `scripts/ui/bottom_bar/bottom_bar.gd` - Main bottom bar
38. `scripts/ui/bottom_bar/graph_panel.gd` - Base graph component
39. `scripts/ui/bottom_bar/fps_graph.gd` - FPS line graph
40. `scripts/ui/bottom_bar/cpu_graph.gd` - CPU area chart
41. `scripts/ui/bottom_bar/memory_graph.gd` - Memory usage graph
42. `scripts/ui/bottom_bar/frametime_histogram.gd` - Frame time distribution

### Dialogs & Popups (4 files)

43. `scripts/ui/dialogs/settings_dialog.gd` - Full settings dialog
44. `scripts/ui/dialogs/preset_save_dialog.gd` - Save preset dialog
45. `scripts/ui/dialogs/keyboard_shortcuts_dialog.gd` - Shortcut editor
46. `scripts/ui/dialogs/about_dialog.gd` - About/info dialog

### Utilities (4 files)

47. `scripts/utils/validation_helper.gd` - Value validation
48. `scripts/utils/color_utils.gd` - Color conversion utilities
49. `scripts/utils/animation_helper.gd` - Smooth animations
50. `scripts/utils/file_helper.gd` - File I/O helpers

### Scene Files (10+ files)

51. `scenes/main.tscn` - Main application scene
52. `scenes/ui/top_bar.tscn` - Top bar scene
53. `scenes/ui/left_panel.tscn` - Left panel scene
54. `scenes/ui/center_panel.tscn` - Center panel scene
55. `scenes/ui/right_panel.tscn` - Right panel scene
56. `scenes/ui/bottom_bar.tscn` - Bottom bar scene
57. `scenes/ui/dialogs/settings_dialog.tscn` - Settings dialog
58. `scenes/ui/dialogs/preset_dialog.tscn` - Preset dialogs
59. `scenes/ui/components/graph_panel.tscn` - Graph component
60. `scenes/ui/components/themed_button.tscn` - Button template

**Total: 60+ files**

---

## Data Flow Diagrams

### Theme Application Flow

```
User clicks theme button
         ↓
ThemeManager.apply_theme(theme_id)
         ↓
    [Load theme data]
         ↓
    ┌────┴─────┐
    │          │
    ▼          ▼
Panels    Landmarks    Buttons    Graphs
    │          │          │          │
    └──────────┴──────────┴──────────┘
                 ↓
        UI updates with fade
                 ↓
    theme_changed signal emitted
                 ↓
    SettingsManager saves choice
```

### Settings Persistence Flow

```
Application starts
        ↓
SettingsManager.load_settings()
        ↓
    [Read user://settings.cfg]
        ↓
    [Validate all values]
        ↓
settings_loaded signal
        ↓
All managers receive settings
        ↓
UI updates to match settings
        ↓
    
[During use: settings change]
        ↓
CustomizationManager.set_property()
        ↓
UI updates in real-time
        ↓
SettingsManager.set_setting()
        ↓
[Auto-save after 2s delay]
        ↓
[Write to user://settings.cfg]
```

### Customization Flow

```
User adjusts slider
        ↓
Slider emits value_changed
        ↓
CustomizationManager.preview_change()
        ↓
UI updates immediately
        ↓
[User continues adjusting or clicks Save/Cancel]
        ↓
    ┌───┴───┐
    ▼       ▼
  Save    Cancel
    │       │
    │   [Revert to original]
    ↓
CustomizationManager.commit_preview()
    ↓
SettingsManager.set_setting()
    ↓
[Persist to disk]
```

---

## Settings File Format

### Main Settings File (user://settings.cfg)

```ini
[version]
config_version = "1.0.0"
last_modified = "2025-11-08T15:30:00Z"

[theme]
current = "dark"

[panels.left]
background_color = Color(1.0, 1.0, 1.0, 0.05)
border_color = Color(1.0, 1.0, 1.0, 0.15)
corner_radius = 12.0
padding_top = 10.0
padding_right = 10.0
padding_bottom = 10.0
padding_left = 10.0
visible = true
width = 320

[panels.right]
# ... same structure

[landmarks.face_mesh]
point_color = Color(0.0, 1.0, 0.0, 1.0)
point_size = 3.0
line_color = Color(1.0, 1.0, 1.0, 0.3)
line_thickness = 1.5
glow_enabled = false
visible = true

[video]
brightness = 0.0
contrast = 1.0
saturation = 1.0
# ... all video properties

[graphs.fps]
line_color = Color(0.0, 1.0, 0.0, 1.0)
line_thickness = 2.0
area_fill = true
time_range = 60.0
# ... all graph properties

[keyboard_shortcuts]
open_settings = "Ctrl+,"
cycle_theme = "Ctrl+T"
save_preset = "Ctrl+S"
# ... all shortcuts
```

### Theme File Format (user://themes/custom_001.json)

```json
{
  "version": "1.0.0",
  "name": "My Custom Theme",
  "id": "custom_001",
  "author": "User Name",
  "created": "2025-11-08T15:30:00Z",
  "based_on": "dark",
  "colors": {
    "background": [26, 26, 46, 1.0],
    "secondary": [22, 33, 62, 1.0],
    "accent": [15, 52, 96, 1.0],
    "highlight": [233, 69, 96, 1.0],
    "text_primary": [255, 255, 255, 1.0],
    "text_secondary": [160, 160, 160, 1.0]
  },
  "panels": { /* all panel styles */ },
  "landmarks": { /* all landmark styles */ },
  "buttons": { /* all button styles */ },
  "graphs": { /* all graph styles */ }
}
```

### Preset File Format (user://presets/my_preset.json)

```json
{
  "version": "1.0.0",
  "name": "My Preset",
  "description": "Custom settings for streaming",
  "created": "2025-11-08T15:30:00Z",
  "theme": "neon",
  "settings": {
    "panels": { /* specific overrides */ },
    "landmarks": { /* specific overrides */ },
    "video": { /* specific overrides */ },
    "graphs": { /* specific overrides */ }
  }
}
```

---

## Integration with Existing System

### Backend Connection

The modernized UI integrates with existing managers:

```gdscript
# In main.gd or similar
var video_manager: VideoManager
var landmark_manager: LandmarkManager
var render_manager: RenderManager
var gpu_compositor: GPUCompositor

func _ready():
    # Initialize new UI managers
    theme_manager = ThemeManager.new()
    settings_manager = SettingsManager.new()
    
    # Connect to existing backend
    video_manager.frame_ready.connect(_on_frame_ready)
    landmark_manager.landmarks_updated.connect(_on_landmarks_updated)
    render_manager.render_complete.connect(_on_render_complete)
    
    # Apply saved settings to backend
    apply_video_settings()
    apply_landmark_settings()
```

### Video Settings Application

```gdscript
func apply_video_settings():
    var brightness = settings_manager.get_setting("video", "brightness", 0.0)
    var contrast = settings_manager.get_setting("video", "contrast", 1.0)
    var saturation = settings_manager.get_setting("video", "saturation", 1.0)
    
    # Apply to GPU compositor shader
    if gpu_compositor:
        gpu_compositor.set_brightness(brightness)
        gpu_compositor.set_contrast(contrast)
        gpu_compositor.set_saturation(saturation)
```

### Landmark Settings Application

```gdscript
func apply_landmark_settings():
    var face_color = settings_manager.get_setting("landmarks.face_mesh", "point_color", Color.GREEN)
    var point_size = settings_manager.get_setting("landmarks.face_mesh", "point_size", 3.0)
    
    # Apply to landmark renderer
    if landmark_manager:
        landmark_manager.set_face_color(face_color)
        landmark_manager.set_point_size(point_size)
```

---

## Performance Optimization Strategies

### 1. Lazy Loading
- Load UI components only when panels become visible
- Defer graph initialization until bottom bar opens
- Load custom themes on demand

### 2. Update Throttling
- Batch property updates (max 60/second)
- Debounce slider changes (update after 50ms idle)
- Update only visible graphs

### 3. Caching
- Cache theme colors after load
- Cache computed styles
- Reuse Material objects where possible

### 4. Signal Optimization
- Disconnect unused signal connections
- Use call_deferred for non-critical updates
- Batch signal emissions

### 5. Shader-Based Effects
- Use shaders for video adjustments (GPU)
- Shader-based glassmorphism (if supported)
- GPU-accelerated graph rendering (if needed)

---

## Testing Strategy

### Unit Tests
Test individual managers:
- ThemeManager theme loading
- SettingsManager validation
- PresetManager save/load
- KeyboardManager shortcut handling

### Integration Tests
Test component interactions:
- Theme change updates all components
- Setting change persists and reloads
- Preset load applies all settings
- Shortcut triggers correct action

### UI Tests
Visual regression testing:
- Screenshot comparison per theme
- Panel layout at different resolutions
- Animation smoothness
- Color accuracy

### Performance Tests
Benchmarks for:
- Theme switch time (<100ms)
- Settings load time (<50ms)
- Real-time update latency (<16ms)
- Memory usage (<50MB for UI)

---

## Deployment Strategy

### Phase 1: Foundation
Deploy core managers and base components:
```bash
# Copy from source to workspace
./setup_v2/scripts/Deploy-LenzForge.ps1 -Component "Core"
```

### Phase 2: Panel by Panel
Deploy each panel incrementally:
```bash
./setup_v2/scripts/Deploy-LenzForge.ps1 -Component "LeftPanel"
./setup_v2/scripts/Deploy-LenzForge.ps1 -Component "RightPanel"
# etc.
```

### Phase 3: Integration
Deploy full integrated system:
```bash
./setup_v2/scripts/Deploy-LenzForge.ps1 -Full
```

### Verification
After each deployment:
1. Launch LenzForge AR
2. Test new components
3. Verify no regressions
4. Check performance metrics

---

## Future Extensibility

### Plugin System (Future)
Allow third-party plugins:
- Custom themes in plugins/themes/
- Custom effects in plugins/effects/
- Custom panels in plugins/panels/

### API for External Control (Future)
WebSocket API for external apps:
- Change settings remotely
- Trigger actions
- Stream performance data

### Cloud Sync (Future)
Sync settings across devices:
- Upload settings to cloud
- Download on other machines
- Conflict resolution

---

## Conclusion

This architecture provides:
- ✅ **Clean separation of concerns** via manager pattern
- ✅ **Loose coupling** through signal-based communication
- ✅ **60+ new components** organized logically
- ✅ **Robust settings system** with validation and persistence
- ✅ **Extensible design** for future enhancements
- ✅ **Clear deployment strategy** with source of truth pattern

**Total New Files:** 60+ (scripts, scenes, assets)

**Next Steps:**
1. Review architecture design
2. Approve component organization
3. Proceed to implementation phases
4. Begin Phase 1 development

---

*Return to [MODERNIZATION_PLAN.md](./MODERNIZATION_PLAN.md) for overview and links to other documents.*
