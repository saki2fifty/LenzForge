extends RefCounted
## Convert grooming rules into reusable triangle bindings when a look changes.
const Surface = preload("res://tracking/head_surface.gd")
const Groom = preload("res://beard/groom_regions.gd")
const Virtual = preload("res://beard/virtual_head.gd")
const FRAME := Vector2(1280,720)

static func build(surface: RefCounted, config: Dictionary, anchors: Array, overrides: Dictionary) -> Dictionary:
	var face := PackedVector2Array()
	var depth := PackedFloat32Array()
	for p in Surface.canonical_points():
		face.append((FRAME*.5+Vector2(p.x,p.y)*20)/FRAME)
		depth.append(p.z*20/FRAME.x)
	var virtual_anchors := Virtual.build(config) if config.virtual_enabled else []
	var basis := Virtual.frame(face,FRAME,depth)
	var virtual_points := Virtual.project(virtual_anchors,face,FRAME,basis)
	var virtual_depth := Virtual.FaceFrame.depths(virtual_anchors,depth,FRAME,basis)
	var positions := Groom.root_positions(config,anchors,face,FRAME,virtual_points)
	var depths := Groom.root_depths(config,anchors,face,FRAME,depth,virtual_depth)
	var targets := PackedVector3Array()
	var reference := Surface.canonical_points()
	var reference_width := reference[454].distance_to(reference[234])
	var fitted: PackedVector3Array = surface.build_reference()
	# The measured ear-side points define the rear edge, not the virtual skull.
	var rear_limit := maxf(reference[234].z,reference[454].z)
	for i in anchors.size():
		var xy := (positions[i]-FRAME*.5)/20
		targets.append(Vector3(xy.x,xy.y,depths[i]*FRAME.x/20))
		if anchors[i].has("sideburn_target"): targets[i] = anchors[i].sideburn_target*reference_width
	var result: Dictionary = surface.bind_nearest(targets)
	for i in anchors.size():
		var anchor: String = overrides.get(anchors[i].id,{}).get("anchor","")
		var binding := Surface.binding(anchor)
		if binding.is_empty() and anchors[i].has("lower_surface"):
			var uv: Vector2 = anchors[i].lower_surface
			var allowed := bounded_depth(uv.x,float(config.lower_root_depth),fitted,rear_limit)
			uv.y *= allowed/float(config.lower_root_depth)
			binding = lower_binding(uv)
		if binding.is_empty(): continue
		for j in 3: result.indices[i*3+j] = binding.indices[j]
		result.weights[i] = binding.weights[0]
	# Covers sideburn width and legacy offset presets too. Explicit attachments
	# still allow the editor to put any hair on any measured/virtual landmark.
	var clipped_targets := PackedVector3Array()
	var clipped_ids: Array[int] = []
	var placed: PackedVector3Array = surface.math.sample(fitted,result.indices,result.weights)
	for i in anchors.size():
		if anchors[i].region != "beard" or overrides.get(anchors[i].id,{}).has("anchor") or placed[i].z <= rear_limit: continue
		clipped_ids.append(i)
		clipped_targets.append(Vector3(placed[i].x,placed[i].y,rear_limit))
	if not clipped_ids.is_empty():
		var front := PackedInt32Array()
		var topology := Surface.topology()
		for i in range(0,topology.size(),3):
			if minf(fitted[topology[i]].z,minf(fitted[topology[i+1]].z,fitted[topology[i+2]].z)) <= rear_limit:
				front.append_array(topology.slice(i,i+3))
		var clipped: Dictionary = surface.math.bind_nearest(fitted,front,clipped_targets)
		for j in clipped_ids.size():
			var ids: PackedInt32Array = clipped.indices.slice(j*3,j*3+3)
			var weights: Vector3 = clipped.weights[j]
			var z := Vector3(fitted[ids[0]].z,fitted[ids[1]].z,fitted[ids[2]].z)
			if z.dot(weights) > rear_limit:
				var nearest := z.min_axis_index()
				var vertex := Vector3.ZERO; vertex[nearest] = 1
				weights = weights.lerp(vertex,clampf((z.dot(weights)-rear_limit)/(z.dot(weights)-z[nearest]),0,1))
			var id := clipped_ids[j]
			for k in 3: result.indices[id*3+k] = ids[k]
			result.weights[id] = weights
	return result

static func bounded_depth(column: float, requested: float, vertices: PackedVector3Array, limit: float) -> float:
	# Configuration-time bisection on the shared triangles. Redistribute roots
	# across the available strip instead of piling them along a clipping line.
	var low := 0.0
	var high := requested
	for i in 14:
		var middle := (low+high)*.5
		var binding := lower_binding(Vector2(column,middle))
		var ids: PackedInt32Array = binding.indices
		var w: Vector3 = binding.weights[0]
		var z := vertices[ids[0]].z*w.x+vertices[ids[1]].z*w.y+vertices[ids[2]].z*w.z
		if z <= limit: low = middle
		else: high = middle
	return low

static func draw_order(surface: RefCounted, bindings: Dictionary, anchors: Array) -> PackedInt32Array:
	# Sort fitted neutral roots once per placement edit, never by noisy live
	# screen Y. Lower facial roots draw first; upper roots overlap them.
	var positions: PackedVector3Array = surface.math.sample(surface.neutral_vertices(),bindings.indices,bindings.weights)
	var facial: Array[int] = []
	var order := PackedInt32Array(range(anchors.size()))
	for i in anchors.size():
		if anchors[i].region in ["beard","mustache"]: facial.append(i)
	var slots := facial.duplicate()
	facial.sort_custom(func(a: int, b: int):
		if positions[a].y == positions[b].y: return a < b
		return positions[a].y > positions[b].y)
	for i in slots.size(): order[slots[i]] = facial[i]
	return order

static func lower_binding(uv: Vector2) -> Dictionary:
	# Reuse the shared head triangles directly. Guide density/visibility never
	# changes these attachments, and no nearest search runs during tracking.
	var column := int(uv.x)%36
	var next := (column+1)%36
	var along := uv.x-floorf(uv.x)
	var depth := clampf(uv.y,0,.999)*Surface.RINGS
	var ring := int(depth)
	var back := depth-ring
	var a: int = Surface.OUTLINE[column] if ring == 0 else 478+(ring-1)*36+column
	var b: int = Surface.OUTLINE[next] if ring == 0 else 478+(ring-1)*36+next
	var c := 478+ring*36+column
	var d := 478+ring*36+next
	if along+back <= 1:
		return {"indices":PackedInt32Array([a,b,c]),"weights":PackedVector3Array([Vector3(1-along-back,along,back)])}
	return {"indices":PackedInt32Array([b,d,c]),"weights":PackedVector3Array([Vector3(1-back,along+back-1,1-along)])}
