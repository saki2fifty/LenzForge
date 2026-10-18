extends SceneTree
class FaceMode extends RefCounted:
	var mannequin := false
class Host extends Control:
	var material_video := ShaderMaterial.new()
	var beard := FaceMode.new()
	var frame_timestamp := 1000000
	var backend_url := "http://127.0.0.1:9"
	var online := false
	var last_video_at := 0
	var current_buffers := {}
var failures: Array[String] = []
func check(value: bool, detail: String) -> void:
	if not value: failures.append(detail)
func _initialize() -> void: _run.call_deferred()
func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func texture(width: int, height: int, channels: int) -> ImageTexture:
	var bytes := PackedByteArray(); bytes.resize(width*height*channels)
	for y in height:
		for x in width:
			for c in channels: bytes[(y*width+x)*channels+c] = 128 if channels==2 else 32 if x%8<4 else 220
	return ImageTexture.create_from_image(Image.create_from_data(width,height,false,Image.FORMAT_RG8 if channels==2 else Image.FORMAT_R8,bytes))
func variation(image: Image, region: Rect2i) -> float:
	var sum := 0.0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x-1): sum += absf(image.get_pixel(x,y).r-image.get_pixel(x+1,y).r)
	return sum/(region.size.x*region.size.y)
func _run() -> void:
	root.size = Vector2i(400,224)
	var host := Host.new(); root.add_child(host)
	host.material_video.shader = preload("res://video.gdshader")
	host.material_video.set_shader_parameter("mirror",false)
	var picture := ColorRect.new(); picture.size=Vector2(400,224); picture.material=host.material_video
	host.add_child(picture)
	var controller := preload("res://effects/portrait_effects.gd").new()
	host.add_child(controller); controller.setup(host,{})
	var y := texture(400,224,1); var uv := texture(200,112,2)
	host.material_video.set_shader_parameter("y_texture",y); host.material_video.set_shader_parameter("uv_texture",uv)
	await frame()
	var baseline := root.get_texture().get_image()
	controller.set_config({"blur":true,"blur_strength":36.0})
	controller.set_process(false)
	var packet := PackedByteArray(); packet.resize(28+256*144)
	packet.encode_u32(0,0x314b534d); packet.encode_u16(4,256); packet.encode_u16(6,144)
	packet.encode_u64(8,host.frame_timestamp); packet.encode_u64(16,1); packet.encode_float(24,4.5)
	for row in 144:
		for x in 256: packet[28+row*256+x] = 255 if x<100 else 0
	check(controller.accept_packet(packet),"Accept a valid current foreground mask")
	check(not controller.accept_packet(packet),"Ignore duplicate/stale mask timestamps")
	check(not controller.accept_packet(PackedByteArray([1,2,3])),"Reject malformed masks")
	controller.frame(y,uv)
	await frame()
	var blurred := root.get_texture().get_image()
	blurred.save_png(ProjectSettings.globalize_path("res://../artifacts/effects-isolation.png"))
	var subject := Rect2i(24,40,96,100); var background := Rect2i(220,40,120,100)
	check(variation(blurred,subject)>.95*variation(baseline,subject),"Foreground stays sharp")
	check(variation(blurred,background)<.3*variation(baseline,background),"Background detail is blurred")
	var output := SubViewport.new()
	output.disable_3d = true; output.size = root.size
	output.world_2d = host.get_viewport().world_2d
	output.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(output)
	await frame()
	var composed := output.get_texture().get_image()
	check(variation(composed,background)<.3*variation(baseline,background),"Shared-world virtual-camera composition includes blur")
	output.queue_free()
	host.material_video.set_shader_parameter("mirror",true)
	controller.frame(y,uv); await frame()
	var mirrored := root.get_texture().get_image()
	check(variation(mirrored,Rect2i(280,40,96,100))>.95*variation(baseline,subject),"Mirror keeps person mask aligned")
	check(variation(mirrored,Rect2i(60,40,120,100))<.3*variation(baseline,background),"Mirrored background stays blurred")
	host.material_video.set_shader_parameter("mirror",false)
	# Simulate a highly confident false-positive wall: a threshold cannot fix it.
	host.frame_timestamp += 1000; packet.encode_u64(8,host.frame_timestamp)
	for i in range(28,packet.size()): packet[i] = 255
	controller.accept_packet(packet); controller.frame(y,uv); await frame()
	check(variation(root.get_texture().get_image(),background)>.9*variation(baseline,background),"Fixture reproduces a clear background patch")
	await controller._capture_room()
	check(controller.room_reference!=null,"Learn empty room with a single GPU readback")
	var person_image := y.get_image()
	for row in 224:
		for x in range(20,130): person_image.set_pixel(x,row,Color((144.0 if x%8<4 else 235.0)/255.0,0,0,1))
	y.update(person_image)
	controller.mask_received = Time.get_ticks_msec()
	controller.frame(y,uv); await frame()
	var cleaned := root.get_texture().get_image()
	check(variation(cleaned,background)<.3*variation(baseline,background),"Learned wall stays blurred despite a fully confident false person mask")
	check(variation(cleaned,subject)>.075,"Person with changed colors remains sharp over the learned room")
	# Expose the wall again while keeping the exact same (stale) AI mask.
	y.update(texture(400,224,1).get_image())
	controller.mask_received = Time.get_ticks_msec()
	controller.frame(y,uv); await frame()
	check(variation(root.get_texture().get_image(),subject)<.3*variation(baseline,subject),"Newly exposed background blurs on the next video frame without waiting for inference")
	controller.set_config({"room_cleanup":false}); controller.set_process(false)
	controller.mask_received = Time.get_ticks_msec(); controller.frame(y,uv); await frame()
	check(variation(root.get_texture().get_image(),background)>.9*variation(baseline,background),"Room cleanup can be bypassed without deleting the reference")
	controller.forget_room()
	check(controller.room_reference==null,"Forget discards the session reference")
	# Uncertain patches and thin fringes can also be reduced without a reference.
	host.frame_timestamp += 1000; packet.encode_u64(8,host.frame_timestamp)
	for row in 144:
		for x in 256: packet[28+row*256+x] = 255 if x<100 else 170
	controller.accept_packet(packet)
	controller.set_config({"person_confidence":.85}); controller.set_process(false)
	controller.frame(y,uv); await frame()
	check(variation(root.get_texture().get_image(),background)<.3*variation(baseline,background),"Higher confidence removes uncertain background patches")
	controller.set_config({"person_confidence":.65,"edge_inset":4.0}); controller.set_process(false)
	controller.mask_received = Time.get_ticks_msec(); controller.frame(y,uv); await frame()
	var refined := controller.mask_viewport.get_texture().get_image()
	check(refined.get_pixel(98,72).r<.8 and refined.get_pixel(90,72).r>.99,"Inset trims the outline while preserving its interior")
	host.last_video_at = Time.get_ticks_msec()
	controller.learn_room()
	check(controller.learn_until>0,"Empty-room capture provides a countdown")
	controller.learn_room()
	check(controller.learn_until==0,"Countdown can be canceled")
	controller._capture_room(); controller.forget_room(); await frame()
	check(controller.room_reference==null,"Canceling also discards an in-flight room capture")
	controller.set_config({"mask_quality":"balanced"}); controller.set_process(false)
	check(not controller.accept_packet(packet),"Reject old model dimensions after a quality change")
	packet.resize(28+256*256); packet.encode_u16(6,256)
	check(controller.accept_packet(packet) and controller.mask.get_height()==256,"Accept full square-model detail without truncation")
	host.frame_timestamp += 200000
	controller.frame(y,uv)
	check(not controller.mask_ready,"Old masks immediately restore sharp video")
	controller.set_config({"filter":2,"vignette":.7,"enabled":false})
	check(not controller.is_processing() and not controller.mask_ready,"Master off stops polling and blur")
	check(host.material_video.get_shader_parameter("fx_filter")==0,"Master off bypasses color effects")
	controller.set_config({"enabled":true,"blur":false,"filter":2,"vignette":0.0})
	await frame()
	var sepia := root.get_texture().get_image().get_pixel(24,100)
	check(sepia.r>sepia.g and sepia.g>sepia.b,"Sepia applies the warm color transform: %s"%sepia)
	controller.set_config({"filter":1})
	await frame()
	var mono := root.get_texture().get_image().get_pixel(20,100)
	check(absf(mono.r-mono.g)<.01 and absf(mono.r-mono.b)<.01,"Black and white removes chroma")
	print("EFFECTS_RENDER subject=",variation(blurred,subject)," background=",variation(blurred,background)," failures=",failures)
	quit(0 if failures.is_empty() else 1)
