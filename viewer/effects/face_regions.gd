extends Node2D
## Small anatomical mask in source-camera coordinates: red skin, blue lips.
const OVAL = preload("res://tracking/face_extensions.gd").OUTLINE
const EYE_LEFT := [263,249,390,373,374,380,381,382,362,398,384,385,386,387,388,466]
const EYE_RIGHT := [33,7,163,144,145,153,154,155,133,173,157,158,159,160,161,246]
const BROW_LEFT := [276,283,282,295,285,336,296,334,293,300]
const BROW_RIGHT := [46,53,52,65,55,107,66,105,63,70]
const LIP_OUTER := [61,146,91,181,84,17,314,405,321,375,291,409,270,269,267,0,37,39,40,185]
const LIP_INNER := [78,95,88,178,87,14,317,402,318,324,308,415,310,311,312,13,82,81,80,191]
var face := PackedVector2Array()
var dimensions := Vector2(512,288)

func _polygon(indices: Array, expansion: float, convex: bool) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var center := Vector2.ZERO
	for i in indices:
		var point := face[i]*dimensions
		polygon.append(point); center += point
	center /= polygon.size()
	if expansion!=1.0:
		for i in polygon.size(): polygon[i] = center+(polygon[i]-center)*expansion
	if convex:
		polygon = Geometry2D.convex_hull(polygon)
		if polygon.size()>1: polygon.resize(polygon.size()-1)
	return polygon

func _region(indices: Array, color: Color, expansion := 1.0, convex := true) -> void:
	var polygon := _polygon(indices,expansion,convex)
	# Closed eyelids/lips can become degenerate during blinking/speaking.
	if polygon.size()>=3 and not Geometry2D.triangulate_polygon(polygon).is_empty():
		draw_colored_polygon(polygon,color)

func _draw() -> void:
	if face.size()<468: return
	_region(OVAL,Color(1,0,0,1))
	for indices in [EYE_LEFT,EYE_RIGHT,BROW_LEFT,BROW_RIGHT]:
		_region(indices,Color.BLACK,1.25)
	_region(LIP_OUTER,Color.BLACK,1.15)
	_region(LIP_OUTER,Color(0,0,1,1),1.0,false)
	_region(LIP_INNER,Color.BLACK,1.04)
