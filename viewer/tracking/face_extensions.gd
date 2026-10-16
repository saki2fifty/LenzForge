extends RefCounted
## General virtual landmarks; independent of hair, tracking IDs, and rendering.
const FaceFrame = preload("res://tracking/face_frame.gd")
# MediaPipe FACE_LANDMARKS_FACE_OVAL, clockwise from the forehead.
const OUTLINE := [10,338,297,332,284,251,389,356,454,323,361,288,397,365,379,378,400,377,
	152,148,176,149,150,136,172,58,132,93,234,127,162,21,54,103,67,109]
const LIMITS := {"top":[0,1.5],"bottom":[0,1.5],"left":[0,1.5],"right":[0,1.5],
	"depth":[-1,1],"columns":[36,144],"rings":[1,12],"point_size":[1,6]}
var config := defaults()
var ids := PackedStringArray()
var source_a := PackedInt32Array()
var source_b := PackedInt32Array()
var weights := PackedFloat32Array()
var offsets := PackedVector3Array()
var points := PackedVector2Array()

static func defaults() -> Dictionary:
	return {"enabled":true,"show_points":true,"top":.42,"bottom":.2,"left":.18,"right":.18,
		"depth":.15,"columns":72,"rings":4,"point_size":2.5,"color":"ffbf69ff"}

static func validate(values: Dictionary) -> bool:
	for key in values:
		var value = values[key]
		if key in LIMITS:
			if not (value is float or value is int) or not is_finite(float(value)): return false
			if value < LIMITS[key][0] or value > LIMITS[key][1]: return false
			if key in ["columns","rings"] and float(value) != floorf(value): return false
		elif key in ["enabled","show_points"]:
			if not value is bool: return false
		elif key == "color":
			if not value is String or not Color.html_is_valid(value): return false
		else: return false
	return true

func _init() -> void:
	_rebuild()

func configure(values: Dictionary) -> bool:
	if not validate(values): return false
	var rebuild := false
	for key in values:
		if key in ["top","bottom","left","right","depth","columns","rings"] and values[key] != config[key]: rebuild = true
	config.merge(values,true)
	config.columns = int(config.columns)
	config.rings = int(config.rings)
	if rebuild: _rebuild()
	return true

func _rebuild() -> void:
	ids.clear(); source_a.clear(); source_b.clear(); weights.clear(); offsets.clear()
	for ring in range(1,int(config.rings)+1):
		var v := float(ring)/int(config.rings)
		for column in int(config.columns):
			var along := float(column)*OUTLINE.size()/int(config.columns)
			var edge := int(along)
			# Align cardinal directions to forehead, cheek sides, and chin.
			var quarter := along/8 if along < 8 else 1+(along-8)/10 if along < 18 else 2+(along-18)/10 if along < 28 else 3+(along-28)/8
			var direction := Vector2(sin(quarter*PI*.5),-cos(quarter*PI*.5))
			ids.append("extension:%d:%d"%[ring,column])
			source_a.append(OUTLINE[edge])
			source_b.append(OUTLINE[(edge+1)%OUTLINE.size()])
			weights.append(along-edge)
			offsets.append(Vector3(direction.x*float(config.left if direction.x < 0 else config.right),
				direction.y*float(config.top if direction.y < 0 else config.bottom),float(config.depth))*v)

func update(face: PackedVector2Array, dimensions: Vector2, depth: PackedFloat32Array = PackedFloat32Array()) -> void:
	if not config.enabled:
		points.clear()
		return
	var basis := FaceFrame.frame(face,dimensions,depth)
	if basis.is_empty():
		points.clear()
		return
	for index in OUTLINE:
		if not face[index].is_finite():
			points.clear()
			return
	points.resize(ids.size())
	var right: Vector2 = basis.right
	var down: Vector2 = basis.down
	var back: Vector2 = basis.back
	for i in points.size():
		var offset := offsets[i]
		points[i] = face[source_a[i]].lerp(face[source_b[i]],weights[i])*dimensions + right*offset.x + down*offset.y + back*offset.z
