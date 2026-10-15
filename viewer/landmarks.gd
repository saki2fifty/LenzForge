extends Control
## Geometry overlays scale with landmark count, not video pixels × landmark count.
var points: PackedVector2Array = []
var mirror := true
var point_size := 2.0
var tint := Color("68dfc3")
var show_points := true
var video_size := Vector2(1280, 720)

func _draw() -> void:
	if not show_points or points.is_empty():
		return
	var scale_factor := minf(size.x / video_size.x, size.y / video_size.y)
	var fitted := video_size * scale_factor
	var origin := (size - fitted) * 0.5
	for point in points:
		var uv := Vector2(1.0 - point.x if mirror else point.x, point.y)
		draw_circle(origin + uv * fitted, point_size, tint, true, -1, true)
