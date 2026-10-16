extends RefCounted
const Head = preload("res://beard/virtual_head.gd")
## Procedural root regions and rest guides, all expressed in tracked face widths.
const MOTIONS := ["Free", "Styled", "Static"]
const HAIR_STYLES := ["None", "Regular", "Mohawk", "Afro"]
const MUSTACHE_STYLES := ["Natural", "Chevron", "Handlebar", "Walrus"]
const BROW_STYLES := ["Natural", "Straight", "Arched", "Bushy"]
const NUMBERS := {
	"chin_extension":[0,.8], "jaw_expansion":[0,.5], "ear_reach":[0,.6], "sideburn_height":[0,1],
	"virtual_columns":[8,48], "virtual_rows":[2,10], "crown_height":[0,.8], "crown_width":[.6,1.8],
	"crown_back":[0,1], "side_back":[0,.8], "chin_back":[0,.5],
	"root_layers":[1,6], "coverage_fill":[0,1],
	"mustache_width":[.4,2], "mustache_thickness":[.2,3], "mustache_density":[0,3],
	"mustache_length":[.005,.6], "mustache_lift":[-.08,.15], "mustache_curl":[0,1], "mustache_hold":[0,1],
	"brow_count":[16,256], "brow_width":[.5,1.6], "brow_thickness":[.005,.12], "brow_arch":[-.05,.15],
	"brow_length":[.01,.2], "brow_lift":[-.1,.15], "brow_angle":[-1,1], "brow_hold":[0,1],
	"hair_count":[32,768], "hair_length":[.02,1.5], "hair_width":[.5,1.5], "hair_volume":[0,1],
	"hairline":[-.2,.25], "hair_sweep":[-1,1], "hair_part":[-.4,.4], "hair_sides":[0,1],
	"hawk_width":[.04,.6], "hair_curl":[0,1], "hair_coils":[1,6], "hair_clump":[0,1],
	"hair_frizz":[0,1], "hair_variation":[0,.8], "hair_hold":[0,1],
	"mustache_root_width":[.1,12], "mustache_tip_width":[0,12],
	"brow_root_width":[.1,12], "brow_tip_width":[0,12], "hair_root_width":[.1,12], "hair_tip_width":[0,12]
}
const INTEGERS := ["root_layers", "brow_count", "hair_count", "virtual_columns", "virtual_rows"]
const BOOLEANS := ["beard_visible", "mustache_enabled", "brow_enabled", "show_generated_roots", "virtual_enabled", "show_virtual_landmarks"]
const ENUMS := {"mustache_style":MUSTACHE_STYLES, "brow_style":BROW_STYLES, "hair_style":HAIR_STYLES,
	"mustache_motion":MOTIONS, "brow_motion":MOTIONS, "hair_motion":MOTIONS}
const COLORS := ["generated_root_color", "mustache_color", "mustache_tip_color", "brow_color", "hair_color", "hair_tip_color", "virtual_color"]

static func defaults(style: String) -> Dictionary:
	return {"virtual_enabled":false,"show_virtual_landmarks":true,"virtual_color":"ffbf69ff",
		"virtual_columns":24,"virtual_rows":4,"crown_height":.42,"crown_width":1.08,"crown_back":.35,"side_back":.3,"chin_back":.05,
		"beard_visible":true, "chin_extension":0.0, "jaw_expansion":0.0, "ear_reach":0.0,
		"sideburn_height":0.0, "root_layers":3, "coverage_fill":.45, "show_generated_roots":true,
		"generated_root_color":"ed8bffff", "mustache_enabled":style in ["Full beard","Mustache"],
		"mustache_style":"Natural", "mustache_width":1.0, "mustache_thickness":1.0, "mustache_density":1.0,
		"mustache_length":.15, "mustache_lift":0.0, "mustache_curl":.25, "mustache_motion":"Free", "mustache_hold":.7,
		"mustache_root_width":2.4, "mustache_tip_width":.25, "mustache_color":"302019ff", "mustache_tip_color":"302019ff",
		"brow_enabled":false, "brow_style":"Natural", "brow_count":96, "brow_width":1.0, "brow_thickness":.025,
		"brow_arch":.025, "brow_length":.045, "brow_lift":0.0, "brow_angle":.2, "brow_motion":"Static", "brow_hold":.8,
		"brow_root_width":2.0, "brow_tip_width":.15, "brow_color":"302019ff",
		"hair_style":"None", "hair_count":512, "hair_length":.32, "hair_width":1.0, "hair_volume":.35,
		"hairline":0.0, "hair_sweep":.65, "hair_part":-.2, "hair_sides":.4, "hawk_width":.18,
		"hair_curl":.08, "hair_coils":3.0, "hair_clump":.35, "hair_frizz":.08, "hair_variation":.2,
		"hair_motion":"Styled", "hair_hold":.65, "hair_root_width":3.0, "hair_tip_width":.35,
		"hair_color":"302019ff", "hair_tip_color":"77513aff"}

static func normalized(config: Dictionary) -> Dictionary:
	var result := defaults(config.get("style","Full beard"))
	# Old files used the beard's color, widths, length, and motion for the mustache.
	for mapping in [["mustache_color","root_color"],["mustache_tip_color","tip_color"],
		["mustache_root_width","root_width"],["mustache_tip_width","tip_width"],["mustache_curl","curl"],["mustache_hold","stiffness"]]:
		if not config.has(mapping[0]) and config.has(mapping[1]): result[mapping[0]] = config[mapping[1]]
	if not config.has("mustache_length"): result.mustache_length = float(config.get("length",.45))*.365
	if not config.has("mustache_motion"): result.mustache_motion = "Styled" if config.get("preserve_shape",false) else "Free"
	result.merge(config,true)
	return result

static func validate(config: Dictionary) -> String:
	for key in NUMBERS:
		if not config.has(key): continue
		var value = config[key]
		if not (value is int or value is float) or not is_finite(float(value)) or value < NUMBERS[key][0] or value > NUMBERS[key][1]:
			return "Invalid grooming setting: " + key
		if key in INTEGERS and float(value) != floor(float(value)): return "Use a whole number for " + key
	for key in BOOLEANS:
		if config.has(key) and not config[key] is bool: return "Invalid grooming switch: " + key
	for key in ENUMS:
		if config.has(key) and not config[key] in ENUMS[key]: return "Unknown grooming option: " + key
	for key in COLORS:
		if config.has(key) and (not config[key] is String or config[key].length() not in [6,8] or not Color.html_is_valid(config[key])):
			return "Invalid grooming color: " + key
	return ""

static func valid_id(id: String, config: Dictionary) -> bool:
	if id.is_valid_int(): return id == str(int(id)) and int(id) >= 0 and int(id) < int(config.strands)
	var pieces := id.split(":")
	if pieces.size() != 2 or not pieces[1].is_valid_int() or str(int(pieces[1])) != pieces[1]: return false
	var count := int(config.get("brow_count",96)) if pieces[0] == "brow" else int(config.get("hair_count",512)) if pieces[0] == "hair" else 0
	return int(pieces[1]) >= 0 and int(pieces[1]) < count

static func hair_preset(style: String) -> Dictionary:
	match style:
		"Mohawk": return {"hair_style":style,"hair_length":.4,"hair_volume":.65,"hair_sweep":0.0,"hair_curl":.03,"hair_frizz":.05,"hair_clump":.7,"hair_sides":0.0,"hair_hold":.85,"hair_motion":"Styled"}
		"Afro": return {"hair_style":style,"hair_length":.45,"hair_volume":.65,"hair_sweep":0.0,"hair_curl":.9,"hair_coils":1.75,"hair_frizz":.15,"hair_clump":.15,"hair_sides":1.0,"hair_hold":.9,"hair_motion":"Styled"}
		"Regular": return {"hair_style":style,"hair_length":.32,"hair_volume":.35,"hair_sweep":.65,"hair_curl":.08,"hair_frizz":.08,"hair_clump":.35,"hair_sides":.4,"hair_hold":.65,"hair_motion":"Styled"}
	return {"hair_style":"None"}

static func virtual_preset() -> Dictionary:
	return {"virtual_enabled":true,"show_virtual_landmarks":true,"show_generated_roots":false,
		"crown_height":.42,"crown_width":1.08,"crown_back":.35,"side_back":.3,"chin_back":.05,
		"chin_extension":.18,"jaw_expansion":.08,"ear_reach":.15,"sideburn_height":1.0,"coverage_fill":.6}

static func extend_beard(binding: Dictionary, config: Dictionary, rng: RandomNumberGenerator) -> void:
	if binding.region == "mustache": return
	if rng.randf() >= float(config.coverage_fill): return
	var reach := float(config.ear_reach)
	var height := float(config.sideburn_height)
	var chin := float(config.chin_extension)
	var jaw := float(config.jaw_expansion)
	var back := float(config.side_back) if config.virtual_enabled else 0.0
	var under := float(config.chin_back) if config.virtual_enabled else 0.0
	if maxf(maxf(reach,height),maxf(chin,jaw)) <= 0 and maxf(back,under) <= 0: return
	var layer := (rng.randi_range(0,int(config.root_layers)-1)+.5+rng.randf_range(-.18,.18))/float(config.root_layers)
	var side := -1.0 if rng.randf() < .5 else 1.0
	var t := rng.randf()
	if (reach > 0 or height > 0 or back > 0) and rng.randf() < .45:
		var path := [93,234,127] if side < 0 else [323,454,356]
		var along := t*(.15+height*1.85)
		var segment := mini(1,int(along))
		binding.indices = Vector3i(path[segment],path[segment+1],path[segment])
		binding.weights = Vector3(1-fmod(along,1.0),fmod(along,1.0),0)
		binding.offset = Vector2(side*(reach*layer+jaw*.25),0)
		binding.zone = "Ear / sideburn"
		if config.virtual_enabled:
			Head.bind_root(binding,"left_side" if side < 0 else "right_side",Vector2(t,layer),config)
	else:
		var path := [172,136,150,152,379,365,397]
		var along := t*(path.size()-1)
		var segment := mini(path.size()-2,int(along))
		binding.indices = Vector3i(path[segment],path[segment+1],path[segment])
		binding.weights = Vector3(1-fmod(along,1.0),fmod(along,1.0),0)
		binding.offset = Vector2((t*2-1)*jaw*layer,chin*layer*(1-absf(t*2-1)*.5))
		binding.zone = "Chin / jaw"
		if config.virtual_enabled: Head.bind_root(binding,"chin",Vector2(t,layer),config)
	binding.synthetic = true

static func append_regions(config: Dictionary, bindings: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.seed)+83219
	if config.brow_enabled:
		for i in int(config.brow_count):
			var side := -1.0 if i%2 == 0 else 1.0
			var path := [70,63,105,66,107] if side < 0 else [300,293,334,296,336]
			var t := rng.randf()
			var segment := mini(3,int(t*4))
			bindings.append({"id":"brow:%d"%i,"region":"brow","zone":"Eyebrow","synthetic":true,
				"indices":Vector3i(path[segment],path[segment+1],path[segment]),"weights":Vector3(1-fmod(t*4,1),fmod(t*4,1),0),
				"offset":Vector2.ZERO,"side":side,"u":t,"v":rng.randf()-.5,"length":1.0,"noise":rng.randf()})
	if config.hair_style != "None":
		for i in int(config.hair_count):
			var u := rng.randf()*2-1
			var v := rng.randf()
			var offset := Vector2.ZERO
			var direction := Vector2.UP
			if config.hair_style == "Mohawk":
				offset = Vector2(u*float(config.hawk_width)*.5,.08-v*.2)
				direction = Vector2(u*.35,-1).normalized()
			elif config.hair_style == "Afro":
				var angle := -.12+(u+1)*(PI+.24)*.5
				var radius := lerpf(.3,1.0,v)
				offset = Vector2(cos(angle)*.48*radius,.2-sin(angle)*.48*radius)
				direction = Vector2(cos(angle),-sin(angle)).normalized()
			else:
				offset = Vector2(u*.49,lerpf(-.25*sqrt(1-u*u),.04,v)+u*u*.22)
				direction = Vector2(float(config.hair_sweep)*.8+signf(u-float(config.hair_part))*.25,-.7).normalized()
			offset.x *= float(config.hair_width)
			offset.y += float(config.hairline)
			var binding := {"id":"hair:%d"%i,"region":"hair","zone":"Scalp (estimated)","synthetic":true,
				"indices":Vector3i(10,10,10),"weights":Vector3(1,0,0),"offset":offset,"direction":direction,
				"u":u,"v":v,"side":signf(u),"length":1.0,"noise":rng.randf()}
			if config.virtual_enabled:
				var across := u
				if config.hair_style == "Mohawk": across = u*float(config.hawk_width)/float(config.crown_width)
				elif config.hair_style == "Afro": across = cos(-.12+(u+1)*(PI+.24)*.5)
				binding.virtual_across = across
				Head.bind_root(binding,"scalp",Vector2((across+1)*.5,v),config)
			bindings.append(binding)

static func root_positions(config: Dictionary, bindings: Array, face: PackedVector2Array, dimensions: Vector2, virtual_points: PackedVector2Array = PackedVector2Array()) -> PackedVector2Array:
	var horizontal := (face[454]-face[234])*dimensions
	var width := horizontal.length()
	var right := horizontal.normalized()
	var down := Vector2(-right.y,right.x)
	var lip := face[0]*dimensions
	if config.get("virtual_enabled",false) and virtual_points.is_empty():
		virtual_points = Head.project(Head.build(config),face,dimensions,Head.frame(face,dimensions))
	var result := PackedVector2Array()
	result.resize(bindings.size())
	for i in bindings.size():
		var b: Dictionary = bindings[i]
		if b.has("virtual_cell") and not virtual_points.is_empty():
			result[i] = Head.interpolate(b,virtual_points)
			if b.region == "hair":
				result[i] += down*float(config.hairline)*width
				result[i] += right*width*float(b.virtual_across)*.5*float(config.crown_width)*(float(config.hair_width)-1)
			continue
		var ids: Vector3i = b.indices
		var w: Vector3 = b.weights
		var root := (face[ids.x]*w.x+face[ids.y]*w.y+face[ids.z]*w.z)*dimensions
		var offset: Vector2 = b.get("offset",Vector2.ZERO)
		if b.region == "mustache":
			var local := root-lip
			root = lip+right*local.dot(right)*float(config.mustache_width)+down*local.dot(down)*float(config.mustache_thickness)
			offset.y -= float(config.mustache_lift)
		elif b.region == "brow":
			var center := face[105 if b.side < 0 else 334]*dimensions
			root = center+(root-center)*float(config.brow_width)
			offset.y = float(b.v)*float(config.brow_thickness)-float(config.brow_lift)-sin(float(b.u)*PI)*float(config.brow_arch)
			if config.brow_style == "Straight":
				var outer := face[70 if b.side < 0 else 300]*dimensions
				var inner := face[107 if b.side < 0 else 336]*dimensions
				root = center+(outer.lerp(inner,float(b.u))-center)*float(config.brow_width)
			if config.brow_style == "Bushy": offset.y += float(b.v)*float(config.brow_thickness)
		result[i] = root+(right*offset.x+down*offset.y)*width
	return result

static func strand_settings(config: Dictionary, binding: Dictionary) -> Dictionary:
	var region: String = binding.region
	var result := {"length":float(config.length)*float(binding.length),"root_width":config.root_width,"tip_width":config.tip_width,
		"root_color":config.root_color,"tip_color":config.tip_color,"curl":config.curl,
		"mode":1 if config.get("preserve_shape",false) else 0,"hold":config.stiffness,"collision":config.collisions}
	if region == "beard":
		if not config.beard_visible: result.length = 0.0
		return result
	result.mode = MOTIONS.find(config[region+"_motion"])
	result.hold = config[region+"_hold"]
	result.root_width = config[region+"_root_width"]
	result.tip_width = config[region+"_tip_width"]
	result.root_color = config[region+"_color"]
	result.tip_color = config[region+"_tip_color"] if region in ["hair","mustache"] else result.root_color
	result.length = float(config[region+"_length"])
	result.collision = config.collisions if region == "mustache" else false
	result.curl = config.mustache_curl if region == "mustache" else config.hair_curl if region == "hair" else 0.0
	if region == "mustache":
		result.length *= float(binding.length)/.365
		if not config.mustache_enabled or float(config.mustache_density) <= 0: result.length = 0.0
	elif region == "hair":
		result.length *= (0.65+float(config.hair_volume)*.7)*(1-float(config.hair_variation)*float(binding.noise))
		if config.hair_style == "Regular": result.length *= lerpf(1.0,float(config.hair_sides),pow(absf(float(binding.u)),3))
	return result

static func root_depths(config: Dictionary, bindings: Array, face: PackedVector2Array, dimensions: Vector2, depth: PackedFloat32Array, virtual_depth: PackedFloat32Array) -> PackedFloat32Array:
	var basis := Head.frame(face,dimensions,depth)
	var result := Head.FaceFrame.depths(bindings,depth,dimensions,basis)
	if basis.is_empty(): return result
	var scale: float = basis.width/dimensions.x
	for i in bindings.size():
		var b: Dictionary = bindings[i]
		if b.has("virtual_cell") and not virtual_depth.is_empty():
			var c: Vector4i = b.virtual_cell
			var w: Vector4 = b.virtual_weights
			result[i] = virtual_depth[c.x]*w.x+virtual_depth[c.y]*w.y+virtual_depth[c.z]*w.z+virtual_depth[c.w]*w.w
			if b.region == "hair": result[i] += float(basis.down3.z)*float(config.hairline)*scale + float(basis.right3.z)*scale*float(b.virtual_across)*.5*float(config.crown_width)*(float(config.hair_width)-1)
		elif b.region == "mustache": result[i] -= float(basis.down3.z)*float(config.mustache_lift)*scale
		elif b.region == "brow": result[i] += float(basis.down3.z)*(float(b.v)*float(config.brow_thickness)-float(config.brow_lift)-sin(float(b.u)*PI)*float(config.brow_arch))*scale
	return result

static func procedural_steps(config: Dictionary, b: Dictionary, index: int, curl: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n := int(config.segments)
	var region: String = b.get("region","beard")
	var previous := Vector2.ZERO
	var total := 0.0
	for j in range(1,n+1):
		var t := float(j)/n
		var point := Vector2(0,t)
		if region == "hair":
			var direction: Vector2 = b.direction
			var normal := Vector2(-direction.y,direction.x)
			var phase := float(b.noise)*TAU
			# At least four samples per coil prevents aliases at low segment counts.
			var frequency := minf(float(config.hair_coils),n*.25)
			var angle := t*frequency*TAU+phase
			var coil := sin(angle)-sin(phase)
			var frizz := sin(j*2.399+phase)*float(config.hair_frizz)*.04*t
			var clump := snappedf(float(b.u),.2)-float(b.u)
			point = direction*t+normal*(coil*curl*.13*t+frizz)+Vector2(clump*float(config.hair_clump)*t*t,0)
			if config.hair_style == "Afro":
				# Coils wind around a short outward guide instead of opening into a fan.
				point = direction*(t*.5+(cos(phase)-cos(angle))*curl*.09)+normal*(coil*curl*.1+frizz)
				point += normal*clump*float(config.hair_clump)*t*t
			if config.hair_style == "Regular": point += Vector2(float(config.hair_sweep)*.35*t*t,.25*t*t)
		elif region == "brow":
			point = Vector2(float(b.side)*t,-(.3+float(config.brow_angle))*t)
			if config.brow_style == "Arched": point.y -= sin(t*PI)*.3
		elif region == "mustache":
			var side := float(b.get("side",1))
			match config.mustache_style:
				"Handlebar": point = Vector2(side*(t+.15*sin(t*PI)),.25*sin(t*PI)-curl*t*t)
				"Chevron": point = Vector2(side*t*.6,t)
				"Walrus": point = Vector2(side*t*.12,t)
				_: point = Vector2(side*t*.5,t*.65)
			if config.mustache_style != "Handlebar": point.x += side*sin(t*PI)*curl*.25
		else:
			var angle := sin(t*(2+curl*3)*TAU+sin(index*12.9898)*2)*curl*1.15
			point = previous+Vector2(-sin(angle),cos(angle))/n
		result.append(point-previous)
		total += result[-1].length()
		previous = point
	for j in result.size(): result[j] /= maxf(.00001,total)
	return result
