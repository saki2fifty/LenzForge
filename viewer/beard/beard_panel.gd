extends VBoxContainer
const Profile = preload("res://beard/beard_profile.gd")
const Library = preload("res://beard/beard_library.gd")
signal message(text: String)
var beard: Control
var library := Library.new()
var current_id := ""
var host: Control
var controls: Dictionary = {}
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

func setup(layer: Control, studio: Control) -> void:
	beard = layer
	host = studio
	add_theme_constant_override("separation", 10)
	host._section(self, "Physics beard", "Create a style, then adjust its strands. Face + iris tracking attaches it to your face.")
	enabled_check = _check("Show beard", func(value): beard.set_enabled(value))
	mannequin_check = _check("Try on mannequin", func(value): beard.set_mannequin(value))
	mannequin_check.tooltip_text = "Drag the mannequin to test motion. Camera capture can stay off."
	style = OptionButton.new()
	for title in Profile.STYLES: style.add_item(title)
	add_child(style)
	add_child(host._button("Create beard", _create, true))
	add_child(HSeparator.new())
	name_field = LineEdit.new()
	name_field.placeholder_text = "Beard name"
	name_field.max_length = 80
	name_field.text_changed.connect(func(value): beard.model_name = value if not value.strip_edges().is_empty() else "My beard")
	add_child(name_field)
	models = OptionButton.new()
	models.fit_to_longest_item = false
	models.clip_text = true
	add_child(models)
	var row := HBoxContainer.new()
	add_child(row)
	for item in [["Load", _load_selected], ["Save", _save], ["Copy", _save_copy]]:
		var button: Button = host._button(item[0], item[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	var actions := HBoxContainer.new()
	add_child(actions)
	for item in [["Import", func(): import_dialog.popup_centered_ratio(.7)], ["Export", _export], ["Delete", _ask_delete]]:
		var button: Button = host._button(item[0], item[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	add_child(HSeparator.new())
	host._section(self, "Shape")
	_spin(self, "strands", "Strands", 16, 1024, 16)
	_spin(self, "segments", "Segments per strand", 2, 16, 1)
	_spin(self, "length", "Length / face width", .02, 1.5, .01)
	_spin(self, "root_width", "Starting width", .1, 12, .1)
	_spin(self, "tip_width", "Ending width", 0, 12, .05)
	_spin(self, "curl", "Curl", 0, 1, .01)
	_spin(self, "variation", "Length variation", 0, .8, .01)
	controls.root_width.tooltip_text = "Pixels at a 300-pixel face width; follows face scale."
	controls.tip_width.tooltip_text = controls.root_width.tooltip_text
	_color(self, "root_color", "Root color")
	_color(self, "tip_color", "Tip color")
	add_child(host._button("Regrow strands", func(): beard.set_setting("seed", randi_range(0, 2147483647))))
	add_child(HSeparator.new())
	host._section(self, "Physics")
	_spin(self, "gravity", "Gravity", 0, 12, .1)
	_spin(self, "wind", "Horizontal wind", -10, 10, .1)
	_spin(self, "turbulence", "Wind variation", 0, 5, .05)
	controls.turbulence.tooltip_text = "Adds gusts only while horizontal wind is nonzero."
	_spin(self, "damping", "Damping", 0, .95, .005)
	controls.preserve_shape = _check("Preserve styled shape", func(value):
		if not _syncing: beard.set_setting("preserve_shape", value))
	controls.preserve_shape.tooltip_text = "Off: strands hang under gravity and swing with head motion or wind. On: stiffness holds the curled or imported style."
	_spin(self, "stiffness", "Shape stiffness", 0, 1, .01)
	controls.stiffness.tooltip_text = "Used only when Preserve styled shape is enabled."
	controls.curl.tooltip_text = "Rest-shape curl; enable Preserve styled shape to hold it against gravity."
	controls.collisions = _check("Keep strands out of mouth", func(value):
		if not _syncing: beard.set_setting("collisions", value))
	add_child(host._button("Reset motion", func():
		if beard.simulator: beard.simulator.reset()))
	add_child(HSeparator.new())
	host._section(self, "Individual strands")
	_check("Select strands in preview", func(value): beard.set_edit_strands(value))
	selected_label = host._label("Click a strand root to edit it.", 12, host.MUTED)
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(selected_label)
	selected_group = VBoxContainer.new()
	selected_group.add_theme_constant_override("separation", 8)
	add_child(selected_group)
	_spin(selected_group, "length", "Length multiplier", 0, 3, .05, true)
	_spin(selected_group, "root_width", "Starting width", .1, 12, .1, true)
	_spin(selected_group, "tip_width", "Ending width", 0, 12, .05, true)
	_spin(selected_group, "curl", "Curl", 0, 1, .01, true)
	_color(selected_group, "root_color", "Root color", true)
	_color(selected_group, "tip_color", "Tip color", true)
	selected_group.add_child(host._button("Restore strand defaults", func(): beard.reset_selected()))
	selected_group.add_child(host._button("Hide this strand", func(): beard.set_strand_setting("length", 0.0)))
	stats = host._label("", 11, host.MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(stats)
	var note: Label = host._label("Snapshots include the beard. Source recordings and the browser preview keep the original camera image.", 12, host.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
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
	_sync()

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
	(strand_controls if individual else controls)[key] = spin
	spin.value_changed.connect(func(value):
		if _syncing: return
		if individual: beard.set_strand_setting(key, value)
		else: beard.set_setting(key, int(value) if key in ["strands", "segments"] else value))

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
		elif key in ["collisions", "preserve_shape"]: controls[key].set_pressed_no_signal(beard.config[key])
		else: controls[key].set_value_no_signal(beard.config[key])
	controls.stiffness.editable = beard.config.preserve_shape
	selected_group.visible = beard.selected_strand >= 0
	selected_label.text = "Strand %d" % (beard.selected_strand + 1) if beard.selected_strand >= 0 else "Click a strand root to edit it."
	var edit: Dictionary = beard.overrides.get(str(beard.selected_strand), {})
	for key in strand_controls:
		var value = edit.get(key, 1.0 if key == "length" else beard.config[key])
		if key.ends_with("color"): strand_controls[key].color = Color.html(value)
		else: strand_controls[key].set_value_no_signal(value)
	_syncing = false

func _create() -> void:
	var chosen: String = Profile.STYLES[style.selected]
	current_id = ""
	beard.apply_document(Profile.document(chosen, Profile.defaults(chosen), {}))
	beard.set_enabled(true)
	message.emit("Created " + chosen + ". Start face tracking or choose Try on mannequin.")

func _refresh_library(select_id := "") -> void:
	models.clear()
	models.add_item("Saved beards…")
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
	if models.selected <= 0: message.emit("Choose a saved beard first."); return
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
	import_dialog.filters = PackedStringArray(["*.json ; LenzForge beard"])
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
	delete_dialog.title = "Delete saved beard"
	delete_dialog.confirmed.connect(func():
		if models.selected <= 0: return
		var id: String = models.get_item_metadata(models.selected)
		var error := library.delete_model(id)
		if id == current_id: current_id = ""
		_refresh_library()
		message.emit("Removed the saved beard. The current preview is still available." if error.is_empty() else error))
	add_child(delete_dialog)

func _export() -> void:
	export_dialog.current_file = "beard.json"
	export_dialog.popup_centered_ratio(.7)

func _ask_delete() -> void:
	if models.selected <= 0: message.emit("Choose a saved beard first."); return
	delete_dialog.dialog_text = "Delete “%s” from the library?" % models.get_item_text(models.selected)
	delete_dialog.popup_centered()

func _update_stats() -> void:
	if not beard.last_error.is_empty(): stats.text = beard.last_error
	elif not beard.enabled: stats.text = "Beard is hidden; physics is idle."
	elif not beard._face_live: stats.text = "Waiting for a face. Try the mannequin to design offline."
	else: stats.text = "%d strands · %d segments\n%.2f ms physics + upload preparation" % [int(beard.config.strands), int(beard.config.strands)*int(beard.config.segments), beard.update_ms]
