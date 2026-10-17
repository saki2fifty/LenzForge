extends SceneTree
## Exercise pose gating and asynchronous Skip/Cancel without a person's camera.
class Fixture extends "res://tracking/calibration_wizard.gd":
	var samples := 0
	var releases := 0
	var held := false
	var face: Array = []
	func _send(kind: String, _data := {}) -> void:
		assert(not busy,"Only one analysis request may be active")
		operation = kind
		request_generation = generation
		busy = true
		if not held: respond.call_deferred()
	func respond() -> void:
		if operation == "fit":
			_completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"profile":{"version":1,"depth":.8,"crown":.3,"sides":1.1,"jaw":1.08,"views":observations.size()}}).to_utf8_buffer())
			return
		samples += 1
		var target: Array = steps[stage]
		var packet := {"frame_id":samples,"face":face,"contour":[[200,100],[220,100],[240,100],[260,100],[280,100],[300,100],[320,100],[340,100]],"usable":true,"yaw":target[1],"pitch":target[2]}
		if samples <= 3: packet.yaw = 80 # Bad pose must not fill the progress bar.
		_completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify(packet).to_utf8_buffer())
	func _release_models() -> void:
		releases += 1
		begin_button.disabled = busy or running

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	var wizard := Fixture.new()
	studio.add_child(wizard)
	wizard.setup(studio)
	for i in 478: wizard.face.append([320.0,240.0,0.0])
	wizard.face[234] = [200.0,240.0,0.0]
	wizard.face[454] = [440.0,240.0,0.0]
	wizard.reveal.button_pressed = false
	wizard.open()
	wizard._begin()
	while wizard.samples < 3: await process_frame
	assert(wizard.stage==0 and wizard.stable==0,"Wrong poses cannot be accepted")
	var deadline := Time.get_ticks_msec()+20000
	while wizard.save_button.disabled and Time.get_ticks_msec()<deadline: await process_frame
	assert(not wizard.save_button.disabled,"Five steady poses complete the wizard")
	assert(wizard.observations.size()==5 and wizard.captures.size()==5)
	assert(studio.calibration_profile.is_empty(),"Review must not apply an unsaved draft")
	wizard._save()
	assert(studio.calibration_profile.views==5 and is_equal_approx(studio.occlusion.head_depth,.8))
	wizard.open()
	wizard.held = true
	wizard._begin()
	wizard._skip()
	assert(wizard.stage==0 and wizard.skip_pending and wizard.busy,"Skip waits for in-flight analysis")
	wizard.respond()
	assert(wizard.stage==1 and wizard.busy and not wizard.skip_pending)
	var releases := wizard.releases
	wizard._close()
	assert(wizard.busy and wizard.releases==releases,"Cancel defers cleanup until analysis finishes")
	wizard.open()
	wizard.respond()
	assert(not wizard.busy and wizard.releases==releases+1 and wizard.draft.is_empty(),"Reopening ignores the canceled response")
	assert(studio.calibration_profile.views==5,"Cancel retains the saved profile")
	print("CALIBRATION_WIZARD passed")
	quit()
