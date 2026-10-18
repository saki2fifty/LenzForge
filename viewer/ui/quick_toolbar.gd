extends PanelContainer
## Event-driven shortcuts to the studio's existing controls and autosave path.
const ICONS := {
	"landmarks": '<path d="M6 6 12 3 18 6 20 13 16 20 8 20 4 13Z M6 6 9 12 15 12 18 6 M9 12 8 20 M15 12 16 20"/><g fill="white" stroke="none"><circle cx="6" cy="6" r="2"/><circle cx="12" cy="3" r="2"/><circle cx="18" cy="6" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="15" cy="12" r="2"/><circle cx="8" cy="20" r="2"/><circle cx="16" cy="20" r="2"/></g>',
	"occlusion": '<path d="m12 3 8 3v6c0 4-4 7-8 9-4-2-8-5-8-9V6Z M12 3v18"/><path d="m12 6 5 2v4c0 3-3 5-5 6Z" fill="white" stroke="none"/>',
	"hair": '<path d="M5 5v6c0 5 3 8 7 10 4-2 7-5 7-10V5 M8 10v4l4 4 4-4v-4 M9 6l3 2 3-2"/>',
	"mirror": '<path d="M12 3v18 M8 6 3 18h5Z M16 6l5 12h-5Z"/>',
	"mannequin": '<path d="M7 8a5 5 0 0 1 10 0v4c0 3-2 5-5 5s-5-2-5-5Z M9 17v3h6v-3 M6 21h12 M8 10h2 M14 10h2"/>',
	"clippers": '<path d="M6 3v4 M9 3v4 M12 3v4 M15 3v4 M18 3v4 M5 7h14v4l-4 3v6H9v-6l-4-3Z M10 17h4"/>',
	"processor": '<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 2v4 M15 2v4 M9 18v4 M15 18v4 M2 9h4 M2 15h4 M18 9h4 M18 15h4"/><rect x="9" y="9" width="6" height="6" rx="1"/>',
	"models": '<path d="m12 3 9 5-9 5-9-5Z M3 12l9 5 9-5 M3 16l9 5 9-5"/>',
	"camera": '<rect x="2" y="5" width="13" height="14" rx="3"/><path d="m15 10 7-4v12l-7-4 M6 12h5 M8.5 9.5v5"/>',
	"calibrate": '<path d="M3 8V3h5 M16 3h5v5 M21 16v5h-5 M8 21H3v-5 M8 8a4 4 0 0 1 8 0v5c0 3-2 5-4 5s-4-2-4-5Z M9 10h1 M14 10h1"/>'
}
const MODES := ["auto", "gpu", "cpu"]
var host: Control
var buttons: Dictionary = {}
var processing := MenuButton.new()
var models := MenuButton.new()
var clipper_menu := MenuButton.new()
var model_popups: Dictionary = {}
var row := HFlowContainer.new()
var active_backend := ""
var fallback_reason := ""

func setup(studio: Control) -> void:
	host = studio
	var surface = host._style(host.PANEL, 10)
	surface.content_margin_left = 8
	surface.content_margin_right = 8
	surface.content_margin_top = 6
	surface.content_margin_bottom = 6
	add_theme_stylebox_override("panel", surface)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	add_child(row)
	_toggle("landmarks", "Landmark guides", "Show / hide all measured, virtual, and hair-root dots. Tracking stays active.", func(value): host.guides_check.button_pressed = value)
	_toggle("occlusion", "Head occlusion", "Hide landmarks and hair behind the fitted head in the camera preview.", func(value): host.occlusion_check.button_pressed = value)
	_toggle("hair", "Hair and beard", "Show / hide hair and beard.", func(value): host.beard.set_enabled(value))
	_toggle("mirror", "Mirror preview", "Mirror preview (M).", func(value): host.mirror_check.button_pressed = value)
	_toggle("mannequin", "3D mannequin", "Switch between the camera and 3D mannequin.", func(value): host.beard.set_mannequin(value))
	_toggle("clippers", "Clippers", "3D mannequin only. Drag a line to cut the nearest visible hair. Right-drag rotates; Ctrl+Z undoes.", func(value): host.beard.clippers.set_active(value))
	buttons.clippers.text = "Clippers"
	buttons.clippers.add_theme_color_override("icon_disabled_color",Color("596472"))
	buttons.clippers.add_theme_color_override("font_disabled_color",Color("596472"))
	var clipper_group := HBoxContainer.new()
	clipper_group.add_theme_constant_override("separation",0)
	row.add_child(clipper_group)
	buttons.clippers.reparent(clipper_group)
	clipper_menu.text = "▾"
	clipper_menu.flat = false
	_style_button(clipper_menu)
	clipper_menu.custom_minimum_size.x = 24
	clipper_menu.tooltip_text = "Clippers function and blade width (3D mannequin only)"
	clipper_group.add_child(clipper_menu)
	var clip_popup := clipper_menu.get_popup()
	clip_popup.add_radio_check_item("Line · drag and release",0)
	clip_popup.add_radio_check_item("Buzz · hold left click",1)
	clip_popup.add_separator("Buzz blade width")
	for entry in [["Small · 24 px",24],["Medium · 40 px",40],["Large · 64 px",64]]: clip_popup.add_radio_check_item(entry[0],entry[1])
	clip_popup.id_pressed.connect(func(id):
		if id<2: host.beard.clippers.set_mode("Line" if id==0 else "Buzz")
		else: host.beard.clippers.set_blade_width(id))
	host.beard.clippers.changed.connect(sync)
	host.beard.clippers.preferences_changed.connect(host.queue_settings_save)
	host.beard.clippers.message.connect(func(text): host.message.text = text)
	_toggle("camera", "Virtual camera", "Send the composed preview to other apps.", func(value):
		if value: host.virtual_camera.start()
		else: host.virtual_camera.stop())
	host.virtual_camera.changed.connect(_sync_camera)
	var calibrate := Button.new()
	calibrate.icon = _icon("calibrate")
	calibrate.tooltip_text = "Calibrate head\nGuided poses and optional hair/beard reveal steps."
	_style_button(calibrate)
	calibrate.pressed.connect(func(): host.calibration.open())
	buttons["calibrate"] = calibrate
	row.add_child(calibrate)
	processing.text = "Auto"
	processing.flat = false
	processing.icon = _icon("processor")
	_style_button(processing)
	processing.custom_minimum_size.x = 86
	processing.get_popup().add_radio_check_item("Auto · fastest measured",0)
	processing.get_popup().add_radio_check_item("GPU · browser worker",1)
	processing.get_popup().add_radio_check_item("CPU · native",2)
	processing.get_popup().id_pressed.connect(func(id): host.tracking_panel.choose("backend",MODES[id]))
	row.add_child(processing)
	models.text = "Models"
	models.flat = false
	models.icon = _icon("models")
	_style_button(models)
	row.add_child(models)
	var popup := models.get_popup()
	for kind in ["face", "hand", "pose"]:
		var menu := PopupMenu.new()
		menu.name = kind.capitalize() + "Models"
		popup.add_child(menu)
		model_popups[kind] = menu
		popup.add_submenu_item({"face":"Face", "hand":"Hands", "pose":"Body pose"}[kind],menu.name)
		menu.id_pressed.connect(func(id):
			var selected: String = str(menu.get_item_metadata(menu.get_item_index(id)))
			host.tracking_panel.choose(kind+"_model",selected))
	popup.add_separator()
	popup.add_item("Manage / download models…",10)
	popup.id_pressed.connect(func(id):
		if id == 10: open_models())
	popup.about_to_popup.connect(_populate_models)
	for check in [host.guides_check,host.occlusion_check,host.mirror_check]:
		check.toggled.connect(func(_value): sync())
	host.beard.changed.connect(sync)
	host.tracking_panel.settings_changed.connect(sync)
	resized.connect(_adapt_width)
	sync()
	_adapt_width.call_deferred()
	_sync_camera()

func _sync_camera() -> void:
	var camera: Node = host.virtual_camera
	buttons.camera.set_pressed_no_signal(camera.active)
	buttons.camera.text = "ON" if camera.active else ""
	buttons.camera.tooltip_text = "Virtual camera · " + camera.state + "\n" + camera.detail

func _icon(key: String) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' + ICONS[key] + '</svg>')
	return ImageTexture.create_from_image(image)

func _style_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(36,34)
	button.add_theme_font_size_override("font_size",12)
	button.add_theme_constant_override("h_separation",6)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","hover_pressed","focus"]:
		var fill = host.BG if state == "normal" else Color("23473f") if state in ["pressed","hover_pressed"] else Color("253447")
		var box = host._style(fill,6)
		box.content_margin_left = 9
		box.content_margin_right = 9
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		if state == "focus": box.border_color = host.ACCENT; box.bg_color = Color.TRANSPARENT
		button.add_theme_stylebox_override(state,box)
	for state in ["normal","hover","focus"]: button.add_theme_color_override("icon_"+state+"_color",host.INK)
	for state in ["pressed","hover_pressed"]: button.add_theme_color_override("icon_"+state+"_color",host.ACCENT)

func _toggle(key: String, title: String, hint: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = title.replace(" ","")
	button.icon = _icon(key)
	button.tooltip_text = title + "\n" + hint
	button.toggle_mode = true
	_style_button(button)
	button.toggled.connect(callback)
	buttons[key] = button
	row.add_child(button)

func sync() -> void:
	buttons.landmarks.set_pressed_no_signal(host.guides_check.button_pressed)
	buttons.occlusion.set_pressed_no_signal(host.occlusion.enabled)
	buttons.hair.set_pressed_no_signal(host.beard.enabled)
	buttons.mirror.set_pressed_no_signal(host.mirror_check.button_pressed)
	buttons.mannequin.set_pressed_no_signal(host.beard.mannequin)
	buttons.clippers.disabled = not host.beard.mannequin
	buttons.clippers.set_pressed_no_signal(host.beard.clippers.active)
	clipper_menu.disabled = buttons.clippers.disabled
	buttons.clippers.tooltip_text = "Clippers · " + host.beard.clippers.mode + "\nUse the dropdown to choose Line or Buzz. Right-drag rotates; Ctrl+Z undoes."
	for i in clipper_menu.get_popup().item_count:
		var id := clipper_menu.get_popup().get_item_id(i)
		clipper_menu.get_popup().set_item_checked(i,(id==0 and host.beard.clippers.mode=="Line") or (id==1 and host.beard.clippers.mode=="Buzz") or (id>1 and id==int(host.beard.clippers.blade_width)))
	var config: Dictionary = host.tracking_panel.values()
	var mode: String = config.get("backend","auto")
	var label := "Auto" if mode == "auto" else mode.to_upper()
	processing.text = label + " ▾"
	processing.tooltip_text = "Tracking processor: " + label
	if not active_backend.is_empty(): processing.tooltip_text += "\nRunning on " + active_backend.to_upper()
	if not fallback_reason.is_empty(): processing.tooltip_text += "\nCPU fallback: " + fallback_reason
	for i in MODES.size(): processing.get_popup().set_item_checked(i,MODES[i] == mode)
	models.tooltip_text = "Tracking models"
	for kind in ["face","hand","pose"]: models.tooltip_text += "\n" + kind.capitalize() + ": " + str(config.get(kind+"_model",""))

func update_status(data: Dictionary) -> void:
	active_backend = str(data.get("active_backend", "")) if data.get("active_backend") else ""
	fallback_reason = str(data.get("fallback_reason", "")) if data.get("fallback_reason") else ""
	sync()

func _adapt_width() -> void:
	models.text = "Models ▾" if size.x >= 460 else ""

func _populate_models() -> void:
	for kind in model_popups:
		var popup: PopupMenu = model_popups[kind]
		var picker: OptionButton = host.tracking_panel.controls[kind+"_model"]
		popup.clear()
		for i in picker.item_count:
			popup.add_radio_check_item(picker.get_item_text(i),i)
			popup.set_item_metadata(i,picker.get_item_metadata(i))
			popup.set_item_checked(i,i == picker.selected)
			popup.set_item_tooltip(i,picker.get_item_tooltip(i))

func open_models() -> void:
	host.sidebar_tabs.current_tab = 3
	host.tracking_panel.model_group.show()
	var scroll: ScrollContainer = host.sidebar_tabs.get_tab_control(3)
	scroll.ensure_control_visible.call_deferred(host.tracking_panel.model_group)
	host.queue_settings_save()
