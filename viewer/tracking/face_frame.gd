extends RefCounted
## Face-local offsets in face widths, projected using existing relative depth.
static func frame(face: PackedVector2Array, dimensions: Vector2, depth: PackedFloat32Array = PackedFloat32Array()) -> Dictionary:
	if face.size() < 455 or not dimensions.is_finite() or dimensions.x <= 0 or dimensions.y <= 0: return {}
	var horizontal := (face[454]-face[234])*dimensions
	if not horizontal.is_finite() or horizontal.length() < 10: return {}
	var right := Vector3(horizontal.x,horizontal.y,0)
	var vertical := (face[152]-face[10])*dimensions
	if not vertical.is_finite(): return {}
	var down := Vector3(vertical.x,vertical.y,0)
	if depth.size() >= 455:
		var valid := true
		for index in [10,152,234,454]: valid = valid and is_finite(depth[index])
		if valid:
			# MediaPipe relative Z has the same scale as normalized image X.
			right.z = (depth[454]-depth[234])*dimensions.x
			down.z = (depth[152]-depth[10])*dimensions.x
	var width := right.length()
	# Reject malformed depth rather than exploding the extrapolated head.
	if not is_finite(width) or width > horizontal.length()*4 or not down.is_finite() or down.length() > width*6:
		return frame(face,dimensions) if not depth.is_empty() else {}
	right /= width
	down -= right*down.dot(right)
	if down.length_squared() < 1: return {}
	down = down.normalized()
	var back := right.cross(down).normalized()
	return {"right":Vector2(right.x,right.y)*width,"down":Vector2(down.x,down.y)*width,
		"back":Vector2(back.x,back.y)*width,"width":width}

static func project(anchors: Array, face: PackedVector2Array, dimensions: Vector2, basis: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	if basis.is_empty(): return result
	result.resize(anchors.size())
	var right: Vector2 = basis.right
	var down: Vector2 = basis.down
	var back: Vector2 = basis.back
	for i in anchors.size():
		var anchor: Dictionary = anchors[i]
		var ids: Vector3i = anchor.indices
		var w: Vector3 = anchor.weights
		var offset: Vector3 = anchor.offset
		result[i] = (face[ids.x]*w.x+face[ids.y]*w.y+face[ids.z]*w.z)*dimensions+right*offset.x+down*offset.y+back*offset.z
	return result
