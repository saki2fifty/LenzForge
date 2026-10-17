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
	for i in anchors.size():
		var xy := (positions[i]-FRAME*.5)/20
		targets.append(Vector3(xy.x,xy.y,depths[i]*FRAME.x/20))
	var result: Dictionary = surface.bind_nearest(targets)
	for i in anchors.size():
		var anchor: String = overrides.get(anchors[i].id,{}).get("anchor","")
		var binding := Surface.binding(anchor)
		if binding.is_empty() and anchors[i].has("lower_surface"):
			binding = lower_binding(anchors[i].lower_surface)
		if binding.is_empty(): continue
		for j in 3: result.indices[i*3+j] = binding.indices[j]
		result.weights[i] = binding.weights[0]
	return result

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
