extends RefCounted
## Bounded virtual surfaces, fitted to the existing face and relative depth.
## X/Y/Z offsets use one face width; +Z points behind the face plane.
const PATCHES := ["scalp","chin","left_side","right_side"]

static func layout(config: Dictionary) -> Dictionary:
	var result := {}
	var start := 0
	for patch in PATCHES:
		var columns := int(config.virtual_columns)
		if patch.ends_with("side"): columns = maxi(4,columns/2)
		var rows := int(config.virtual_rows)
		result[patch] = {"start":start,"columns":columns,"rows":rows}
		start += (columns+1)*(rows+1)
	return result

static func bind_root(binding: Dictionary, patch: String, uv: Vector2, config: Dictionary) -> void:
	var grid: Dictionary = layout(config)[patch]
	var x := clampf(uv.x,0,1)*int(grid.columns)
	var y := clampf(uv.y,0,1)*int(grid.rows)
	var column := mini(int(x),int(grid.columns)-1)
	var row := mini(int(y),int(grid.rows)-1)
	var a := int(grid.start)+row*(int(grid.columns)+1)+column
	var u := x-column
	var v := y-row
	binding.virtual_cell = Vector4i(a,a+1,a+int(grid.columns)+1,a+int(grid.columns)+2)
	binding.virtual_weights = Vector4((1-u)*(1-v),u*(1-v),(1-u)*v,u*v)
	binding.virtual_patch = patch
	binding.synthetic = true

static func build(config: Dictionary) -> Array:
	var result: Array = []
	var grids := layout(config)
	for patch in PATCHES:
		var grid: Dictionary = grids[patch]
		for row in range(int(grid.rows)+1):
			for column in range(int(grid.columns)+1):
				var u := float(column)/int(grid.columns)
				var v := float(row)/int(grid.rows)
				var point := {"id":"virtual:%s:%d:%d"%[patch,row,column],"patch":patch,
					"indices":Vector3i(10,10,10),"weights":Vector3(1,0,0),"offset":Vector3.ZERO}
				if patch == "scalp":
					var across := u*2-1
					point.offset = Vector3(across*.5*float(config.crown_width),
						across*across*.12-float(config.crown_height)*sqrt(maxf(0,1-across*across))*sin(v*PI*.5),
						v*float(config.crown_back))
				elif patch == "chin":
					_path_binding(point,[172,136,150,152,379,365,397],u*6)
					point.offset = Vector3((u*2-1)*float(config.jaw_expansion)*v,
						float(config.chin_extension)*v*(1-absf(u*2-1)*.5),float(config.chin_back)*v)
				else:
					var side := -1.0 if patch == "left_side" else 1.0
					_path_binding(point,[93,234,127] if side < 0 else [323,454,356],u*(.15+float(config.sideburn_height)*1.85))
					point.offset = Vector3(side*(float(config.ear_reach)*v+float(config.jaw_expansion)*.25),0,float(config.side_back)*v)
				result.append(point)
	return result

static func _path_binding(point: Dictionary, path: Array, along: float) -> void:
	var segment := mini(int(along),path.size()-2)
	var fraction := along-segment
	point.indices = Vector3i(path[segment],path[segment+1],path[segment])
	point.weights = Vector3(1-fraction,fraction,0)

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

static func interpolate(binding: Dictionary, points: PackedVector2Array) -> Vector2:
	var cell: Vector4i = binding.virtual_cell
	var w: Vector4 = binding.virtual_weights
	return points[cell.x]*w.x+points[cell.y]*w.y+points[cell.z]*w.z+points[cell.w]*w.w
