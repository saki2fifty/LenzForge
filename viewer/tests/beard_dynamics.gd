extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const ATTRIBUTES = [1, 4, 0, .8, 1, .3, .1, 1, .3, .1, .1, 1]
const ROOT = Vector2(100,100)
const STEP = 1.0/120.0
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func fixture_settings() -> Dictionary:
	# These dynamics comparisons use fixed lengths and damping, not UI defaults.
	var config := Profile.defaults()
	config.merge({"length":.45,"gravity":3.0,"damping":.025},true)
	return config

func solver_with(gravity: float, wind := 0.0, horizontal := false) -> RefCounted:
	var solver: RefCounted = ClassDB.instantiate("BeardSimulator")
	var config := fixture_settings()
	config.gravity = gravity; config.wind = wind; config.collisions = false
	config.preserve_shape = horizontal
	# A horizontal initial condition lets us measure falling speed, not initialization.
	var attributes := PackedFloat32Array(ATTRIBUTES)
	attributes[3] = 0
	solver.configure(1,8,config,attributes)
	solver.set_anchors(PackedVector2Array([ROOT]),200,Vector2.RIGHT if horizontal else Vector2.DOWN,Vector2.ZERO,Vector2.ONE)
	config.preserve_shape = false
	solver.configure(1,8,config,attributes)
	return solver

func simulate(solver: RefCounted, ticks: int) -> Vector2:
	for i in ticks: solver.advance(STEP)
	return solver.get_strand_points(0)[-1]

func turn(ticks: int, frame_ticks := 1) -> Dictionary:
	var solver := solver_with(3)
	var pivot := ROOT-Vector2(60,40)
	var endpoint := ROOT
	for frame in ticks/frame_ticks:
		var angle := .8*float((frame+1)*frame_ticks)/ticks
		endpoint = pivot+Vector2(60,40).rotated(angle)
		solver.set_anchors(PackedVector2Array([endpoint]),200,Vector2.DOWN.rotated(angle),Vector2.ZERO,Vector2.ONE)
		solver.advance(STEP*frame_ticks)
	var tip: Vector2 = solver.get_strand_points(0)[-1]
	var after := simulate(solver,1200)
	return {"deflection":absf(tip.x-endpoint.x), "settled":absf(after.x-endpoint.x), "tip":tip,
		"length_error":solver.get_max_length_error(), "root":solver.get_strand_points(0)[0], "target":endpoint}

func _initialize() -> void:
	var solver := solver_with(3)
	var config := fixture_settings()
	config.collisions = false; config.turbulence = 5; config.stiffness = 1
	solver.configure(1,8,config,PackedFloat32Array(ATTRIBUTES))
	solver.set_anchors(PackedVector2Array([ROOT]),200,Vector2.RIGHT,Vector2.ZERO,Vector2.ONE)
	var stationary := simulate(solver,1200)
	check(absf(stationary.x-ROOT.x) < .01 and absf(stationary.y-ROOT.y-90) < .01,
		"Still head and zero wind must hang vertically, even with old curl/stiffness/gust settings")
	check(stationary.distance_to(simulate(solver,120)) < .01, "Zero wind must produce no idle animation")
	var weak_fall := simulate(solver_with(1,0,true),60)
	var strong_fall := simulate(solver_with(8,0,true),60)
	check(strong_fall.y > weak_fall.y+5, "Stronger gravity must accelerate falling")
	check(simulate(solver_with(0,0,true),1200).is_equal_approx(ROOT+Vector2(90,0)),
		"With gravity and wind disabled, no artificial spring may pull the strand down")
	var styled := solver_with(3,0,true)
	config = fixture_settings(); config.collisions = false; config.preserve_shape = true
	styled.configure(1,8,config,PackedFloat32Array(ATTRIBUTES))
	check(simulate(styled,600).x > ROOT.x+50, "Explicit shape preservation must still hold a styled beard")
	var light_wind := simulate(solver_with(3,1),1200)
	var strong_wind := simulate(solver_with(3,4),1200)
	check(strong_wind.x > light_wind.x+10, "Stronger wind must deflect the same beard farther")
	var strong_gravity := simulate(solver_with(9,4),1200)
	check(strong_gravity.x < strong_wind.x-10, "Stronger gravity must resist the same wind more")
	check(strong_wind.distance_to(ROOT+Vector2(4,3).normalized()*90) < 1,
		"Steady wind and gravity must settle along their combined acceleration")
	solver = solver_with(3,4)
	simulate(solver,600)
	config = fixture_settings(); config.collisions = false
	solver.configure(1,8,config,PackedFloat32Array(ATTRIBUTES))
	var wind_stopped := simulate(solver,1200)
	check(absf(wind_stopped.x-ROOT.x) < 1, "Stopping wind must return the beard to vertical")
	var stopped_points: PackedVector2Array = solver.get_strand_points(0)
	for i in stopped_points.size():
		check(stopped_points[i].distance_to(ROOT+Vector2(0,90.0*i/8)) < 1,
			"Every segment must settle downward after wind stops")
	check(simulate(solver,120).distance_to(wind_stopped) < .1, "Settled strands must remain still")
	var slow := turn(240)
	var fast := turn(30)
	check(fast.deflection > slow.deflection+5, "Faster head turns must produce more inertial deflection")
	check(fast.settled < 1 and slow.settled < 1, "Stopped head must settle vertically despite its tilt")
	check(fast.root.is_equal_approx(fast.target), "Root must follow the face through a turn")
	check(fast.length_error < .001, "Turning must not stretch the strand")
	var at_60 := turn(120,2)
	var at_30 := turn(120,4)
	var at_120 := turn(120)
	check(at_60.tip.distance_to(at_120.tip) < 1 and at_30.tip.distance_to(at_120.tip) < 1,
		"Motion response must agree across 30/60/120 Hz frame delivery")
	print("BEARD_DYNAMICS ", JSON.stringify({"weak_fall":weak_fall.y-ROOT.y,"strong_fall":strong_fall.y-ROOT.y,
		"light_wind":light_wind.x-ROOT.x,"strong_wind":strong_wind.x-ROOT.x,"strong_gravity":strong_gravity.x-ROOT.x,
		"slow_turn":slow.deflection,"fast_turn":fast.deflection,"settled_turn":fast.settled,
		"settled_slow_turn":slow.settled,"wind_stopped":wind_stopped.x-ROOT.x,
		"fps_difference":at_30.tip.distance_to(at_120.tip),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
