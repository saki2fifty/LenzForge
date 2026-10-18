extends VBoxContainer
const SceneRefs = preload("res://ui/scene_refs.gd")
var ui_actions: Dictionary = {}
var controls: Dictionary = {}
var status: Label
var host: Control
var effects: Node
var face_status: Label
var room_status: Label
var pages: Array[VBoxContainer] = []
var values: Dictionary = {}
var page_picker: OptionButton
func setup(studio: Control, controller: Node) -> void:
	host = studio
	effects = controller
	SceneRefs.bind(self)
	page_picker.item_selected.connect(func(i): effects.set_config({"page":i}))
	for key in controls:
		var control = controls[key]
		if control is CheckBox:
			control.toggled.connect(func(value): effects.set_config({key:value}))
		elif control is Slider:
			control.value_changed.connect(func(value): effects.set_config({key:value}))
		elif control is ColorPickerButton:
			control.color_changed.connect(func(value): effects.set_config({key:value.to_html(false)}))
		elif key == "mask_quality":
			control.item_selected.connect(func(i): effects.set_config({key:"fast" if i==0 else "balanced"}))
		elif key == "mask_rate":
			control.item_selected.connect(func(i): effects.set_config({key:[30,15,60][i]}))
		else:
			control.item_selected.connect(func(i): effects.set_config({key:i}))
	SceneRefs.action(self,"Natural skin preset",func(): effects.set_config({
		"enabled":true,"face_enabled":true,"skin_smoothing":.45,"skin_detail":.65,
		"face_brightness":.025,"face_warmth":.005,"blush":0.0,"lip_tint":0.0}))
	SceneRefs.action(self,"Reset facial effects",func():
		var defaults := {}
		for key in ["face_enabled","skin_smoothing","skin_detail","face_brightness","face_warmth","blush","blush_color","lip_tint","lip_color"]:
			defaults[key] = effects.DEFAULTS[key]
		effects.set_config(defaults))
	SceneRefs.action(self,"Reduce background leaks",func(): effects.set_config({
		"enabled":true,"blur":true,"person_confidence":.75,"edge_inset":1.0,"edge_softness":.08,"mask_rate":60}))
	SceneRefs.action(self,"Learn empty room · 5 s",effects.learn_room)
	SceneRefs.action(self,"Forget learned room",effects.forget_room)
	SceneRefs.action(self,"Reset effects",func(): effects.set_config(effects.DEFAULTS))
	face_status.text = effects.facial.detail
	status.text = effects.detail
	room_status.text = effects.room_detail
	effects.facial.status_changed.connect(func(): face_status.text = effects.facial.detail)
	effects.status_changed.connect(func(): status.text = effects.detail)
	effects.room_status_changed.connect(func():
		room_status.text = effects.room_detail
		ui_actions["Learn empty room · 5 s"][0].text = "Cancel room capture" if effects.learning or effects.learn_until>0 else "Learn empty room · 5 s")
	effects.changed.connect(_sync)
	_sync()

func _sync() -> void:
	page_picker.select(effects.config.page)
	for i in pages.size(): pages[i].visible = i==effects.config.page
	for key in controls:
		if controls[key] is CheckBox: controls[key].set_pressed_no_signal(effects.config[key])
		elif controls[key] is Slider:
			controls[key].set_value_no_signal(effects.config[key]); values[key].text = String.num(effects.config[key],3)
		elif controls[key] is ColorPickerButton: controls[key].color = Color(effects.config[key])
		elif key=="filter": controls[key].select(effects.config.filter)
		elif key=="mask_rate": controls[key].select([30,15,60].find(effects.config.mask_rate))
		elif key=="mask_quality": controls[key].select(0 if effects.config.mask_quality=="fast" else 1)
	controls.blur.disabled = not effects.config.enabled
	controls.mask_rate.disabled = not effects.config.enabled or not effects.config.blur
	controls.mask_quality.disabled = controls.mask_rate.disabled
	for key in ["blur_strength","edge_softness","person_confidence","edge_inset","room_tolerance"]:
		controls[key].editable = effects.config.enabled and effects.config.blur
	controls.face_enabled.disabled = not effects.config.enabled
	for key in ["skin_smoothing","skin_detail","face_brightness","face_warmth","blush","lip_tint"]:
		controls[key].editable = effects.config.enabled and effects.config.face_enabled
	for key in ["blush_color","lip_color"]: controls[key].disabled = not effects.config.enabled or not effects.config.face_enabled
