# ================================================================================================
# ThemeTestScene.gd
# ================================================================================================
# Test scene for Phase 1: Foundation + Theme System
# Demonstrates all 4 managers and 5 base UI components with theme switching
# 
# Part of: Modernization Phase 1 - Foundation + Theme System
# ================================================================================================

extends Control

# ================================================================================================
# UI REFERENCES
# ================================================================================================

@onready var main_panel: Panel = $MainPanel
@onready var title_label: Label = $MainPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var theme_info_label: Label = $MainPanel/MarginContainer/VBoxContainer/ThemeInfoLabel

@onready var cycle_theme_button: Button = $MainPanel/MarginContainer/VBoxContainer/HBoxContainer/CycleThemeButton
@onready var dark_button: Button = $MainPanel/MarginContainer/VBoxContainer/HBoxContainer/DarkButton
@onready var light_button: Button = $MainPanel/MarginContainer/VBoxContainer/HBoxContainer/LightButton
@onready var neon_button: Button = $MainPanel/MarginContainer/VBoxContainer/HBoxContainer/NeonButton

@onready var primary_label: Label = $MainPanel/MarginContainer/VBoxContainer/LabelsContainer/PrimaryLabel
@onready var secondary_label: Label = $MainPanel/MarginContainer/VBoxContainer/LabelsContainer/SecondaryLabel
@onready var accent_label: Label = $MainPanel/MarginContainer/VBoxContainer/LabelsContainer/AccentLabel
@onready var warning_label: Label = $MainPanel/MarginContainer/VBoxContainer/LabelsContainer/WarningLabel
@onready var error_label: Label = $MainPanel/MarginContainer/VBoxContainer/LabelsContainer/ErrorLabel

@onready var opacity_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/SlidersContainer/OpacitySlider
@onready var scale_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/SlidersContainer/ScaleSlider

@onready var fps_checkbox: CheckBox = $MainPanel/MarginContainer/VBoxContainer/CheckboxContainer/FPSCheckBox
@onready var metrics_checkbox: CheckBox = $MainPanel/MarginContainer/VBoxContainer/CheckboxContainer/MetricsCheckBox
@onready var animations_checkbox: CheckBox = $MainPanel/MarginContainer/VBoxContainer/CheckboxContainer/AnimationsCheckBox

@onready var stats_label: Label = $MainPanel/MarginContainer/VBoxContainer/StatsLabel

# ================================================================================================
# LIFECYCLE
# ================================================================================================

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_theme_info()
	print("[ThemeTestScene] Test scene initialized")

# ================================================================================================
# SETUP
# ================================================================================================

func _setup_ui() -> void:
	"""Initialize UI components with current settings"""
	
	# Set slider values from settings
	if SettingsManager:
		opacity_slider.value = SettingsManager.get_setting("ui", "panel_opacity", 0.85) * 100.0
		scale_slider.value = SettingsManager.get_setting("ui", "ui_scale", 1.0) * 100.0
		
		fps_checkbox.button_pressed = SettingsManager.get_setting("ui", "show_fps", true)
		metrics_checkbox.button_pressed = SettingsManager.get_setting("ui", "show_metrics", true)
		animations_checkbox.button_pressed = SettingsManager.get_setting("ui", "enable_animations", true)

# ================================================================================================
# SIGNAL CONNECTIONS
# ================================================================================================

func _connect_signals() -> void:
	"""Connect UI signals"""
	
	# Theme buttons
	cycle_theme_button.pressed.connect(_on_cycle_theme_pressed)
	dark_button.pressed.connect(_on_dark_theme_pressed)
	light_button.pressed.connect(_on_light_theme_pressed)
	neon_button.pressed.connect(_on_neon_theme_pressed)
	
	# Sliders
	opacity_slider.value_changed.connect(_on_opacity_changed)
	scale_slider.value_changed.connect(_on_scale_changed)
	
	# Checkboxes
	fps_checkbox.toggled.connect(_on_fps_toggled)
	metrics_checkbox.toggled.connect(_on_metrics_toggled)
	animations_checkbox.toggled.connect(_on_animations_toggled)
	
	# ThemeManager signals
	if ThemeManager:
		ThemeManager.theme_changed.connect(_on_theme_changed)
		ThemeManager.theme_transition_started.connect(_on_theme_transition_started)
		ThemeManager.theme_transition_completed.connect(_on_theme_transition_completed)
	
	# SettingsManager signals
	if SettingsManager:
		SettingsManager.setting_changed.connect(_on_setting_changed)

# ================================================================================================
# THEME BUTTON HANDLERS
# ================================================================================================

func _on_cycle_theme_pressed() -> void:
	"""Cycle to next theme"""
	if ThemeManager:
		ThemeManager.cycle_theme()
		print("[ThemeTestScene] Cycling theme")

func _on_dark_theme_pressed() -> void:
	"""Switch to dark theme"""
	if ThemeManager:
		ThemeManager.switch_theme("dark", true)
		print("[ThemeTestScene] Switching to dark theme")

func _on_light_theme_pressed() -> void:
	"""Switch to light theme"""
	if ThemeManager:
		ThemeManager.switch_theme("light", true)
		print("[ThemeTestScene] Switching to light theme")

func _on_neon_theme_pressed() -> void:
	"""Switch to neon theme"""
	if ThemeManager:
		ThemeManager.switch_theme("neon", true)
		print("[ThemeTestScene] Switching to neon theme")

# ================================================================================================
# SLIDER HANDLERS
# ================================================================================================

func _on_opacity_changed(value: float) -> void:
	"""Handle opacity slider change"""
	var opacity := value / 100.0
	if SettingsManager:
		SettingsManager.set_setting("ui", "panel_opacity", opacity)
	
	# Update main panel opacity if it's a BasePanel
	if main_panel.has_method("set_panel_opacity"):
		main_panel.set_panel_opacity(opacity)

func _on_scale_changed(value: float) -> void:
	"""Handle UI scale slider change"""
	var ui_scale := value / 100.0
	if SettingsManager:
		SettingsManager.set_setting("ui", "ui_scale", ui_scale)
	
	print("[ThemeTestScene] UI Scale set to: %.2f" % ui_scale)

# ================================================================================================
# CHECKBOX HANDLERS
# ================================================================================================

func _on_fps_toggled(toggled_on: bool) -> void:
	"""Handle FPS checkbox toggle"""
	if SettingsManager:
		SettingsManager.set_setting("ui", "show_fps", toggled_on)
	print("[ThemeTestScene] Show FPS: %s" % toggled_on)

func _on_metrics_toggled(toggled_on: bool) -> void:
	"""Handle metrics checkbox toggle"""
	if SettingsManager:
		SettingsManager.set_setting("ui", "show_metrics", toggled_on)
	print("[ThemeTestScene] Show Metrics: %s" % toggled_on)

func _on_animations_toggled(toggled_on: bool) -> void:
	"""Handle animations checkbox toggle"""
	if SettingsManager:
		SettingsManager.set_setting("ui", "enable_animations", toggled_on)
	print("[ThemeTestScene] Enable Animations: %s" % toggled_on)

# ================================================================================================
# MANAGER EVENT HANDLERS
# ================================================================================================

func _on_theme_changed(theme_id: String) -> void:
	"""Handle theme change"""
	_update_theme_info()
	print("[ThemeTestScene] Theme changed to: %s" % theme_id)
	
	# Flash the title label
	if title_label and title_label.has_method("flash_text"):
		var flash_color := ThemeManager.get_base_color("highlight")
		title_label.flash_text(flash_color, 0.3)

func _on_theme_transition_started(from_theme: String, to_theme: String) -> void:
	"""Handle theme transition start"""
	print("[ThemeTestScene] Theme transition: %s -> %s" % [from_theme, to_theme])

func _on_theme_transition_completed(theme_id: String) -> void:
	"""Handle theme transition completion"""
	print("[ThemeTestScene] Theme transition completed: %s" % theme_id)

func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	"""Handle setting changes"""
	_update_stats()

# ================================================================================================
# UI UPDATES
# ================================================================================================

func _update_theme_info() -> void:
	"""Update theme information display"""
	if not ThemeManager:
		return
	
	var theme_name := ThemeManager.get_current_theme_name()
	var theme_id := ThemeManager.get_current_theme_id()
	
	if theme_info_label:
		theme_info_label.text = "Current Theme: %s (%s)" % [theme_name, theme_id]
	
	# Update button active states
	if dark_button and dark_button.has_method("set_active"):
		dark_button.set_active(theme_id == "dark")
	if light_button and light_button.has_method("set_active"):
		light_button.set_active(theme_id == "light")
	if neon_button and neon_button.has_method("set_active"):
		neon_button.set_active(theme_id == "neon")

func _update_stats() -> void:
	"""Update statistics display"""
	if not stats_label or not SettingsManager:
		return
	
	var theme_id: String = ThemeManager.get_current_theme_id() if ThemeManager else "unknown"
	var ui_scale: float = SettingsManager.get_setting("ui", "ui_scale", 1.0)
	var panel_opacity: float = SettingsManager.get_setting("ui", "panel_opacity", 0.85)
	var show_fps: bool = SettingsManager.get_setting("ui", "show_fps", true)
	var show_metrics: bool = SettingsManager.get_setting("ui", "show_metrics", true)
	var animations: bool = SettingsManager.get_setting("ui", "enable_animations", true)
	
	stats_label.text = "Stats: Theme=%s | Scale=%.2f | Opacity=%.2f | FPS=%s | Metrics=%s | Animations=%s" % [
		theme_id,
		ui_scale,
		panel_opacity,
		show_fps,
		show_metrics,
		animations
	]

# ================================================================================================
# PROCESS
# ================================================================================================

func _process(_delta: float) -> void:
	"""Update stats every frame"""
	_update_stats()

# ================================================================================================
# INPUT HANDLING
# ================================================================================================

func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts for testing"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_T:
				# Test: Cycle theme
				if ThemeManager:
					ThemeManager.cycle_theme()
			KEY_1:
				# Test: Dark theme
				if ThemeManager:
					ThemeManager.switch_theme("dark", true)
			KEY_2:
				# Test: Light theme
				if ThemeManager:
					ThemeManager.switch_theme("light", true)
			KEY_3:
				# Test: Neon theme
				if ThemeManager:
					ThemeManager.switch_theme("neon", true)
			KEY_R:
				# Test: Reset settings
				if SettingsManager:
					print("[ThemeTestScene] Resetting UI settings...")
					SettingsManager.reset_section("ui")
					_setup_ui()
			KEY_P:
				# Test: Print theme info
				if ThemeManager:
					ThemeManager.print_current_theme()
			KEY_S:
				# Test: Save settings
				if SettingsManager:
					SettingsManager.save_now()
					print("[ThemeTestScene] Settings saved manually")
