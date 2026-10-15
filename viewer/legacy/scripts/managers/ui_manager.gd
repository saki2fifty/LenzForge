extends Node
## UI System Manager - Super Modern Always-Visible Layout
## Glassmorphic dashboard with permanent UI elements
## Performance: 60 FPS target with GPU-accelerated effects

signal effect_selected(effect_name: String)
signal setting_changed(setting_name: String, value)

# UI References
var top_bar: Panel  # Performance stats bar
var bottom_bar: Panel  # Controls and effects
var side_panel: Panel  # Additional controls
var fps_label: Label
var frame_time_label: Label
var gpu_status_label: Label
var landmark_count_label: Label
var effect_buttons: Array = []
var current_effect_label: Label

# State
var is_running: bool = false
var current_effect: String = "None"

# Animation
var button_tween: Tween
const BUTTON_ANIM_DURATION: float = 0.2

# Modern color scheme - Cyberpunk/Tech inspired
const COLOR_BG_GLASS: Color = Color(0.08, 0.08, 0.12, 0.85)  # Darker translucent
const COLOR_BG_GLASS_LIGHT: Color = Color(0.12, 0.12, 0.18, 0.75)
const COLOR_ACCENT_CYAN: Color = Color(0.0, 0.9, 1.0, 1.0)
const COLOR_ACCENT_MAGENTA: Color = Color(1.0, 0.0, 0.6, 1.0)
const COLOR_ACCENT_PURPLE: Color = Color(0.6, 0.0, 1.0, 1.0)
const COLOR_TEXT_PRIMARY: Color = Color(0.95, 0.95, 1.0, 1.0)
const COLOR_TEXT_SECONDARY: Color = Color(0.7, 0.7, 0.85, 0.9)
const COLOR_SUCCESS: Color = Color(0.0, 1.0, 0.5, 1.0)
const COLOR_WARNING: Color = Color(1.0, 0.8, 0.0, 1.0)
const COLOR_ERROR: Color = Color(1.0, 0.2, 0.3, 1.0)
const COLOR_BORDER: Color = Color(0.3, 0.6, 0.9, 0.4)
const COLOR_BORDER_GLOW: Color = Color(0.0, 0.8, 1.0, 0.6)

func _ready() -> void:
	print("[UIManager] 🚀 Initializing SUPER MODERN ALWAYS-VISIBLE UI...")
	
	# Create permanent UI layout
	_create_top_bar()
	_create_bottom_bar()
	_create_side_panel()
	
	is_running = true
	print("[UIManager] ✨ Super modern dashboard active!")
	print("[UIManager] 🎨 Glassmorphic design - All controls visible")

func _create_top_bar() -> void:
	"""Create permanent top performance bar"""
	top_bar = Panel.new()
	top_bar.name = "TopBar"
	
	# Anchor to top, full width
	top_bar.anchor_left = 0.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 0
	top_bar.offset_top = 0
	top_bar.offset_right = 0
	top_bar.offset_bottom = 60
	
	# Modern glassmorphic style
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = COLOR_BG_GLASS
	stylebox.border_width_bottom = 2
	stylebox.border_color = COLOR_BORDER_GLOW
	stylebox.shadow_size = 8
	stylebox.shadow_color = Color(0, 0, 0, 0.6)
	top_bar.add_theme_stylebox_override("panel", stylebox)
	
	add_child(top_bar)
	
	# Content - horizontal layout
	var hbox = HBoxContainer.new()
	hbox.name = "Content"
	hbox.anchor_left = 0.0
	hbox.anchor_right = 1.0
	hbox.offset_left = 20
	hbox.offset_top = 10
	hbox.offset_right = -20
	hbox.offset_bottom = 50
	hbox.add_theme_constant_override("separation", 40)
	top_bar.add_child(hbox)
	
	# Section 1: App title
	var title_section = VBoxContainer.new()
	title_section.custom_minimum_size = Vector2(200, 0)
	var title = Label.new()
	title.text = "⚡ LENZFORGE AR"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_ACCENT_CYAN)
	title_section.add_child(title)
	var subtitle = Label.new()
	subtitle.text = "Real-Time Vision System"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	title_section.add_child(subtitle)
	hbox.add_child(title_section)
	
	# Section 2: FPS Display
	var fps_section = VBoxContainer.new()
	fps_section.custom_minimum_size = Vector2(120, 0)
	var fps_header = Label.new()
	fps_header.text = "FPS"
	fps_header.add_theme_font_size_override("font_size", 10)
	fps_header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	fps_section.add_child(fps_header)
	fps_label = Label.new()
	fps_label.text = "--"
	fps_label.add_theme_font_size_override("font_size", 24)
	fps_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	fps_section.add_child(fps_label)
	hbox.add_child(fps_section)
	
	# Section 3: Frame Time
	var frame_section = VBoxContainer.new()
	frame_section.custom_minimum_size = Vector2(140, 0)
	var frame_header = Label.new()
	frame_header.text = "FRAME TIME"
	frame_header.add_theme_font_size_override("font_size", 10)
	frame_header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	frame_section.add_child(frame_header)
	frame_time_label = Label.new()
	frame_time_label.text = "-- ms"
	frame_time_label.add_theme_font_size_override("font_size", 16)
	frame_time_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	frame_section.add_child(frame_time_label)
	hbox.add_child(frame_section)
	
	# Section 4: GPU Status
	var gpu_section = VBoxContainer.new()
	gpu_section.custom_minimum_size = Vector2(150, 0)
	var gpu_header = Label.new()
	gpu_header.text = "GPU STATUS"
	gpu_header.add_theme_font_size_override("font_size", 10)
	gpu_header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	gpu_section.add_child(gpu_header)
	gpu_status_label = Label.new()
	gpu_status_label.text = "🎨 Active"
	gpu_status_label.add_theme_font_size_override("font_size", 14)
	gpu_status_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	gpu_section.add_child(gpu_status_label)
	hbox.add_child(gpu_section)
	
	# Section 5: Landmarks
	var landmark_section = VBoxContainer.new()
	landmark_section.custom_minimum_size = Vector2(140, 0)
	var landmark_header = Label.new()
	landmark_header.text = "LANDMARKS"
	landmark_header.add_theme_font_size_override("font_size", 10)
	landmark_header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	landmark_section.add_child(landmark_header)
	landmark_count_label = Label.new()
	landmark_count_label.text = "🎯 --"
	landmark_count_label.add_theme_font_size_override("font_size", 14)
	landmark_count_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	landmark_section.add_child(landmark_count_label)
	hbox.add_child(landmark_section)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# Current Effect Display
	var effect_section = VBoxContainer.new()
	effect_section.custom_minimum_size = Vector2(180, 0)
	var effect_header = Label.new()
	effect_header.text = "CURRENT EFFECT"
	effect_header.add_theme_font_size_override("font_size", 10)
	effect_header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	effect_section.add_child(effect_header)
	current_effect_label = Label.new()
	current_effect_label.text = "✨ None"
	current_effect_label.add_theme_font_size_override("font_size", 14)
	current_effect_label.add_theme_color_override("font_color", COLOR_ACCENT_MAGENTA)
	effect_section.add_child(current_effect_label)
	hbox.add_child(effect_section)

func _create_bottom_bar() -> void:
	"""Create permanent bottom control bar with effects"""
	bottom_bar = Panel.new()
	bottom_bar.name = "BottomBar"
	
	# Anchor to bottom, full width
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_left = 0
	bottom_bar.offset_top = -100
	bottom_bar.offset_right = 0
	bottom_bar.offset_bottom = 0
	
	# Modern style
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = COLOR_BG_GLASS
	stylebox.border_width_top = 2
	stylebox.border_color = COLOR_BORDER_GLOW
	stylebox.shadow_size = 12
	stylebox.shadow_color = Color(0, 0, 0, 0.7)
	bottom_bar.add_theme_stylebox_override("panel", stylebox)
	
	add_child(bottom_bar)
	
	# Content - horizontal scrollable layout
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.offset_left = 15
	scroll.offset_top = 15
	scroll.offset_right = -15
	scroll.offset_bottom = 85
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom_bar.add_child(scroll)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	scroll.add_child(hbox)
	
	# Label
	var label = Label.new()
	label.text = "✨ EFFECTS"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR_ACCENT_MAGENTA)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(label)
	
	# Separator
	var separator = VSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = COLOR_BORDER
	separator.add_theme_stylebox_override("separator", sep_style)
	hbox.add_child(separator)
	
	# Effect buttons
	var effects = [
		{"name": "None", "icon": "⭕", "color": COLOR_TEXT_SECONDARY},
		{"name": "Face Mesh", "icon": "🕸️", "color": COLOR_ACCENT_CYAN},
		{"name": "Contours", "icon": "📐", "color": COLOR_ACCENT_PURPLE},
		{"name": "Eye Tracking", "icon": "👁️", "color": COLOR_ACCENT_MAGENTA},
		{"name": "Iris Detail", "icon": "🎯", "color": Color(1.0, 0.5, 0.0)},
		{"name": "Glow Effect", "icon": "✨", "color": Color(1.0, 1.0, 0.0)},
		{"name": "Cyberpunk", "icon": "🌆", "color": COLOR_ACCENT_CYAN},
		{"name": "Neon Trails", "icon": "💫", "color": COLOR_ACCENT_MAGENTA},
	]
	
	for effect in effects:
		var btn = _create_modern_effect_button(effect.icon, effect.name, effect.color)
		hbox.add_child(btn)
		effect_buttons.append(btn)

func _create_modern_effect_button(icon: String, effect_name: String, accent_color: Color) -> Button:
	"""Create a sleek modern effect button"""
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(100, 60)
	
	# Create vertical layout inside button
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var name_label = Label.new()
	name_label.text = effect_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Cannot add children to Button in a simple way, so we use text instead
	btn.text = "%s\n%s" % [icon, effect_name]
	
	# Modern button style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = COLOR_BG_GLASS_LIGHT
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 3
	normal_style.border_color = COLOR_BORDER
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	hover_style.border_color = accent_color
	hover_style.border_width_bottom = 4
	hover_style.shadow_size = 4
	hover_style.shadow_color = accent_color
	hover_style.shadow_color.a = 0.5
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = accent_color
	pressed_style.bg_color.a = 0.3
	pressed_style.border_color = accent_color
	pressed_style.border_width_bottom = 2
	
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", 12)
	
	btn.pressed.connect(func(): _on_effect_button_clicked(effect_name, btn))
	
	return btn

func _create_side_panel() -> void:
	"""Create permanent side panel for settings"""
	side_panel = Panel.new()
	side_panel.name = "SidePanel"
	
	# Anchor to right side
	side_panel.anchor_left = 1.0
	side_panel.anchor_top = 0.0
	side_panel.anchor_right = 1.0
	side_panel.anchor_bottom = 1.0
	side_panel.offset_left = -80
	side_panel.offset_top = 70
	side_panel.offset_right = 0
	side_panel.offset_bottom = -110
	
	# Modern style
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = COLOR_BG_GLASS
	stylebox.border_width_left = 2
	stylebox.border_color = COLOR_BORDER_GLOW
	stylebox.shadow_size = 10
	stylebox.shadow_color = Color(0, 0, 0, 0.6)
	side_panel.add_theme_stylebox_override("panel", stylebox)
	
	add_child(side_panel)
	
	# Content - vertical button layout
	var vbox = VBoxContainer.new()
	vbox.name = "Content"
	vbox.anchor_left = 0.0
	vbox.anchor_right = 1.0
	vbox.offset_left = 8
	vbox.offset_top = 15
	vbox.offset_right = -8
	vbox.add_theme_constant_override("separation", 15)
	side_panel.add_child(vbox)
	
	# Settings button
	var settings_btn = _create_icon_button("⚙️", "Settings")
	settings_btn.pressed.connect(_on_settings_clicked)
	vbox.add_child(settings_btn)
	
	# Info button
	var info_btn = _create_icon_button("ℹ️", "Info")
	info_btn.pressed.connect(_on_info_clicked)
	vbox.add_child(info_btn)
	
	# Help button
	var help_btn = _create_icon_button("❓", "Help")
	help_btn.pressed.connect(_on_help_clicked)
	vbox.add_child(help_btn)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(spacer)
	
	# Toggle landmarks button
	var landmarks_btn = _create_icon_button("🎯", "Landmarks")
	landmarks_btn.pressed.connect(_on_landmarks_clicked)
	vbox.add_child(landmarks_btn)

func _create_icon_button(icon: String, tooltip: String) -> Button:
	"""Create a modern icon button for side panel"""
	var btn = Button.new()
	btn.text = icon
	btn.custom_minimum_size = Vector2(50, 50)
	btn.tooltip_text = tooltip
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = COLOR_BG_GLASS_LIGHT
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = COLOR_BORDER
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	hover_style.border_color = COLOR_ACCENT_CYAN
	hover_style.shadow_size = 4
	hover_style.shadow_color = COLOR_ACCENT_CYAN
	hover_style.shadow_color.a = 0.4
	
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", 24)
	
	return btn

func _on_effect_button_clicked(effect_name: String, button: Button) -> void:
	"""Handle effect button click with visual feedback"""
	current_effect = effect_name
	
	# Update current effect display
	if current_effect_label:
		current_effect_label.text = "✨ %s" % effect_name
	
	# Animate button
	if button_tween:
		button_tween.kill()
	
	button_tween = create_tween()
	button_tween.tween_property(button, "scale", Vector2(0.95, 0.95), BUTTON_ANIM_DURATION * 0.5)
	button_tween.tween_property(button, "scale", Vector2(1.0, 1.0), BUTTON_ANIM_DURATION * 0.5)
	
	# Emit signal
	effect_selected.emit(effect_name)
	print("[UIManager] ✨ Effect selected: %s" % effect_name)

func _on_settings_clicked() -> void:
	"""Handle settings button click"""
	print("[UIManager] ⚙️ Settings clicked")
	# TODO: Open settings panel/modal

func _on_info_clicked() -> void:
	"""Handle info button click"""
	print("[UIManager] ℹ️ Info clicked")
	# TODO: Show info panel

func _on_help_clicked() -> void:
	"""Handle help button click"""
	print("[UIManager] ❓ Help clicked")
	# TODO: Show help panel

func _on_landmarks_clicked() -> void:
	"""Handle landmarks toggle button click"""
	print("[UIManager] 🎯 Landmarks toggled")
	# TODO: Toggle landmarks visibility

func update_performance_display(fps: float, frame_time_ms: float) -> void:
	"""Update performance metrics with modern styling"""
	if not fps_label:
		return
	
	# Update FPS with color coding
	fps_label.text = "%.0f" % fps
	
	if fps >= 58.0:
		fps_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	elif fps >= 50.0:
		fps_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		fps_label.add_theme_color_override("font_color", COLOR_ERROR)
	
	# Update frame time
	if frame_time_label:
		frame_time_label.text = "%.2f ms" % frame_time_ms
		
		if frame_time_ms < 17.0:  # 60 FPS
			frame_time_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		elif frame_time_ms < 22.0:  # 45 FPS
			frame_time_label.add_theme_color_override("font_color", COLOR_WARNING)
		else:
			frame_time_label.add_theme_color_override("font_color", COLOR_ERROR)

func update_landmark_count(count: int) -> void:
	"""Update landmark count display"""
	if landmark_count_label:
		landmark_count_label.text = "🎯 %d" % count

func get_stats() -> Dictionary:
	"""Get UI system statistics"""
	return {
		"is_running": is_running,
		"current_effect": current_effect,
		"effect_count": effect_buttons.size()
	}
