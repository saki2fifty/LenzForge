extends Node
## Landmark-synchronized GPU effects. No extra inference, image copies or readback.
signal status_changed
var host: Control
var active := false
var face_ready := false
var stamp := 0
var received := 0
var viewport: SubViewport
var regions: Node2D
var detail := "Enable facial effects and Face tracking for the live camera."

func setup(studio: Control) -> void:
	host = studio
	set_process(false)

func _status(text: String) -> void:
	if detail==text: return
	detail = text; status_changed.emit()

func _ready_face(value: bool) -> void:
	if face_ready==value: return
	face_ready = value
	host.material_video.set_shader_parameter("face_ready",face_ready)

func configure(config: Dictionary) -> void:
	active = config.enabled and config.face_enabled
	for key in ["skin_smoothing","skin_detail","face_brightness","face_warmth","blush","lip_tint"]:
		host.material_video.set_shader_parameter("fx_"+key,config[key])
	for key in ["blush_color","lip_color"]:
		host.material_video.set_shader_parameter("fx_"+key,Color(config[key]))
	set_process(active)
	if not active:
		clear()
		_status("Enable facial effects and Face tracking for the live camera.")
	else: frame()

func clear() -> void:
	stamp = 0
	_ready_face(false)
	if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if active: _status("Waiting for a tracked face. Enable Face tracking in Capture.")

func frame() -> void:
	var fresh: bool = active and not host.beard.mannequin and stamp>0 and stamp==host.frame_timestamp and Time.get_ticks_msec()-received<250
	_ready_face(fresh)
	if not fresh and active:
		if host.beard.mannequin: _status("Facial effects use the live camera.")
		elif stamp==0 or Time.get_ticks_msec()-received>=250:
			# Video is presented immediately before its paired landmark callback.
			# Do not churn the status label/layout during that transient mismatch.
			_status("Waiting for a tracked face. Enable Face tracking in Capture.")

func _process(_delta: float) -> void: frame()

func set_face(points: PackedVector2Array, timestamp: int, frame_size: Vector2) -> void:
	if not active: return
	if host.beard.mannequin or points.size()<468 or timestamp!=host.frame_timestamp or not frame_size.is_finite() or frame_size.x<=0 or frame_size.y<=0:
		clear(); return
	for point in points:
		if not point.is_finite(): clear(); return
	var width := ((points[454]-points[234])*frame_size).length()
	if width<10 or (points[10]-points[152]).length()<.01:
		clear(); return
	if not viewport:
		viewport = SubViewport.new()
		viewport.disable_3d = true; viewport.world_2d = World2D.new()
		viewport.gui_disable_input = true
		viewport.transparent_bg = false
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		add_child(viewport)
		# Explicit black base avoids inheriting the app's tinted clear color.
		var background := ColorRect.new()
		background.color = Color.BLACK; background.size = Vector2(512,512)
		viewport.add_child(background)
		regions = preload("res://effects/face_regions.gd").new()
		viewport.add_child(regions)
		host.material_video.set_shader_parameter("face_mask",viewport.get_texture())
	viewport.size = Vector2i(512,clampi(roundi(512*frame_size.y/frame_size.x),128,512))
	regions.dimensions = Vector2(viewport.size)
	regions.face = points
	regions.queue_redraw()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var bounds := Rect2(points[10],Vector2.ZERO)
	for i in regions.OVAL: bounds = bounds.expand(points[i])
	bounds = bounds.grow(.01)
	host.material_video.set_shader_parameter("face_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
	host.material_video.set_shader_parameter("face_width",width)
	host.material_video.set_shader_parameter("face_right",((points[454]-points[234])*frame_size).normalized())
	host.material_video.set_shader_parameter("cheeks",Vector4(points[50].x,points[50].y,points[280].x,points[280].y))
	stamp = timestamp; received = Time.get_ticks_msec()
	_ready_face(true)
	_status("Face & skin active · uses the existing tracked face.")
