extends MeshInstance3D
## One fitted, opaque hair object. Geometry changes only when its shape changes.
const Surface = preload("res://tracking/head_surface.gd")
const FLIP := Basis(Vector3.RIGHT,Vector3.DOWN,Vector3.FORWARD)
const SHAPE_KEYS := ["hair_style","hair_length","hair_width","hair_volume","hairline","hair_sweep",
	"hair_part","hair_sides","hawk_width","hair_frizz","crown_width","crown_height","crown_back"]
const EDIT_KEYS := ["hair_style","hair_length","hair_width","hair_volume","hairline","hair_sweep",
	"hair_part","hair_sides","hawk_width","hair_curl","hair_frizz","hair_color","hair_tip_color",
	"hair_count","hair_motion","hair_hold","hair_root_width","hair_tip_width","hair_coils","hair_clump","hair_variation"]
# Three non-collinear points beyond the deforming two-ring skin seam.
const POSE_IDS := [478+5*36+27,478+5*36+9,478+5*36]
var shader_material := ShaderMaterial.new()
var revision := 0
var build_ms := 0.0
var triangle_count := 0
var _key: Array = []
var _fit_key: Array = []
var _reference := PackedVector3Array()
var _colors: Array = []
var _shape: Dictionary = {}
var _skin := PackedVector3Array()
var _normals := PackedVector3Array()
var _indices := PackedInt32Array()
var _lookup: Dictionary = {}
var _center := Vector3.ZERO
var _width := 1.0

func _init() -> void:
	shader_material.shader = preload("res://beard/scalp_mesh.gdshader")
	material_override = shader_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

static func pose(vertices: PackedVector3Array) -> Transform3D:
	if vertices.size() <= POSE_IDS[0]: return Transform3D.IDENTITY
	var center := (vertices[POSE_IDS[0]]+vertices[POSE_IDS[1]])*.5
	var right := vertices[POSE_IDS[1]]-vertices[POSE_IDS[0]]
	var scale := right.length()
	if scale < .000001: return Transform3D.IDENTITY
	right /= scale
	var down := center-vertices[POSE_IDS[2]]
	down = (down-right*down.dot(right)).normalized()
	var back := right.cross(down)
	return Transform3D(Basis(right*scale,down*scale,back*scale),center)

func invalidate_fit() -> void:
	_key.clear()
	_fit_key.clear()

func configure(surface: RefCounted, config: Dictionary) -> void:
	var colors := [config.hair_color,config.hair_tip_color,config.hair_style,config.hair_sweep,config.hair_curl]
	if colors != _colors:
		_colors = colors
		shader_material.set_shader_parameter("base_color",Color.html(config.hair_color))
		shader_material.set_shader_parameter("highlight_color",Color.html(config.hair_tip_color))
		shader_material.set_shader_parameter("style",2 if config.hair_style=="Afro" else 1 if config.hair_style=="Mohawk" else 0)
		shader_material.set_shader_parameter("sweep",float(config.hair_sweep))
		shader_material.set_shader_parameter("curl",float(config.hair_curl))
	var settings := {}
	for key in SHAPE_KEYS: settings[key] = config[key]
	var fit := [surface.shape_signature(),surface.reference_id,surface.get_instance_id(),not surface.vertices.is_empty()]
	var next := [settings,fit]
	if next == _key: return
	_key = next
	_shape = settings
	var started := Time.get_ticks_usec()
	mesh = null
	triangle_count = 0
	if config.hair_style != "None":
		if fit != _fit_key:
			_fit_key = fit
			_reference = surface.vertices if not surface.vertices.is_empty() else surface.build_reference()
		_build(_reference)
	revision += 1
	build_ms = (Time.get_ticks_usec()-started)/1000.0
	visible = mesh != null

func follow(surface: RefCounted, offset := Vector3.ZERO) -> void:
	if mesh == null or surface.vertices.is_empty(): return
	var head := pose(surface.vertices)
	transform = Transform3D(FLIP*head.basis*FLIP,FLIP*head.origin+offset)

func set_occlusion(occlusion: RefCounted, frame_size: Vector2) -> void:
	var enabled: bool = occlusion != null and occlusion.enabled and occlusion.valid
	shader_material.set_shader_parameter("head_occlusion_enabled",enabled)
	shader_material.set_shader_parameter("frame_size",frame_size)
	if enabled:
		shader_material.set_shader_parameter("head_depth",occlusion.texture)
		shader_material.set_shader_parameter("head_depth_bias",occlusion.width*occlusion.tolerance)

func _boundary(p: Vector3) -> float:
	var q := (p-_center)/_width
	var frontal := clampf((.08-q.z)/.35,0,1)
	var boundary := lerpf(.08,-.51,pow(frontal,.8))+float(_shape.hairline)
	boundary += (float(_shape.hair_width)*float(_shape.crown_width)/1.08-1)*.3*(1-frontal)
	boundary += (float(_shape.crown_height)-.42)*.35
	return boundary-q.y

static func clip(poly: Array, distance: Vector3) -> Array:
	var result := []
	if poly.is_empty(): return result
	var previous: Vector3 = poly[-1]
	var before := previous.dot(distance)
	for weight: Vector3 in poly:
		var after := weight.dot(distance)
		if (before>=0)!=(after>=0): result.append(previous.lerp(weight,before/(before-after)))
		if after>=0: result.append(weight)
		previous = weight; before = after
	return result

func _vertex(p: Vector3, n: Vector3) -> int:
	var key := p.snapped(Vector3.ONE*.00001)
	if _lookup.has(key): return _lookup[key]
	var id := _skin.size()
	_lookup[key] = id
	_skin.append(p); _normals.append(n.normalized())
	return id

func _build(source: PackedVector3Array) -> void:
	_skin.clear(); _normals.clear(); _indices.clear(); _lookup.clear()
	var frame := pose(source).affine_inverse()
	var vertices := PackedVector3Array()
	for p in source: vertices.append(frame*p)
	_center = (vertices[234]+vertices[454])*.5
	_width = vertices[234].distance_to(vertices[454])
	var topology := Surface.topology()
	var normals := PackedVector3Array(); normals.resize(vertices.size())
	var middle := _center+Vector3(0,-.15,.18)*_width
	for i in range(0,topology.size(),3):
		var a := topology[i]; var b := topology[i+1]; var c := topology[i+2]
		var n := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
		if n.dot((vertices[a]+vertices[b]+vertices[c])/3-middle)<0: n = -n
		normals[a] += n; normals[b] += n; normals[c] += n
	for i in normals.size(): normals[i] = normals[i].normalized()
	for i in range(0,topology.size(),3):
		var ids := topology.slice(i,i+3)
		var a := vertices[ids[0]]; var b := vertices[ids[1]]; var c := vertices[ids[2]]
		var poly := clip([Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1)],Vector3(_boundary(a),_boundary(b),_boundary(c)))
		var rear := _center.z+lerpf(-.42,.72,clampf(float(_shape.crown_back)/.35,0,1))*_width
		poly = clip(poly,Vector3.ONE*rear-Vector3(a.z,b.z,c.z))
		if _shape.hair_style=="Mohawk":
			var x := Vector3(a.x,b.x,c.x)-Vector3.ONE*_center.x
			var half := float(_shape.hawk_width)*float(_shape.hair_width)*_width*.5
			poly = clip(clip(poly,Vector3.ONE*half-x),Vector3.ONE*half+x)
		var polygon := PackedInt32Array()
		for w: Vector3 in poly:
			polygon.append(_vertex(a*w.x+b*w.y+c*w.z,normals[ids[0]]*w.x+normals[ids[1]]*w.y+normals[ids[2]]*w.z))
		for j in range(1,polygon.size()-1): _indices.append_array(PackedInt32Array([polygon[0],polygon[j],polygon[j+1]]))
	if _indices.is_empty(): return
	# Uniform subdivisions give smooth silhouettes, bounded independently of strand settings.
	for pass_index in 2:
		var refined := PackedInt32Array()
		for i in range(0,_indices.size(),3):
			var a := _indices[i]; var b := _indices[i+1]; var c := _indices[i+2]
			var ab := _vertex((_skin[a]+_skin[b])*.5,(_normals[a]+_normals[b])*.5)
			var bc := _vertex((_skin[b]+_skin[c])*.5,(_normals[b]+_normals[c])*.5)
			var ca := _vertex((_skin[c]+_skin[a])*.5,(_normals[c]+_normals[a])*.5)
			refined.append_array(PackedInt32Array([a,ab,ca,ab,b,bc,ca,bc,c,ab,bc,ca]))
		_indices = refined
	var points := PackedVector3Array()
	for i in _skin.size(): points.append(_sculpt(_skin[i],_normals[i]))
	# Consistent outward winding, with a closed rim and inner shell at the scalp.
	var indices := PackedInt32Array()
	var edges := {}
	for i in range(0,_indices.size(),3):
		var a := _indices[i]; var b := _indices[i+1]; var c := _indices[i+2]
		var normal := (_skin[b]-_skin[a]).cross(_skin[c]-_skin[a])
		if a==b or b==c or c==a or normal.length_squared()<1e-24: continue
		if normal.dot(_normals[a]+_normals[b]+_normals[c])>0:
			var swap := b; b = c; c = swap
		indices.append_array(PackedInt32Array([a,b,c]))
		for edge in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			var key := Vector2i(mini(edge.x,edge.y),maxi(edge.x,edge.y))
			if edges.has(key): edges.erase(key)
			else: edges[key] = edge
	var outer_count := points.size()
	for i in _skin.size(): points.append(_skin[i]+_normals[i]*_width*.001)
	var outer_indices := indices.duplicate()
	for i in range(0,outer_indices.size(),3):
		indices.append_array(PackedInt32Array([outer_indices[i]+outer_count,outer_indices[i+2]+outer_count,outer_indices[i+1]+outer_count]))
	for edge: Vector2i in edges.values():
		indices.append_array(PackedInt32Array([edge.y,edge.x,edge.x+outer_count,edge.y,edge.x+outer_count,edge.y+outer_count]))
	var smooth := PackedVector3Array(); smooth.resize(points.size())
	for i in range(0,indices.size(),3):
		var a := indices[i]; var b := indices[i+1]; var c := indices[i+2]
		var n := (points[c]-points[a]).cross(points[b]-points[a])
		smooth[a] += n; smooth[b] += n; smooth[c] += n
	for i in points.size():
		points[i] = FLIP*points[i]
		smooth[i] = FLIP*smooth[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = smooth
	arrays[Mesh.ARRAY_INDEX] = indices
	var generated := ArrayMesh.new()
	generated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh = generated
	triangle_count = indices.size()/3
	_lookup.clear(); _skin.clear(); _normals.clear(); _indices.clear()

func _sculpt(p: Vector3, n: Vector3) -> Vector3:
	var q := (p-_center)/_width
	var taper := smoothstep(0,.12,_boundary(p))
	var top := smoothstep(.15,.75,-n.y)
	var length := float(_shape.hair_length)
	var volume := float(_shape.hair_volume)
	var height := .006
	match _shape.hair_style:
		"Afro":
			var bumps := sin(q.x*83+sin(q.z*25))*sin(q.y*77+sin(q.x*23))*sin(q.z*81+sin(q.y*27))
			height += length*(.6+volume*.65)*taper*(1+bumps*(.08+float(_shape.hair_frizz)*.18))
		"Mohawk":
			var half := float(_shape.hawk_width)*float(_shape.hair_width)*.5
			var ridge := sqrt(maxf(0,1-pow(q.x/maxf(half,.001),2)))
			height += length*(.7+volume)*taper*ridge*(.96+.04*sin(q.z*70))
			n = (n*.7+Vector3.UP*.3).normalized()
		_:
			var side := lerpf(.14,.7,float(_shape.hair_sides))
			var groove := exp(-pow((q.x-float(_shape.hair_part)+q.z*.12)*40,2))*.55*top
			var comb := .99+.01*sin((q.x-float(_shape.hair_sweep)*q.z*.7)*95+q.y*12)
			height += length*(.3+volume*.7)*lerpf(side,1.0,top)*taper*(1-groove)*comb
			p.x += float(_shape.hair_sweep)*length*_width*.2*top*taper
	return p+n*height*_width
