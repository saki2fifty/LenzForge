extends RefCounted
## Authored meshes are loaded once; fitting happens only on hairstyle/head edits.
const MODELS := {
	"Side-swept":preload("res://beard/assets/hair/side_swept.glb"),
	"Center-parted":preload("res://beard/assets/hair/center_parted.glb"),
	"Long layered":preload("res://beard/assets/hair/long_layered.glb")
}
const SOURCE_CENTER := Vector3(0,.13,-.10)
const SOURCE_RADII := Vector3(.85,1.27,.95)
const Surface = preload("res://tracking/head_surface.gd")
static var _arrays: Dictionary = {}

static func has_style(style: String) -> bool: return MODELS.has(style)

static func source_arrays(style: String) -> Array:
	if not _arrays.has(style):
		var scene: Node3D = MODELS[style].instantiate()
		var nodes: Array[Node] = [scene]
		while not nodes.is_empty():
			var node := nodes.pop_back() as Node3D
			if node is MeshInstance3D:
				_arrays[style] = node.mesh.surface_get_arrays(0)
				break
			nodes.append_array(node.get_children())
		scene.free()
	return _arrays[style]

static func fit(head: PackedVector3Array, settings: Dictionary) -> ArrayMesh:
	# The exported models use +Y up / +Z forward, like the renderer. Match the
	# shared skull, excluding facial features such as the nose and moving lips.
	var lower := Vector3(INF,INF,INF)
	var upper := -lower
	for i in range(478,head.size()):
		lower = lower.min(head[i]); upper = upper.max(head[i])
	for i in Surface.OUTLINE:
		lower = lower.min(head[i]); upper = upper.max(head[i])
	var center := (lower+upper)*.5
	var scale := (upper-lower)/(SOURCE_RADII*2)
	scale.x *= float(settings.hair_width)
	var style: String = settings.hair_style
	var arrays := source_arrays(style).duplicate()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
	var length := float(settings.hair_length)/.32
	var volume := 1.0+(float(settings.hair_volume)-.35)*1.7
	var shift := Vector3(0,-float(settings.hairline)*(upper.x-lower.x),0)
	var exterior := PackedInt32Array()
	for i in points.size():
		var q := points[i]-SOURCE_CENTER
		var radius := (q/SOURCE_RADII).length()
		if radius>=1.0: exterior.append(i)
		# Long locks below the temples hang beside the head. Keep their lateral
		# support cylindrical so length changes never pull them into the neck.
		if style=="Long layered" and q.y<.3:
			var cylinder := Vector2(q.x/SOURCE_RADII.x,q.z/SOURCE_RADII.z).length()
			radius = lerpf(radius,cylinder,smoothstep(.3,0.0,q.y))
		var support := q/maxf(radius,1.0)
		var lift := volume*(length if style!="Long layered" else 1.0)
		q = support+(q-support)*lift
		if style=="Long layered" and q.y<.3: q.y = .3+(q.y-.3)*length
		points[i] = center+q*scale+shift
		# Inverse-transpose of the fit; preserve the sculpt's smooth normals
		# across UV seams instead of splitting locks into faceted triangles.
		var normal_scale := scale
		if style=="Long layered" and q.y<.3: normal_scale.y *= length
		normals[i] = (normals[i]/normal_scale).normalized()
	_clear_scalp(head,points,exterior,(upper.x-lower.x)*.004)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null # Shader uses UV flow, not imported tangent space.
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func _clear_scalp(head: PackedVector3Array, points: PackedVector3Array, exterior: PackedInt32Array, clearance: float) -> void:
	# The reference ellipsoid and a calibrated human skull differ locally. Push
	# buried vertices onto the actual shared surface once, never during tracking.
	# Use the native nearest-triangle BVH in bounded batches, avoiding a quadratic
	# GDScript scan of every hair vertex against every head triangle.
	var math: RefCounted = ClassDB.instantiate("HeadSurfaceMath")
	var topology := Surface.topology()
	# Leave the intentionally buried cap closure inside the skull. Projecting
	# that underside onto the face would expose fragments near the eyebrows.
	for start in range(0,exterior.size(),16000):
		var targets := PackedVector3Array()
		for i in range(start,mini(start+16000,exterior.size())): targets.append(points[exterior[i]])
		var bindings: Dictionary = math.bind_nearest(head,topology,targets)
		var skin: PackedVector3Array = math.sample(head,bindings.indices,bindings.weights)
		var ids: PackedInt32Array = bindings.indices
		for i in targets.size():
			var a := head[ids[i*3]]; var b := head[ids[i*3+1]]; var c := head[ids[i*3+2]]
			var normal := (b-a).cross(c-a).normalized()
			var distance := (targets[i]-skin[i]).dot(normal)
			if distance<clearance: points[exterior[start+i]] += normal*(clearance-distance)
