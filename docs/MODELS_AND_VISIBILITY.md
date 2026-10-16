# Model library, head visibility, and GPU timing

Implemented October 16, 2026. Restart the backend and viewer after updating. The native extension has already been rebuilt in the development workspace; other existing installations should run `Setup.ps1 -SkipInstall` to rebuild it.

## Pink dots and visibility

Pink/magenta points mark **generated hair roots**, including scalp, mustache, eyebrow, and expanded beard roots. They are attachment guides calculated from the tracked face, rather than extra points detected by MediaPipe. Toggle **Hair → Roots → Show generated roots** to hide them without removing hair. Orange general virtual landmarks have their own toggle under **Landmarks**. Root-surface guides also have a separate control under **Hair → Root surface**.

The live preview previously drew points and hair as 2D overlays with no head depth test. It now defaults to **Landmarks → Visibility → Hide behind head**. This applies to measured landmarks, general virtual landmarks, generated-root markers, root-surface markers, and live strands. Disable it when inspecting hidden guides. **Head depth** and **Crown height** adjust the estimated back/scalp surface. Settings persist in the viewer's existing preferences. The 3D mannequin continues to use its own depth buffer.

The occluder uses the measured face's triangle topology and relative landmark Z, plus a closed fitted cranium behind the face outline. A native rasterizer produces a 384-pixel-wide float depth texture once per tracking result. All overlays share that texture. Fragment tests clip only hidden parts of strands, so a strand can emerge beyond the head silhouette. Mirroring and letterboxing use the same video coordinates as the preview.

This is **estimated head self-occlusion**, not a depth-camera scan or scene segmentation. Untracked hands, headphones, furniture, and other objects do not occlude overlays. Live strand physics still runs in 2D; each strand uses its root's estimated Z for visibility. It does not yet simulate every strand vertex in 3D or resolve strand-on-strand depth. A future accessory must supply depth to the shared shader, or use a full 3D rendering path, to participate correctly. Extreme poses and inaccurate fitted head dimensions can produce imperfect edges.

The geometry check hid 186 of 468 measured face vertices at both ±65° yaw, versus six in the frontal fixture, with about 1.8–2.3ms to construct/upload the map in the standalone test. Actual shader tests verify near/far points, a strand crossing the head silhouette, and mirrored coordinates. These use synthetic geometry, not a live camera or a claim of exact anatomical reconstruction.

A twenty-second [complete-pipeline check](performance/occlusion-pipeline-cpu.json), after eight seconds of warmup, kept CPU tracking at 59.94fps, with 8.74ms median inference round trip and 28.32ms p95 landmark age at the viewer callback. It used the same synthetic portrait, 1280×720/60fps source, 640px tracking, and 512-strand/eight-segment beard as the earlier comparison. The off-screen viewer displayed 27.1fps with no gaps over 50ms; as in the earlier report, background-window presentation is not a foreground FPS measurement.

## Choose, download, and import models

Open **Tracking → Models · select / download…**. The group expands without permanently crowding the confidence/settings controls. The browser studio exposes the same library below MediaPipe settings.

1. Choose a model for Face, Hand, or Pose.
2. If it is not installed, press **Download selected … model** and wait for Ready.
3. Press **Apply tracking settings**. Enable **Body pose** or **Hands** under Capture/Tracking to run those tasks. Changing their model does not enable a disabled task automatically.

| Task | Official bundles | Download size |
| --- | --- | ---: |
| Face | Standard, 478 points and optional expression/transform outputs | 3.6 MiB |
| Hands | Full, 21 points per hand | 7.5 MiB |
| Pose | Lite | 5.5 MiB |
| Pose | Full | 9.0 MiB |
| Pose | Heavy | 29.2 MiB |

Google currently lists **one standard Face Landmarker bundle** and **one Hand Landmarker bundle**; Lite/Full/Heavy are Pose variants. Models from different tasks are not interchangeable. The library follows the official [face](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker#models), [hand](https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker#models), and [pose](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker#models) listings. All catalog URLs pin float16 version 1, with SHA-256 and size checks recorded in [the catalog](../backend/tracking/models.py).

For a compatible custom model, choose its task type and **Import compatible .task…**. The browser provides a file picker and Import button. Imports must be complete Landmarker task bundles, under 100 MiB, with the expected model members. The importer checks the task type, expanded size, CPU initialization, optional face outputs, and a blank-image inference before publishing the model. A generic classifier, detector, raw `.tflite`, or differently indexed mesh is not a substitute. Custom face models must retain the standard 478-point layout; graph validation alone does not prove semantic landmark equivalence.

Files download to a temporary path and are published atomically after verification. Failed downloads/imports leave existing files and tracking selection intact. Only one library job runs at a time, with progress/error reporting. Custom IDs are content hashes; imported files and labels cannot choose arbitrary filesystem destinations. Downloaded/imported models persist in `models/` (or the existing `LENZFORGE_MODELS` directory override); custom metadata lives in `library.json`. These files are ignored by Git. Active model choices follow the existing session-scoped tracking settings and reset when the backend restarts.

Both native CPU and browser GPU resolve the same selected model. Changing a selection uses the existing live reconfiguration flow: capture continues, CPU initializes the new configuration, and GPU warms if requested. No browser CDN or remote inference is introduced. All five official bundles are installed in the current workspace and have passed native CPU and browser GPU checks. The portrait fixture verified 478 face points and 33 pose points; it is not a comprehensive hand-detection accuracy test.

## Why GPU was slower than native CPU

The original comparison crossed **two runtimes**: optimized native Python MediaPipe/XNNPACK on CPU versus JavaScript/WASM/WebGL in a browser worker on GPU, with a local image/result bridge. It was not the same native executable with only its device changed.

A second diagnostic uses the identical browser worker and bridge with a CPU delegate, then a GPU delegate. Each run uses the same 640×360 public-domain portrait translations, one face, expression coefficients and transform enabled, 30 warmup frames, and 180 measured frames. No live camera is involved. All measured frames returned 478 points. [Raw diagnostic results](performance/tracking-runtime-breakdown.json).

| Runtime | Median complete request | Median browser detection call |
| --- | ---: | ---: |
| Native CPU, before browser runs | 7.79 ms | — |
| Browser WASM CPU | 20.83 ms | 17.80 ms |
| Browser GPU, Radeon RX 7900 XTX / ANGLE D3D11 | 13.01 ms | 10.40 ms |
| Native CPU, repeat | 8.20 ms | — |

**GPU accelerated the browser implementation**, but that implementation still took longer than native CPU. The GPU run's median input preparation was 0.10ms and result decoding 0.51ms. The browser task call accounted for 10.40ms, so eliminating the external bridge alone would not close the observed gap. Medians from separate distributions should not be added as an exact accounting identity.

`detectForVideo` is synchronous and encompasses the task graph, preprocessing, GPU work, synchronization, and results becoming available to JavaScript. This timing is **not isolated GPU kernel time**. The benchmark does not identify which internal stage dominates. A small single-face workload can favor native CPU because scheduling, texture transfers, readbacks, and runtime costs compete with the computation saved by GPU parallelism. Internal tensor sizes are fixed; increasing camera resolution does not proportionally increase neural-network work. Godot also shares the graphics device in the complete application; the isolated comparison above excludes that workload.

Keep **Auto** as the default, or compare explicit CPU/GPU for the models and tasks you actually use. Larger models may change the outcome. A GPU-native capture/texture path or another native GPU runtime could be investigated next, but requires separate compatibility and end-to-end measurements; more GPU utilization alone is not evidence of lower latency.

## Verification

```powershell
# CPU/GPU models, real download, and compatible custom import:
.\buildtools\python-3.15.0\python.exe -B tools\check_models.py

# Native CPU vs browser CPU vs browser GPU, with transport stages:
.\buildtools\python-3.15.0\python.exe -B tools\benchmark_tracking.py --browser-cpu --frames 180 --warmup 30 --output artifacts\tracking-runtime-breakdown.json

# Geometry and rendered mirrored/partial-strand visibility:
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path viewer --script res://tests/occlusion_probe.gd -- --render

# Python, Godot, physics, layout, native IPC, and live Apply:
.\buildtools\python-3.15.0\python.exe -B tools\check.py
```
