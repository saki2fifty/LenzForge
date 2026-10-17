extends RefCounted
const LIMITS := {"depth":[.25,1.0],"crown":[0.0,.5],"sides":[.8,1.25],"jaw":[.8,1.2]}
static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or (value.get("version",0) != 1 and value.get("version",0) != 2): return {}
	var result := {"version":int(value.version),"estimated":true}
	for key in LIMITS:
		if not value.get(key) is float and not value.get(key) is int: return {}
		var number := float(value[key])
		if not is_finite(number) or number < LIMITS[key][0] or number > LIMITS[key][1]: return {}
		result[key] = number
	var views: Variant = value.get("views",0)
	result["views"] = clampi(int(views),0,12) if (views is float or views is int) and is_finite(float(views)) else 0
	if value.version == 2:
		var points: Variant = value.get("reference",[])
		if not points is Array or points.size() != 478: return {}
		for point in points:
			if not point is Array or point.size() != 3: return {}
			for coordinate in point:
				if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or absf(float(coordinate)) > 4: return {}
		var right := Vector3(points[454][0]-points[234][0],points[454][1]-points[234][1],points[454][2]-points[234][2])
		var down := Vector3(points[152][0]-points[10][0],points[152][1]-points[10][1],points[152][2]-points[10][2])
		if absf(right.length()-1) > .01 or right.cross(down).length() < .1: return {}
		result["reference"] = points.duplicate(true)
		result["crown_observed"] = bool(value.get("crown_observed",false))
	return result

static func reference_points(profile: Dictionary) -> PackedVector3Array:
	var result := PackedVector3Array()
	if profile.get("version",1) != 2: return result
	var canonical := preload("res://tracking/head_surface.gd").canonical_points()
	var width := canonical[234].distance_to(canonical[454])
	var center := (canonical[234]+canonical[454])*.5
	for p in profile.reference: result.append(Vector3(p[0],p[1],p[2])*width+center)
	return result
