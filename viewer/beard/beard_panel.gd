extends VBoxContainer
const SceneRefs = preload("res://ui/scene_refs.gd")
var ui_actions: Dictionary = {}
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
var select_check: CheckBox
var selected_label: Label
var stats: Label
var selected_group: VBoxContainer
var import_dialog: FileDialog
var export_dialog: FileDialog
var delete_dialog: ConfirmationDialog
var _syncing := false
var pages: Dictionary = {}
var page_picker: OptionButton
var anchor_picker: OptionButton

func setup(layer: Control, studio: Control) -> void:
	beard = layer
	host = studio
	SceneRefs.bind(self)
	enabled_check.toggled.connect(func(value): beard.set_enabled(value))
	mannequin_check.toggled.connect(func(value): beard.set_mannequin(value))
	page_picker.item_selected.connect(func(index): show_page(page_picker.get_item_text(index)))
	for key in controls: _connect_control(key, controls[key])
	for key in control_copies:
		for control in control_copies[key]: _connect_control(key, control)
	for key in strand_controls: _connect_control(key, strand_controls[key], true)
	SceneRefs.action(self,"Apply beard preset",_create)
	SceneRefs.action(self,"Regrow roots",func(): beard.set_setting("seed",randi_range(0,2147483647)))
	SceneRefs.action(self,"Fuller coverage",func():
		beard.set_settings({"strands":maxi(512,int(beard.config.strands)),"beard_virtual_roots":true,"lower_root_depth":.35,"beard_sideburns":true,"sideburn_rise":.35,"sideburn_width":.06,"chin_extension":.1,"jaw_expansion":.08,"ear_reach":.08,"sideburn_height":.8,"coverage_fill":.6})
		beard.set_enabled(true))
	SceneRefs.action(self,"Reset coverage",func(): beard.set_settings({"beard_virtual_roots":true,"lower_root_depth":.35,"beard_sideburns":true,"sideburn_rise":.35,"sideburn_width":.06,"chin_extension":0.0,"jaw_expansion":0.0,"ear_reach":0.0,"sideburn_height":0.0}))
	SceneRefs.action(self,"Fit root surface…",func(): show_page("Root surface"))
	SceneRefs.action(self,"Show shared landmarks…",func(): host.sidebar_tabs.current_tab = 1)
	SceneRefs.action(self,"Extend root coverage",func():
		beard.set_settings(Groom.virtual_preset())
		beard.set_enabled(true))
	SceneRefs.action(self,"Reset motion",func():
		if beard.simulator: beard.simulator.reset())
	select_check.toggled.connect(func(value): beard.set_edit_strands(value))
	anchor_picker.get_popup().about_to_popup.connect(_fill_anchors)
	anchor_picker.item_selected.connect(func(index):
		var id: String = anchor_picker.get_item_metadata(index)
		if not id.is_empty(): beard.set_strand_setting("anchor",id))
	SceneRefs.action(self,"Restore root placement",func():
		var id: String = beard.selected_key()
		if beard.overrides.has(id):
			beard.overrides[id].erase("anchor")
			beard._rebuild()
			beard.changed.emit())
	SceneRefs.action(self,"Restore strand defaults",func(): beard.reset_selected())
	SceneRefs.action(self,"Hide this strand",func(): beard.set_strand_setting("length",0.0))
	name_field.text_changed.connect(func(value): beard.model_name = value if not value.strip_edges().is_empty() else "My look")
	SceneRefs.action(self,"Load",_load_selected)
	SceneRefs.action(self,"Save",_save)
	SceneRefs.action(self,"Copy",_save_copy)
	SceneRefs.action(self,"Import",func(): import_dialog.popup_centered_ratio(.7))
	SceneRefs.action(self,"Export",_export)
	SceneRefs.action(self,"Delete",_ask_delete)
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

func _connect_control(key: String, control: Control, individual := false) -> void:
	if control is CheckBox:
		control.toggled.connect(func(value):
			if _syncing: return
			beard.set_setting(key,value)
			if value and key in ["beard_visible","mustache_enabled","brow_enabled","virtual_enabled"]: beard.set_enabled(true))
	elif control is OptionButton:
		control.item_selected.connect(func(index):
			if _syncing: return
			var value: String = Groom.ENUMS[key][index]
			if key == "hair_style":
				beard.set_settings(Groom.hair_preset(value))
				if value != "None": beard.set_enabled(true)
			elif key == "mustache_style":
				beard.set_settings({"mustache_style":value,"mustache_motion":"Free" if value == "Natural" else "Styled"})
			else: beard.set_setting(key,value))
	elif control is ColorPickerButton:
		control.color_changed.connect(func(color):
			if _syncing: return
			if individual: beard.set_strand_setting(key,color.to_html())
			else: beard.set_setting(key,color.to_html()))
	else:
		control.value_changed.connect(func(value):
			if _syncing: return
			if individual: beard.set_strand_setting(key,value)
			else: beard.set_setting(key,int(value) if key in ["strands","segments"] or key in Groom.INTEGERS else value))

func show_page(title: String) -> void:
	for key in pages: pages[key].visible = key == title
	for i in page_picker.item_count:
		if page_picker.get_item_text(i) == title: page_picker.select(i)

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
	for key in ["hair_sweep","hair_part","hair_sides"]: controls[key].get_parent().visible = beard.config.hair_style=="Regular"
	controls.hawk_width.get_parent().visible = beard.config.hair_style=="Mohawk"
	controls.hair_frizz.get_parent().visible = beard.config.hair_style=="Afro"
	controls.hair_curl.get_parent().visible = beard.config.hair_style in ["Regular","Afro"]
	for key in control_copies:
		for control in control_copies[key]: control.set_value_no_signal(beard.config[key])
	controls.lower_root_depth.editable = beard.config.beard_virtual_roots
	controls.beard_sideburns.disabled = not beard.config.beard_virtual_roots or beard.config.style not in ["Full beard","Sideburns"]
	for key in ["sideburn_rise","sideburn_width"]:
		controls[key].editable = not controls.beard_sideburns.disabled and beard.config.beard_sideburns
	for key in ["chin_extension","jaw_expansion","ear_reach","sideburn_height","chin_back","side_back"]:
		controls[key].editable = not beard.config.beard_virtual_roots
		for control in control_copies.get(key,[]): control.editable = not beard.config.beard_virtual_roots
	selected_group.visible = beard.selected_strand >= 0
	selected_label.text = "%s · %s" % [beard.attachment[beard.selected_strand].zone,beard.selected_key()] if beard.selected_strand >= 0 else "Click a strand root to edit it."
	var edit: Dictionary = beard.overrides.get(beard.selected_key(), {})
	anchor_picker.clear()
	anchor_picker.add_item(edit.get("anchor","Automatic surface placement"))
	anchor_picker.set_item_metadata(0,edit.get("anchor",""))
	var regional: Dictionary = beard.selected_defaults()
	for key in strand_controls:
		var value = edit.get(key, 1.0 if key == "length" else regional[key])
		if key.ends_with("color"): strand_controls[key].color = Color.html(value)
		else: strand_controls[key].set_value_no_signal(value)
	_syncing = false
	_update_stats()

func _fill_anchors() -> void:
	var current: String = beard.overrides.get(beard.selected_key(),{}).get("anchor","")
	anchor_picker.clear()
	anchor_picker.add_item("Choose a landmark…")
	anchor_picker.set_item_metadata(0,"")
	anchor_picker.set_item_disabled(0,true)
	var ids := PackedStringArray()
	for i in 478:
		ids.append("face:%d"%i)
		anchor_picker.add_item("Measured %d"%i)
	if beard.extension_model != null:
		for i in beard.extension_model.ids.size():
			ids.append(beard.extension_model.ids[i])
			anchor_picker.add_item("Virtual %d · row %d"%[i%int(beard.extension_model.config.columns)+1,i/int(beard.extension_model.config.columns)+1])
	if not current.is_empty() and not current in ids:
		ids.append(current)
		anchor_picker.add_item("Saved virtual anchor")
	for i in ids.size():
		anchor_picker.set_item_metadata(i+1,ids[i])
		if ids[i] == current: anchor_picker.select(i+1)

func _create() -> void:
	var chosen: String = Profile.STYLES[style.selected]
	var updated := Profile.defaults(chosen)
	for key in beard.config:
		if key.begins_with("hair_") or key.begins_with("brow_") or key.begins_with("mustache_") or key.begins_with("virtual_") or key.begins_with("crown_") or key in ["hawk_width","side_back","chin_back","show_virtual_landmarks"]: updated[key] = beard.config[key]
	if chosen == "Mustache": updated.mustache_enabled = true
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
	host.queue_settings_save()
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
		host.queue_settings_save()
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
	else:
		stats.text = "%d / 1280 facial strands · %d segments\n%.2f ms physics + upload preparation" % [beard.attachment.size(), beard.attachment.size()*int(beard.config.segments), beard.update_ms]
		if beard.config.hair_style!="None": stats.text += "\n%s · 3D hair object"%beard.config.hair_style
