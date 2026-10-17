extends RefCounted
const LIMITS := {"depth":[.25,1.0],"crown":[0.0,.5],"sides":[.8,1.25],"jaw":[.8,1.2]}
static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("version",0) != 1: return {}
	var result := {"version":1,"estimated":true}
	for key in LIMITS:
		if not value.get(key) is float and not value.get(key) is int: return {}
		var number := float(value[key])
		if not is_finite(number) or number < LIMITS[key][0] or number > LIMITS[key][1]: return {}
		result[key] = number
	var views: Variant = value.get("views",0)
	result["views"] = clampi(int(views),0,12) if (views is float or views is int) and is_finite(float(views)) else 0
	return result
