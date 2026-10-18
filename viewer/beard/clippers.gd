extends Control
## Screen-space blade, native depth picking/physics, persisted strand overrides.
signal changed
signal message(text: String)
signal preferences_changed
var host: Control
var active := false
var dragging := false
var mode := "Line"
var blade_width := 40.0
var buzzing := false
var cursor := Vector2.ZERO
var sampled := Vector2.ZERO
var cursor_visible := false
var buzz_time := 0.0
var notify_time := 0.0
var stroke_count := 0
var stroke_saved := false
var clipper_image: ImageTexture
var start := Vector2.ZERO
var finish := Vector2.ZERO
var history: Array[Dictionary] = []
var last_count := 0
var last_cut_ms := 0.0
var undo_button := Button.new()

func _ready() -> void:
	get_window().focus_exited.connect(cancel_stroke)

func setup(layer: Control) -> void:
	host = layer
	set_process(false)
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="116" viewBox="0 0 64 116"><path d="M4 6h56v18L46 38v60q0 14-14 14T18 98V38L4 24Z" fill="#182432" stroke="#9daeba" stroke-width="3"/><path d="M5 6h54v12H5Z" fill="#dbe5ec"/><path d="M8 1v11m8-11v11m8-11v11m8-11v11m8-11v11m8-11v11m8-11v11" stroke="#dbe5ec" stroke-width="4"/><rect x="24" y="45" width="16" height="29" rx="7" fill="#496075"/><path d="M25 88h14m-14 7h14" stroke="#8299aa" stroke-width="3"/></svg>')
	clipper_image = ImageTexture.create_from_image(image)
	host.mouse_exited.connect(func(): cursor_visible=false; cancel_stroke())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	undo_button.text = "Undo cut"
	undo_button.tooltip_text = "Restore the previous cut (Ctrl+Z). Up to 12 cuts; other grooming edits clear this history."
	undo_button.add_theme_font_size_override("font_size",12)
	undo_button.pressed.connect(undo)
	host.mannequin_toolbar.add_child(undo_button)
	_sync()

func set_active(value: bool) -> void:
	active = value and host.mannequin
	cancel_stroke()
	if active and not host.enabled: host.set_enabled(true)
	host._update_mouse()
	_sync()
	changed.emit()
	if active: message.emit("Buzz: hold left click to run the clippers; the teeth cut on contact. Right-drag rotates; Ctrl+Z undoes a stroke." if mode=="Buzz" else "Clippers: drag a start-to-finish line across visible hair. Right-drag rotates; wheel zooms; Ctrl+Z undoes.")

func set_mode(value: String) -> void:
	if not value in ["Line","Buzz"]: return
	cancel_stroke()
	mode = value
	preferences_changed.emit()
	set_active(host.mannequin)

func set_blade_width(value: float) -> void:
	if not is_finite(value): return
	cancel_stroke()
	blade_width = clampf(value,16,96)
	preferences_changed.emit()
	changed.emit()
	queue_redraw()

func cancel_stroke() -> void:
	dragging = false
	if buzzing:
		buzzing = false
		set_process(false)
		if stroke_saved: host.changed.emit()
		message.emit("Buzz stroke finished: %d cuts. Ctrl+Z restores the stroke." % stroke_count)
		_sync()
	queue_redraw()

func invalidate() -> void:
	history.clear()
	cancel_stroke()
	clear_clippings()
	_sync()

func clear_clippings() -> void:
	if host.simulator: host.simulator.clear_clippings()
	host.mannequin_view.update_clippings(PackedFloat32Array())

func _sync() -> void:
	undo_button.visible = active
	undo_button.disabled = history.is_empty()
	var hint: Label = host.mannequin_toolbar.get_child(4)
	hint.text = "Right-drag to rotate · Wheel to zoom" if active else "Drag to rotate · Wheel to zoom"
	hint.visible = host.size.x >= (660 if active else 540)
	queue_redraw()

func handle_input(event: InputEvent) -> bool:
	if not active: return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var at: Vector2 = host._video_transform.affine_inverse()*event.position
				if not Rect2(Vector2.ZERO,host.video_size).has_point(at): return true
				if mode=="Buzz":
					cursor=event.position; sampled=cursor; cursor_visible=true
					buzzing=true; stroke_saved=false; stroke_count=0; buzz_time=0; notify_time=0
					set_process(true)
					_buzz_sample()
					queue_redraw()
					return true
				dragging = true
				start = event.position
				finish = start
			elif buzzing:
				cursor=event.position
				_buzz_sample()
				cancel_stroke()
			elif dragging:
				finish = event.position
				dragging = false
				if start.distance_to(finish)>=6: cut(start,finish)
			queue_redraw()
			return true
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_stroke()
			return true
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: cancel_stroke()
	if event is InputEventMouseMotion:
		cursor=event.position; cursor_visible=true
		if dragging:
			finish = event.position
			queue_redraw()
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT: host.mannequin_view.orbit(event.relative)
		if mode=="Buzz": queue_redraw()
		return true
	return false

func _unhandled_key_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if dragging or buzzing: cancel_stroke()
		else: set_active(false)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Z and event.ctrl_pressed:
		undo()
		get_viewport().set_input_as_handled()

func cut(from: Vector2, to: Vector2) -> int:
	if not host.mannequin or not host.enabled or host.simulator == null: return 0
	var view: Control = host.mannequin_view
	var inverse: Transform2D = host._video_transform.affine_inverse()
	var projection: Transform3D = view.world_to_pixels()
	var before: Dictionary = host.overrides.duplicate(true)
	var began := Time.get_ticks_usec()
	var result: Dictionary = host.simulator.clip_line(inverse*from,inverse*to,view.cut_vertices,view.cut_triangles,
		projection*view.pivot.transform,projection,inverse.x.length())
	var cuts: Array = result.get("cuts",[])
	last_count = cuts.size()
	if not cuts.is_empty():
		history.append(before)
		if history.size()>12: history.pop_front()
		_apply_edits(cuts)
		view.update_hair(host.simulator.get_render_buffer(),int(host.config.segments),true)
		view.update_clippings(host.simulator.get_clippings_buffer(projection))
		host.changed.emit()
	last_cut_ms = (Time.get_ticks_usec()-began)/1000.0
	_sync()
	message.emit("Cut %d visible strands. Lengths saved; %d segments per strand. Ctrl+Z to undo." % [last_count,int(host.config.segments)] if last_count else "No visible hair crossed the line. Rotate the mannequin to reach another side.")
	return last_count

func _apply_edits(cuts: Array) -> void:
	for edit in cuts:
		var id: String = host.attachment[int(edit.index)].id
		var value: Dictionary = host.overrides.get(id,{}).duplicate(true)
		value.length = float(value.get("length",1.0))*float(edit.fraction)
		value.tip_width = float(edit.tip_width)
		value.tip_color = edit.tip_color.to_html()
		value.erase("guide"); value.erase("guide3d")
		if edit.has("guide3d"): value.guide3d = edit.guide3d
		elif edit.has("guide"): value.guide = edit.guide
		host.overrides[id] = value

func _process(delta: float) -> void:
	buzz_time += delta
	notify_time += delta
	if buzzing and buzz_time>=1.0/60:
		buzz_time=0
		_buzz_sample()
		if stroke_saved and notify_time>=.5:
			notify_time=0
			host.changed.emit()

func _buzz_sample() -> void:
	if not buzzing or not host.mannequin or not host.enabled or host.simulator==null: return
	var view: Control = host.mannequin_view
	var inverse: Transform2D = host._video_transform.affine_inverse()
	var projection: Transform3D = view.world_to_pixels()
	var began := Time.get_ticks_usec()
	var result: Dictionary = host.simulator.clip_buzz(inverse*sampled,inverse*cursor,blade_width*inverse.x.length(),
		view.cut_vertices,view.cut_triangles,projection*view.pivot.transform,projection,inverse.x.length())
	sampled=cursor
	var cuts: Array = result.get("cuts",[])
	last_count=cuts.size()
	if not cuts.is_empty():
		if not stroke_saved:
			history.append(host.overrides.duplicate(true))
			if history.size()>12: history.pop_front()
			stroke_saved=true
			_sync()
		_apply_edits(cuts)
		stroke_count += cuts.size()
	last_cut_ms=(Time.get_ticks_usec()-began)/1000.0

func undo() -> void:
	if not host.mannequin or history.is_empty(): return
	cancel_stroke()
	host.overrides = history.pop_back()
	host._rebuild(true)
	host.simulator.reset()
	clear_clippings()
	host.changed.emit()
	_sync()
	message.emit("Previous cut restored.")

func _draw() -> void:
	if active and mode=="Buzz" and cursor_visible:
		draw_texture_rect(clipper_image,Rect2(cursor+Vector2(-blade_width*.5,-3),Vector2(blade_width,blade_width*116/64)),false)
		draw_line(cursor+Vector2(-blade_width*.5,0),cursor+Vector2(blade_width*.5,0),Color("68dfc3") if buzzing else Color("ffbf69"),3,true)
		draw_circle(cursor+Vector2(0,blade_width*.8),3,Color("68dfc3") if buzzing else Color("596472"))
		return
	if not active or not dragging: return
	draw_line(start,finish,Color(0,0,0,.8),5,true)
	draw_line(start,finish,Color("68dfc3"),2,true)
	draw_circle(start,5,Color("68dfc3"))
	draw_arc(finish,6,0,TAU,24,Color("ffbf69"),2,true)
	var font := ThemeDB.fallback_font
	draw_string(font,start+Vector2(9,-9),"Start",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	draw_string(font,finish+Vector2(9,-9),"Finish",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
