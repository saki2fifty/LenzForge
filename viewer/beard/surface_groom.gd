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
		if binding.is_empty(): continue
		for j in 3: result.indices[i*3+j] = binding.indices[j]
		result.weights[i] = binding.weights[0]
	return result
