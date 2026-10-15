# Studio API

Default base: `http://127.0.0.1:5000`. JSON control requests use `Content-Type: application/json`. Camera index `-1` selects the synthetic demo. These endpoints back the current studio; archived API documents describe the older implementation.

| Method | Path | Behavior |
| --- | --- | --- |
| GET | `/health` | Service version and health |
| GET | `/api/status` | Active source, measured fps, frame count, resolution, mapping names, tracking worker state, and recording flag |
| GET | `/api/camera/list` | Demo and probed camera choices; while a physical camera is active, returns it without opening competing handles |
| GET | `/api/camera/current` | Current camera configuration |
| POST | `/api/camera/select` | Start/reopen with `camera_index`, `resolution: [width,height]`, and `fps` |
| POST | `/api/camera/configure` | Reopen current source with a new resolution/fps |
| POST | `/api/camera/stop` | Stop capture and finalize recording |
| GET | `/api/tracking/status` | Requested feature toggles and actual worker state |
| POST | `/api/tracking/enable` | Boolean `face_mesh`, `iris`, `hands`, and/or `pose` toggles |
| GET | `/api/tracking/landmarks` | Latest worker snapshot: `frame_id`, QPC `timestamp`, and `landmarks` |
| GET | `/api/tracking/statistics` | Actual worker timing, counts, queue depth, dropped work, and errors |
| GET | `/video_feed` | Shared MJPEG preview with browser effects and overlays |
| GET | `/api/effects/list` | Retained effect registry, including experimental categories |
| POST | `/api/effects/apply` | Append an effect with `effect_name` and optional `parameters` |
| POST | `/api/effects/clear` | Clear the browser preview effect chain |
| GET / POST | `/api/performance/config` | Read/update validated preview and inference-size settings |
| GET | `/api/performance/presets` | Available quality/performance presets |
| POST | `/api/performance/preset/<name>` | Apply a preset |
| GET | `/api/export/frame?format=png` | Download the latest original source frame |
| GET | `/api/export/landmarks` | Export current non-stale landmarks |
| POST | `/api/export/recording/start` | Start source AVI/JSONL recording; optional `include_video` and `include_landmarks` booleans |
| POST | `/api/export/recording/stop` | Finalize recording and return file paths |
| GET | `/api/export/recording/status` | Recording state, files, frame count, and error |
| GET | `/api/system/stats` | Process memory/threads, host CPU/memory, and uptime |
| GET | `/api/camera/stats` | Capture frame counts and read failures |
| GET | `/api/mediapipe/stats` | Worker measurements |
| GET | `/api/ringbuffer/stats` | Active mapping names and published frame count |
| GET | `/api/docs/list` | Current documentation index |
| GET | `/api/docs/<id>` | Repository documentation content |

Capture dimensions must be even, at least 64×64, and no larger than 3840×2160. Requested fps is 1–120; actual hardware capability may be lower. A successful source change creates new shared-memory mapping names; consumers must reattach when `/api/status` changes.

Performance keys are `mediapipe_max_width` (0, 480, 640, or 960), `preview_max_fps` (1–120), `preview_quality` (1–100), and `preview_scale` (0.1–1). Only inference-width changes require a capture restart. Removed queue/triple-buffer settings did not describe the new latest-frame mailbox and are rejected.

The desktop reads face/iris points from LMK1. HTTP landmark snapshots can additionally contain `hands`, `pose`, `blendshapes`, and `face_transform`. A face is not guaranteed in every frame. Consumers should clear old overlays and use timestamps, rather than assuming results belong to the newest video frame.

Legacy `/api/tracking/configure` and `/api/tracking/reset` now return HTTP 501 with guidance instead of pretending to apply model changes. The unused `/api/config` store was archived; camera and tracking controls are the authoritative runtime configuration.
