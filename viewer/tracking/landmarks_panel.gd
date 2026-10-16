extends VBoxContainer
const Extensions = preload("res://tracking/face_extensions.gd")
var host: Control
var layer: Control
var controls: Dictionary = {}
var stats: Label
var preview_check: CheckBox

func setup(studio: Control, extension_layer: Control) -> void:
	host = studio
	layer = extension_layer
	add_theme_constant_override("separation",10)
	host._section(self,"Virtual landmarks","Extend the tracked outline in every direction. Orange points follow your face, even with hair turned off.")
	_check("enabled","Extend face / head landmarks")
	_check("show_points","Show virtual landmarks")
	stats = host._label("",12,host.MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(stats)
	preview_check = CheckBox.new()
	preview_check.text = "Try on mannequin"
	preview_check.toggled.connect(func(value): host.beard.set_mannequin(value))
	add_child(preview_check)
	host.beard.changed.connect(func(): preview_check.set_pressed_no_signal(host.beard.mannequin))
	for row in [["vertical_offset","Move up / down",-1.5,1.5,.01],
		["top","Above head",0,1.5,.01],["bottom","Below chin",0,1.5,.01],
		["left","Left side",0,1.5,.01],["right","Right side",0,1.5,.01],["depth","Front / back",-1,1,.01],
		["rings","Outward layers",1,12,1],["columns","Points around face",36,144,4],["point_size","Point size",1,6,.25]]:
		_spin(row)
	controls.vertical_offset.tooltip_text = "Negative moves all virtual points up; positive moves them down. Zero centers the fit. The offset follows your head, in face widths."
	controls.depth.tooltip_text = "Negative reaches forward; positive reaches behind the face. Turn or tilt your head to see the depth offset."
	controls.left.tooltip_text = "Left in the unmirrored camera image; follows the head when rotated."
	controls.right.tooltip_text = controls.left.tooltip_text
	var color := ColorPickerButton.new()
	color.custom_minimum_size.y = 30
	color.edit_alpha = false
	color.color_changed.connect(func(value): layer.set_settings({"color":value.to_html()}))
	controls.color = color
	add_child(color)
	add_child(host._button("Reset extensions",func(): layer.set_settings(Extensions.defaults())))
	host._section(self,"Fitting","Distances are in face widths. Fit the orange rings to your head, chin, temples, and sides. These are estimated reference points, not additional camera measurements.")
	layer.settings_changed.connect(_sync)
	layer.tracking_changed.connect(_update_stats)
	var timer := Timer.new()
	timer.wait_time = .25
	timer.timeout.connect(_update_stats)
	add_child(timer)
	if is_inside_tree(): timer.start()
	_sync()

func _check(key: String, title: String) -> void:
	var check := CheckBox.new()
	check.text = title
	check.toggled.connect(func(value): layer.set_settings({key:value}))
	controls[key] = check
	add_child(check)

func _spin(row: Array) -> void:
	var box := HBoxContainer.new()
	add_child(box)
	var label: Label = host._label(row[1],12,host.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = row[2]; spin.max_value = row[3]; spin.step = row[4]
	spin.custom_minimum_size.x = 86
	spin.value_changed.connect(func(value): layer.set_settings({row[0]:value}))
	box.add_child(spin)
	controls[row[0]] = spin

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
