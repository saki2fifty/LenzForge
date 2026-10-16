extends RefCounted
const Profile = preload("res://beard/beard_profile.gd")
var directory := "user://beards"

func _valid_id(id: String) -> bool:
	return not id.is_empty() and id.length() <= 80 and id.replace("-", "").is_valid_hex_number(false)

func list_models() -> Array:
	var result: Array = []
	if not DirAccess.dir_exists_absolute(directory): return result
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".json"): continue
		var id := file.trim_suffix(".json")
		if not _valid_id(id): continue
		var loaded := read_path(directory.path_join(file))
		if loaded.error.is_empty(): result.append({"id": id, "name": loaded.data.name})
	result.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	return result

func read_path(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "Could not open beard file.", "data": {}}
	if file.get_length() > 8 * 1024 * 1024: return {"error": "Beard file exceeds 8 MB.", "data": {}}
	var data = JSON.parse_string(file.get_as_text())
	var error := Profile.validate(data)
	return {"error": error, "data": data if error.is_empty() else {}}

func load_model(id: String) -> Dictionary:
	if not _valid_id(id): return {"error": "Invalid model ID.", "data": {}}
	return read_path(directory.path_join(id + ".json"))

func save_model(data: Dictionary, id := "") -> Dictionary:
	if id.is_empty(): id = "%x-%x" % [Time.get_ticks_usec(), randi()]
	if not _valid_id(id): return {"error": "Invalid model ID.", "id": ""}
	var error := write_path(directory.path_join(id + ".json"), data)
	return {"error": error, "id": id if error.is_empty() else ""}

func write_path(path: String, data: Dictionary) -> String:
	var error := Profile.validate(data)
	if not error.is_empty(): return error
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return "Could not create the beard folder."
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return "Could not write beard file."
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return "Writing the beard file failed."
	if DirAccess.rename_absolute(path + ".tmp", path) != OK: return "Could not replace the beard file."
	return ""

func delete_model(id: String) -> String:
	if not _valid_id(id): return "Invalid model ID."
	# Only named entries in this library can be deleted; imports are never removed.
	if DirAccess.remove_absolute(directory.path_join(id + ".json")) != OK: return "Could not delete beard."
	if FileAccess.file_exists(thumbnail_path(id)): DirAccess.remove_absolute(thumbnail_path(id))
	return ""

func thumbnail_path(id: String) -> String:
	return directory.path_join(id + ".png") if _valid_id(id) else ""
