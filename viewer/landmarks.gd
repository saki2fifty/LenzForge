extends Control
## One instanced draw replaces hundreds of separately tessellated circles.
var points: PackedVector2Array = []
var mirror := true
var point_size := 2.0
var tint := Color("68dfc3")
var show_points := true
var video_size := Vector2(1280, 720)
var instances := MultiMesh.new()

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.mesh = quad
	var dots := ShaderMaterial.new()
	dots.shader = preload("res://landmarks.gdshader")
	material = dots
	resized.connect(queue_redraw)

func _draw() -> void:
	if not show_points or points.is_empty():
		return
	if instances.instance_count < points.size():
		instances.instance_count = points.size()
	instances.visible_instance_count = points.size()
	var scale_factor := minf(size.x / video_size.x, size.y / video_size.y)
	var fitted := video_size * scale_factor
	var origin := (size - fitted) * 0.5
	var diameter := point_size * 2.0
	for index in points.size():
		var point := points[index]
		var uv := Vector2(1.0 - point.x if mirror else point.x, point.y)
		instances.set_instance_transform_2d(index, Transform2D(
			Vector2(diameter, 0), Vector2(0, diameter), origin + uv * fitted))
	material.set_shader_parameter("point_color", tint)
	draw_multimesh(instances, null)
