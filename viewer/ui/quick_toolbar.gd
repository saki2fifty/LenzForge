extends PanelContainer
const SceneRefs = preload("res://ui/scene_refs.gd")
var ui_actions: Dictionary = {}
## Event-driven shortcuts to the studio's existing controls and autosave path.
const MODES := ["auto", "gpu", "cpu"]
var host: Control
var buttons: Dictionary = {}
var processing: MenuButton
var models: MenuButton
var clipper_menu: MenuButton
var model_popups: Dictionary = {}
var row: HFlowContainer
var active_backend := ""
var fallback_reason := ""

func setup(studio: Control) -> void:
	host = studio
	SceneRefs.bind(self)
	buttons.landmarks.toggled.connect(func(value): host.guides_check.button_pressed = value)
	buttons.occlusion.toggled.connect(func(value): host.occlusion_check.button_pressed = value)
	buttons.hair.toggled.connect(func(value): host.beard.set_enabled(value))
	buttons.mirror.toggled.connect(func(value): host.mirror_check.button_pressed = value)
	buttons.mannequin.toggled.connect(func(value): host.beard.set_mannequin(value))
	buttons.clippers.toggled.connect(func(value): host.beard.clippers.set_active(value))
	var clip_popup := clipper_menu.get_popup()
	clip_popup.clear()
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
	buttons.camera.toggled.connect(func(value):
		if value: host.virtual_camera.start()
		else: host.virtual_camera.stop())
	host.virtual_camera.changed.connect(_sync_camera)
	buttons.calibrate.pressed.connect(func(): host.calibration.open())
	processing.get_popup().clear()
	processing.get_popup().add_radio_check_item("Auto · fastest measured",0)
	processing.get_popup().add_radio_check_item("GPU · browser worker",1)
	processing.get_popup().add_radio_check_item("CPU · native",2)
	processing.get_popup().id_pressed.connect(func(id): host.tracking_panel.choose("backend",MODES[id]))
	var popup := models.get_popup()
	popup.clear()
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
