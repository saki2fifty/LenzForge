# GPU tracking, live controls, and performance

Implemented October 16, 2026. LenzForge can run MediaPipe face, iris, hand, and pose tracking in a local browser GPU worker, with native Python CPU tracking available throughout startup and as a fallback. GPU is an execution option, not a promise of lower latency: the measured CPU path is faster on the development PC for this workload.

## Start and configure

The follow-up [model library and visibility guide](MODELS_AND_VISIBILITY.md) covers model downloads/imports, head self-occlusion, and a native CPU / browser CPU / browser GPU diagnostic that explains the runtime comparison more precisely.

Existing installations should run `Setup.ps1 -SkipBuild` once to install the pinned browser JS/WASM assets and WebSocket dependency. This workspace already has them installed. Restart the backend and viewer to load the changes. GPU mode requires Microsoft Edge or Chrome and a working hardware WebGL2 context. A missing browser, missing assets, unsupported graphics context, model error, or lost connection leaves tracking on CPU and reports the reason.

Open the desktop's **Tracking** tab on the right. The browser studio exposes the same controls below its appearance settings. Changes save and apply automatically after a short pause; capture continues without reopening the camera. Pending edits are preserved when status updates arrive and across app restarts.

| Setting | Behavior |
| --- | --- |
| Auto, default | Measures a CPU baseline, warms GPU in the background, then uses GPU only if its median complete round trip is at least 5% faster. |
| GPU | Uses the browser GPU worker after warmup. CPU remains active during initialization and resumes if GPU fails. |
| CPU | Uses the existing native Python Tasks implementation, without a browser worker. |
| Tracking image width | 320, 480, 640 (default), 960, or native source width. Does not increase a smaller input's resolution. Applies during capture. |
| Maximum faces | 1–4. One face retains MediaPipe smoothing. The desktop follows the first face; additional faces are available in JSON. |
| Detection / presence / tracking confidence | Independent 0–1 thresholds, default 0.5; zero is preserved. These settings also apply to enabled hand/pose tasks. |
| Expression coefficients / 3D face transform | Optional face outputs, enabled by default for compatibility. Available through the backend/JSON; the existing desktop landmark transport still carries points only. |

The panel reports the actual active backend, startup/calibration progress, GPU fallback reason, tracking fps, median/p95 round trip, and capture-to-landmark p95. Auto displays both comparison times. **Restore tracking defaults** restores Auto/640px/one face/0.5 thresholds and both optional outputs, and saves that reset. **Apply tracking settings** retries GPU after a fallback. Settings and model selections persist across backend restarts. See [automatic settings](SETTINGS.md) for storage and offline behavior.

The right sidebar now uses compact 12px controls, wrapping row labels, constrained menu widths, and vertical scrolling. The preview's action buttons wrap when space is limited. Layout checks cover all tabs and hair pages at 1440×900, 1200×800, and 960×640.

## How processing stays responsive

Python retains sole ownership of the camera. It resizes the latest frame, then either calls native CPU models or sends uncompressed RGBA to the browser worker. Float32 landmark results return in binary form, with small metadata for optional outputs. The bridge disables WebSocket compression, permits one production request in flight, and reuses its input buffer. Capture keeps replacing stale queued work instead of accumulating a delay. No JPEG round trip, camera duplication, or user-opened browser tab is required.

All runtime/model assets are served locally. The browser connection uses a random session token, an exact local Origin check, and a loopback-only server. Setup downloads MediaPipe JS/WASM 1.1.1, verifies its SHA-512, and pins WebSocket transport 17.2. No CDN or remote inference service is used during tracking.

Auto collects 24 CPU samples and discards the first eight before launching GPU work. It then discards eight GPU warmup results and measures sixteen. Face tracking waits for a detected face so a cheap empty scene does not decide which backend should run the full landmark model. CPU continues producing results while GPU compiles and calibrates. The CPU baseline is measured before GPU starts, avoiding a comparison biased by simultaneous GPU warmup slowing CPU. The GPU comparison includes browser transport and result conversion; it is a conservative startup selection, not a laboratory benchmark.

Explicit GPU mode warms eight frames and then switches. A production GPU request has a 750ms response deadline; a failure switches subsequent processing to the already-initialized CPU engine and closes the browser in the background. Reconfiguration similarly retires the old engine without stopping capture. Both paths preserve source timestamps, existing JSON fields, and LMK1 publication. Browser matrices are transposed from column-major storage to the existing Python row-array convention.

Godot rendering and GPU inference share the same graphics hardware. Their combined behavior matters more than a model-only timing. Python's Windows wheel remains CPU-only; selecting GPU changes the runtime, rather than enabling an unsupported Python delegate.

## Attachment synchronization

The desktop now pairs each face result with its exact source video frame, using both frame ID and capture timestamp. Hair updates afterward in the same render cycle. CPU and GPU use this same native path, with no growing queue or motion prediction. It removes the extra sliding caused by displaying older landmarks over newer video. A missing frame or stalled tracker clears the overlays and returns to raw video.

A slower delegate now reduces the number of distinct matched frames displayed, rather than letting its landmarks trail a faster video stream. It also increases capture-to-display age. Auto selects the faster measured delegate; explicit GPU still respects your selection and retains CPU failure recovery. This fix does not eliminate model localization error, internal smoothing or camera motion blur. Current CPU/GPU timings and limits are recorded in [Performance](PERFORMANCE.md#matched-attachments-and-beard-boundary).

## Measurements

Development PC: Windows, Ryzen 5 5500, Radeon RX 7900 XTX. Browser GPU renderer: ANGLE / Direct3D 11 on the AMD card. The webcam was enumerated but returned no frames during this review, so these comparisons use Matplotlib's public-domain portrait with deterministic small translations. They are not measurements of live head motion, camera exposure/driver delay, or foreground display presentation.

The isolated comparison uses identical 640×360 inputs, one face, expression coefficients and transform enabled, 30 warmup frames, and 180 measured frames per run. GPU round trip includes RGBA preparation, transport, inference, decoding, and result conversion; CPU includes its native call and result conversion. All measured frames returned 478 face points.

| Isolated run | Median round trip | p95 round trip | Process CPU time per frame |
| --- | ---: | ---: | ---: |
| CPU before GPU | 7.58 ms | 9.10 ms | 8.25 ms |
| Browser GPU | 13.06 ms | 24.36 ms | 17.36 ms |
| CPU after GPU | 8.30 ms | 9.92 ms | 9.29 ms |

Process CPU time sums user/system time for the Python process and, for GPU, its browser processes; it is not GPU utilization or elapsed latency. The GPU detection call alone had a 10.50ms median, illustrating why model-only time omits relevant costs. These are short development runs with variation, not universal hardware rankings. Raw results: [isolated CPU/GPU comparison](performance/tracking-isolated.json).

The full-pipeline comparison uses the actual Godot viewer, 1280×720 synthetic source at 60fps, 640px tracking, face overlays, and a 512-strand/eight-segment beard. Each run measures twenty seconds after startup warmup. The test window is off-screen and does not accept input; its background presentation cadence should not be treated as foreground FPS. Landmark age is measured at Godot's receive callback from the shared capture timestamp, before display presentation. See [CPU run](performance/tracking-pipeline-cpu.json), [GPU run](performance/tracking-pipeline-gpu.json), and [Auto run](performance/tracking-pipeline-auto.json).

| Full pipeline | CPU | GPU | Auto (selected CPU) |
| --- | ---: | ---: | ---: |
| Tracking median, recent 240 results | 9.59 ms | 14.96 ms | 9.03 ms |
| Tracking throughput, recent 2 seconds | 59.96 fps | 55.44 fps | 60.04 fps |
| Landmark age at viewer callback, p95 over 20 seconds | 27.26 ms | 84.76 ms | 28.84 ms |

The off-screen viewer displayed about 28 frames/sec in all three runs; this background-window result is separate from the tracking throughput above. GPU remained active throughout the measured GPU run, with no fallback. Auto's conservative calibration reported 10.10ms CPU versus 26.85ms GPU while CPU continued tracking, then released the unused browser. Its settled CPU performance is reported in the table, not the temporary calibration workload.

Auto selected CPU on this hardware. Keep Auto as the normal choice; explicit GPU is useful for comparing a different machine or workload. Reducing tracking width can reduce transfer/preprocessing costs, but changes image detail. Disabling unused optional outputs is available; it should be measured rather than assumed to provide a large improvement.

## Reproduce and validate

```powershell
# Actual GPU models, live option changes, and recovery after browser termination:
.\buildtools\python-3.15.0\python.exe -B tools\check_tracking.py

# Same-image CPU → GPU → CPU comparison, without opening a camera:
.\buildtools\python-3.15.0\python.exe -B tools\benchmark_tracking.py --frames 180 --warmup 30 --output artifacts\tracking.json

# Complete viewer pipeline; repeat with --tracking-backend gpu and auto:
.\buildtools\python-3.15.0\python.exe -B tools\benchmark.py --portrait --tracking-backend cpu --seconds 20 --warmup 8 --offscreen --beard --beard-strands 512 --beard-segments 8 --output artifacts\pipeline-cpu.json

# Standard regression and Godot integration checks:
.\buildtools\python-3.15.0\python.exe -B tools\check.py
```

For a live camera benchmark, replace `--portrait` with `--camera <discovered-index>` and keep a face in view. Neither benchmark saves camera images/video. The direct GPU check is separate from ordinary CI tests because hardware/browser availability varies. Regression coverage includes initialization failure, runtime GPU failure, Auto selection in both directions, binary packet validation, zero-valued settings, live resolution changes, and the viewer's actual Apply action without a camera restart.

Implementation: [tracking engine](../backend/tracking/engine.py), [browser bridge](../backend/tracking/browser_tracker.py), [GPU worker](../backend/tracking/web/worker.mjs), [live configuration](../backend/pipeline/tracking_config.py), and [desktop panel](../viewer/tracking/tracking_panel.gd). The earlier [official MediaPipe review](MEDIAPIPE_FACE_LANDMARKER.md) records the upstream capabilities and sources that informed this implementation.
