extends RefCounted
## A complete neutral bust, with the canonical face's original landmark indices.
const Surface = preload("res://tracking/head_surface.gd")

static func reference_points() -> PackedVector3Array:
	var points := Surface.canonical_points().duplicate()
	for i in points.size(): points[i] *= Vector3(1,-1,-1)
	return points

static func build(_points: PackedVector3Array, surface: RefCounted = null) -> Node3D:
	var bust := Node3D.new()
	var clay := _material(Color("b3a899"))
	var dark := _material(Color("303e43"))
	var eye := _material(Color("d0c9ba"))
	if surface == null:
		surface = Surface.new()
		surface.set_reference()
	var vertices: PackedVector3Array = surface.vertices.duplicate()
	for i in vertices.size(): vertices[i] *= Vector3(1,-1,-1)
	var indices: PackedInt32Array = surface.topology().duplicate()
	# Surface triangles have outward counterclockwise winding; Godot uses clockwise.
	for i in range(0,indices.size(),3):
		var swap := indices[i+1]
		indices[i+1] = indices[i+2]
		indices[i+2] = swap
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,indices.size(),3):
		var a := indices[i]; var b := indices[i+1]; var c := indices[i+2]
		var normal := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a] += normal; normals[b] += normal; normals[c] += normal
	for i in normals.size(): normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_add(bust,mesh,Vector3.ZERO,Vector3.ONE,clay)
	for side in [-1.0,1.0]:
		_ellipsoid(bust,Vector3(side*3.15,2.62,3.0),Vector3(1.3,.68,.88),eye)
		_ellipsoid(bust,Vector3(side*3.15,2.62,3.85),Vector3(.33,.33,.07),dark)
		_ellipsoid(bust,Vector3(side*7.8,.3,-2.1),Vector3(.95,2.0,.72),clay)
		_ellipsoid(bust,Vector3(side*8.0,.45,-1.48),Vector3(.44,1.23,.12),_material(Color("897f74")))
	_ellipsoid(bust,Vector3(0,-4.25,4.7),Vector3(2.2,.45,.2),dark)
	var neck := CylinderMesh.new()
	neck.top_radius = 3.0; neck.bottom_radius = 3.7; neck.height = 8.0
	_add(bust,neck,Vector3(0,-10.6,-2.8),Vector3.ONE,clay)
	_ellipsoid(bust,Vector3(0,-15.3,-2.8),Vector3(9.2,2.4,4.7),clay)
	var stand := CylinderMesh.new()
	stand.top_radius = 7.4; stand.bottom_radius = 7.7; stand.height = .7
	_add(bust,stand,Vector3(0,-17.1,-2.8),Vector3.ONE,dark)
	return bust

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .82
	return material

static func _ellipsoid(parent: Node3D, center: Vector3, dimensions: Vector3, material: Material) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1; sphere.height = 2
	sphere.radial_segments = 32; sphere.rings = 16
	_add(parent,sphere,center,dimensions,material)

static func _add(parent: Node3D, mesh: Mesh, center: Vector3, dimensions: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh; instance.material_override = material
	instance.position = center; instance.scale = dimensions
	parent.add_child(instance)
