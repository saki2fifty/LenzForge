# LenzForge AR - Reusable Utility Classes

**Location:** `scripts/utils/`  
**Purpose:** Small, focused, reusable components that can be used across the entire project

---

## Overview

These utility classes follow best practices:
- **Small & Focused:** Each class has one clear responsibility
- **Reusable:** Can be used by any manager or component
- **Well-Documented:** Clear comments and usage examples
- **Type-Safe:** Full GDScript typing
- **Testable:** Easy to unit test in isolation

---

## Available Utilities

### 1. RingBufferReader (`ring_buffer_reader.gd`)

**Purpose:** Base class for reading from LenzForge ring buffers

**Usage:**
```gdscript
var reader = preload("res://scripts/utils/ring_buffer_reader.gd").new()

# Open a ring buffer
if reader.open("LenzForge_Video", "res://addons/lenzforge/video/vid1_reader.gd"):
    # Check for new data
    if reader.has_new_data():
        var data = reader.read_latest()
        print("Frame ID: ", data.get("frame_id"))

# Clean up
reader.close()
```

**Benefits:**
- Eliminates duplicate code across VID1/LMK1/GOD1 readers
- Consistent error handling
- Signal-based notifications
- Statistics tracking

---

### 2. PerformanceTracker (`performance_tracker.gd`)

**Purpose:** Track timing metrics with automatic warnings

**Usage:**
```gdscript
var tracker = preload("res://scripts/utils/performance_tracker.gd").new(
    "VideoProcessing",  # Operation name
    60,                 # History size
    5.0                 # Warning threshold (ms)
)

# Track an operation
var start = Time.get_ticks_usec()
# ... do work ...
var time_ms = (Time.get_ticks_usec() - start) / 1000.0
tracker.track(time_ms)

# Get statistics
var stats = tracker.get_stats()
print("Average: ", stats.avg_ms, " ms")
print("P95: ", stats.p95_ms, " ms")
```

**Benefits:**
- Automatic performance warnings
- Percentile calculations (p50, p95, p99)
- Min/max/average tracking
- Configurable history size

---

### 3. SignalBus (`signal_bus.gd`)

**Purpose:** Global signal communication hub (Autoload singleton)

**Setup:**
Add to `project.godot`:
```
[autoload]
SignalBus="*res://scripts/utils/signal_bus.gd"
```

**Usage:**
```gdscript
# Emit from anywhere
SignalBus.fps_updated.emit(60.0, 16.67)

# Connect from anywhere
SignalBus.fps_updated.connect(_on_fps_updated)

func _on_fps_updated(fps: float, frame_time_ms: float):
    print("FPS: ", fps)
```

**Benefits:**
- Reduces coupling between managers
- Centralized signal definitions
- Easy to trace signal flow
- No need to manually wire signals

---

### 4. AppConfig (`app_config.gd`)

**Purpose:** Centralized configuration constants

**Usage:**
```gdscript
# Get ring buffer name
var buffer_name = AppConfig.get_ring_buffer_name("video")
print(buffer_name)  # "LenzForge_Video"

# Get reader path
var reader_path = AppConfig.get_reader_path("landmarks")
print(reader_path)  # "res://addons/lenzforge/landmarks/lmk1_reader.gd"

# Get default settings
var settings = AppConfig.create_default_settings()
print(settings.video.width)  # 1920

# Use constants
if frame_time_ms > AppConfig.TARGET_FRAME_TIME_MS:
    push_warning("Slow frame!")
```

**Benefits:**
- Single source of truth for constants
- No magic numbers in code
- Easy to change configuration
- Type-safe access

---

## Design Principles

### 1. Small Files
Each utility is < 100 lines of focused code

### 2. Single Responsibility
Each class does ONE thing well

### 3. Reusability
Can be used by any component in the project

### 4. No Dependencies
Utilities don't depend on each other (except SignalBus autoload)

### 5. Easy Testing
Each utility can be tested in isolation

---

## Usage Patterns

### Pattern 1: Performance Tracking
```gdscript
# In any manager
var perf = PerformanceTracker.new("MyOperation", 60, 5.0)

func process_frame():
    var start = Time.get_ticks_usec()
    # ... work ...
    perf.track((Time.get_ticks_usec() - start) / 1000.0)
```

### Pattern 2: Ring Buffer Reading
```gdscript
# In any manager
var reader = RingBufferReader.new()

func _ready():
    reader.open(
        AppConfig.VID1_BUFFER_NAME,
        AppConfig.VID1_READER_PATH
    )

func _process(_delta):
    if reader.has_new_data():
        var data = reader.read_latest()
        # Use data
```

### Pattern 3: Signal Communication
```gdscript
# Producer
SignalBus.landmarks_updated.emit(landmark_data)

# Consumer (in another manager)
func _ready():
    SignalBus.landmarks_updated.connect(_on_landmarks_ready)

func _on_landmarks_ready(data: Dictionary):
    # React to landmarks
```

---

## Future Utilities

Consider adding:
- `FileManager` - Centralized file I/O
- `Logger` - Structured logging
- `EventQueue` - Async event processing
- `ResourcePool` - Object pooling
- `MathUtils` - Common math operations
- `ColorUtils` - Color manipulation
- `TimerManager` - Centralized timers

---

## Best Practices

### DO:
✅ Keep utilities small (<100 lines)
✅ Make them reusable
✅ Add comprehensive documentation
✅ Use type hints everywhere
✅ Provide usage examples

### DON'T:
❌ Create dependencies between utilities
❌ Mix multiple responsibilities
❌ Add game-specific logic
❌ Skip documentation
❌ Ignore error handling

---

## Testing

Each utility should have unit tests:

```gdscript
# test_performance_tracker.gd
extends GutTest

func test_track_adds_to_history():
    var tracker = PerformanceTracker.new("Test", 5)
    tracker.track(10.0)
    tracker.track(20.0)
    assert_eq(tracker.get_average(), 15.0)

func test_warning_emitted_above_threshold():
    var tracker = PerformanceTracker.new("Test", 5, 10.0)
    watch_signals(tracker)
    tracker.track(15.0)
    assert_signal_emitted(tracker, "performance_warning")
```

---

## Contributing

When adding new utilities:

1. **Check if it already exists** - Don't duplicate
2. **Keep it small** - One file, one purpose
3. **Document thoroughly** - Add to this README
4. **Add usage examples** - Show how to use it
5. **Consider reusability** - Will others need this?

---

**Created:** October 29, 2025  
**Last Updated:** October 29, 2025  
**Utilities Count:** 4
