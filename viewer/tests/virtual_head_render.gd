extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Groom = preload("res://beard/groom_regions.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	studio.sidebar_tabs.current_tab = 1
	var config := Profile.defaults()
	config.merge(Groom.hair_preset("Mohawk"),true)
	studio.beard.apply_document(Profile.document("Extended head",config,{}))
	studio.beard.set_mannequin(true)
	studio.beard_panel.show_page("Virtual landmarks")
	for child in studio.beard_panel.pages["Virtual landmarks"].get_children():
		if child is Button and child.text == "Extend head coverage": child.pressed.emit()
	if not studio.beard.enabled or not studio.beard.config.virtual_enabled or studio.beard.virtual_points.size() != 380:
		failures.append("Extend head coverage button did not enable and fit the virtual grid")
	studio.beard.simulator.reset()
	for i in 60: studio.beard.simulator.advance(1.0/120)
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var orange := 0
	for y in screenshot.get_height():
		for x in screenshot.get_width():
			var c := screenshot.get_pixel(x,y)
			if c.r > .85 and c.g > .6 and c.g < .83 and c.b > .25 and c.b < .5: orange += 1
	if orange < 300: failures.append("Virtual landmarks did not render in their distinct orange color")
	var args := OS.get_cmdline_user_args()
	var suffix := args[0] if not args.is_empty() else ""
	screenshot.save_png(ProjectSettings.globalize_path("res://../artifacts/virtual-head%s.png"%suffix))
	studio.beard_panel.control_copies.chin_extension[0].value = .25
	if not is_equal_approx(float(studio.beard.config.chin_extension),.25) or not is_equal_approx(studio.beard_panel.controls.chin_extension.value,.25):
		failures.append("Shared chin controls did not synchronize between pages")
	var count: int = studio.beard.attachment.size()
	studio.beard_panel.controls.virtual_columns.value = 32
	studio.beard_panel.controls.virtual_rows.value = 8
	if studio.beard.virtual_points.size() != 900 or studio.beard.attachment.size() != count:
		failures.append("Virtual density controls changed the wrong budget")
	# Exercise the actual native-reader callback, which previously discarded Z.
	studio.beard.set_mannequin(false)
	var face := Profile.mannequin()
	var landmarks: Array = []
	for p in face: landmarks.append(Vector3(p.x,p.y,(p.x-.5)*.4))
	studio.frame_timestamp = Time.get_ticks_usec()
	studio._on_landmarks(landmarks,1,studio.frame_timestamp)
	if studio.beard.face_depth.size() != 478 or not is_equal_approx(studio.beard.face_depth[234],landmarks[234].z):
		failures.append("Studio did not forward existing landmark depth")
	studio.beard_panel.controls.show_virtual_landmarks.button_pressed = false
	if studio.beard.virtual_markers.visible: failures.append("Show virtual landmarks switch did not hide the grid")
	studio.beard_panel.controls.virtual_enabled.button_pressed = false
	if not studio.beard.virtual_anchors.is_empty(): failures.append("Disabling virtual fitting retained virtual bindings")
	print("VIRTUAL_HEAD_RENDER orange_pixels=",orange," failures=",failures)
	quit(0 if failures.is_empty() else 1)
