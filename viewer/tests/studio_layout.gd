extends SceneTree
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	studio.beard.set_enabled(false)
	studio.beard.set_mannequin(true)
	studio.tracking_panel.accept_config({"backend":"auto","max_width":640,"num_faces":1,
		"detection_confidence":.5,"presence_confidence":.5,"tracking_confidence":.5,
		"blendshapes":true,"face_transform":true}, 1)
	for dimensions in [Vector2i(1440,900),Vector2i(1200,800),Vector2i(960,640)]:
		root.size = dimensions
		for tab in studio.sidebar_tabs.get_tab_count():
			studio.sidebar_tabs.current_tab = tab
			await process_frame
			await process_frame
			await process_frame
			var box: Rect2 = studio.right_panel.get_global_rect()
			check(box.end.x <= dimensions.x, "Right panel fits %s tab %d: %s" % [dimensions,tab,box])
			check(box.end.y <= dimensions.y, "Right panel height fits %s" % dimensions)
			var scroll: ScrollContainer = studio.sidebar_tabs.get_tab_control(tab)
			check(not scroll.get_h_scroll_bar().visible, "No horizontal clipping at %s tab %d" % [dimensions,tab])
			if tab == 2:
				for page in studio.beard_panel.pages:
					studio.beard_panel.show_page(page)
					await process_frame
					await process_frame
					check(not scroll.get_h_scroll_bar().visible, "Hair page %s fits %s" % [page,dimensions])
			if "--render" in OS.get_cmdline_user_args() and tab == 3:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/tracking-panel-%d.png" % dimensions.x))
			if tab == 3:
				studio.tracking_panel.model_group.show()
				await process_frame
				await process_frame
				check(not scroll.get_h_scroll_bar().visible,"Expanded model library fits %s"%dimensions)
				studio.tracking_panel.model_group.hide()
	check(studio.tracking_panel.values().detection_confidence == .5,"Tracking controls round trip configuration")
	studio.tracking_panel.controls.detection_confidence.value = 0
	check(studio.tracking_panel.dirty and studio.tracking_panel.values().detection_confidence == 0,"Zero confidence is editable")
	studio.tracking_panel.update_status({"settings_revision":2,"settings":{"detection_confidence":.8}})
	check(studio.tracking_panel.values().detection_confidence == 0,"Polling preserves unsubmitted settings")
	print("STUDIO_LAYOUT failures=",failures)
	quit(0 if failures.is_empty() else 1)
