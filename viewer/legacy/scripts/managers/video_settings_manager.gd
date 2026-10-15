extends Node
## Video Settings Manager
## Manages video capture settings like resolution, frame rate, and quality

signal settings_changed

enum Resolution {
    RES_720P,
    RES_1080P,
    RES_480P,
    RES_640x360
}

enum FrameRate {
    FPS_24 = 24,
    FPS_30 = 30,
    FPS_60 = 60,
    FPS_120 = 120
}

enum Quality {
    QUALITY_LOW = 0,
    QUALITY_MEDIUM = 1,
    QUALITY_HIGH = 2,
    QUALITY_ULTRA = 3
}

var current_resolution: Resolution = Resolution.RES_720P
var current_framerate: FrameRate = FrameRate.FPS_30
var current_quality: Quality = Quality.QUALITY_MEDIUM

# Settings file path
const SETTINGS_FILE = "user://video_settings.json"

func _ready():
    print("[VideoSettingsManager] Initializing video settings manager...")
    load_settings()
    
    # Connect to backend API for settings changes
    _connect_backend_signals()

func _connect_backend_signals():
    """Connect to backend signals for settings changes"""
    # This would connect to backend API endpoints
    # For now, we'll use local settings only
    pass

func load_settings():
    """Load settings from JSON file"""
    if FileAccess.file_exists(SETTINGS_FILE):
        var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
        var json_text = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        var parse_result = json.parse(json_text)
        
        if parse_result == OK:
            var data = json.data
            _apply_settings_from_dict(data)
            print("[VideoSettingsManager] Settings loaded from file")
        else:
            print("[VideoSettingsManager] Failed to parse settings file: ", parse_result.error_string)
    else:
        print("[VideoSettingsManager] No settings file found, using defaults")
        _apply_default_settings()

func _apply_settings_from_dict(data: Dictionary):
    """Apply settings from dictionary"""
    if data.has("resolution"):
        var res_str = data["resolution"]
        current_resolution = _parse_resolution(res_str)
    
    if data.has("framerate"):
        current_framerate = data["framerate"]
    
    if data.has("quality"):
        current_quality = data["quality"]

func _apply_default_settings():
    """Apply default settings"""
    current_resolution = Resolution.RES_720P
    current_framerate = FrameRate.FPS_30
    current_quality = Quality.QUALITY_MEDIUM

func _parse_resolution(res_str: String) -> Resolution:
    """Parse resolution string to enum"""
    match res_str.to_lower():
        "720p", "1280x720":
            return Resolution.RES_720P
        "1080p", "1920x1080":
            return Resolution.RES_1080P
        "480p", "854x480":
            return Resolution.RES_480P
        "640x360":
            return Resolution.RES_640x360
        _:
            print("[VideoSettingsManager] Unknown resolution: ", res_str)
            return Resolution.RES_720P

func save_settings():
    """Save current settings to JSON file"""
    var settings_dict = {
        "resolution": _get_resolution_string(),
        "framerate": current_framerate,
        "quality": current_quality
    }
    
    var json = JSON.new()
    var json_string = json.stringify(settings_dict)
    
    var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
    file.store_string(json_string)
    file.close()
    
    print("[VideoSettingsManager] Settings saved to file")

func _get_resolution_string() -> String:
    """Get current resolution as string"""
    match current_resolution:
        Resolution.RES_720P:
            return "1280x720"
        Resolution.RES_1080P:
            return "1920x1080"
        Resolution.RES_480P:
            return "854x480"
        Resolution.RES_640x360:
            return "640x360"
        _:
            return "1280x720"

func get_resolution() -> Vector2i:
    """Get current resolution"""
    match current_resolution:
        Resolution.RES_720P:
            return Vector2i(1280, 720)
        Resolution.RES_1080P:
            return Vector2i(1920, 1080)
        Resolution.RES_480P:
            return Vector2i(854, 480)
        Resolution.RES_640x360:
            return Vector2i(640, 360)
        _:
            return Vector2i(1280, 720)

func set_resolution(resolution: Resolution):
    """Set new resolution"""
    if current_resolution != resolution:
        current_resolution = resolution
        save_settings()
        settings_changed.emit()
        print("[VideoSettingsManager] Resolution changed to: ", _get_resolution_string())

func get_framerate() -> int:
    """Get current frame rate"""
    return current_framerate

func set_framerate(framerate: FrameRate):
    """Set new frame rate"""
    if current_framerate != framerate:
        current_framerate = framerate
        save_settings()
        settings_changed.emit()
        print("[VideoSettingsManager] Frame rate changed to: ", framerate)

func get_quality() -> Quality:
    """Get current quality"""
    return current_quality

func set_quality(quality: Quality):
    """Set new quality"""
    if current_quality != quality:
        current_quality = quality
        save_settings()
        settings_changed.emit()
        print("[VideoSettingsManager] Quality changed to: ", quality)

func get_settings_dict() -> Dictionary:
    """Get all current settings as dictionary"""
    return {
        "resolution": _get_resolution_string(),
        "framerate": current_framerate,
        "quality": current_quality,
        "resolution_vector": current_resolution,
        "available_resolutions": ["1280x720", "1920x1080", "854x480", "640x360"],
        "available_framerates": [24, 30, 60, 120],
        "available_qualities": ["Low", "Medium", "High", "Ultra"]
    }

func apply_to_backend():
    """Apply settings to backend via API"""
    # This would make HTTP requests to backend API
    # For now, we'll just emit the signal
    settings_changed.emit()
    print("[VideoSettingsManager] Applying settings to backend...")
