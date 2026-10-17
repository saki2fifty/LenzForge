extends SceneTree
const Layer = preload("res://beard/beard_layer.gd")
var failures: Array[String] = []
func check(value: bool, detail: String) -> void:
	if not value and not detail in failures: failures.append(detail)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var layers := []
	for parallel in [false,true]:
		var layer := Layer.new()
		root.add_child(layer)
		layer.set_settings({"strands":512,"brow_enabled":true,"brow_count":32,"hair_style":"Regular","hair_count":64,
			"wind":2.0,"turbulence":.4,"mustache_wind":-1.0,"mustache_turbulence":.2})
		layer.set_enabled(true); layer.set_mannequin(true); layer.set_process(false)
		layer.simulator.set_parallel_enabled(parallel)
		layers.append(layer)
	var workers := 1
	for tick in 90:
		for layer in layers:
			if tick == 30: layer.set_settings({"strands":1024,"hair_count":768,"brow_count":256,"segments":16})
			if tick == 50: layer.set_setting("mustache_wind",3.0)
			if tick == 60: layer.set_settings({"strands":16,"hair_style":"None","brow_enabled":false,"segments":2})
			layer.mannequin_view.set_pose(sin(tick*.07)*110,cos(tick*.05)*20)
			layer.set_process(false)
			layer.simulator.advance([1.0/240,1.0/120,1.0/60,1.0/30][tick%4])
		workers = maxi(workers,layers[1].simulator.get_worker_count())
		check(layers[0].simulator.get_render_buffer() == layers[1].simulator.get_render_buffer(),"Parallel/serial output stays identical through turns, mixed motion, force edits and resizing")
	check(workers > 1 or OS.get_processor_count() <= 1,"Large workloads use native workers")
	check(layers[1].simulator.get_worker_count() == 1,"Small workloads avoid dispatch overhead")
	for layer in layers: layer.free()
	print("PARALLEL_PHYSICS workers=",workers," failures=",failures)
	quit(0 if failures.is_empty() else 1)
