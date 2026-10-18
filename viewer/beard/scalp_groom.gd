extends RefCounted
## Configuration-time scalp coverage and spatial guides; no per-frame searches.
const Surface = preload("res://tracking/head_surface.gd")
const Groom = preload("res://beard/groom_regions.gd")

static func _clip(poly: Array, distances: Vector3) -> Array:
	var output := []
	if poly.is_empty(): return output
	var prior: Vector3 = poly[-1]
	var before := prior.dot(distances)
	for weight: Vector3 in poly:
		var after := weight.dot(distances)
		if (before>=0)!=(after>=0): output.append(prior.lerp(weight,before/(before-after)))
		if after>=0: output.append(weight)
		prior = weight; before = after
	return output

static func bindings(surface: RefCounted, config: Dictionary, anchors: Array) -> Dictionary:
	if config.hair_style == "None": return {}
	var vertices: PackedVector3Array = surface.build_reference()
	var triangles := Surface.topology()
	var center := (vertices[234]+vertices[454])*.5
	var width := vertices[234].distance_to(vertices[454])
	var patches := []
	var cumulative := PackedFloat64Array()
	var total := 0.0
	for i in range(0,triangles.size(),3):
		var ids := triangles.slice(i,i+3)
		var local := PackedVector3Array()
		var edge := Vector3.ZERO
		for j in 3:
			var p := (vertices[ids[j]]-center)/width
			local.append(p)
			# Higher frontal hairline, temples above the ears, lower at the back.
			var frontal := clampf((.08-p.z)/.35,0,1)
			var boundary := lerpf(.08,-.51,pow(frontal,.8))+float(config.hairline)
			boundary += (float(config.hair_width)*float(config.crown_width)/1.08-1)*.3*(1-frontal)
			boundary += (float(config.crown_height)-.42)*.35
			edge[j] = boundary-p.y
		var poly := _clip([Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1)],edge)
		var rear := lerpf(-.42,.72,clampf(float(config.crown_back)/.35,0,1))
		poly = _clip(poly,Vector3.ONE*rear-Vector3(local[0].z,local[1].z,local[2].z))
		if config.hair_style == "Mohawk":
			var x := Vector3(local[0].x,local[1].x,local[2].x)
			var half := float(config.hawk_width)*float(config.hair_width)*.5
			poly = _clip(_clip(poly,Vector3.ONE*half-x),Vector3.ONE*half+x)
		for j in range(1,poly.size()-1):
			var weights := PackedVector3Array([poly[0],poly[j],poly[j+1]])
			var points := PackedVector3Array()
			for w in weights: points.append(vertices[ids[0]]*w.x+vertices[ids[1]]*w.y+vertices[ids[2]]*w.z)
			var area := (points[1]-points[0]).cross(points[2]-points[0]).length()*.5
			if area<.000001: continue
			total += area
			cumulative.append(total)
			patches.append({"indices":ids,"weights":weights})
	var result := {}
	if patches.is_empty(): return result
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.seed)+60317
	for anchor in anchors:
		if anchor.region != "hair": continue
		var slot := mini(cumulative.bsearch(rng.randf()*total),patches.size()-1)
		var patch: Dictionary = patches[slot]
		var u := sqrt(rng.randf())
		var v := rng.randf()
		var w: Vector3 = patch.weights[0]*(1-u)+patch.weights[1]*(u*(1-v))+patch.weights[2]*(u*v)
		result[anchor.id] = {"indices":patch.indices,"weights":PackedVector3Array([w])}
	return result

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

static func guides(surface: RefCounted, config: Dictionary, anchors: Array, fitted: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := {}
	var vertices: PackedVector3Array = surface.build_reference()
	var roots: PackedVector3Array = surface.math.sample(vertices,fitted.indices,fitted.weights)
	var width := vertices[234].distance_to(vertices[454])
	var center := (vertices[234]+vertices[454])*.5+Vector3(0,-.12,.18)*width
	var n := int(config.segments)
	var targets := PackedVector3Array()
	var jobs := []
	for i in anchors.size():
		var b: Dictionary = anchors[i]
		if b.region == "hair": b.scalp_side = clampf(((roots[i].y-(vertices[234].y+vertices[454].y)*.5)/width+.45)/.5,0,1)
		var edit: Dictionary = overrides.get(b.id,{})
		if edit.has("guide3d"):
			result[b.id] = resample(edit.guide3d,n)
			continue
		if b.region != "hair" or edit.has("guide"): continue
		var root := roots[i]
		var normal := (root-center).normalized()
		var regional := Groom.strand_settings(config,b)
		var length := maxf(.001,float(regional.length)*float(edit.get("length",1.0)))*width
		var tangent := Vector3(float(config.hair_sweep)*.9+signf(root.x/width-float(config.hair_part))*.2,.15,.55)
		if absf(normal.x)>.65: tangent = Vector3(normal.x*.15,1,.4)
		tangent.x += (snappedf(root.x/width,.15)-root.x/width)*float(config.hair_clump)*2
		tangent = (tangent-normal*tangent.dot(normal)).normalized()
		var axis := normal.cross(tangent).normalized()
		var points := PackedVector3Array([root])
		var radius := root.distance_to(center)
		var phase := float(b.noise)*TAU
		var curl_amount := float(edit.get("curl",config.hair_curl))
		for j in range(1,n+1):
			var t := float(j)/n
			var curl := sin(t*minf(float(config.hair_coils),n*.25)*TAU+phase)-sin(phase)
			var p: Vector3
			if config.hair_style == "Regular":
				p = center+normal.rotated(axis,length*t/maxf(radius,.01))*radius
				p += axis*(curl*curl_amount*length*.08*t+sin(j*2.399+phase)*float(config.hair_frizz)*length*.04*t)
				targets.append(p)
			else:
				var direction := normal if config.hair_style == "Afro" else (normal*.6+Vector3.UP*.4).normalized()
				p = root+direction*(length*t*.8)+tangent*curl*curl_amount*length*.12
				p += axis*((cos(phase)-cos(t*minf(float(config.hair_coils),n*.25)*TAU+phase))*curl_amount*length*.12+sin(j*2.399+phase)*float(config.hair_frizz)*length*.04*t)
			points.append(p)
		if config.hair_style == "Regular": jobs.append({"id":b.id,"root":root,"normal":normal,"length":length})
		else:
			var steps := PackedVector3Array()
			for j in range(1,points.size()): steps.append((points[j]-points[j-1])/width)
			result[b.id] = normalize(steps)
	if not targets.is_empty():
		var nearest: Dictionary = surface.math.bind_nearest(vertices,Surface.topology(),targets)
		var skin: PackedVector3Array = surface.math.sample(vertices,nearest.indices,nearest.weights)
		for i in jobs.size():
			var job: Dictionary = jobs[i]
			var previous: Vector3 = job.root
			var steps := PackedVector3Array()
			for j in n:
				var p := skin[i*n+j]
				var outward := (p-center).normalized()
				p += outward*width*(.008+float(config.hair_volume)*.07)*sin(float(j+1)/n*PI*.7)
				steps.append((p-previous)/width); previous = p
			result[job.id] = normalize(steps)
	return result
