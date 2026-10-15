extends Control
## Video Settings Panel
## UI panel for configuring video capture settings

var video_settings_manager: Node
var resolution_option: OptionButton
var framerate_option: OptionButton
var quality_option: OptionButton

var resolution_label: Label
var framerate_label: Label
var quality_label: Label

var apply_button: Button
var reset_button: Button

# UI Containers
var main_container: VBoxContainer
var options_container: HBoxContainer
var button_container: HBoxContainer

func _ready():
    name = "VideoSettingsPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    
    _create_ui()
    _connect_signals()

func _create_ui():
    """Create the UI elements"""
    # Main container
    main_container = VBoxContainer.new()
    add_child(main_container)
    
    # Title
    var title_label = Label.new()
    title_label.text = "Video Settings"
    title_label.add_theme_font_size_override("font_size", 16)
    main_container.add_child(title_label)
    
    # Separator
    var separator = HSeparator.new()
    main_container.add_child(separator)
    
    # Options container
    options_container = HBoxContainer.new()
    main_container.add_child(options_container)
    
    # Resolution section
    var res_container = VBoxContainer.new()
    options_container.add_child(res_container)
    
    resolution_label = Label.new()
    resolution_label.text = "Resolution:"
    res_container.add_child(resolution_label)
    
    resolution_option = OptionButton.new()
    resolution_option.text = "1280x720"
    _populate_resolution_options()
    res_container.add_child(resolution_option)
    
    # Frame rate section
    var fps_container = VBoxContainer.new()
    options_container.add_child(fps_container)
    
    framerate_label = Label.new()
    framerate_label.text = "Frame Rate:"
    fps_container.add_child(framerate_label)
    
    framerate_option = OptionButton.new()
    framerate_option.text = "30 FPS"
    _populate_framerate_options()
    fps_container.add_child(framerate_option)
    
    # Quality section
    var quality_container = VBoxContainer.new()
    options_container.add_child(quality_container)
    
    quality_label = Label.new()
    quality_label.text = "Quality:"
    quality_container.add_child(quality_label)
    
    quality_option = OptionButton.new()
    quality_option.text = "Medium"
    _populate_quality_options()
    quality_container.add_child(quality_option)
    
    # Separator
    var separator2 = HSeparator.new()
    main_container.add_child(separator2)
    
    # Button container
    button_container = HBoxContainer.new()
    main_container.add_child(button_container)
    
    apply_button = Button.new()
    apply_button.text = "Apply"
    apply_button.pressed.connect(_on_apply_pressed)
    button_container.add_child(apply_button)
    
    reset_button = Button.new()
    reset_button.text = "Reset"
    reset_button.pressed.connect(_on_reset_pressed)
    button_container.add_child(reset_button)
    
    # Add spacer
    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(20, 0)
    button_container.add_child(spacer)

func _populate_resolution_options():
    """Populate resolution dropdown"""
    resolution_option.clear()
    
    var resolutions = [
        {"name": "1280x720", "value": Vector2i(1280, 720)},
        {"name": "1920x1080", "value": Vector2i(1920, 1080)},
        {"name": "854x480", "value": Vector2i(854, 480)},
        {"name": "640x360", "value": Vector2i(640, 360)}
    ]
    
    for res in resolutions:
        resolution_option.add_item(res["name"])
    
    # Select current resolution
    var current_res_str = _resolution_to_string(video_settings_manager.get_resolution())
    for i in range(resolution_option.get_item_count()):
        if resolution_option.get_item_text(i) == current_res_str:
            resolution_option.select(i)
            break

func _populate_framerate_options():
    """Populate frame rate dropdown"""
    framerate_option.clear()
    
    var framerates = [24, 30, 60, 120]
    
    for fps in framerates:
        framerate_option.add_item(str(fps) + " FPS")
    
    # Select current frame rate
    var current_fps = video_settings_manager.get_framerate()
    for i in range(framerate_option.get_item_count()):
        if framerate_option.get_item_text(i) == str(current_fps) + " FPS":
            framerate_option.select(i)
            break

func _populate_quality_options():
    """Populate quality dropdown"""
    quality_option.clear()
    
    var qualities = ["Low", "Medium", "High", "Ultra"]
    
    for quality in qualities:
        quality_option.add_item(quality)
    
    # Select current quality
    var current_quality = video_settings_manager.get_quality()
    var quality_str = _quality_to_string(current_quality)
    for i in range(quality_option.get_item_count()):
        if quality_option.get_item_text(i) == quality_str:
            quality_option.select(i)
            break

func _connect_signals():
    """Connect signals and managers"""
    # Get video settings manager from parent
    video_settings_manager = get_node("../VideoSettingsManager")
    if video_settings_manager:
        video_settings_manager.settings_changed.connect(_on_settings_changed)

func _resolution_to_string(resolution: Vector2i) -> String:
    """Convert resolution vector to string"""
    if resolution == Vector2i(1280, 720):
        return "1280x720"
    elif resolution == Vector2i(1920, 1080):
        return "1920x1080"
    elif resolution == Vector2i(854, 480):
        return "854x480"
    elif resolution == Vector2i(640, 360):
        return "640x360"
    else:
        return "1280x720"

func _string_to_resolution(res_str: String) -> Vector2i:
    """Convert string to resolution vector"""
    match res_str:
        "1280x720":
            return Vector2i(1280, 720)
        "1920x1080":
            return Vector2i(1920, 1080)
        "854x480":
            return Vector2i(854, 480)
        "640x360":
            return Vector2i(640, 360)
        _:
            return Vector2i(1280, 720)

func _quality_to_string(quality: int) -> String:
    """Convert quality enum to string"""
    match quality:
        0:
            return "Low"
        1:
            return "Medium"
        2:
            return "High"
        3:
            return "Ultra"
        _:
            return "Medium"

func _string_to_quality(quality_str: String) -> int:
    """Convert string to quality enum"""
    match quality_str:
        "Low":
            return 0
        "Medium":
            return 1
        "High":
            return 2
        "Ultra":
            return 3
        _:
            return 1

func _on_apply_pressed():
    """Handle apply button press"""
    var selected_res = resolution_option.get_selected_text()
    var selected_fps = framerate_option.get_selected_text()
    var selected_quality = quality_option.get_selected_text()
    
    # Convert selections to proper types
    var new_resolution = _string_to_resolution(selected_res)
    var new_framerate = int(selected_fps.split(" ")[0])
    var new_quality = _string_to_quality(selected_quality)
    
    # Apply settings
    video_settings_manager.set_resolution(new_resolution)
    video_settings_manager.set_framerate(new_framerate)
    video_settings_manager.set_quality(new_quality)
    
    print("[VideoSettingsPanel] Applied settings: ", selected_res, " ", selected_fps, " FPS, ", selected_quality)

func _on_reset_pressed():
    """Handle reset button press"""
    video_settings_manager.set_resolution(Vector2i(1280, 720))
    video_settings_manager.set_framerate(30)
    video_settings_manager.set_quality(1)  # Medium
    
    # Update UI to reflect reset
    _update_ui_from_manager()
    
    print("[VideoSettingsPanel] Settings reset to defaults")

func _on_settings_changed():
    """Handle settings changed signal"""
    _update_ui_from_manager()

func _update_ui_from_manager():
    """Update UI to reflect current manager settings"""
    if not video_settings_manager:
        return
    
    # Update resolution
    var current_res_str = _resolution_to_string(video_settings_manager.get_resolution())
    for i in range(resolution_option.get_item_count()):
        if resolution_option.get_item_text(i) == current_res_str:
            resolution_option.select(i)
            break
    
    # Update frame rate
    var current_fps = video_settings_manager.get_framerate()
    for i in range(framerate_option.get_item_count()):
        if framerate_option.get_item_text(i) == str(current_fps) + " FPS":
            framerate_option.select(i)
            break
    
    # Update quality
    var current_quality = video_settings_manager.get_quality()
    var quality_str = _quality_to_string(current_quality)
    for i in range(quality_option.get_item_count()):
        if quality_option.get_item_text(i) == quality_str:
            quality_option.select(i)
            break

func get_current_settings() -> Dictionary:
    """Get current settings as dictionary"""
    if video_settings_manager:
        return video_settings_manager.get_settings_dict()
    else:
        return {}

func show_panel():
    """Show the panel"""
    visible = true

func hide_panel():
    """Hide the panel"""
    visible = false
