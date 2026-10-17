extends RefCounted
## One deforming surface for measured/virtual anchors, hair, objects and depth.
## Coordinates: camera pixels, +X right, +Y down, +Z away (also in pixels).
signal updated
const RINGS := 20
const OUTLINE := [10,338,297,332,284,251,389,356,454,323,361,288,397,365,379,378,400,377,
	152,148,176,149,150,136,172,58,132,93,234,127,162,21,54,103,67,109]
static var _topology := PackedInt32Array()
static var _triangle_ids: Dictionary = {}
static var _adjacency: Dictionary = {}
static var _reference := PackedVector3Array()
static var _neutral := PackedVector3Array()
var math: RefCounted = ClassDB.instantiate("HeadSurfaceMath")
var vertices := PackedVector3Array()
var measured_count := 0
var width := 0.0
var screen_down := Vector2.DOWN
var dimensions := Vector2.ONE
var head_depth := .65
var crown := .20
var sides := 1.0
var jaw := 1.0
var personal_reference := PackedVector3Array()
var reference_id := 0

func set_personal_reference(value: PackedVector3Array) -> void:
	if value == personal_reference: return
	if not math.set_reference(value): return
	personal_reference = value
	reference_id = hash(value) if not value.is_empty() else 0

func shape_signature() -> Vector4: return Vector4(head_depth,crown,sides,jaw)

func build_reference() -> PackedVector3Array:
	return math.build(personal_reference if not personal_reference.is_empty() else canonical_points(),PackedInt32Array(OUTLINE),RINGS,head_depth,crown,sides,jaw)

static func topology() -> PackedInt32Array:
	if not _topology.is_empty(): return _topology
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mannequin/assets/canonical_face.json"))
	for triangle in data.triangles: _topology.append_array(PackedInt32Array(triangle))
	var previous := PackedInt32Array(OUTLINE)
	for ring in RINGS:
		var next := PackedInt32Array()
		for column in 36: next.append(478+ring*36+column)
		for i in 36:
			var j := (i+1)%36
			_topology.append_array(PackedInt32Array([previous[i],previous[j],next[i],previous[j],next[j],next[i]]))
		previous = next
	for i in range(0,_topology.size(),3):
		_triangle_ids[Vector3i(_topology[i],_topology[i+1],_topology[i+2])] = i/3
		for j in 3:
			var vertex := _topology[i+j]
			if not _adjacency.has(vertex): _adjacency[vertex] = PackedInt32Array()
			_adjacency[vertex].append(i)
	return _topology

static func canonical_points() -> PackedVector3Array:
	if not _reference.is_empty(): return _reference
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mannequin/assets/canonical_face.json"))
	for p in data.vertices: _reference.append(Vector3(p[0],-p[1],-p[2]))
	for side in [-1.0,1.0]:
		var center := Vector3(side*3.15,-2.62,-3.88)
		_reference.append(center)
		for offset in [Vector3(.34,0,0),Vector3(0,-.34,0),Vector3(-.34,0,0),Vector3(0,.34,0)]:
			_reference.append(center+offset)
	return _reference

func neutral_vertices() -> PackedVector3Array:
	if _neutral.is_empty(): _neutral = math.build(canonical_points(),PackedInt32Array(OUTLINE),RINGS,.65,.20)
	return _neutral

func set_reference() -> void:
	vertices = build_reference()
	measured_count = 478
	width = vertices[234].distance_to(vertices[454])
	updated.emit()

func update(face: PackedVector2Array, depth: PackedFloat32Array, frame_size: Vector2) -> void:
	dimensions = frame_size
	if face.size() < 468 or not dimensions.is_finite() or dimensions.x <= 0 or dimensions.y <= 0:
		clear()
		return
	var measured := PackedVector3Array()
	measured.resize(478)
	measured_count = mini(face.size(),478)
	for i in measured_count:
		measured[i] = Vector3(face[i].x*dimensions.x,face[i].y*dimensions.y,depth[i]*dimensions.x if i < depth.size() else 0.0)
	for i in range(measured_count,478): measured[i] = measured[1]
	vertices = math.build_stable(measured,PackedInt32Array(OUTLINE),RINGS,head_depth,crown,sides,jaw)
	width = measured[234].distance_to(measured[454]) if not vertices.is_empty() else 0.0
	if width > .00001:
		var right := (measured[454]-measured[234])/width
		var down := measured[152]-measured[10]
		down -= right*down.dot(right)
		var projected := Vector2(down.x,down.y)
		if projected.length_squared() > .00001: screen_down = projected.normalized()
	updated.emit()

func clear() -> void:
	math.set_reference(personal_reference)
	vertices.clear()
	measured_count = 0
	width = 0.0
	updated.emit()

func bind_nearest(targets: PackedVector3Array) -> Dictionary:
	return math.bind_nearest(neutral_vertices(),topology(),targets)

func sample(bindings: Dictionary) -> PackedVector3Array:
	if vertices.is_empty() or bindings.is_empty(): return PackedVector3Array()
	return math.sample(vertices,bindings.indices,bindings.weights)

static func id_for(bindings: Dictionary, index: int) -> String:
	topology()
	var ids: PackedInt32Array = bindings.indices
	var w: Vector3 = bindings.weights[index]
	var triangle: int = _triangle_ids[Vector3i(ids[index*3],ids[index*3+1],ids[index*3+2])]
	var a := clampi(roundi(w.x*1000000),0,1000000)
	var b := clampi(roundi(w.y*1000000),0,1000000-a)
	return "virtual:%d:%d:%d"%[triangle,a,b]

static func binding(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size() == 2 and parts[0] == "face" and parts[1].is_valid_int():
		var i := int(parts[1])
		if i >= 0 and i < 478: return {"indices":PackedInt32Array([i,i,i]),"weights":PackedVector3Array([Vector3(1,0,0)])}
	if parts.size() != 4 or parts[0] != "virtual": return {}
	for i in range(1,4):
		if not parts[i].is_valid_int(): return {}
	var triangle := int(parts[1]); var a := int(parts[2]); var b := int(parts[3])
	var indices := topology()
	if triangle < 0 or triangle >= indices.size()/3 or a < 0 or b < 0 or a > 1000000 or b > 1000000 or a+b > 1000000: return {}
	return {"indices":indices.slice(triangle*3,triangle*3+3),"weights":PackedVector3Array([Vector3(a,b,1000000-a-b)/1000000.0])}

func resolve(id: String) -> Dictionary:
	var bound := binding(id)
	if bound.is_empty() or vertices.is_empty(): return {}
	var ids: PackedInt32Array = bound.indices
	if id.begins_with("face:") and ids[0] >= measured_count: return {}
	var position := sample(bound)[0]
	var normal := Vector3.ZERO
	if id.begins_with("face:"):
		var triangles := topology()
		for i in _adjacency.get(ids[0],PackedInt32Array()):
			normal += (vertices[triangles[i+1]]-vertices[triangles[i]]).cross(vertices[triangles[i+2]]-vertices[triangles[i]])
	else: normal = (vertices[ids[1]]-vertices[ids[0]]).cross(vertices[ids[2]]-vertices[ids[0]])
	if normal.length_squared() < .000001: normal = -(vertices[454]-vertices[234]).cross(vertices[152]-vertices[10])
	normal = normal.normalized()
	var tangent := (vertices[454]-vertices[234]).normalized()
	tangent = (tangent-normal*tangent.dot(normal)).normalized()
	if tangent.length_squared() < .1: tangent = normal.cross(Vector3.UP).normalized()
	return {"position":position,"normal":normal,"transform":Transform3D(Basis(tangent,normal.cross(tangent),normal),position),
		"estimated":id.begins_with("virtual:")}
