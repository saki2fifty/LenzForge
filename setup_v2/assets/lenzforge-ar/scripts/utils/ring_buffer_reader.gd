extends RefCounted
## Reusable Ring Buffer Reader Base Class
## Provides common functionality for reading from LenzForge ring buffers
## Inherit this class for VID1, LMK1, or any future ring buffers

signal buffer_opened()
signal buffer_closed()
signal read_error(error_message: String)

var buffer_name: String = ""
var is_open: bool = false
var reader_node: Node = null
var last_read_frame_id: int = -1

func open(name: String, script_path: String) -> bool:
	"""Open a ring buffer with the specified GDExtension reader script"""
	if is_open:
		push_warning("[RingBufferReader] Buffer already open: %s" % buffer_name)
		return true
	
	buffer_name = name
	
	# Load GDExtension script
	var script = load(script_path)
	if not script:
		push_error("[RingBufferReader] Failed to load script: %s" % script_path)
		return false
	
	# Create reader node
	reader_node = Node.new()
	reader_node.set_script(script)
	reader_node.name = buffer_name + "Reader"
	
	# Open buffer
	if reader_node.has_method("open"):
		var success: bool = reader_node.open(buffer_name)
		if not success:
			push_error("[RingBufferReader] Failed to open buffer: %s" % buffer_name)
			reader_node.free()
			reader_node = null
			return false
	else:
		push_error("[RingBufferReader] Reader missing 'open' method!")
		reader_node.free()
		reader_node = null
		return false
	
	is_open = true
	buffer_opened.emit()
	return true

func has_new_data() -> bool:
	"""Check if new data is available"""
	if not is_open or not reader_node:
		return false
	
	if not reader_node.has_method("has_new_data"):
		return false
	
	return reader_node.has_new_data()

func read_latest() -> Dictionary:
	"""Read the latest data from the buffer"""
	if not is_open or not reader_node:
		return {}
	
	if not reader_node.has_method("read_latest"):
		read_error.emit("Reader missing 'read_latest' method")
		return {}
	
	var data: Dictionary = reader_node.read_latest()
	
	if not data.is_empty():
		last_read_frame_id = data.get("frame_id", -1)
	
	return data

func close() -> void:
	"""Close the ring buffer"""
	if not is_open:
		return
	
	if reader_node:
		if reader_node.has_method("close"):
			reader_node.close()
		reader_node.free()
		reader_node = null
	
	is_open = false
	buffer_closed.emit()

func get_stats() -> Dictionary:
	"""Get reader statistics"""
	return {
		"buffer_name": buffer_name,
		"is_open": is_open,
		"last_frame_id": last_read_frame_id
	}
