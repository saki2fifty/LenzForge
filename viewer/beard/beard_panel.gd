extends VBoxContainer
const Profile = preload("res://beard/beard_profile.gd")
const Library = preload("res://beard/beard_library.gd")
const Groom = preload("res://beard/groom_regions.gd")
signal message(text: String)
var beard: Control
var library := Library.new()
var current_id := ""
var host: Control
var controls: Dictionary = {}
var control_copies: Dictionary = {}
var strand_controls: Dictionary = {}
var name_field: LineEdit
var models: OptionButton
var style: OptionButton
var enabled_check: CheckBox
var mannequin_check: CheckBox
var selected_label: Label
var stats: Label
var selected_group: VBoxContainer
var import_dialog: FileDialog
var export_dialog: FileDialog
var delete_dialog: ConfirmationDialog
var _syncing := false
var pages: Dictionary = {}
var page_picker: OptionButton

func setup(layer: Control, studio: Control) -> void:
	beard = layer
	host = studio
	add_theme_constant_override("separation", 10)
	host._section(self, "Hair & beard", "Design roots, facial hair, and scalp styles.")
	enabled_check = _check("Show hair and beard", func(value): beard.set_enabled(value))
	mannequin_check = _check("Try on mannequin", func(value): beard.set_mannequin(value))
	mannequin_check.tooltip_text = "Drag the mannequin to test motion. Camera capture can stay off."
	page_picker = OptionButton.new()
	for title in ["Beard","Roots","Virtual landmarks","Mustache","Eyebrows","Scalp hair","Physics","Strands","Library"]: page_picker.add_item(title)
	add_child(page_picker)
	page_picker.item_selected.connect(func(index): show_page(page_picker.get_item_text(index)))
	var shape := _page("Beard")
	_config_check(shape,"beard_visible","Include beard")
	style = OptionButton.new()
	for title in Profile.STYLES: style.add_item(title)
	shape.add_child(style)
	shape.add_child(host._button("Apply beard preset", _create, true))
	for row in [["strands","Facial strands",16,1024,16],["segments","Segments / strand",2,16,1],
		["length","Beard length",.02,1.5,.01],["root_width","Starting width",.1,12,.1],
		["tip_width","Ending width",0,12,.05],["curl","Curl",0,1,.01],["variation","Length variation",0,.8,.01]]:
		_spin(shape,row[0],row[1],row[2],row[3],row[4])
	controls.root_width.tooltip_text = "Pixels at a 300-pixel face width; follows face scale."
	controls.tip_width.tooltip_text = controls.root_width.tooltip_text
	controls.curl.tooltip_text = "Rest-shape curl; enable Preserve styled shape to hold it against gravity."
	_color(shape,"root_color","Root color")
	_color(shape,"tip_color","Tip color")
	shape.add_child(host._button("Regrow roots",func(): beard.set_setting("seed",randi_range(0,2147483647))))

	var roots_page := _page("Roots")
	host._section(roots_page,"Expanded coverage","Magenta marks generated roots; green marks measured landmarks. Offsets follow face size and rotation.")
	_config_check(roots_page,"show_generated_roots","Show generated roots")
	_color(roots_page,"generated_root_color","Generated point color")
	for row in [["chin_extension","Below chin",0,.8,.01],["jaw_expansion","Jaw expansion",0,.5,.01],
		["ear_reach","Toward ears",0,.6,.01],["sideburn_height","Height around ears",0,1,.05],
		["root_layers","Root layers",1,6,1],["coverage_fill","Expanded root share",0,1,.05]]:
		_spin(roots_page,row[0],row[1],row[2],row[3],row[4])
	roots_page.add_child(host._button("Fuller coverage",func():
		beard.set_settings({"strands":maxi(512,int(beard.config.strands)),"chin_extension":.1,"jaw_expansion":.08,"ear_reach":.08,"sideburn_height":.8,"coverage_fill":.6})
		beard.set_enabled(true)))
	roots_page.add_child(host._button("Reset coverage",func(): beard.set_settings({"chin_extension":0.0,"jaw_expansion":0.0,"ear_reach":0.0,"sideburn_height":0.0})))
	roots_page.add_child(host._button("Fit virtual head…",func(): show_page("Virtual landmarks")))

	var virtual_page := _page("Virtual landmarks")
	host._section(virtual_page,"Extended head","Orange points extend the tracked face over the crown, below the chin, and around the sides. Hair roots attach between these points.")
	_config_check(virtual_page,"virtual_enabled","Use virtual head for roots")
	_config_check(virtual_page,"show_virtual_landmarks","Show virtual landmarks")
	_color(virtual_page,"virtual_color","Virtual point color")
	virtual_page.add_child(host._button("Extend head coverage",func():
		beard.set_settings(Groom.virtual_preset())
		beard.set_enabled(true),true))
	for row in [["crown_height","Crown height",0,.8,.01],["crown_width","Crown width",.6,1.8,.02],
		["crown_back","Crown back reach",0,1,.01],["chin_extension","Below chin",0,.8,.01],
		["jaw_expansion","Jaw expansion",0,.5,.01],["chin_back","Under-chin depth",0,.5,.01],
		["ear_reach","Toward ears",0,.6,.01],["side_back","Side / back reach",0,.8,.02],
		["sideburn_height","Height around ears",0,1,.05],["virtual_columns","Columns per region",8,48,1],
		["virtual_rows","Rows per region",2,10,1]]:
		_spin(virtual_page,row[0],row[1],row[2],row[3],row[4])
	controls.crown_height.tooltip_text = "Distance above the tracked forehead, in face widths. Fit the orange top row to your crown."
	controls.side_back.tooltip_text = "Depth behind the face; it becomes visible as you turn or tilt your head. This is estimated geometry."
	host._section(virtual_page,"Fitting","Adjust Crown height and width to your head. Back reach uses the existing landmark depth during turns. Point density is independent of hair density; increase strand counts separately for more hair.")

	var mustache := _page("Mustache")
	_config_check(mustache,"mustache_enabled","Include mustache")
	_enum(mustache,"mustache_style","Style",Groom.MUSTACHE_STYLES)
	_enum(mustache,"mustache_motion","Motion",Groom.MOTIONS)
	for row in [["mustache_width","Coverage width",.4,2,.05],["mustache_thickness","Coverage thickness",.2,3,.05],
		["mustache_density","Density / beard",0,3,.1],["mustache_length","Strand length",.005,.6,.005],
		["mustache_lift","Lift above lip",-.08,.15,.01],["mustache_curl","Tip curl",0,1,.05],
		["mustache_hold","Shape hold",0,1,.05],["mustache_root_width","Starting width",.1,12,.1],["mustache_tip_width","Ending width",0,12,.05]]:
		_spin(mustache,row[0],row[1],row[2],row[3],row[4])
	_color(mustache,"mustache_color","Root color")
	_color(mustache,"mustache_tip_color","Tip color")
	host._section(mustache,"Motion modes","Static follows the face without swinging. Styled reacts to motion while holding its shape. Free hangs under gravity.")

	var brows := _page("Eyebrows")
	_config_check(brows,"brow_enabled","Include eyebrows")
	_enum(brows,"brow_style","Style",Groom.BROW_STYLES)
	_enum(brows,"brow_motion","Motion",Groom.MOTIONS)
	for row in [["brow_count","Strands (both brows)",16,256,16],["brow_width","Coverage width",.5,1.6,.05],
		["brow_thickness","Thickness",.005,.12,.005],["brow_arch","Arch",-.05,.15,.005],
		["brow_length","Strand length",.01,.2,.005],["brow_lift","Lift",-.1,.15,.005],
		["brow_angle","Growth angle",-1,1,.05],["brow_hold","Shape hold",0,1,.05],
		["brow_root_width","Starting width",.1,12,.1],["brow_tip_width","Ending width",0,12,.05]]:
		_spin(brows,row[0],row[1],row[2],row[3],row[4])
	_color(brows,"brow_color","Color")

	var hair := _page("Scalp hair")
	host._section(hair,"Scalp styles","Scalp roots are estimated from the forehead and face width. Adjust the hairline and width to fit.")
	_enum(hair,"hair_style","Style",Groom.HAIR_STYLES)
	_enum(hair,"hair_motion","Motion",Groom.MOTIONS)
	for row in [["hair_count","Strands",32,768,32],["hair_length","Length",.02,1.5,.01],
		["hair_width","Scalp width",.5,1.5,.05],["hair_volume","Height / volume",0,1,.05],
		["hairline","Hairline offset",-.2,.25,.01],["hair_sweep","Sweep direction",-1,1,.05],
		["hair_part","Part position",-.4,.4,.02],["hair_sides","Side length",0,1,.05],
		["hawk_width","Mohawk strip width",.04,.6,.02],["hair_curl","Curl amount",0,1,.05],
		["hair_coils","Coil frequency",1,6,.25],["hair_clump","Clumping",0,1,.05],
		["hair_frizz","Frizz",0,1,.05],["hair_variation","Length variation",0,.8,.05],
		["hair_hold","Shape hold",0,1,.05],["hair_root_width","Starting width",.1,12,.1],
		["hair_tip_width","Ending width",0,12,.05]]:
		_spin(hair,row[0],row[1],row[2],row[3],row[4])
	_color(hair,"hair_color","Root color")
	_color(hair,"hair_tip_color","Tip color")
	controls.hair_coils.tooltip_text = "Limited to one coil per four segments to avoid jagged undersampling. Increase Segments / strand on the Beard page for finer coils."
	for key in ["hair_sweep","hair_part","hair_sides"]: controls[key].tooltip_text = "Controls the Regular hairstyle."
	controls.hawk_width.tooltip_text = "Controls the central root strip of the Mohawk."

	var physics := _page("Physics")
	host._section(physics,"Shared forces","Gravity, wind, and damping affect moving strands. Static regions keep their shape.")
	for row in [["gravity","Gravity",0,12,.1],["wind","Horizontal wind",-10,10,.1],
		["turbulence","Wind variation",0,5,.05],["damping","Damping",0,.95,.005]]:
		_spin(physics,row[0],row[1],row[2],row[3],row[4])
	controls.turbulence.tooltip_text = "Adds gusts only while horizontal wind is nonzero."
	_config_check(physics,"preserve_shape","Preserve styled beard shape")
	_spin(physics,"stiffness","Beard shape stiffness",0,1,.01)
	_config_check(physics,"collisions","Keep moving hair out of mouth")
	physics.add_child(host._button("Reset motion",func():
		if beard.simulator: beard.simulator.reset()))

	var strands := _page("Strands")
	host._section(strands,"Individual strands","Select a root to edit that hair in any region.")
	var select_check := CheckBox.new()
	select_check.text = "Select strands in preview"
	select_check.toggled.connect(func(value): beard.set_edit_strands(value))
	strands.add_child(select_check)
	selected_label = host._label("Click a strand root to edit it.",12,host.MUTED)
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strands.add_child(selected_label)
	selected_group = VBoxContainer.new()
	selected_group.add_theme_constant_override("separation",8)
	strands.add_child(selected_group)
	_spin(selected_group,"length","Length multiplier",0,3,.05,true)
	_spin(selected_group,"root_width","Starting width",.1,12,.1,true)
	_spin(selected_group,"tip_width","Ending width",0,12,.05,true)
	_spin(selected_group,"curl","Curl",0,1,.01,true)
	_color(selected_group,"root_color","Root color",true)
	_color(selected_group,"tip_color","Tip color",true)
	selected_group.add_child(host._button("Restore strand defaults",func(): beard.reset_selected()))
	selected_group.add_child(host._button("Hide this strand",func(): beard.set_strand_setting("length",0.0)))

	var saved := _page("Library")
	host._section(saved,"Saved looks","Save beard, mustache, eyebrows, scalp hair, and all root settings together.")
	name_field = LineEdit.new()
	name_field.placeholder_text = "Look name"
	name_field.max_length = 80
	name_field.text_changed.connect(func(value): beard.model_name = value if not value.strip_edges().is_empty() else "My look")
	saved.add_child(name_field)
	models = OptionButton.new()
	models.fit_to_longest_item = false
	models.clip_text = true
	saved.add_child(models)
	for items in [[["Load",_load_selected],["Save",_save],["Copy",_save_copy]],
		[["Import",func(): import_dialog.popup_centered_ratio(.7)],["Export",_export],["Delete",_ask_delete]]]:
		var row := HBoxContainer.new()
		saved.add_child(row)
		for item in items:
			var button: Button = host._button(item[0],item[1])
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(button)
	host._section(saved,"Output","Desktop snapshots include hair. Source recordings and the browser preview do not include this overlay.")
	stats = host._label("",11,host.MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(stats)
	_setup_dialogs()
	beard.changed.connect(_sync)
	beard.strand_selected.connect(func(_index): _sync())
	var timer := Timer.new()
	timer.wait_time = .5
	timer.timeout.connect(_update_stats)
	add_child(timer)
	if is_inside_tree(): timer.start()
	else: timer.tree_entered.connect(timer.start)
	_refresh_library()
	show_page("Beard")
	_sync()

func _page(title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation",10)
	pages[title] = page
	add_child(page)
	return page

func show_page(title: String) -> void:
	for key in pages: pages[key].visible = key == title
	for i in page_picker.item_count:
		if page_picker.get_item_text(i) == title: page_picker.select(i)

func _config_check(parent: Node, key: String, title: String) -> void:
	var check := CheckBox.new()
	check.text = title
	parent.add_child(check)
	controls[key] = check
	check.toggled.connect(func(value):
		if _syncing: return
		beard.set_setting(key,value)
		if value and key in ["beard_visible","mustache_enabled","brow_enabled","virtual_enabled"]: beard.set_enabled(true))

func _enum(parent: Node, key: String, title: String, values: Array) -> void:
	parent.add_child(host._label(title,12,host.MUTED))
	var picker := OptionButton.new()
	for value in values: picker.add_item(value)
	parent.add_child(picker)
	controls[key] = picker
	picker.item_selected.connect(func(index):
		if _syncing: return
		var value: String = values[index]
		if key == "hair_style":
			beard.set_settings(Groom.hair_preset(value))
			if value != "None": beard.set_enabled(true)
		elif key == "mustache_style":
			beard.set_settings({"mustache_style":value,"mustache_motion":"Free" if value == "Natural" else "Styled"})
		else: beard.set_setting(key,value))

func _check(title: String, action: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = title
	check.toggled.connect(action)
	add_child(check)
	return check

func _spin(parent: Node, key: String, title: String, minimum: float, maximum: float, step: float, individual := false) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label: Label = host._label(title, 12, host.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum; spin.max_value = maximum; spin.step = step
	spin.custom_minimum_size.x = 86
	row.add_child(spin)
	if individual: strand_controls[key] = spin
	elif controls.has(key):
		if not control_copies.has(key): control_copies[key] = []
		control_copies[key].append(spin)
	else: controls[key] = spin
	spin.value_changed.connect(func(value):
		if _syncing: return
		if individual: beard.set_strand_setting(key, value)
		else: beard.set_setting(key, int(value) if key in ["strands", "segments"] or key in Groom.INTEGERS else value))

func _color(parent: Node, key: String, title: String, individual := false) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label: Label = host._label(title, 12, host.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(86, 28)
	row.add_child(picker)
	(strand_controls if individual else controls)[key] = picker
	picker.color_changed.connect(func(color):
		if _syncing: return
		if individual: beard.set_strand_setting(key, color.to_html())
		else: beard.set_setting(key, color.to_html()))

func _sync() -> void:
	_syncing = true
	enabled_check.set_pressed_no_signal(beard.enabled)
	mannequin_check.set_pressed_no_signal(beard.mannequin)
	name_field.text = beard.model_name
	style.select(Profile.STYLES.find(beard.config.style))
	for key in controls:
		if key.ends_with("color"): controls[key].color = Color.html(beard.config[key])
		elif controls[key] is CheckBox: controls[key].set_pressed_no_signal(beard.config[key])
		elif controls[key] is OptionButton: controls[key].select(Groom.ENUMS[key].find(beard.config[key]))
		else: controls[key].set_value_no_signal(beard.config[key])
	controls.stiffness.editable = beard.config.preserve_shape
	for key in control_copies:
		for control in control_copies[key]: control.set_value_no_signal(beard.config[key])
	selected_group.visible = beard.selected_strand >= 0
	selected_label.text = "%s · %s" % [beard.attachment[beard.selected_strand].zone,beard.selected_key()] if beard.selected_strand >= 0 else "Click a strand root to edit it."
	var edit: Dictionary = beard.overrides.get(beard.selected_key(), {})
	var regional: Dictionary = beard.selected_defaults()
	for key in strand_controls:
		var value = edit.get(key, 1.0 if key == "length" else regional[key])
		if key.ends_with("color"): strand_controls[key].color = Color.html(value)
		else: strand_controls[key].set_value_no_signal(value)
	_syncing = false

func _create() -> void:
	var chosen: String = Profile.STYLES[style.selected]
	var updated := Profile.defaults(chosen)
	for key in beard.config:
		if key.begins_with("hair_") or key.begins_with("brow_") or key.begins_with("virtual_") or key.begins_with("crown_") or key in ["hawk_width","side_back","chin_back","show_virtual_landmarks"]: updated[key] = beard.config[key]
	var edits: Dictionary = beard.overrides.duplicate(true)
	for id in edits.keys():
		if id.is_valid_int(): edits.erase(id)
	beard.apply_document(Profile.document(chosen, updated, edits))
	beard.set_enabled(true)
	message.emit("Created " + chosen + ". Start face tracking or choose Try on mannequin.")

func _refresh_library(select_id := "") -> void:
	models.clear()
	models.add_item("Saved looks…")
	models.set_item_disabled(0, true)
	for entry in library.list_models():
		models.add_item(entry.name)
		var index := models.item_count - 1
		models.set_item_metadata(index, entry.id)
		var thumbnail := library.thumbnail_path(entry.id)
		if FileAccess.file_exists(thumbnail):
			var image := Image.load_from_file(thumbnail)
			if image and image.get_width() <= 256 and image.get_height() <= 256:
				image.resize(40,40,Image.INTERPOLATE_LANCZOS)
				models.set_item_icon(index, ImageTexture.create_from_image(image))
		if entry.id == select_id: models.select(index)

func _load_selected() -> void:
	if models.selected <= 0: message.emit("Choose a saved look first."); return
	var id: String = models.get_item_metadata(models.selected)
	var result := library.load_model(id)
	if not result.error.is_empty(): message.emit(result.error); return
	beard.apply_document(result.data)
	current_id = id
	beard.set_enabled(true)
	message.emit("Loaded " + beard.model_name + ".")

func _save() -> void:
	var result := library.save_model(beard.get_document(), current_id)
	if not result.error.is_empty(): message.emit(result.error); return
	current_id = result.id
	_refresh_library(current_id)
	message.emit("Saved " + beard.model_name + " to " + ProjectSettings.globalize_path(library.directory))
	_make_thumbnail(current_id, beard.get_document())

func _make_thumbnail(id: String, data: Dictionary) -> void:
	# Render a neutral mannequin, never the user's live camera image.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160,160)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var preview = load("res://beard/beard_layer.gd").new()
	preview.size = Vector2(160,160)
	viewport.add_child(preview)
	preview.apply_document(data)
	preview.set_enabled(true)
	preview.set_mannequin(true)
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if FileAccess.file_exists(library.directory.path_join(id + ".json")):
		viewport.get_texture().get_image().save_png(library.thumbnail_path(id))
	viewport.queue_free()
	_refresh_library(current_id)

func _save_copy() -> void:
	current_id = ""
	beard.model_name = beard.model_name.left(75) + " copy"
	_sync()
	_save()

func _setup_dialogs() -> void:
	import_dialog = FileDialog.new()
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.filters = PackedStringArray(["*.json ; LenzForge hair and beard"])
	import_dialog.file_selected.connect(func(path):
		var result := library.read_path(path)
		if not result.error.is_empty(): message.emit(result.error); return
		beard.apply_document(result.data)
		current_id = ""
		beard.set_enabled(true)
		message.emit("Imported " + beard.model_name + ". Save to add it to your library."))
	add_child(import_dialog)
	export_dialog = FileDialog.new()
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.filters = import_dialog.filters
	export_dialog.file_selected.connect(func(path):
		var error := library.write_path(path, Profile.with_geometry(beard.get_document()))
		message.emit("Exported " + path if error.is_empty() else error))
	add_child(export_dialog)
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "Delete saved look"
	delete_dialog.confirmed.connect(func():
		if models.selected <= 0: return
		var id: String = models.get_item_metadata(models.selected)
		var error := library.delete_model(id)
		if id == current_id: current_id = ""
		_refresh_library()
		message.emit("Removed the saved look. The current preview is still available." if error.is_empty() else error))
	add_child(delete_dialog)

func _export() -> void:
	export_dialog.current_file = "look.json"
	export_dialog.popup_centered_ratio(.7)

func _ask_delete() -> void:
	if models.selected <= 0: message.emit("Choose a saved look first."); return
	delete_dialog.dialog_text = "Delete “%s” from the library?" % models.get_item_text(models.selected)
	delete_dialog.popup_centered()

func _update_stats() -> void:
	if not beard.last_error.is_empty(): stats.text = beard.last_error
	elif not beard.enabled: stats.text = "Hair is hidden; physics is idle."
	elif not beard._face_live: stats.text = "Waiting for a face. Try the mannequin to design offline."
	else: stats.text = "%d / 2048 strands · %d segments\n%d virtual landmarks · %.2f ms physics + upload preparation" % [beard.attachment.size(), beard.attachment.size()*int(beard.config.segments), beard.virtual_points.size(),beard.update_ms]
