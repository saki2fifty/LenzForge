extends Node
## Shares the preview's canvas, not its physics/tracking. Only the output viewport
## is transferred at a bounded cadence while a camera client requests video.
## GL/D3D shared textures avoid readback when supported; CPU output is the fallback.
signal changed
const OUTPUT_SIZE := Vector2i(1280,720)
const PERIOD_US := 16667
var host: Control
var canvas: Control
var writer: RefCounted
var viewport: SubViewport
var active := false
var state := "Off"
var detail := "Send the composed preview to LenzForge Virtual Camera."
var stats: Dictionary = {}
var next_frame_us := 0
var scheduled := false
var readback_ms := 0.0

func setup(studio: Control, preview: Control) -> void:
	host = studio
	canvas = preview
	process_priority = 30
	set_process(false)
	# Cull siblings along the preview's ancestry. All content inside the preview
	# remains on layer 1; controls stay visible in the window on layer 2.
	var branch: Node = canvas
	while branch != host:
		for sibling in branch.get_parent().get_children():
			if sibling != branch and sibling is CanvasItem: sibling.visibility_layer = 2
		branch = branch.get_parent()
	host.beard.mannequin_toolbar.visibility_layer = 2
	host.beard.selection.visibility_layer = 2
	host.empty_state.get_parent().visibility_layer = 2
	RenderingServer.frame_post_draw.connect(_after_draw)
	if ClassDB.class_exists("VirtualCameraOutput"): writer = ClassDB.instantiate("VirtualCameraOutput")

func start() -> void:
	if active: return
	if not writer:
		_fail("Rebuild the native extension with Setup.ps1 -SkipInstall to enable virtual-camera output.")
		return
	if not host.beard.mannequin and (host.last_video_at == 0 or Time.get_ticks_msec()-host.last_video_at > 1500):
		_fail("Start camera capture or the 3D mannequin before enabling virtual-camera output.")
		return
	if not writer.start(ProjectSettings.globalize_path("res://gdextension/bin/LenzForgeCamera.dll")):
		_fail(writer.get_status().error)
		return
	active = true
	state = "Starting"
	detail = "Starting LenzForge Virtual Camera…"
	next_frame_us = 0
	set_process(true)
	changed.emit()

func stop() -> void:
	active = false
	scheduled = false
	set_process(false)
	if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if writer: writer.stop()
	state = "Off"
	detail = "Virtual camera stopped."
	changed.emit()

func _fail(reason: String) -> void:
	stop()
	state = "Unavailable"
	detail = reason
	host.message.text = reason
	changed.emit()

func _make_viewport() -> void:
	viewport = SubViewport.new()
	viewport.name = "VirtualCameraComposition"
	viewport.size = OUTPUT_SIZE
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.canvas_cull_mask = 1
	viewport.world_2d = host.get_viewport().world_2d
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)

func _process(_delta: float) -> void:
	stats = writer.get_status()
	if stats.state == 3:
		_fail(stats.error)
		return
	var desired := "Starting" if stats.state == 1 else "Live" if stats.consumer else "Ready"
	var transfer := "GPU shared textures" if stats.get("gpu_transfer",false) else "CPU transfer fallback"
	var desired_detail := "Sending composed video · 1280 × 720 · up to 60 fps · " + transfer if desired == "Live" else "Select LenzForge Windows Virtual Camera in your calling or recording app." if desired == "Ready" else "Starting LenzForge Virtual Camera…"
	if desired != state or desired_detail != detail:
		state = desired
		detail = desired_detail
		host.message.text = detail
		changed.emit()
	if stats.state != 2 or not stats.consumer: return
	var now := Time.get_ticks_usec()
	if now < next_frame_us: return
	# Carry fractional render intervals without accumulating a catch-up queue.
	next_frame_us = maxi(next_frame_us + PERIOD_US, now + 1000)
	if not viewport: _make_viewport()
	var dimensions: Vector2 = host.beard.video_size
	var fit := minf(canvas.size.x/dimensions.x,canvas.size.y/dimensions.y)
	var rect := Rect2(canvas.global_position + (canvas.size-dimensions*fit)*.5,dimensions*fit)
	if rect.size.x < 1 or rect.size.y < 1: return
	var output_fit := minf(OUTPUT_SIZE.x/rect.size.x,OUTPUT_SIZE.y/rect.size.y)
	var offset := (Vector2(OUTPUT_SIZE)-rect.size*output_fit)*.5 - rect.position*output_fit
	viewport.canvas_transform = Transform2D(Vector2(output_fit,0),Vector2(0,output_fit),offset)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	scheduled = true

func _after_draw() -> void:
	if not active or not scheduled: return
	scheduled = false
	# A stopped/disconnected source must never keep broadcasting its last face.
	if not host.beard.mannequin and (host.last_video_at == 0 or Time.get_ticks_msec()-host.last_video_at > 1500):
		_fail("Virtual camera stopped because the capture source stopped.")
		return
	var began := Time.get_ticks_usec()
	if writer.has_method("submit_texture") and RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# ViewportTexture exposes a proxy RID; GL's native handle belongs to the
		# renderer's actual viewport texture, not that proxy.
		var handle := RenderingServer.texture_get_native_handle(RenderingServer.viewport_get_texture(viewport.get_viewport_rid()))
		if writer.submit_texture(handle):
			readback_ms = float(Time.get_ticks_usec()-began)/1000.0
			return
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("The renderer could not read the virtual-camera output.")
		return
	if image.get_format() != Image.FORMAT_RGBA8: image.convert(Image.FORMAT_RGBA8)
	writer.submit(image)
	readback_ms = float(Time.get_ticks_usec()-began)/1000.0

func _exit_tree() -> void:
	if writer: writer.stop()
