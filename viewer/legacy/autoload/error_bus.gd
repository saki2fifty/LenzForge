extends Node

# Error Bus
# Central error handling and reporting system

signal error_reported(error_data: Dictionary)
signal warning_reported(warning_data: Dictionary)

enum ErrorLevel {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

var error_history: Array = []
var max_history: int = 100

func _ready():
	print("[ErrorBus] Initialized")

func report_error(message: String, level: ErrorLevel = ErrorLevel.ERROR, source: String = ""):
	var error_data = {
		"message": message,
		"level": level,
		"source": source,
		"timestamp": Time.get_ticks_msec()
	}
	
	error_history.append(error_data)
	if error_history.size() > max_history:
		error_history.pop_front()
	
	if level == ErrorLevel.WARNING:
		warning_reported.emit(error_data)
		print("[ErrorBus] WARNING: [", source, "] ", message)
	else:
		error_reported.emit(error_data)
		if level == ErrorLevel.CRITICAL:
			printerr("[ErrorBus] CRITICAL: [", source, "] ", message)
		else:
			printerr("[ErrorBus] ERROR: [", source, "] ", message)

func get_recent_errors(count: int = 10) -> Array:
	var start_idx = max(0, error_history.size() - count)
	return error_history.slice(start_idx)

func clear_history():
	error_history.clear()
	print("[ErrorBus] History cleared")
