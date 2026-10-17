# Studio API

Default base: `http://127.0.0.1:5000`. JSON control requests use `Content-Type: application/json`. Camera index `-1` selects the synthetic demo. These endpoints back the current studio; archived API documents describe the older implementation.

| Method | Path | Behavior |
| --- | --- | --- |
| GET | `/health` | Service version and health |
| GET | `/api/status` | Active source, measured fps, capture format/timing, frame count, resolution, mapping names, tracking worker state, and recording flag |
| GET | `/api/camera/list` | Windows device names, capture indices, and stable `device_id` values, followed by the demo source; discovery does not open cameras or interrupt capture |
| GET | `/api/camera/current` | Current camera configuration |
| POST | `/api/camera/select` | Start/reopen with `camera_index`, `resolution: [width,height]`, and `fps`; optional `device_id` preserves device identity if Windows indices change |
| POST | `/api/camera/configure` | Reopen current source with a new resolution/fps |
| POST | `/api/camera/stop` | Stop capture and finalize recording |
| GET | `/api/tracking/status` | Requested feature toggles and actual worker state |
| POST | `/api/tracking/enable` | Boolean `face_mesh`, `iris`, `hands`, and/or `pose` toggles |
| GET | `/api/tracking/landmarks` | Latest worker snapshot: `frame_id`, QPC `timestamp`, and `landmarks` |
| GET | `/api/tracking/statistics` | Actual worker timing, counts, queue depth, dropped work, and errors |
| GET / POST | `/api/tracking/configure` | Read/update live tracking settings; returns validated `config` and `revision` |
| POST | `/api/tracking/reset` | Restore Auto/640px/single-face/0.5 confidence defaults, optional outputs enabled |
| POST | `/api/calibration/sample` | Analyze the current camera frame on demand; returns local JPEG, face/contour coordinates, hand boxes, pose, frame ID and usability. Lazily loads verified contour/face/hand models; requires active capture. |
| POST | `/api/calibration/fit` | Fit 2–12 observations (`face`: 478 XYZ points, `contour`: 8–160 XY points) with `initial: [depth,crown,sides,jaw]`; returns a bounded version-1 profile. Different head angles are required. The desktop saves only after review. |
| POST | `/api/calibration/stop` | Release calibration-only models; waits for any in-flight analysis to finish. Normal tracking continues. |
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

Capture dimensions must be even, at least 64×64, and no larger than 3840×2160. Requested fps is 1–120, default 60; actual hardware capability may be lower. A successful source change creates new shared-memory mapping names; consumers must reattach when `/api/status` changes.

`capture_format` reports `NV12` or the `BGR` fallback. `capture_timing` summarizes up to 240 recent capture intervals: `fps`, `sample_count`, `late_frames` (intervals exceeding 1.5× the negotiated frame period), and mean/p95/max distributions in milliseconds for `interval_ms`, `read_ms`, `convert_ms`, and `publish_ms`. Native NV12 `convert_ms` covers packet/plane preparation, with no color conversion. The top-level `fps` measures the shared preview/export worker; it is distinct from hardware capture, browser JPEG, and Godot display rates.

Camera indices must be whole numbers >= -1. JSON numbers such as `1.0` are accepted as `1`; fractional numbers, booleans, strings, and non-finite values are rejected.

Performance keys are `mediapipe_max_width` (0, 320, 480, 640, or 960), `preview_max_fps` (1–120), `preview_quality` (1–100), and `preview_scale` (0.1–1). Inference width updates the shared tracking configuration immediately; no capture restart is needed. Removed queue/triple-buffer settings did not describe the new latest-frame mailbox and are rejected.

The desktop reads face/iris points from LMK1. HTTP landmark snapshots can additionally contain `hands`, `pose`, `blendshapes`, and `face_transform`. A face is not guaranteed in every frame. Consumers should clear old overlays and use timestamps, rather than assuming results belong to the newest video frame.

Tracking configuration keys are `backend` (`auto`, `gpu`, `cpu`), `max_width` (0/native, 320, 480, 640, 960), `num_faces` (integer 1–4), `detection_confidence`, `presence_confidence`, `tracking_confidence` (finite numbers 0–1), and boolean `blendshapes` / `face_transform`. Unknown keys and invalid values return HTTP 400 without changing configuration. Confidence zero is preserved. Reapplying settings increments the revision and retries GPU startup after a fallback. Successful tracking, feature, performance, and effect edits save before the response and survive backend restarts. Persistence failures return HTTP 500. See [settings storage](SETTINGS.md).

Worker status includes `requested_backend`, `active_backend`, `phase`, `fallback_reason`, `renderer`, `settings`, `settings_revision`, and `applied_revision`. Settings are accepted immediately and adopted by the worker on its next input frame. During GPU startup/calibration, the active backend remains CPU. Auto's `comparison` contains CPU/GPU median timings, sample count, and selection. It establishes a CPU baseline before starting GPU work and waits for a detected face when face tracking is enabled. Explicit GPU mode can warm up without a face.

`face_model`, `hand_model`, and `pose_model` accept installed catalog IDs of the corresponding task type. Defaults are `face_landmarker`, `hand_landmarker`, and `pose_landmarker_lite`. A missing, corrupt, unknown, or wrong-task selection returns 400 atomically. These apply to both CPU and browser GPU.

| Method | Model library endpoint | Behavior |
| --- | --- | --- |
| GET | `/api/tracking/models` | `models` list with ID, kind, label, size, hash, official/installed state; current `job` |
| POST | `/api/tracking/models/download` | JSON `{"id":"pose_landmarker_full"}` starts background download; returns 202 |
| POST | `/api/tracking/models/import` | Multipart `file` + `kind`, or raw octet-stream with `?kind=face&name=example.task`; returns 202 while validation runs |

Library jobs report `idle`, `downloading`, `validating`, `ready`, or `error`, with byte progress and an error message when applicable. A concurrent job returns 409; invalid input returns 400. Downloads/imports never change tracking selection automatically: select a completed model through `/api/tracking/configure`. `/api/status.tracking.library` includes the same catalog/job snapshot for UI polling. See [model library behavior](MODELS_AND_VISIBILITY.md).

`model_ms` reports the active inference call; GPU excludes bridge overhead. `last_inference_ms` and rolling `round_trip_p50_ms` / `round_trip_p95_ms` cover tracking preprocessing and the complete request/result path. `capture_to_landmarks_p95_ms` additionally includes waiting since the source timestamp. Rolling summaries use up to 240 results; tracking `fps` uses a recent two-second window. Optional multi-face JSON adds `faces` when more than one face is found; the existing `face` field and LMK1 follow the first face. Browser matrices are converted to the CPU API's row-array layout.
