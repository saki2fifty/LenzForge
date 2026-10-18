extends SceneTree
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func authored_count(node: Node, owner_node: Node) -> int:
	var count := int(node.owner == owner_node)
	for child in node.get_children(): count += authored_count(child, owner_node)
	return count

func _run() -> void:
	root.size = Vector2i(1440,900)
	var studio = load("res://studio.tscn").instantiate()
	var refs: Dictionary = studio.get_meta("scene_refs")
	var source: OptionButton = studio.get_node(refs.source_picker)
	var start: Button = studio.get_node(refs.ui_actions["Start capture"][0])
	var sidebar: PanelContainer = studio.get_node(refs.right_panel)
	var count := authored_count(studio, studio)
	check(count > 500, "Full layout exists before startup / without executing UI builders")
	check(studio.api_poll == null and studio.video_reader == null, "Loading the scene does not start capture or HTTP")
	start.text = "Scene-authored caption"
	sidebar.custom_minimum_size.x = 336
	var edited := PackedScene.new()
	check(edited.pack(studio) == OK, "Edited layout packs as an ordinary Godot scene")
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	await process_frame
	await process_frame
	check(studio.source_picker == source, "Startup binds the authored controls instead of rebuilding them")
	check(authored_count(studio, studio) == count, "Startup adds no duplicate authored controls")
	check(start.text == "Scene-authored caption", "Startup respects scene-authored button captions")
	check(is_equal_approx(sidebar.custom_minimum_size.x,336), "Responsive layout respects authored sidebar width")
	check(studio.tracking_panel.values().backend == "auto", "Tracking picker retains its semantic values")
	studio.effects_panel.ui_actions["Natural skin preset"][0].pressed.emit()
	check(studio.portrait_effects.config.face_enabled, "Authored facial-preset button is wired")
	studio.effects_panel.controls.skin_smoothing.value = .8
	check(is_equal_approx(studio.portrait_effects.config.skin_smoothing,.8), "Authored effect slider updates configuration")
	var gravity: float = studio.beard.config.gravity
	studio.beard_panel.controls.mustache_gravity.value = 6.7
	check(is_equal_approx(studio.beard.config.mustache_gravity,6.7) and is_equal_approx(studio.beard.config.gravity,gravity), "Authored mustache controls remain independent")
	studio.beard_panel.show_page("Root surface")
	studio.beard_panel.control_copies.chin_extension[0].value = .2
	check(is_equal_approx(studio.beard_panel.controls.chin_extension.value,.2), "Repeated controls stay synchronized")
	studio.beard_panel.controls.mustache_style.select(0)
	studio.beard_panel.controls.mustache_style.item_selected.emit(0)
	check(studio.beard.config.mustache_style == "Natural" and studio.beard.config.mustache_motion == "Free", "Saved option controls preserve preset behavior")
	studio.effects_panel.ui_actions["Reset effects"][0].pressed.emit()
	check(not studio.portrait_effects.config.face_enabled, "Reset button restores effect defaults")
	root.remove_child(studio)
	studio.free()
	var restored = edited.instantiate()
	restored.persist_settings = false
	restored.backend_url = "http://127.0.0.1:9"
	root.add_child(restored)
	await process_frame
	await process_frame
	check(restored.connect_button.text == "Scene-authored caption", "Caption survives scene save/reload and startup")
	check(is_equal_approx(restored.right_panel.custom_minimum_size.x,336), "Panel width survives scene save/reload")
	print("AUTHORED_LAYOUT nodes=",count," failures=",failures)
	quit(0 if failures.is_empty() else 1)
