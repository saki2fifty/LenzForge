extends Node
## Optional, bounded mask polling and quarter-size GPU background blur.
signal changed
signal status_changed
signal room_status_changed
const DEFAULTS := {"enabled":true,"blur":false,"blur_strength":20.0,"edge_softness":.12,"mask_rate":30,
	"page":0,"face_enabled":false,"skin_smoothing":.35,"skin_detail":.65,"face_brightness":0.0,"face_warmth":0.0,
	"blush":0.0,"blush_color":"df7890","lip_tint":0.0,"lip_color":"b84055",
	"mask_quality":"fast","person_confidence":.65,"edge_inset":.5,"room_cleanup":true,"room_tolerance":.10,
	"saturation":1.0,"contrast":1.0,"warmth":0.0,"vignette":0.0,"filter":0}
const RANGES := {"blur_strength":Vector2(2,48),"edge_softness":Vector2(.02,.3),
	"skin_smoothing":Vector2(0,1),"skin_detail":Vector2(0,1),"face_brightness":Vector2(-.15,.15),
	"face_warmth":Vector2(-.08,.08),"blush":Vector2(0,1),"lip_tint":Vector2(0,1),
	"person_confidence":Vector2(.3,.95),"edge_inset":Vector2(0,4),"room_tolerance":Vector2(.02,.35),
	"saturation":Vector2(0,2),"contrast":Vector2(.5,1.5),"warmth":Vector2(-.15,.15),"vignette":Vector2(0,1)}
var config := DEFAULTS.duplicate()
var host: Control
var detail := "Effects apply to camera video and virtual-camera output."
var request := HTTPRequest.new()
var stop_request := HTTPRequest.new()
var busy := false
var leased := false
var next_request := 0
var request_source := ""
var request_quality := "fast"
var source := ""
var mask: ImageTexture
var mask_stamp := 0
var mask_received := 0
var mask_ms := 0.0
var mask_ready := false
var viewport: SubViewport
var pass_rect: ColorRect
var pass_material := ShaderMaterial.new()
var input_viewport: SubViewport
var input_rect: ColorRect
var input_material := ShaderMaterial.new()
var last_y: ImageTexture
var last_uv: ImageTexture
var next_status := 0
var mask_viewport: SubViewport
var mask_rect: ColorRect
var mask_material := ShaderMaterial.new()
var room_reference: ImageTexture
var room_dimensions := Vector2i.ZERO
var room_detail := "For stubborn patches, learn the empty room. Keep the camera still."
var learn_until := 0
var learning := false
var learn_generation := 0
var facial: Node

func _room_status(text: String) -> void:
	if room_detail==text: return
	room_detail = text
	room_status_changed.emit()

func forget_room() -> void:
	learn_until = 0; learning = false; learn_generation += 1
	room_reference = null; room_dimensions = Vector2i.ZERO
	mask_material.set_shader_parameter("room_ready",false)
	mask_material.set_shader_parameter("room_reference",null)
	_room_status("Room reference cleared. Learn again after moving the camera or changing lighting.")

func learn_room() -> void:
	if learning or learn_until>0:
		learn_until = 0; learning = false; learn_generation += 1
		_room_status("Learning canceled."); return
	if not config.enabled or not config.blur or not mask_ready or not last_y or Time.get_ticks_msec()-host.last_video_at>500:
		_room_status("Start the camera and enable background blur first."); return
	learn_generation += 1
	learn_until = Time.get_ticks_msec()+5000
	_room_status("Step completely out of view. Capturing the empty room in 5 seconds…")

func _capture_room() -> void:
	learning = true
	var generation := learn_generation
	var dimensions := Vector2i(last_y.get_width(),last_y.get_height())
	var capture := SubViewport.new()
	capture.disable_3d = true; capture.world_2d = World2D.new()
	capture.size = Vector2i(256,144); capture.gui_disable_input = true
	var rectangle := ColorRect.new()
	rectangle.size = Vector2(capture.size)
	var material := ShaderMaterial.new()
	material.shader = preload("res://effects/room_capture.gdshader")
	material.set_shader_parameter("y_texture",last_y); material.set_shader_parameter("uv_texture",last_uv)
	rectangle.material = material
	capture.add_child(rectangle); add_child(capture)
	capture.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if generation==learn_generation and config.enabled and config.blur and source==host.current_buffers.get("video",""):
		room_reference = ImageTexture.create_from_image(capture.get_texture().get_image())
		room_dimensions = dimensions
		mask_material.set_shader_parameter("room_reference",room_reference)
		mask_material.set_shader_parameter("room_ready",config.room_cleanup)
		learning = false
		_room_status("Room learned. You can return. Reference lasts for this camera session.")
	capture.queue_free()
	if generation==learn_generation: learning = false

func setup(studio: Control, saved: Variant) -> void:
	host = studio
	facial = preload("res://effects/face_effects.gd").new()
	add_child(facial); facial.setup(host)
	request.use_threads = true
	request.timeout = 3.0
	request.body_size_limit = 28+256*256
	stop_request.use_threads = true
	stop_request.timeout = 2.0
	add_child(request); add_child(stop_request)
	request.request_completed.connect(_received)
	if saved is Dictionary: set_config(saved)
	else: set_config({})

func set_config(values: Dictionary) -> void:
	var previous_quality: String = config.mask_quality
	for key in DEFAULTS:
		if not values.has(key): continue
		var value = values[key]
		if key in ["enabled","blur","room_cleanup","face_enabled"]:
			if value is bool: config[key] = value
		elif key in ["blush_color","lip_color"]:
			if value is String and Color.html_is_valid(value): config[key] = Color(value).to_html(false)
		elif key=="page":
			if (value is int or value is float) and is_finite(float(value)): config[key] = clampi(int(value),0,2)
		elif key == "mask_rate":
			if value in [15,30,60]: config[key] = int(value)
		elif key == "mask_quality":
			if value in ["fast","balanced"]: config[key] = value
		elif key == "filter":
			if (value is int or value is float) and is_finite(float(value)): config[key] = clampi(int(value),0,4)
		elif (value is int or value is float) and is_finite(float(value)):
			config[key] = clampf(float(value),RANGES[key].x,RANGES[key].y)
	if not host: return
	facial.configure(config)
	for key in ["saturation","contrast","warmth","vignette","filter"]:
		host.material_video.set_shader_parameter("fx_"+key,config[key] if config.enabled else DEFAULTS[key])
	host.material_video.set_shader_parameter("blur_strength",config.blur_strength)
	host.material_video.set_shader_parameter("edge_softness",config.edge_softness)
	pass_material.set_shader_parameter("blur_strength",config.blur_strength)
	input_material.set_shader_parameter("edge_softness",config.edge_softness)
	for key in ["edge_softness","person_confidence","edge_inset","room_tolerance"]:
		mask_material.set_shader_parameter(key,config[key])
	mask_material.set_shader_parameter("room_ready",config.room_cleanup and room_reference!=null)
	if config.mask_quality!=previous_quality:
		request.cancel_request(); busy = false; mask_stamp = 0
		_ready_mask(false)
	var wanted: bool = config.enabled and config.blur
	set_process(wanted)
	if not wanted: _release()
	else: next_request = 0
	changed.emit()

func _status(value: String) -> void:
	if value == detail: return
	detail = value
	status_changed.emit()

func _ready_mask(value: bool) -> void:
	if mask_ready == value: return
	mask_ready = value
	host.material_video.set_shader_parameter("background_ready",value)

func _fresh() -> bool:
	return mask_stamp>0 and absi(host.frame_timestamp-mask_stamp)<=150000 and Time.get_ticks_msec()-mask_received<250

func _release() -> void:
	request.cancel_request()
	busy = false
	mask_stamp = 0
	_ready_mask(false)
	if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if input_viewport: input_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if mask_viewport: mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# A cached room is valid only for its uninterrupted camera session.
	forget_room()
	if leased:
		stop_request.cancel_request()
		stop_request.request(host.backend_url+"/api/portrait/stop",[],HTTPClient.METHOD_POST)
	leased = false
	source = ""
	_status("Effects apply to camera video and virtual-camera output.")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if host.beard.mannequin or not host.online or host.last_video_at==0 or now-host.last_video_at>500:
		if leased or busy or mask_ready: _release()
		_status("Background blur is for the live camera." if host.beard.mannequin else "Start camera capture for background blur.")
		return
	var current: String = host.current_buffers.get("video","")
	if current != source:
		forget_room()
		request.cancel_request(); busy = false
		source = current; mask_stamp = 0; next_request = 0
		_ready_mask(false)
	if not _fresh(): _ready_mask(false)
	if learn_until>0:
		if now>=learn_until:
			learn_until = 0
			if last_y and mask_ready: _capture_room()
			else: _room_status("Could not capture a fresh camera frame. Try learning again.")
		else: _room_status("Step completely out of view. Capturing in %d seconds…"%ceili((learn_until-now)/1000.0))
	if busy or now<next_request or source.is_empty(): return
	request_source = source
	request_quality = config.mask_quality
	var error := request.request(host.backend_url+"/api/portrait/mask",["Content-Type: application/json"],HTTPClient.METHOD_POST,
		JSON.stringify({"source":source,"rate":config.mask_rate,"quality":config.mask_quality}))
	busy = error==OK
	leased = true
	# Poll at display cadence even when inference is capped lower. This reduces
	# transport delay without scheduling duplicate inference or queuing frames.
	next_request = now+16
	if error!=OK: next_request = now+1000

func _received(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if not config.enabled or not config.blur or request_source!=source or request_quality!=config.mask_quality: return
	if code!=200 or result!=HTTPRequest.RESULT_SUCCESS:
		var response = JSON.parse_string(body.get_string_from_utf8())
		var text := "Background blur needs the updated backend. Restart Start-Backend.ps1." if code==404 else "Waiting for background blur…"
		if response is Dictionary:
			text = str(response.get("error","")) if response.get("error","") else str(response.get("state",text))
		_status(text)
		next_request = Time.get_ticks_msec()+(250 if code==202 else 1000)
		return
	# An already-completing HTTP response must not cross a capture generation.
	var source_matches := false
	var quality_matches := false
	for header in headers:
		if header.to_lower().begins_with("x-lenzforge-source:"):
			source_matches = header.substr(header.find(":")+1).strip_edges()==source
		if header.to_lower().begins_with("x-lenzforge-mask-quality:"):
			quality_matches = header.substr(header.find(":")+1).strip_edges()==config.mask_quality
	if source_matches and quality_matches: accept_packet(body)
	elif source_matches: _status("Restart the backend to use the updated background controls.")

func accept_packet(body: PackedByteArray) -> bool:
	if body.size()<28 or body.slice(0,4).get_string_from_ascii()!="MSK1": return false
	var width := body.decode_u16(4); var height := body.decode_u16(6)
	var expected_height := 144 if config.mask_quality=="fast" else 256
	if width!=256 or height!=expected_height or body.size()!=28+width*height: return false
	var stamp := int(body.decode_u64(8))
	if stamp<=mask_stamp: return false
	mask_stamp = stamp
	mask_received = Time.get_ticks_msec()
	mask_ms = body.decode_float(24)
	var image := Image.create_from_data(width,height,false,Image.FORMAT_R8,body.slice(28))
	if mask and mask.get_height()==height: mask.update(image)
	else:
		mask = ImageTexture.create_from_image(image)
		mask_material.set_shader_parameter("raw_mask",mask)
	if mask_received>=next_status:
		next_status = mask_received+500
		_status("Background blur · %.1f ms person detection · up to %d masks/s"%[mask_ms,config.mask_rate])
	return true

func _make_pass() -> void:
	mask_viewport = SubViewport.new()
	mask_viewport.disable_3d = true; mask_viewport.world_2d = World2D.new()
	mask_viewport.gui_disable_input = true
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mask_viewport)
	mask_rect = ColorRect.new()
	mask_material.shader = preload("res://effects/refine_mask.gdshader")
	mask_material.set_shader_parameter("raw_mask",mask)
	for key in ["edge_softness","person_confidence","edge_inset","room_tolerance"]:
		mask_material.set_shader_parameter(key,config[key])
	mask_rect.material = mask_material
	mask_viewport.add_child(mask_rect)
	host.material_video.set_shader_parameter("person_mask",mask_viewport.get_texture())
	input_viewport = SubViewport.new()
	input_viewport.disable_3d = true
	input_viewport.world_2d = World2D.new()
	input_viewport.gui_disable_input = true
	input_viewport.transparent_bg = true
	input_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(input_viewport)
	input_rect = ColorRect.new()
	input_material.shader = preload("res://effects/background_downsample.gdshader")
	input_material.set_shader_parameter("person_mask",mask_viewport.get_texture())
	input_material.set_shader_parameter("edge_softness",config.edge_softness)
	input_rect.material = input_material
	input_viewport.add_child(input_rect)
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.gui_disable_input = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	pass_rect = ColorRect.new()
	pass_material.shader = preload("res://effects/background_blur.gdshader")
	pass_material.set_shader_parameter("background_small",input_viewport.get_texture())
	pass_material.set_shader_parameter("blur_strength",config.blur_strength)
	pass_rect.material = pass_material
	viewport.add_child(pass_rect)
	host.material_video.set_shader_parameter("background_horizontal",viewport.get_texture())

func frame(y: ImageTexture, uv: ImageTexture) -> void:
	facial.frame()
	if not config.enabled or not config.blur or host.beard.mannequin: return
	if not _fresh(): _ready_mask(false); return
	if not viewport: _make_pass()
	var mask_dimensions := Vector2i(mask.get_width(),mask.get_height())
	if mask_viewport.size!=mask_dimensions:
		mask_viewport.size = mask_dimensions; mask_rect.size = Vector2(mask_dimensions)
	if room_reference and room_dimensions!=Vector2i(y.get_width(),y.get_height()): forget_room()
	var dimensions := Vector2i(maxi(1,y.get_width()/4),maxi(1,y.get_height()/4))
	if viewport.size!=dimensions:
		viewport.size = dimensions
		pass_rect.size = Vector2(dimensions)
		input_viewport.size = dimensions
		input_rect.size = Vector2(dimensions)
	if y!=last_y or uv!=last_uv:
		last_y = y; last_uv = uv
		input_material.set_shader_parameter("y_texture",y)
		input_material.set_shader_parameter("uv_texture",uv)
		mask_material.set_shader_parameter("y_texture",y)
		mask_material.set_shader_parameter("uv_texture",uv)
		pass_material.set_shader_parameter("source_size",Vector2(y.get_width(),y.get_height()))
	input_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_ready_mask(true)

func _exit_tree() -> void:
	# The backend's short lease also stops inference after abrupt viewer exits.
	request.cancel_request()
