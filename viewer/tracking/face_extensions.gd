extends RefCounted
## General virtual landmarks; independent of hair, tracking IDs, and rendering.
const Surface = preload("res://tracking/head_surface.gd")
const REGIONS := ["forehead","left_side","right_side","chin"]
# MediaPipe FACE_LANDMARKS_FACE_OVAL, clockwise from the forehead.
const OUTLINE := [10,338,297,332,284,251,389,356,454,323,361,288,397,365,379,378,400,377,
	152,148,176,149,150,136,172,58,132,93,234,127,162,21,54,103,67,109]
const LIMITS := {"vertical_offset":[-1.5,1.5],"top":[0,1.5],"bottom":[0,1.5],"left":[0,1.5],"right":[0,1.5],
	"depth":[-1,1],"columns":[36,144],"rings":[1,12],"point_size":[1,6],
	"left_side_inset":[-1.5,1.5],"right_side_inset":[-1.5,1.5],
	"forehead_vertical":[-1.5,1.5],"forehead_back":[0,1.5],"forehead_wrap":[0,180],
	"left_side_vertical":[-1.5,1.5],"left_side_back":[0,1.5],"left_side_wrap":[0,180],
	"right_side_vertical":[-1.5,1.5],"right_side_back":[0,1.5],"right_side_wrap":[0,180],
	"chin_vertical":[-1.5,1.5],"chin_back":[0,1.5],"chin_wrap":[0,180]}
var config := defaults()
var ids := PackedStringArray()
var source_a := PackedInt32Array()
var source_b := PackedInt32Array()
var weights := PackedFloat32Array()
var offsets := PackedVector3Array()
var points := PackedVector2Array()
var point_depth := PackedFloat32Array()
var surface := Surface.new()
var external_surface := false
var bindings: Dictionary = {}

static func defaults() -> Dictionary:
	# The rounded mannequin-preview fit is the starting and reset configuration.
	var result := straight_defaults()
	result.vertical_offset = -.15
	result.left_side_inset = -.08
	result.right_side_inset = -.08
	for region in REGIONS:
		result.merge(rounded_region(region),true)
		result[region+"_vertical"] = .1
	return result

static func straight_defaults() -> Dictionary:
	var result := {"enabled":true,"show_points":true,"vertical_offset":0.0,"top":.42,"bottom":.2,"left":.18,"right":.18,
		"depth":.15,"columns":72,"rings":4,"point_size":2.5,"color":"ffbf69ff"}
	result.left_side_inset = 0.0
	result.right_side_inset = 0.0
	# Zero contour controls preserve the fitting of existing saved settings.
	for region in REGIONS:
		for suffix in ["vertical","back","wrap"]: result[region+"_"+suffix] = 0.0
	return result

static func for_saved_settings(values: Dictionary) -> Dictionary:
	# Missing fields in older saved fits retain their original straight geometry.
	var result := straight_defaults()
	result.merge(values,true)
	return result

static func rounded_region(region: String) -> Dictionary:
	if region not in REGIONS: return {}
	return {region+"_back":.3 if region == "chin" else .5,region+"_wrap":110.0}

static func _curve(v: float, degrees: float) -> Vector2:
	if degrees < .001: return Vector2(v,v)
	var angle := deg_to_rad(degrees)
	# At 90 degrees the rows form a quarter ellipse; beyond 90 they turn inward.
	var arc := Vector2(sin(v*angle)/sin(minf(angle,PI*.5)),
		(1-cos(v*angle))/maxf(1e-12,1-cos(angle)))
	return Vector2(v,v).lerp(arc,minf(degrees/90,1))

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
		if key in LIMITS and key != "point_size" and values[key] != config[key]: rebuild = true
	config.merge(values,true)
	config.columns = int(config.columns)
	config.rings = int(config.rings)
	if rebuild: _rebuild()
	return true

func _rebuild() -> void:
	ids.clear(); source_a.clear(); source_b.clear(); weights.clear(); offsets.clear()
	for ring in range(1,int(config.rings)+1):
		var v := float(ring)/int(config.rings)
		var upper := _curve(v,float(config.forehead_wrap))
		var lower := _curve(v,float(config.chin_wrap))
		var left := _curve(v,float(config.left_side_wrap))
		var right := _curve(v,float(config.right_side_wrap))
		var depths := Vector4(upper.y*(float(config.depth)+float(config.forehead_back)),
			left.y*(float(config.depth)+float(config.left_side_back)),
			right.y*(float(config.depth)+float(config.right_side_back)),
			lower.y*(float(config.depth)+float(config.chin_back)))
		var heights := Vector4(config.forehead_vertical,config.left_side_vertical,config.right_side_vertical,config.chin_vertical)
		for column in int(config.columns):
			var along := float(column)*OUTLINE.size()/int(config.columns)
			var edge := int(along)
			# Align cardinal directions to forehead, cheek sides, and chin.
			var quarter := along/8 if along < 8 else 1+(along-8)/10 if along < 18 else 2+(along-18)/10 if along < 28 else 3+(along-28)/8
			var direction := Vector2(sin(quarter*PI*.5),-cos(quarter*PI*.5))
			# Squared directional weights sum to one and blend through the temples/jaw.
			var blend := Vector4(maxf(-direction.y,0),maxf(-direction.x,0),maxf(direction.x,0),maxf(direction.y,0))
			blend *= blend
			ids.append("extension:%d:%d"%[ring,column])
			source_a.append(OUTLINE[edge])
			source_b.append(OUTLINE[(edge+1)%OUTLINE.size()])
			weights.append(along-edge)
			offsets.append(Vector3(
				direction.x*float(config.left if direction.x < 0 else config.right)*(left.x if direction.x < 0 else right.x)
					-blend.y*float(config.left_side_inset)+blend.z*float(config.right_side_inset),
				direction.y*float(config.top if direction.y < 0 else config.bottom)*(upper.x if direction.y < 0 else lower.x)
					+blend.dot(heights)+float(config.vertical_offset),blend.dot(depths)))
	# Controls choose locations on the shared head, never a second floating shell.
	# Fitting is cached here, not repeated for every tracking frame.
	var reference := Surface.canonical_points()
	var width := reference[234].distance_to(reference[454])
	var targets := PackedVector3Array()
	for i in offsets.size():
		targets.append(reference[source_a[i]].lerp(reference[source_b[i]],weights[i])+offsets[i]*width)
	bindings = surface.bind_nearest(targets)
	for i in ids.size():
		ids[i] = Surface.id_for(bindings,i)
		# Quantized IDs and the guides resolve to precisely the same positions.
		bindings.weights[i] = Surface.binding(ids[i]).weights[0]

func update(face: PackedVector2Array, dimensions: Vector2, depth: PackedFloat32Array = PackedFloat32Array()) -> void:
	if not external_surface: surface.update(face,depth,dimensions)
	var positions := surface.sample(bindings) if config.enabled else PackedVector3Array()
	points.resize(positions.size())
	point_depth.resize(positions.size())
	for i in positions.size():
		points[i] = Vector2(positions[i].x,positions[i].y)
		point_depth[i] = positions[i].z/dimensions.x
