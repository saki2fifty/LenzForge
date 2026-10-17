extends Window
## Separate, local calibration view. It never changes the live tracking cadence.
const Profile = preload("res://tracking/head_profile.gd")
const STEPS := [
	["Face forward",0,0,"Relax your expression and keep your whole head in view.","all"],
	["Turn toward ←",30,0,"Turn slowly until your nose points left in this preview.","all"],
	["Turn toward →",-30,0,"Turn slowly until your nose points right in this preview.","all"],
	["Look slightly up",0,18,"Raise your chin gently; keep your face visible.","all"],
	["Look slightly down",0,-18,"Lower your chin gently; keep your eyes visible.","all"]]
var host: Control
var request := HTTPRequest.new()
var cleanup := HTTPRequest.new()
var heading: Label
var instruction: Label
var feedback: Label
var progress := ProgressBar.new()
var preview := Preview.new()
var pose_guide := PoseGuide.new()
var view_picker := OptionButton.new()
var reveal := CheckBox.new()
var begin_button: Button
var skip_button: Button
var save_button: Button
var review_box := VBoxContainer.new()
var controls := {}
var steps: Array = []
var observations: Array = []
var captures: Array[Dictionary] = []
var latest: Dictionary = {}
var draft: Dictionary = {}
var stage := -1
var stable := 0
var last_id := -1
var previous := Vector3.ZERO
var operation := ""
var busy := false
var running := false
var generation := 0
var request_generation := 0
var skip_pending := false
var releasing := false

func setup(studio: Control) -> void:
	host = studio
	title = "Calibrate head"
	transient = true
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	visible = false
	min_size = Vector2i(620,500)
	close_requested.connect(_close)
	add_child(request)
	add_child(cleanup)
	request.timeout = 90
	cleanup.timeout = 90
	request.request_completed.connect(_completed)
	cleanup.request_completed.connect(func(_result,_code,_headers,_body):
		releasing = false
		begin_button.disabled = busy or running)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation",10)
	margin.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	scroll.add_child(column)
	heading = host._label("Personalize your head shape",20)
	column.add_child(heading)
	instruction = host._label("Start camera capture first. We collect five steady views and fit exposed head contours. Hair-covered regions remain estimates. All analysis stays on this computer.",13)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(instruction)
	pose_guide.custom_minimum_size = Vector2(100,70)
	column.add_child(pose_guide)
	preview.custom_minimum_size = Vector2(580,270)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(preview)
	reveal.text = "Add optional hair / beard reveal steps"
	reveal.button_pressed = true
	column.add_child(reveal)
	feedback = host._label("Green: exposed contour · orange boxes: detected hands · blue: fitted outline",12,host.MUTED)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(feedback)
	progress.max_value = 6
	progress.show_percentage = false
	column.add_child(progress)
	column.add_child(review_box)
	review_box.add_child(view_picker)
	view_picker.item_selected.connect(func(index):
		preview.packet = captures[index]
		preview.load_frame())
	for entry in [["depth","Head depth"],["crown","Crown height"],["sides","Side fullness"],["jaw","Under-jaw fullness"]]:
		var key: String = entry[0]
		var limits: Array = Profile.LIMITS[key]
		controls[key] = host._slider(review_box,entry[1],limits[0],limits[1],.005,limits[0],func(value):
			draft[key] = value
			preview.profile = draft
			preview.queue_redraw())
	review_box.hide()
	var actions := HFlowContainer.new()
	outer.add_child(actions)
	begin_button = host._button("Start calibration",_begin,true)
	actions.add_child(begin_button)
	skip_button = host._button("Skip this view",_skip)
	actions.add_child(skip_button)
	save_button = host._button("Save head fit",_save,true)
	actions.add_child(save_button)
	actions.add_child(host._button("Reset saved fit",func(): host.apply_calibration({}); _close()))
	actions.add_child(host._button("Cancel",_close))
	skip_button.disabled = true
	save_button.disabled = true

func open() -> void:
	if not running and draft.is_empty():
		pose_guide.pose = Vector2.ZERO
		pose_guide.queue_redraw()
		pose_guide.show()
		reveal.show()
		progress.show()
		heading.text = "Personalize your head shape"
		instruction.text = "Start camera capture first. Follow the illustrated poses, keeping your whole head visible. Optional reveal steps help when hair covers the outline. Covered areas remain estimates; all analysis stays local."
		begin_button.disabled = busy or releasing
		feedback.text = "Finishing earlier analysis…" if busy or releasing else "Green: exposed contour · orange boxes: detected hands · blue: fitted outline"
	popup_centered(Vector2i(mini(800,host.get_window().size.x-40),mini(740,host.get_window().size.y-40)))

func _begin() -> void:
	if busy or releasing: return
	generation += 1
	running = true
	stage = 0
	steps = STEPS.duplicate(true)
	if reveal.button_pressed:
		steps.append(["Reveal forehead and crown",0,0,"Gently hold hair back from the forehead and temples. Keep fingers behind the contour. Skip if the scalp stays covered.","top"])
		steps.append(["Reveal left jaw",30,0,"Gently move beard hair aside to expose the jaw. Avoid pressing or pulling the skin; keep fingers away from the edge. Skip if it stays covered.","jaw"])
		steps.append(["Reveal right jaw",-30,0,"Repeat on the other side. Green marks usable skin outline; orange boxes exclude detected hands. Covered areas remain estimated.","jaw"])
	observations.clear()
	draft = {}
	latest = {}
	pose_guide.show()
	reveal.show()
	progress.show()
	captures.clear()
	view_picker.clear()
	skip_pending = false
	preview.profile = {}
	review_box.hide()
	save_button.disabled = true
	begin_button.disabled = true
	skip_button.disabled = false
	reveal.disabled = true
	_next()

func _next() -> void:
	stable = 0
	last_id = -1
	progress.value = 0
	previous = Vector3(999,999,0)
	if stage >= steps.size():
		running = false
		skip_button.disabled = true
		if observations.size() < 2:
			feedback.text = "At least two clear views are needed. Retry, or keep your existing fit."
			begin_button.disabled = false
			reveal.disabled = false
			_release_models()
			return
		heading.text = "Fitting your head…"
		_send("fit",{"observations":observations,"initial":[host.occlusion.head_depth,host.occlusion.crown,host.occlusion.surface.sides,host.occlusion.surface.jaw]})
		return
	heading.text = "%d / %d · %s" % [stage+1,steps.size(),steps[stage][0]]
	instruction.text = steps[stage][3]
	pose_guide.pose = Vector2(steps[stage][1],steps[stage][2])
	pose_guide.queue_redraw()
	feedback.text = "Preparing local analysis… First use downloads a verified 16 MB contour model."
	_send("sample")

func _skip() -> void:
	if not running: return
	generation += 1
	if busy:
		skip_pending = true
		skip_button.disabled = true
		feedback.text = "Finishing the current analysis before skipping…"
		return
	stage += 1
	_next()

func _send(kind: String, data := {}) -> void:
	if busy: return
	operation = kind
	request_generation = generation
	busy = true
	var error := request.request(host.backend_url+"/api/calibration/"+kind,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(data))
	if error != OK:
		busy = false
		running = false
		feedback.text = "Could not reach calibration: " + error_string(error)
		skip_button.disabled = true
		reveal.disabled = false
		_release_models()

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if not visible or (operation == "sample" and not running):
		_release_models()
		return
	if skip_pending:
		skip_pending = false
		skip_button.disabled = false
		stage += 1
		_next()
		return
	if request_generation != generation:
		_release_models()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not data is Dictionary:
		feedback.text = str(data.get("error","Calibration unavailable; check the backend.")) if data is Dictionary else "Calibration unavailable; check the backend."
		running = false
		begin_button.disabled = false
		skip_button.disabled = true
		reveal.disabled = false
		_release_models()
		return
	if operation == "fit":
		draft = Profile.validate(data.get("profile",{}))
		if draft.is_empty():
			feedback.text = "The fitted profile was invalid. Your saved fit is unchanged."
			begin_button.disabled = false
			_release_models()
			return
		for key in controls: controls[key].set_value_no_signal(draft[key])
		preview.profile = draft
		preview.queue_redraw()
		review_box.show()
		pose_guide.hide()
		reveal.hide()
		progress.hide()
		heading.text = "Review your head fit"
		instruction.text = "Compare the blue fit across your captured views and adjust if needed. Hidden scalp and jaw areas remain estimates; segmentation can miss facial hair or hands."
		feedback.text = "%d views captured. Save applies this surface to virtual landmarks, roots, objects, occlusion and collisions." % observations.size()
		save_button.disabled = false
		begin_button.disabled = false
		begin_button.text = "Recalibrate"
		reveal.disabled = false
		view_picker.select(captures.size()-1)
		_release_models()
		return
	latest = data
	preview.packet = data
	preview.load_frame()
	var target: Array = steps[stage]
	var yaw := float(data.get("yaw",999))
	var pitch := float(data.get("pitch",999))
	var face: Array = data.get("face",[])
	var enough := bool(data.get("usable",false)) and face.size() == 478
	var span := 1.0
	if face.size() == 478:
		span = Vector3(face[454][0]-face[234][0],face[454][1]-face[234][1],face[454][2]-face[234][2]).length()
		if target[4] != "all":
			var count := 0
			for point in data.contour:
				if (target[4] == "top" and point[1] < face[10][1]+span*.05) or (target[4] == "jaw" and point[1] > face[1][1]+span*.15): count += 1
			enough = enough and count >= 8
	var pose := Vector3(yaw,pitch,span)
	var aligned: bool = absf(yaw-float(target[1])) < 12 and absf(pitch-float(target[2])) < 12
	var steady := absf(pose.x-previous.x)<3 and absf(pose.y-previous.y)<3 and absf(pose.z-previous.z)<span*.035
	if int(data.get("frame_id",-1)) != last_id:
		stable = stable+1 if enough and aligned and steady else 0
		previous = pose
		last_id = int(data.frame_id)
	progress.value = stable
	feedback.text = "%s · yaw %.0f° / pitch %.0f°" % ["Hold steady…" if enough and aligned else "Follow the pose instruction." if enough else data.get("reason","Expose the target contour."),yaw,pitch]
	if stable >= 6:
		observations.append({"face":data.face,"contour":data.contour})
		captures.append(data)
		view_picker.add_item(steps[stage][0])
		stage += 1
		_next()
		return
	var token := generation
	await get_tree().create_timer(.25).timeout
	if visible and running and token == generation: _send("sample")

func _save() -> void:
	if not Profile.validate(draft).is_empty(): host.apply_calibration(draft)
	_close()

func _release_models() -> void:
	if releasing: return
	releasing = true
	begin_button.disabled = true
	if cleanup.request(host.backend_url+"/api/calibration/stop",[],HTTPClient.METHOD_POST) != OK:
		releasing = false
		begin_button.disabled = busy or running

func _close() -> void:
	running = false
	generation += 1
	# Let an in-flight sample finish before releasing its models. Cancelling the
	# HTTP client would leave analysis running on the server and race the next run.
	skip_pending = false
	if not busy: _release_models()
	hide()
	draft = {}
	latest = {}
	captures.clear()
	observations.clear()
	preview.packet = {}
	preview.texture = null
	preview.profile = {}
	preview.queue_redraw()
	review_box.hide()
	save_button.disabled = true
	begin_button.disabled = busy or releasing
	reveal.disabled = false
	skip_button.disabled = true

class PoseGuide extends Control:
	var pose := Vector2.ZERO
	func _draw() -> void:
		var center := Vector2(size.x*.5,34)
		var outline := PackedVector2Array()
		for i in 49:
			var angle := TAU*i/48.0
			outline.append(center+Vector2(cos(angle)*22,sin(angle)*28))
		draw_polyline(outline,Color("68dfc3"),2,true)
		var nose := center+Vector2(-pose.x*.5,-pose.y*.65)
		draw_circle(nose,3,Color("68dfc3"))
		for side in [-1,1]: draw_circle(center+Vector2(side*9-pose.x*.14,-7-pose.y*.2),2,Color("d6e2ee"))
		var direction := Vector2(-pose.x,-pose.y).normalized()
		if direction != Vector2.ZERO:
			var start := center+Vector2(65,0)
			var end := start+direction*25
			draw_line(start,end,Color("68dfc3"),3,true)
			draw_line(end,end-direction.rotated(.6)*10,Color("68dfc3"),3,true)
			draw_line(end,end-direction.rotated(-.6)*10,Color("68dfc3"),3,true)

class Preview extends Control:
	var packet: Dictionary = {}
	var profile: Dictionary = {}
	var texture: ImageTexture
	var math: RefCounted = ClassDB.instantiate("HeadSurfaceMath")
	func load_frame() -> void:
		var image := Image.new()
		var encoded := Marshalls.base64_to_raw(packet.get("image",""))
		if not encoded.is_empty() and image.load_jpg_from_buffer(encoded) == OK: texture = ImageTexture.create_from_image(image)
		queue_redraw()
	func _draw() -> void:
		if not texture: return
		var dimensions := Vector2(texture.get_width(),texture.get_height())
		var scale := minf(size.x/dimensions.x,size.y/dimensions.y)
		var origin := (size-dimensions*scale)*.5
		draw_texture_rect(texture,Rect2(origin,dimensions*scale),false)
		for p in packet.get("contour",[]): draw_circle(origin+Vector2(p[0],p[1])*scale,2,Color("68dfc3"))
		for box in packet.get("blocked",[]): draw_rect(Rect2(origin+Vector2(box[0],box[1])*scale,Vector2(box[2]-box[0],box[3]-box[1])*scale),Color("ffbf69"),false,2)
		if profile.is_empty() or packet.get("face",[]).size() != 478: return
		var face := PackedVector3Array()
		for p in packet.face: face.append(Vector3(p[0],p[1],p[2]))
		var head: PackedVector3Array = math.build(face,PackedInt32Array(preload("res://tracking/head_surface.gd").OUTLINE),20,profile.depth,profile.crown,profile.sides,profile.jaw)
		var projected := PackedVector2Array()
		for p in head: projected.append(origin+Vector2(p.x,p.y)*scale)
		var hull := Geometry2D.convex_hull(projected)
		if hull.size()>2: draw_polyline(hull,Color("64adff"),2,true)
