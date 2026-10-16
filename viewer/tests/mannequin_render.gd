extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Extensions = preload("res://tracking/face_extensions.gd")
var failures: Array[String] = []

func check(value: bool, detail: String) -> void:
	if not value: failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func pink_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x,y)
			if c.r > .8 and c.g < .2 and c.b > .8: count += 1
	return count

func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	studio.extensions.set_settings(Extensions.defaults())
	studio.beard.apply_document(Profile.document("3D preview",Profile.defaults(),{}))
	studio.beard.set_enabled(false)
	studio.beard.set_mannequin(true)
	studio._set_points(true)
	studio.sidebar_tabs.current_tab = 1
	var view = studio.beard.mannequin_view
	for pose in [["front",0,0],["turned",40,-12],["side",90,0],["back",180,0]]:
		view.set_pose(pose[1],pose[2])
		await frame()
		await frame()
		check(studio.extensions.model.points.size() == 288,"Virtual landmarks survive %s view"%pose[0])
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/mannequin-%s.png"%pose[0]))
	# A dot in front of the forehead is visible; one behind the solid head is not.
	studio._set_points(false)
	studio.extensions.set_settings({"show_points":false})
	view.reset_view()
	view.set_dots("surface",PackedVector3Array([Vector3(0,4,12)]),Color.MAGENTA,5,true)
	await frame()
	var visible := pink_pixels(view.viewport.get_texture().get_image())
	view.set_dots("surface",PackedVector3Array([Vector3(0,4,-12)]),Color.MAGENTA,5,true)
	await frame()
	var hidden := pink_pixels(view.viewport.get_texture().get_image())
	check(visible > 40 and hidden == 0,"Landmarks are depth-tested against actual geometry")
	view.set_dots("surface",PackedVector3Array(),Color.WHITE,1,false)
	studio.beard.set_settings({"root_color":"ff00ffff","tip_color":"ff00ffff","mustache_color":"ff00ffff",
		"mustache_tip_color":"ff00ffff","show_generated_roots":false,"wind":0,"turbulence":0})
	studio.beard.set_enabled(true)
	for i in 60: studio.beard.simulator.advance(1.0/60)
	await frame()
	await frame()
	var hair_pixels := pink_pixels(view.viewport.get_texture().get_image())
	check(hair_pixels > 500,"Native strand buffer actually renders in the 3D viewport")
	studio.beard.set_settings({"strands":1024,"brow_enabled":true,"brow_count":256,"hair_style":"Afro","hair_count":768,"segments":16})
	await frame()
	check(view.hair.multimesh.instance_count == 32768 and view.hair_texture.get_size() == Vector2(256,512),"Maximum groom fits a bounded GPU texture")
	# Exercise the actual strand picker, including its virtual entries.
	studio.beard.selected_strand = 0
	studio.beard.strand_selected.emit(0)
	studio.beard_panel.show_page("Strands")
	studio.beard_panel._fill_anchors()
	var picker: OptionButton = studio.beard_panel.anchor_picker
	check(picker.item_count == 1+478+288,"Strand picker offers measured and virtual landmarks")
	picker.select(479)
	picker.item_selected.emit(479)
	check(studio.beard.overrides["0"].anchor == studio.extensions.model.ids[0],"Strand picker attaches to a displayed virtual landmark")
	var previous: PackedVector3Array = view.surface.vertices.duplicate()
	studio.occlusion.head_depth = .85
	studio.occlusion.crown = .32
	studio._refresh_occlusion()
	check(view.surface.vertices != previous,"Head shape controls update the rendered mannequin surface")
	var mesh: ArrayMesh = view.pivot.get_child(0).get_child(0).mesh
	var mesh_points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in mesh_points.size(): check(mesh_points[i].distance_to(view.surface.vertices[i]*Vector3(1,-1,-1)) < .00001,"Rendered head and attachment surface remain identical after resizing")
	studio.beard.set_enabled(false)
	await frame()
	await frame()
	check(pink_pixels(view.viewport.get_texture().get_image()) == 0,"Disabling hair removes the 3D batch")
	check(view.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"A stationary hairless head stops rendering after its requested frame")
	var y_texture := ImageTexture.create_from_image(Image.create(640,360,false,Image.FORMAT_R8))
	var uv_texture := ImageTexture.create_from_image(Image.create(320,180,false,Image.FORMAT_RG8))
	studio._on_video(y_texture,uv_texture,1,Time.get_ticks_usec())
	check(studio.overlay.video_size == view.FRAME,"Camera resolution changes cannot distort the mannequin")
	studio.beard.set_mannequin(false)
	check(not view.visible and not view.active,"Leaving preview hides the whole 3D scene")
	studio._on_video(y_texture,uv_texture,2,Time.get_ticks_usec())
	check(studio.overlay.video_size == Vector2(640,360),"Returning to the same camera texture restores its dimensions")
	print("MANNEQUIN_RENDER visible_dot=",visible," hidden_dot=",hidden," hair_pixels=",hair_pixels," failures=",failures)
	quit(0 if failures.is_empty() else 1)
