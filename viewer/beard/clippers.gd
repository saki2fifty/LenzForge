extends Control
## Screen-space blade, native depth picking/physics, persisted strand overrides.
signal changed
signal message(text: String)
var host: Control
var active := false
var dragging := false
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
	if active: message.emit("Clippers: drag a start-to-finish line across visible hair. Right-drag rotates; wheel zooms; Ctrl+Z undoes.")

func cancel_stroke() -> void:
	dragging = false
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
				dragging = true
				start = event.position
				finish = start
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
		if dragging:
			finish = event.position
			queue_redraw()
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT: host.mannequin_view.orbit(event.relative)
		return true
	return false

func _unhandled_key_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if dragging: cancel_stroke()
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
		for edit in cuts:
			var id: String = host.attachment[int(edit.index)].id
			var value: Dictionary = host.overrides.get(id,{}).duplicate(true)
			value.length = float(value.get("length",1.0))*float(edit.fraction)
			value.tip_width = float(edit.tip_width)
			value.tip_color = edit.tip_color.to_html()
			if edit.has("guide"): value.guide = edit.guide
			else: value.erase("guide")
			host.overrides[id] = value
		view.update_hair(host.simulator.get_render_buffer(),int(host.config.segments),true)
		view.update_clippings(host.simulator.get_clippings_buffer(projection))
		host.changed.emit()
	last_cut_ms = (Time.get_ticks_usec()-began)/1000.0
	_sync()
	message.emit("Cut %d visible strands. Lengths saved; %d segments per strand. Ctrl+Z to undo." % [last_count,int(host.config.segments)] if last_count else "No visible hair crossed the line. Rotate the mannequin to reach another side.")
	return last_count

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
	if not active or not dragging: return
	draw_line(start,finish,Color(0,0,0,.8),5,true)
	draw_line(start,finish,Color("68dfc3"),2,true)
	draw_circle(start,5,Color("68dfc3"))
	draw_arc(finish,6,0,TAU,24,Color("ffbf69"),2,true)
	var font := ThemeDB.fallback_font
	draw_string(font,start+Vector2(9,-9),"Start",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	draw_string(font,finish+Vector2(9,-9),"Finish",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
