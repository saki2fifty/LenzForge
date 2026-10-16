extends VBoxContainer
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
	add_theme_constant_override("separation",10)
	host._section(self,"Virtual landmarks","Orange points extend the measured mesh along the head surface. Hair and objects can use either kind of landmark.")
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
	_spin(["vertical_offset","Move up / down",-1.5,1.5,.01])
	controls.vertical_offset.tooltip_text = "Move the coverage up or down along the skin. Points remain on the shared surface."
	host._section(self,"Regional contour","Choose a region and move its guide coverage along the shared head surface.")
	region_picker = OptionButton.new()
	for title in ["Forehead","Left side","Right side","Chin"]: region_picker.add_item(title)
	region_picker.item_selected.connect(func(index): show_region(Extensions.REGIONS[index]))
	add_child(region_picker)
	for i in Extensions.REGIONS.size():
		var region: String = Extensions.REGIONS[i]
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation",8)
		region_pages[region] = page
		add_child(page)
		if region.ends_with("side"):
			_spin([region+"_inset","Start in / out",-1.5,1.5,.01],page)
			controls[region+"_inset"].tooltip_text = "Move coverage toward the face or around its side, constrained to the skin."
		for row in [[region+"_vertical","Start up / down",-1.5,1.5,.01],
			[["top","left","right","bottom"][i],"Surface reach",0,1.5,.01],
			[region+"_back","Back reach",0,1.5,.01],[region+"_wrap","Wrap angle",0,180,5]]:
			_spin(row,page)
		controls[region+"_vertical"].tooltip_text = "Move this region up or down along the skin. Blends into neighboring regions."
		controls[region+"_back"].tooltip_text = "Extra reach behind this region, added to the overall Front / back setting. Turn or tilt your head to see the depth."
		controls[region+"_wrap"].suffix = "°"
		controls[region+"_wrap"].tooltip_text = "Bias the distribution along the contour. All angles remain constrained to the head surface."
		page.add_child(host._button("Round this region",func(): layer.set_settings(Extensions.rounded_region(region))))
	show_region("forehead")
	host._section(self,"Whole set")
	for row in [["depth","Front / back",-1,1,.01],["rings","Guide rows",1,12,1],
		["columns","Points around face",36,144,4],["point_size","Point size",1,6,.25]]:
		_spin(row)
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
	host._section(self,"Fitting","Guides always lie on the shared mesh. Fit Head depth and Crown height in Landmarks → Visibility; these also update hair and occlusion. The unmeasured scalp and back remain estimates. Hiding or changing guide density preserves placed attachments.")
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

func _check(key: String, title: String) -> void:
	var check := CheckBox.new()
	check.text = title
	check.toggled.connect(func(value): layer.set_settings({key:value}))
	controls[key] = check
	add_child(check)

func _spin(row: Array, parent: Node = self) -> void:
	var box := HBoxContainer.new()
	parent.add_child(box)
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
