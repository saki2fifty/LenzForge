extends SceneTree
const Effects = preload("res://effects/portrait_effects.gd")
const Surface = preload("res://tracking/head_surface.gd")
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
var dimensions := Vector2(512,384)
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void: _run.call_deferred()
func frame() -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
func region_variation(picture: Image, mask: Image) -> float:
	var total := 0.0; var count := 0
	for y in range(1,picture.get_height()-1):
		for x in range(1,picture.get_width()-1):
			if mask.get_pixel(x,y).r<.99 or mask.get_pixel(x+1,y).r<.99: continue
			total += absf(picture.get_pixel(x,y).r-picture.get_pixel(x+1,y).r); count += 1
	return total/maxi(1,count)
func color_at(picture: Image, p: Vector2) -> Color:
	return picture.get_pixel(clampi(roundi(p.x*dimensions.x),0,511),clampi(roundi(p.y*dimensions.y),0,383))
func _run() -> void:
	root.size = Vector2i(dimensions)
	var host := Host.new(); root.add_child(host)
	host.material_video.shader = preload("res://video.gdshader")
	host.material_video.set_shader_parameter("mirror",false)
	var luma := PackedByteArray(); luma.resize(512*384)
	for y in 384:
		for x in 512: luma[y*512+x] = 118 if x%2==0 else 138
	var chroma := PackedByteArray(); chroma.resize(256*192*2); chroma.fill(128)
	host.material_video.set_shader_parameter("y_texture",ImageTexture.create_from_image(Image.create_from_data(512,384,false,Image.FORMAT_R8,luma)))
	host.material_video.set_shader_parameter("uv_texture",ImageTexture.create_from_image(Image.create_from_data(256,192,false,Image.FORMAT_RG8,chroma)))
	var rect := ColorRect.new(); rect.size = dimensions; rect.material = host.material_video; host.add_child(rect)
	var effects := Effects.new(); host.add_child(effects); effects.setup(host,{})
	await frame()
	var baseline := root.get_texture().get_image()
	check(not effects.facial.active and not effects.facial.viewport,"Default facial effects allocate no mask viewport")
	var points := PackedVector2Array()
	for p in Surface.canonical_points(): points.append(Vector2(p.x*14/512+.43,p.y*14/384+.5))
	# Open the fixture's mouth so lip color can be checked independently of teeth.
	for index in [14,87,178,88,95,317,402,318,324,17,84,181,91,146,314,405,321,375]: points[index].y += .035
	effects.set_config({"face_enabled":true,"skin_smoothing":.9,"skin_detail":.5})
	effects.facial.set_face(points,host.frame_timestamp,dimensions)
	await frame()
	var mask: Image = effects.facial.viewport.get_texture().get_image()
	var softened := root.get_texture().get_image()
	var before := region_variation(baseline,mask); var after := region_variation(softened,mask)
	check(after<before*.8,"Low-contrast skin texture is softened: %f / %f"%[after,before])
	for index in [159,386,105,334,13]:
		check(color_at(softened,points[index]).is_equal_approx(color_at(baseline,points[index])),"Protect eye/brow/mouth landmark %d"%index)
	check(softened.get_pixel(470,40)==baseline.get_pixel(470,40),"Background remains unchanged")
	check(not effects.is_processing() and not effects.leased,"Facial effects do not activate segmentation or HTTP polling")
	# The same material is consumed by the composed virtual-camera world.
	var output := SubViewport.new(); output.disable_3d = true; output.size = root.size
	output.world_2d = host.get_viewport().world_2d; output.render_target_update_mode = SubViewport.UPDATE_ONCE; host.add_child(output)
	effects.facial.set_face(points,host.frame_timestamp,dimensions); await frame()
	check(region_variation(output.get_texture().get_image(),mask)<before*.8,"Virtual-camera composition includes skin smoothing")
	output.queue_free()
	effects.set_config({"skin_smoothing":0.0,"face_brightness":.08,"face_warmth":.04})
	effects.facial.set_face(points,host.frame_timestamp,dimensions); await frame()
	var warm := root.get_texture().get_image()
	var cheek := color_at(warm,points[50])
	check(cheek.r>cheek.b+.04 and cheek.g>color_at(baseline,points[50]).g+.04,"Face brightness and warmth affect the cheek")
	check(warm.get_pixel(470,40)==baseline.get_pixel(470,40),"Facial color adjustments leave the background alone")
	effects.set_config({"face_brightness":0.0,"face_warmth":0.0,"blush":1.0,"lip_tint":1.0,"lip_color":"ff2040"})
	effects.facial.set_face(points,host.frame_timestamp,dimensions); await frame()
	var tinted := root.get_texture().get_image()
	cheek = color_at(tinted,points[50])
	check(cheek.r>cheek.g+.02,"Blush follows the cheek anchor")
	var lip := Vector2i.ZERO; var weight := 0.0
	for y in 384:
		for x in 512:
			if mask.get_pixel(x,y).b>weight: weight = mask.get_pixel(x,y).b; lip = Vector2i(x,y)
	var lip_color := tinted.get_pixelv(lip)
	check(weight>.5 and lip_color.r>lip_color.g+.1,"Lip tint is limited to the tracked lip ring")
	check(color_at(tinted,(points[13]+points[14])*.5).is_equal_approx(color_at(baseline,(points[13]+points[14])*.5)),"Lip tint does not color the mouth opening")
	host.material_video.set_shader_parameter("mirror",true)
	effects.facial.set_face(points,host.frame_timestamp,dimensions); await frame()
	var mirrored := root.get_texture().get_image()
	check(mirrored.get_pixel(511-lip.x,lip.y).r>mirrored.get_pixel(511-lip.x,lip.y).g+.1,"Mirror keeps lip tint attached")
	host.frame_timestamp += 1; effects.facial.frame()
	check(not effects.facial.face_ready,"Never apply facial effects to a mismatched camera frame")
	effects.facial.set_face(points,host.frame_timestamp,dimensions)
	effects.facial.received = Time.get_ticks_msec()-300; effects.facial.frame()
	check(not effects.facial.face_ready,"Lost tracking expires the face mask")
	effects.facial.set_face(points,host.frame_timestamp,dimensions)
	host.beard.mannequin = true; effects.facial.frame()
	check(not effects.facial.face_ready,"Mannequin bypasses live-camera facial effects")
	effects.set_config({"enabled":false})
	check(not effects.facial.is_processing() and not effects.facial.face_ready,"Master bypass stops facial work")
	print("FACE_EFFECTS_RENDER texture_before=",before," after=",after," failures=",failures)
	quit(0 if failures.is_empty() else 1)
