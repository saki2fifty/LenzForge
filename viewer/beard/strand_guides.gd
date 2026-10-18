extends RefCounted
## Resampling for imported and clipped spatial facial-hair guides.

static func resample(guide: Array, segments: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	var lengths := PackedFloat32Array([0])
	for p in guide: points.append(Vector3(p[0],p[1],p[2]))
	for j in range(1,points.size()): lengths.append(lengths[-1]+points[j].distance_to(points[j-1]))
	var steps := PackedVector3Array()
	var previous := Vector3.ZERO
	var cursor := 1
	for j in range(1,segments+1):
		var at := lengths[-1]*j/segments
		while cursor<points.size()-1 and lengths[cursor]<at: cursor += 1
		var p := points[cursor-1].lerp(points[cursor],(at-lengths[cursor-1])/maxf(.000001,lengths[cursor]-lengths[cursor-1]))
		steps.append(p-previous); previous = p
	return normalize(steps)

static func normalize(steps: PackedVector3Array) -> PackedVector3Array:
	var total := 0.0
	for step in steps: total += step.length()
	for j in steps.size(): steps[j] /= maxf(total,.000001)
	return steps

static func guides(config: Dictionary, anchors: Array, overrides: Dictionary) -> Dictionary:
	var result := {}
	for binding in anchors:
		var edit: Dictionary = overrides.get(binding.id,{})
		if edit.has("guide3d"): result[binding.id] = resample(edit.guide3d,int(config.segments))
	return result
