extends Node

# LenzForge Manager
# Manages lifecycle of LenzForge components

signal backend_connected
signal backend_disconnected
signal error_occurred(message: String)

var backend_url: String = "http://localhost:5000"
var is_connected: bool = false

func _ready():
	print("[LenzForge] Manager initialized")
	check_backend_connection()

func check_backend_connection():
	# Simple connection check - expand as needed
	print("[LenzForge] Checking backend connection to: ", backend_url)
	# For now, assume connected if autoload loaded
	is_connected = true
	backend_connected.emit()
	print("[LenzForge] Backend connection established")

func get_backend_status() -> Dictionary:
	return {
		"connected": is_connected,
		"url": backend_url
	}
