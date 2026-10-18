extends VBoxContainer
var controls: Dictionary = {}
var status: Label
var host: Control
var effects: Node
var column: VBoxContainer
var pages: Array[VBoxContainer] = []
var values: Dictionary = {}
var page_picker: OptionButton
func setup(studio: Control, controller: Node) -> void:
	host = studio; effects = controller
	column = self
	add_theme_constant_override("separation",8)
	host._section(self,"Effects","Apply to live video and virtual-camera output. Source recordings stay unchanged.")
	_toggle("enabled","Enable effects")
	page_picker = OptionButton.new()
	for title in ["Face & skin","Background","Color & finish"]: page_picker.add_item(title)
	page_picker.item_selected.connect(func(i): effects.set_config({"page":i}))
	add_child(page_picker)
	_page()
	host._section(column,"Face & skin","Uses Face tracking. Eyes, brows and mouth detail are protected from smoothing.")
	_toggle("face_enabled","Enable facial effects")
	column.add_child(host._button("Natural skin preset",func(): effects.set_config({
		"enabled":true,"face_enabled":true,"skin_smoothing":.45,"skin_detail":.65,
		"face_brightness":.025,"face_warmth":.005,"blush":0.0,"lip_tint":0.0})))
	_slider("skin_smoothing","Skin smoothing",0,1,.05)
	_slider("skin_detail","Preserve detail",0,1,.05)
	controls.skin_detail.tooltip_text = "Higher keeps more facial texture and strong edges. Lower makes smoothing stronger."
	_slider("face_brightness","Face brightness",-.15,.15,.005)
	_slider("face_warmth","Face warmth",-.08,.08,.005)
	_slider("blush","Cheek blush",0,1,.05)
	_color("blush_color","Blush color")
	_slider("lip_tint","Lip tint",0,1,.05)
	_color("lip_color","Lip color")
	var face_status: Label = host._label(effects.facial.detail,11,host.MUTED)
	face_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(face_status)
	effects.facial.status_changed.connect(func(): face_status.text = effects.facial.detail)
	column.add_child(host._button("Reset facial effects",func():
		var defaults := {}
		for key in ["face_enabled","skin_smoothing","skin_detail","face_brightness","face_warmth","blush","blush_color","lip_tint","lip_color"]:
			defaults[key] = effects.DEFAULTS[key]
		effects.set_config(defaults)))
	_page()
	_toggle("blur","Background blur")
	_slider("blur_strength","Blur strength",2,48,1)
	var quality := OptionButton.new()
	quality.add_item("Fast person detection")
	quality.add_item("Balanced · more vertical detail")
	quality.fit_to_longest_item = false; quality.clip_text = true
	quality.item_selected.connect(func(i): effects.set_config({"mask_quality":"fast" if i==0 else "balanced"}))
	controls.mask_quality = quality; column.add_child(quality)
	_slider("person_confidence","Person confidence",.3,.95,.01)
	controls.person_confidence.tooltip_text = "Raise to blur uncertain background patches. Too high can blur fine hair or fingers."
	_slider("edge_inset","Edge inset",0,4,.25)
	controls.edge_inset.tooltip_text = "Shrinks the sharp outline in mask pixels. Raise slightly to remove clear fringes; too much trims the person."
	_slider("edge_softness","Edge softness",.02,.3,.01)
	var rate := OptionButton.new()
	rate.add_item("Smooth edges · up to 30 masks/s")
	rate.add_item("Lower CPU use · up to 15 masks/s")
	rate.add_item("Fast motion · up to 60 masks/s")
	rate.fit_to_longest_item = false
	rate.clip_text = true
	rate.select(0 if effects.config.mask_rate==30 else 1)
	rate.item_selected.connect(func(i): effects.set_config({"mask_rate":[30,15,60][i]}))
	controls.mask_rate = rate
	column.add_child(rate)
	status = host._label(effects.detail,11,host.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	effects.status_changed.connect(func(): status.text = effects.detail)
	column.add_child(host._button("Reduce background leaks",func(): effects.set_config({
		"enabled":true,"blur":true,"person_confidence":.75,"edge_inset":1.0,"edge_softness":.08,"mask_rate":60})))
	column.add_child(HSeparator.new())
	host._section(column,"Stubborn background patches","Step completely out of view during the countdown. Learn again if the camera or lighting changes.")
	_toggle("room_cleanup","Use learned room")
	var learn: Button = host._button("Learn empty room · 5 s",effects.learn_room)
	column.add_child(learn)
	column.add_child(host._button("Forget learned room",effects.forget_room))
	_slider("room_tolerance","Room tolerance",.02,.35,.01)
	controls.room_tolerance.tooltip_text = "Raise to keep more matching wall colors blurred. Lower if similar-colored clothing starts blurring."
	var room_status: Label = host._label(effects.room_detail,11,host.MUTED)
	room_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(room_status)
	effects.room_status_changed.connect(func():
		room_status.text = effects.room_detail
		learn.text = "Cancel room capture" if effects.learning or effects.learn_until>0 else "Learn empty room · 5 s")
	_page()
	host._section(column,"Color & finish","These adjustments layer over your Look preset.")
	var filters := OptionButton.new()
	for label in ["No color filter","Black & white","Sepia","Negative","Posterize"]: filters.add_item(label)
	filters.select(effects.config.filter)
	filters.item_selected.connect(func(i): effects.set_config({"filter":i}))
	controls.filter = filters
	column.add_child(filters)
	_slider("saturation","Saturation",0,2,.05)
	_slider("contrast","Contrast",.5,1.5,.025)
	_slider("warmth","Warmth",-.15,.15,.005)
	_slider("vignette","Vignette",0,1,.05)
	add_child(host._button("Reset effects",func(): effects.set_config(effects.DEFAULTS)))
	effects.changed.connect(_sync)
	_sync()
func _page() -> void:
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	pages.append(column); add_child(column)
func _color(key: String, title: String) -> void:
	var row := HBoxContainer.new()
	var label: Label = host._label(title,12,host.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(65,24)
	picker.edit_alpha = false
	picker.color_changed.connect(func(value): effects.set_config({key:value.to_html(false)}))
	row.add_child(picker); column.add_child(row)
	controls[key] = picker
func _toggle(key: String, title: String) -> void:
	var check := CheckBox.new()
	check.text = title
	check.button_pressed = effects.config[key]
	check.toggled.connect(func(value): effects.set_config({key:value}))
	controls[key] = check
	column.add_child(check)
func _slider(key: String, title: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	var label: Label = host._label(title,12,host.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
	values[key] = host._label("",11,host.MUTED); row.add_child(values[key]); column.add_child(row)
	var slider := HSlider.new()
	slider.min_value = low; slider.max_value = high; slider.step = step
	slider.value_changed.connect(func(value): effects.set_config({key:value}))
	column.add_child(slider); controls[key] = slider
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
