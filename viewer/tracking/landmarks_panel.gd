extends VBoxContainer
const SceneRefs = preload("res://ui/scene_refs.gd")
var ui_actions: Dictionary = {}
const Extensions = preload("res://tracking/face_extensions.gd")
var host: Control
var layer: Control
var controls: Dictionary = {}
var stats: Label
var preview_check: CheckBox
var region_picker: OptionButton
var region_pages: Dictionary = {}

func setup(studio: Control, extension_layer: Control) -> void:
	host = studio
	layer = extension_layer
	SceneRefs.bind(self)
	for key in controls:
		var control = controls[key]
		if control is CheckBox:
			control.toggled.connect(func(value): layer.set_settings({key:value}))
		elif control is ColorPickerButton:
			control.color_changed.connect(func(value): layer.set_settings({key:value.to_html()}))
		else:
			control.value_changed.connect(func(value): layer.set_settings({key:value}))
	preview_check.toggled.connect(func(value): host.beard.set_mannequin(value))
	host.beard.changed.connect(func(): preview_check.set_pressed_no_signal(host.beard.mannequin))
	region_picker.item_selected.connect(func(index): show_region(Extensions.REGIONS[index]))
	for i in Extensions.REGIONS.size():
		var region: String = Extensions.REGIONS[i]
		ui_actions["Round this region"][i].pressed.connect(func(): layer.set_settings(Extensions.rounded_region(region)))
	SceneRefs.action(self,"Reset extensions",func(): layer.set_settings(Extensions.defaults()))
	show_region("forehead")
	layer.settings_changed.connect(_sync)
	layer.tracking_changed.connect(_update_stats)
	var timer := Timer.new()
	timer.wait_time = .25
	timer.timeout.connect(_update_stats)
	add_child(timer)
	if is_inside_tree(): timer.start()
	_sync()

func show_region(region: String) -> void:
	if region not in region_pages: return
	region_picker.select(Extensions.REGIONS.find(region))
	for key in region_pages: region_pages[key].visible = key == region

func _sync() -> void:
	for key in controls:
		var control = controls[key]
		if control is CheckBox: control.set_pressed_no_signal(layer.model.config[key])
		elif control is ColorPickerButton: control.color = Color.html(layer.model.config[key])
		else: control.set_value_no_signal(layer.model.config[key])
	_update_stats()

func _update_stats() -> void:
	var count: int = layer.model.points.size()
	stats.text = "%d %s · %d virtual\n"%[layer.face.size(),"reference" if layer.preview else "measured",count]
	if not layer.model.config.enabled: stats.text += "Extensions disabled."
	elif layer.face.is_empty(): stats.text += "Waiting for a face. Enable Face + iris, or try the mannequin."
	elif count == 0: stats.text += "Waiting for a stable face outline."
	elif not layer.model.config.show_points: stats.text += "Virtual points hidden; references remain active."
	else: stats.text += "Orange = virtual · green = %s"%["reference" if layer.preview else "measured"]
