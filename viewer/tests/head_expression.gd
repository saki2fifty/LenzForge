extends SceneTree
const Surface = preload("res://tracking/head_surface.gd")
const Profile = preload("res://tracking/head_profile.gd")

func _initialize() -> void:
	var math: RefCounted = ClassDB.instantiate("HeadSurfaceMath")
	var neutral := Surface.canonical_points()
	var outline := PackedInt32Array(Surface.OUTLINE)
	assert(math.set_reference(neutral))
	var baseline: PackedVector3Array = math.build_stable(neutral,outline,20,.7,.3,1.1,1.0)
	var max_error := 0.0
	for yaw in [0,60,-90,180,-135,45,0]:
		var pose := Basis(Vector3.UP,deg_to_rad(yaw))*Basis(Vector3.RIGHT,.2)*Basis(Vector3.BACK,-.15)
		var face := neutral.duplicate()
		for i in [10,151,9,338,109]: face[i].y -= 1.5
		for i in [152,377,400,13,14]: face[i].y += 2.0
		for i in [159,145,386,374]: face[i].y += .8
		for i in face.size(): face[i] = pose*face[i]*23+Vector3(320,240,10)
		var actual: PackedVector3Array = math.build_stable(face,outline,20,.7,.3,1.1,1.0)
		assert(actual.slice(0,478)==face,"Measured eyelids, forehead and mouth stay expressive")
		for i in range(478+72,actual.size()):
			max_error = maxf(max_error,actual[i].distance_to(pose*baseline[i]*23+Vector3(320,240,10)))
	assert(max_error<.002,"Cranium follows immediate pose without expression deformation or temporal lag")
	var modified := neutral.duplicate()
	modified[117] += Vector3(1.75,1.25,.5)
	var robust: PackedVector3Array = math.build_stable(modified,outline,20,.7,.3,1.1,1.0)
	for i in range(478+72,robust.size()): assert(robust[i].distance_to(baseline[i])<.1,"Reject local cheek outlier influence")
	var invalid := PackedVector3Array(); invalid.resize(478)
	assert(not math.set_reference(invalid),"Reject a degenerate reference")
	invalid = neutral.duplicate(); invalid[152] = invalid[10]
	assert(not math.set_reference(invalid),"Bad first-frame geometry cannot poison the skull cache")
	var calibrated := neutral.duplicate()
	calibrated[10].y -= .5
	assert(math.set_reference(calibrated))
	var changed: PackedVector3Array = math.build_stable(calibrated,outline,20,.7,.3,1.1,1.0)
	assert(changed!=baseline,"Changing only the reference invalidates the cached skull")
	var profile := {"version":2,"depth":.7,"crown":.3,"sides":1.1,"jaw":1.0,"views":5,"crown_observed":true,"reference":[]}
	var center := (calibrated[234]+calibrated[454])*.5
	var width := calibrated[234].distance_to(calibrated[454])
	for p in calibrated:
		var q: Vector3 = (p-center)/width
		profile.reference.append([q.x,q.y,q.z])
	assert(not Profile.validate(profile).is_empty())
	assert(not Profile.validate(JSON.parse_string(JSON.stringify(profile))).is_empty(),"Accept numeric versions from HTTP JSON")
	var surface := Surface.new()
	surface.set_personal_reference(Profile.reference_points(Profile.validate(profile)))
	surface.set_reference()
	assert(surface.personal_reference.size()==478 and surface.reference_id!=0)
	for i in 478: assert(surface.personal_reference[i].distance_to(calibrated[i])<.00001)
	profile.reference[454] = profile.reference[234]
	assert(Profile.validate(profile).is_empty(),"Reject collapsed profile geometry")
	print("HEAD_EXPRESSION max_error_pixels=",max_error)
	quit()
