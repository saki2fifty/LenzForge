extends RefCounted
## Reusable Performance Tracking Utility
## Tracks timing metrics with configurable history size
## Can be used by any manager for performance monitoring

signal performance_warning(operation: String, time_ms: float, threshold_ms: float)

var operation_name: String = ""
var history: Array[float] = []
var history_size: int = 60
var warning_threshold_ms: float = 0.0
var total_operations: int = 0

func _init(name: String = "Operation", max_history: int = 60, warn_threshold_ms: float = 0.0):
	operation_name = name
	history_size = max_history
	warning_threshold_ms = warn_threshold_ms

func track(time_ms: float) -> void:
	"""Track a single operation time"""
	history.append(time_ms)
	if history.size() > history_size:
		history.pop_front()
	
	total_operations += 1
	
	# Emit warning if over threshold
	if warning_threshold_ms > 0.0 and time_ms > warning_threshold_ms:
		performance_warning.emit(operation_name, time_ms, warning_threshold_ms)
		push_warning("[PerformanceTracker] Slow %s: %.2fms (threshold: %.2fms)" % [operation_name, time_ms, warning_threshold_ms])

func get_average() -> float:
	"""Get average time across history"""
	if history.is_empty():
		return 0.0
	
	var total: float = 0.0
	for t in history:
		total += t
	return total / history.size()

func get_min() -> float:
	"""Get minimum time in history"""
	if history.is_empty():
		return 0.0
	return history.min()

func get_max() -> float:
	"""Get maximum time in history"""
	if history.is_empty():
		return 0.0
	return history.max()

func get_latest() -> float:
	"""Get most recent time"""
	if history.is_empty():
		return 0.0
	return history[history.size() - 1]

func get_percentile(p: float) -> float:
	"""Get percentile value (p between 0.0 and 1.0)"""
	if history.is_empty():
		return 0.0
	
	var sorted = history.duplicate()
	sorted.sort()
	
	var index = int(p * (sorted.size() - 1))
	return sorted[index]

func reset() -> void:
	"""Clear history"""
	history.clear()
	total_operations = 0

func get_stats() -> Dictionary:
	"""Get comprehensive statistics"""
	return {
		"operation": operation_name,
		"count": total_operations,
		"avg_ms": get_average(),
		"min_ms": get_min(),
		"max_ms": get_max(),
		"latest_ms": get_latest(),
		"p50_ms": get_percentile(0.5),
		"p95_ms": get_percentile(0.95),
		"p99_ms": get_percentile(0.99)
	}
