extends SceneTree
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(OS.has_environment("LENZFORGE_SETTINGS_DIR"), "Persistence test requires an isolated settings directory")
	var studio = load("res://studio.tscn").instantiate()
	studio.backend_url = "http://127.0.0.1:1"
	root.add_child(studio)
	var cameras := [{"index":2,"name":"Test camera","device_id":"stable-test-device"}]
	studio._set_camera_choices(cameras)
	var write := OS.get_cmdline_user_args().has("write")
	if write:
		studio.source_picker.select(1)
		studio.source_picker.item_selected.emit(1)
		studio.resolution_picker.select(2)
		studio.fps_picker.select(0)
		studio.exposure_slider.value = .17
		studio.preset_picker.select(2)
		studio.preset_picker.item_selected.emit(2)
		studio.point_slider.value = 3.25
		studio.point_color.color = Color("c345ab")
		studio.point_color.color_changed.emit(studio.point_color.color)
		studio.mirror_check.button_pressed = false
		studio.pacing_picker.select(2)
		studio.pacing_picker.item_selected.emit(2)
		studio.points_check.button_pressed = false
		studio.quick_toolbar.buttons.landmarks.button_pressed = false
		studio.beard.set_setting("length", .63)
		studio.beard.set_setting("gravity", 4.1)
		studio.beard.set_setting("wind", 0.0)
		studio.beard.set_settings({"mustache_gravity":2.7,"mustache_wind":-1.5,"mustache_turbulence":.3,
			"mustache_damping":.12,"mustache_variation":.32,"mustache_collisions":false,"lower_root_depth":.4,
			"beard_sideburns":false,"sideburn_rise":.65,"sideburn_width":.09})
		studio.beard.set_enabled(true)
		studio.beard.set_mannequin(true)
		studio.beard.selected_strand = 0
		studio.beard.set_strand_setting("curl", .37)
		studio.beard.set_strand_setting("anchor", "virtual:1000:250000:250000")
		studio.beard.mannequin_view.set_pose(35,-12,1.2)
		studio.beard_panel.select_check.button_pressed = true
		studio.beard_panel.name_field.text = "Persistence look"
		studio.beard_panel.name_field.text_changed.emit("Persistence look")
		studio.extensions.set_settings({"vertical_offset":-.23, "top":.61})
		var profile := {"version":2,"depth":.81,"crown":.29,"sides":1.14,"jaw":1.08,"views":5,"crown_observed":true,"reference":[]}
		var neutral := preload("res://tracking/head_surface.gd").canonical_points()
		var center := (neutral[234]+neutral[454])*.5
		var width := neutral[234].distance_to(neutral[454])
		neutral[10].y -= .5
		for p in neutral:
			var q: Vector3 = (p-center)/width
			profile.reference.append([q.x,q.y,q.z])
		studio.apply_calibration(profile)
		studio.occlusion.enabled = false
		studio.sidebar_tabs.current_tab = 3
		studio.tracking_panel.controls.backend.select(1)
		studio.tracking_panel.controls.backend.item_selected.emit(1)
		studio.tracking_panel.controls.detection_confidence.value = 0
		studio.tracking_panel.controls.blendshapes.button_pressed = false
		studio.tracking_panel.accept_config({"pose_model":"custom_pose_test"},-1)
		studio.tracking_panel._edited()
		studio.tracking_checks.hands.button_pressed = true
		await create_timer(.8).timeout
		var disk := ConfigFile.new()
		check(disk.load(studio.settings_path) == OK, "Changes must reach disk while the window is still open")
		check(is_equal_approx(disk.get_value("view","exposure",0),.17), "Exposure must autosave without closing")
		check(disk.get_value("backend","pending",{}).has("/api/tracking/configure"), "Offline edits need a durable queue")
		check(disk.get_value("beard","document",{}).get("name") == "Persistence look", "The complete look must autosave")
	else:
		check(studio.source_picker.selected == 1, "Restore the camera by stable device ID")
		check(studio.resolution_picker.selected == 2 and studio.fps_picker.selected == 0, "Restore capture format")
		check(is_equal_approx(studio.exposure_slider.value,.17), "Restore exposure slider")
		check(is_equal_approx(studio.material_video.get_shader_parameter("exposure"),.17), "Apply restored exposure to shader")
		check(studio.preset_picker.selected == 2, "Restore appearance preset")
		check(not studio.mirror_check.button_pressed and not studio.points_check.button_pressed, "Restore false toggles")
		check(studio.pacing_picker.selected == 2 and Engine.max_fps == 60,"Restore preview pacing")
		check(not studio.quick_toolbar.buttons.landmarks.button_pressed and not studio.overlay.guides_visible and not studio.beard.guides_visible,"Restore the toolbar's master guide visibility")
		check(studio.overlay.tint == Color("c345ab") and studio.overlay.point_size == 3.25, "Restore landmark color and size")
		check(studio.beard.enabled and studio.beard.mannequin and studio.beard.edit_strands, "Restore hair/mannequin/edit toggles")
		check(studio.beard_panel.select_check.button_pressed, "Restored strand toggle must match behavior")
		check(is_equal_approx(studio.beard.config.length,.63) and is_equal_approx(studio.beard.config.gravity,4.1), "Restore hair and physics settings")
		for key in {"mustache_gravity":2.7,"mustache_wind":-1.5,"mustache_turbulence":.3,"mustache_damping":.12,"mustache_variation":.32,"lower_root_depth":.4}:
			check(is_equal_approx(studio.beard.config[key],{"mustache_gravity":2.7,"mustache_wind":-1.5,"mustache_turbulence":.3,"mustache_damping":.12,"mustache_variation":.32,"lower_root_depth":.4}[key]),"Restore independent setting "+key)
		check(not studio.beard.config.mustache_collisions,"Restore independent mustache collision")
		check(not studio.beard.config.beard_sideburns and is_equal_approx(studio.beard.config.sideburn_rise,.65) and is_equal_approx(studio.beard.config.sideburn_width,.09),"Restore sideburn settings")
		check(studio.beard.model_name == "Persistence look", "Restore working look name")
		check(not studio.beard.overrides.is_empty() and is_equal_approx(studio.beard.overrides.values()[0].curl,.37), "Restore individual strand edits")
		check(studio.beard.overrides.get("0",{}).get("anchor","") == "virtual:1000:250000:250000", "Restore virtual attachment after restarting the app")
		check(is_equal_approx(studio.beard.mannequin_view.yaw,35) and is_equal_approx(studio.beard.mannequin_view.zoom,1.2), "Restore 3D mannequin pose")
		check(is_equal_approx(studio.extensions.model.config.vertical_offset,-.23) and is_equal_approx(studio.extensions.model.config.top,.61), "Restore virtual landmark shape")
		check(not studio.occlusion.enabled and is_equal_approx(studio.occlusion.head_depth,.81) and is_equal_approx(studio.occlusion.crown,.29), "Restore visibility settings")
		check(is_equal_approx(studio.occlusion.surface.sides,1.14) and is_equal_approx(studio.occlusion.surface.jaw,1.08) and studio.calibration_profile.views==5,"Restore calibrated surface across processes")
		var personal: PackedVector3Array = studio.occlusion.surface.personal_reference
		check(personal.size()==478 and studio.calibration_profile.crown_observed,"Restore neutral reference and crown evidence")
		check(absf(personal[10].y-preload("res://tracking/head_surface.gd").canonical_points()[10].y+.5)<.0001,"Personal geometry survives restart")
		check(studio.beard.mannequin_view.surface.personal_reference==personal,"Mannequin uses restored personal reference")
		check(studio.beard.mannequin_view.reference[10].distance_to(personal[10]*Vector3(1,-1,-1))<.0001,"Mannequin dots match the fitted face")
		check(studio.sidebar_tabs.current_tab == 3, "Restore active panel")
		var config: Dictionary = studio.tracking_panel.values()
		check(config.backend == "gpu" and config.detection_confidence == 0 and not config.blendshapes, "Restore offline MediaPipe edits")
		check(config.pose_model == "custom_pose_test", "Restore custom model selection before catalog arrives")
		check(studio.tracking_checks.hands.button_pressed, "Restore pending feature toggles")
	print("STUDIO_SETTINGS ", "write" if write else "read", " failures=", failures)
	quit(0 if failures.is_empty() else 1)
