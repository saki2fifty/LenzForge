extends RefCounted
## Versioned, bounded data shared by the editor, library and interchange tools.
const VERSION := 2
const Groom = preload("res://beard/groom_regions.gd")
const STYLES := ["Full beard", "Goatee", "Mustache", "Sideburns"]
const LIMITS := {
	"strands": [16, 1024], "segments": [2, 16], "length": [.02, 1.5],
	"root_width": [0.1, 12.0], "tip_width": [0.0, 12.0], "gravity": [0.0, 12.0],
	"wind": [-10.0, 10.0], "turbulence": [0.0, 5.0], "damping": [0.0, .95],
	"stiffness": [0.0, 1.0], "curl": [0.0, 1.0], "variation": [0.0, .8], "seed": [0, 2147483647]
}
const OVERRIDE_LIMITS := {"length": [0.0, 3.0], "root_width": [.1, 12.0], "tip_width": [0.0, 12.0], "curl": [0.0, 1.0]}
# Each triangle uses stable MediaPipe face indices, a distribution weight and
# a length factor. No roots are placed inside the lips.
const CHEEKS := [[93, 132, 61, 1.0, .7], [132, 172, 61, 1.0, .85], [172, 136, 17, 1.3, 1.0],
	[136, 150, 17, 1.0, 1.1], [150, 152, 17, 1.0, 1.15], [323, 361, 291, 1.0, .7],
	[361, 397, 291, 1.0, .85], [397, 365, 17, 1.3, 1.0], [365, 379, 17, 1.0, 1.1], [379, 152, 17, 1.0, 1.15]]
const CHIN := [[61, 17, 150, 1.0, .85], [150, 17, 152, 1.0, 1.1], [17, 291, 379, 1.0, .85], [17, 379, 152, 1.0, 1.1]]
const MUSTACHE := [[2, 98, 61, 1.0, .38], [2, 61, 0, 1.0, .35], [2, 0, 291, 1.0, .35], [2, 291, 327, 1.0, .38]]
const SIDES := [[127, 234, 93, 1.0, .65], [356, 454, 323, 1.0, .65]]

static func defaults(style := "Full beard") -> Dictionary:
	var result := {"style": style, "strands": 512, "segments": 8, "length": .45,
		"root_width": 2.4, "tip_width": .25, "gravity": 3.0, "wind": 0.0, "turbulence": 0.0,
		"damping": .025, "stiffness": .4, "curl": .12, "variation": .25, "seed": 17, "preserve_shape": false,
		"collisions": true, "root_color": "302019ff", "tip_color": "77513aff"}
	match style:
		"Goatee": result.strands = 144; result.length = .5
		"Mustache": result.strands = 128; result.length = .3; result.stiffness = .7
		"Sideburns": result.strands = 128; result.length = .3
	result.merge(Groom.defaults(style))
	return result

static func document(name: String, config: Dictionary, overrides: Dictionary) -> Dictionary:
	return {"format": "lenzforge-beard", "version": VERSION, "name": name.strip_edges(),
		"settings": config.duplicate(true), "strands": overrides.duplicate(true)}

static func validate(data: Variant) -> String:
	if not data is Dictionary or data.get("format") != "lenzforge-beard" or (data.get("version") != 1 and data.get("version") != VERSION):
		return "This is not a supported LenzForge beard file."
	if not data.get("name") is String or data.name.strip_edges().is_empty() or data.name.length() > 80:
		return "Use a beard name between 1 and 80 characters."
	var config = data.get("settings")
	if not config is Dictionary or not config.get("style") in STYLES:
		return "Unknown beard style."
	var grooming_error := Groom.validate(config)
	if not grooming_error.is_empty(): return grooming_error
	for key in LIMITS:
		if not _number_in(config.get(key), LIMITS[key]):
			return "Invalid beard setting: " + key
		if key in ["strands", "segments", "seed"] and float(config[key]) != floor(float(config[key])):
			return "Use a whole number for " + key
	if not config.get("collisions") is bool:
		return "Invalid mouth collision setting."
	# Older documents open in free-hanging mode without discarding their style.
	if not config.get("preserve_shape", false) is bool:
		return "Invalid shape preservation setting."
	for key in ["root_color", "tip_color"]:
		if not _color_valid(config.get(key)):
			return "Invalid " + key
	var edits = data.get("strands", {})
	if not edits is Dictionary or edits.size() > int(config.strands)+int(config.get("brow_count",96))+int(config.get("hair_count",512)):
		return "Invalid strand edits."
	for index in edits:
		if not index is String or not Groom.valid_id(index,config):
			return "Invalid strand index."
		if not edits[index] is Dictionary:
			return "Invalid strand settings."
		for key in edits[index]:
			if key in OVERRIDE_LIMITS:
				if not _number_in(edits[index][key], OVERRIDE_LIMITS[key]): return "Invalid strand " + key
			elif key in ["root_color", "tip_color"]:
				if not _color_valid(edits[index][key]): return "Invalid strand color."
			elif key == "guide":
				if not _guide_valid(edits[index][key]): return "Invalid custom strand curve."
			else: return "Unknown strand setting: " + str(key)
	return ""

static func _guide_valid(guide: Variant) -> bool:
	if not guide is Array or guide.size() < 2 or guide.size() > 65: return false
	var previous := Vector2.ZERO
	var distance := 0.0
	for i in guide.size():
		if not guide[i] is Array or guide[i].size() != 2: return false
		for value in guide[i]:
			if not _number_in(value, [-4.0,4.0]): return false
		var point := Vector2(guide[i][0],guide[i][1])
		if i == 0 and point.length() > .0001: return false
		distance += point.distance_to(previous)
		previous = point
	return distance > .001 and distance <= 4

static func strand_steps(config: Dictionary, overrides: Dictionary, index: int, binding: Dictionary = {}) -> PackedVector2Array:
	var id: String = binding.get("id",str(index))
	var edit: Dictionary = overrides.get(id, {})
	var result := PackedVector2Array()
	var segments := int(config.segments)
	if edit.has("guide"):
		var guide: Array = edit.guide
		var lengths := PackedFloat32Array([0])
		for i in range(1,guide.size()):
			lengths.append(lengths[-1]+Vector2(guide[i][0]-guide[i-1][0],guide[i][1]-guide[i-1][1]).length())
		var previous := Vector2.ZERO
		var cursor := 1
		var total := 0.0
		for i in range(1,segments+1):
			var target := lengths[-1]*float(i)/segments
			while cursor < guide.size()-1 and lengths[cursor] < target: cursor += 1
			var weight := (target-lengths[cursor-1])/maxf(.00001,lengths[cursor]-lengths[cursor-1])
			var point := Vector2(guide[cursor-1][0],guide[cursor-1][1]).lerp(Vector2(guide[cursor][0],guide[cursor][1]),weight)
			result.append(point-previous)
			total += result[-1].length()
			previous = point
		for i in result.size(): result[i] /= maxf(total,.0001)
	else:
		var normalized := config if config.has("hair_style") else Groom.normalized(config)
		var region_settings := Groom.strand_settings(normalized,binding) if not binding.is_empty() else {"curl":config.curl}
		result = Groom.procedural_steps(normalized,binding,index,float(edit.get("curl",region_settings.curl)))
	return result

static func with_geometry(data: Dictionary) -> Dictionary:
	# Export neutral guides, never a captured face or the current camera pose.
	var result := data.duplicate(true)
	var config := Groom.normalized(data.settings)
	var bindings := all_anchors(config)
	var face := mannequin()
	var dimensions := Vector2(1280,720)
	var scale := ((face[454]-face[234])*dimensions).length()
	var roots := Groom.root_positions(config,bindings,face,dimensions)
	var guides: Array = []
	for i in bindings.size():
		var a: Dictionary = bindings[i]
		var root := (roots[i]-dimensions*.5)/scale
		var edit: Dictionary = data.get("strands",{}).get(a.id,{})
		var regional := Groom.strand_settings(config,a)
		var length: float = float(regional.length)*float(edit.get("length",1.0))
		var points: Array = [[root.x, -root.y, 0.0]]
		var point := root
		for step in strand_steps(config,data.get("strands",{}),i,a):
			point += step*length
			points.append([point.x,-point.y,0.0])
		guides.append({"index":a.id,"region":a.region,"points":points,"base_length":maxf(.0001,float(regional.length)),
			"root_width":float(edit.get("root_width",regional.root_width))/300.0,
			"tip_width":float(edit.get("tip_width",regional.tip_width))/300.0})
	result["geometry"] = {"units":"face-width", "axis":"X right, Y up, Z depth; 2D guides", "guides":guides}
	return result

static func _number_in(value: Variant, bounds: Array) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= bounds[0] and value <= bounds[1]

static func _color_valid(value: Variant) -> bool:
	return value is String and value.length() in [6, 8] and Color.html_is_valid(value)

static func anchors(config: Dictionary) -> Array:
	config = Groom.normalized(config)
	var triangles: Array = CHEEKS.duplicate(true)
	match config.style:
		"Goatee": triangles = CHIN.duplicate(true)
		"Mustache": triangles = []
		"Sideburns": triangles = SIDES.duplicate(true)
	if config.mustache_enabled or config.style == "Mustache":
		for triangle in MUSTACHE:
			var item: Array = triangle.duplicate()
			item[3] *= float(config.mustache_density)
			triangles.append(item)
	var total := 0.0
	for triangle in triangles: total += triangle[3]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.seed)
	var extension_rng := RandomNumberGenerator.new()
	extension_rng.seed = int(config.seed)+1919
	var result: Array = []
	for index in int(config.strands):
		var choice := rng.randf() * total
		var triangle: Array = triangles[-1]
		for candidate in triangles:
			choice -= candidate[3]
			if choice <= 0: triangle = candidate; break
		var u := sqrt(rng.randf())
		var v := rng.randf()
		var noise := rng.randf()
		var mustache: bool = triangle[0] == 2
		var binding := {"id":str(index),"region":"mustache" if mustache else "beard","zone":"Mustache" if mustache else "Beard",
			"synthetic":mustache and (not is_equal_approx(config.mustache_width,1) or not is_equal_approx(config.mustache_thickness,1) or config.mustache_lift != 0),
			"offset":Vector2.ZERO,"side":-1.0 if triangle[1] in [98,61] else 1.0,
			"indices": Vector3i(triangle[0], triangle[1], triangle[2]),
			"weights": Vector3(1-u, u*(1-v), u*v), "noise":noise,"length": triangle[4] * (1.0 - float(config.variation)*noise)}
		Groom.extend_beard(binding,config,extension_rng)
		result.append(binding)
	return result

static func all_anchors(config: Dictionary) -> Array:
	var normalized := Groom.normalized(config)
	var result := anchors(normalized)
	Groom.append_regions(normalized,result)
	return result

static func mannequin() -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(478)
	points.fill(Vector2(.5, .48))
	var positions := {127: [.32,.3], 234: [.30,.43], 93: [.32,.51], 132: [.34,.58], 172: [.37,.65],
		136: [.40,.69], 150: [.45,.72], 152: [.5,.74], 379: [.55,.72], 365: [.60,.69],
		397: [.63,.65], 361: [.66,.58], 323: [.68,.51], 454: [.70,.43], 356: [.68,.3],
		61: [.41,.56], 291: [.59,.56], 0: [.5,.54], 17: [.5,.60], 2: [.5,.49], 98: [.44,.49], 327: [.56,.49],
		10:[.5,.30], 70:[.37,.405],63:[.405,.38],105:[.44,.37],66:[.47,.385],107:[.485,.405],
		300:[.63,.405],293:[.595,.38],334:[.56,.37],296:[.53,.385],336:[.515,.405]}
	var outline: Array = preload("res://tracking/face_extensions.gd").OUTLINE
	for i in outline.size():
		if positions.has(outline[i]): continue
		var before := i-1
		var after := i+1
		while not positions.has(outline[posmod(before,outline.size())]): before -= 1
		while not positions.has(outline[after%outline.size()]): after += 1
		var a: Array = positions[outline[posmod(before,outline.size())]]
		var b: Array = positions[outline[after%outline.size()]]
		var point := Vector2(a[0],a[1]).lerp(Vector2(b[0],b[1]),float(i-before)/(after-before))
		positions[outline[i]] = [point.x,point.y]
	for index in positions: points[index] = Vector2(.5 + (positions[index][0] - .5) * .65, positions[index][1])
	return points
