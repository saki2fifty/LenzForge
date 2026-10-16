# MediaPipe Face Landmarker: capabilities and GPU findings

Reviewed October 16, 2026 against LenzForge commit `022a8eb`.

**MediaPipe Face Landmarker can run its landmark models on the GPU.** The official browser demo successfully initialized its GPU delegate and processed its bundled example image on this Windows machine. LenzForge currently runs inference on the CPU; its installed Windows Python package cannot enable GPU processing simply by changing the delegate option.

## Review scope and evidence

The [original MediaPipe Studio link](https://mediapipe-studio.webapps.google.com/studio/demo/face_landmarker) redirected to Google sign-in in both the page reader and an isolated browser. Its authenticated interface was not accessible. This document therefore inventories the [current official public demo](https://google-ai-edge.github.io/mediapipe-samples-web/#/vision/face_landmarker), which Google's [Face Landmarker overview](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker) links to, and distinguishes that interface from the underlying API.

The review inspected the public demo's image, webcam, model-selection, upload, settings, status, and navigation areas. GPU and CPU inference were exercised with its supplied image. Webcam capture, personal-image upload, custom-model execution, and sustained video performance were not tested.

Implementation details were checked against official demo source at [revision a0e2a1a](https://github.com/google-ai-edge/mediapipe-samples-web/commit/a0e2a1aad500dc7f116bc9800a686af1b676ca5d). That pins the reviewed source, rather than assuming future changes to `main` match this document. Browser observations describe the deployed page on the review date.

| Local check | Result | What it establishes |
| --- | --- | --- |
| Public demo, GPU selected | Sample inference completed; selector remained GPU | The browser GPU path works here without the demo reporting CPU fallback. |
| Public demo, CPU selected | Sample inference completed | Both delegate choices initialize and execute here. |
| Browser graphics renderer | AMD Radeon RX 7900 XTX through ANGLE / Direct3D 11 | This browser path works on the development machine's AMD hardware; NVIDIA/CUDA is not required for it. |
| Project Python 3.15.0, MediaPipe 1.1.1, explicit GPU delegate | `NotImplementedError`: `ImageCloneCalculator: GPU processing is disabled in build flags` | The installed Windows wheel lacks the required GPU graph support. This was an isolated initialization probe using the existing model, without opening a camera. |

Research snapshots and probe output are retained locally under ignored `artifacts/mediapipe-review/`. No application settings or inference implementation were changed by this review.

## Public demo controls

| Area | Options and observed defaults | Behavior |
| --- | --- | --- |
| Model | Standard / Upload; one standard Face Landmarker bundle | Downloads and initializes the selected model; shows loading progress and active/cached state. |
| Custom model | File picker accepts `.tflite` and `.task` | Requires a model compatible with Face Landmarker; accepting a file extension does not make arbitrary models interchangeable. |
| Input | Image / Webcam; fresh session starts with an example image | Image mode supports choosing another image. Webcam mode provides an enable/disable button. |
| Maximum faces | 1–10, default 1 | A demo slider limit; the API describes a positive integer rather than a universal limit of ten. |
| Detection confidence | 0–1, step 0.01, default 0.5 | Acceptance threshold for detecting a face. |
| Presence confidence | 0–1, step 0.01, default 0.5 | Acceptance threshold for face presence during landmark estimation. |
| Tracking confidence | 0–1, step 0.01, default 0.5 | Acceptance threshold for tracking. |
| Delegate | GPU / CPU; default GPU | Reinitializes the task using the selected execution delegate. |
| Output | Mesh over the image or camera frame | Includes facial surface connections, eyes, eyebrows, lips, outline, and irises. |
| Diagnostics | Status, inference time, history chart, separate GPU/CPU averages | Useful for observing execution, with the timing limitations below. |

The control definitions and defaults are in the [face template](https://github.com/google-ai-edge/mediapipe-samples-web/blob/a0e2a1aad500dc7f116bc9800a686af1b676ca5d/src/templates/face-landmarker.html). Face-count and confidence changes are sent to the worker; image mode reruns the current image. The drawing code colors right eye/eyebrow/iris connections red, left connections green, the face surface translucent gray, and lips/outline light gray. Both optional output families are requested internally, but this page does not provide a dedicated blendshape chart or transformation-matrix inspector. See the [face task implementation](https://github.com/google-ai-edge/mediapipe-samples-web/blob/a0e2a1aad500dc7f116bc9800a686af1b676ca5d/src/tasks/face-landmarker.ts).

Model downloads use the browser Cache API, keyed by URL, so reloads and delegate changes can reuse model bytes. Cache availability and storage quotas can affect persistence. Custom file uploads are transient rather than ordinary URL cache entries. The selector distinguishes active models from downloaded ones and supports removing inactive cached models. See [model caching](https://github.com/google-ai-edge/mediapipe-samples-web/blob/a0e2a1aad500dc7f116bc9800a686af1b676ca5d/src/components/model-cache.ts) and [model selection](https://github.com/google-ai-edge/mediapipe-samples-web/blob/a0e2a1aad500dc7f116bc9800a686af1b676ca5d/src/components/model-selector.ts).

The header links documentation, Web/Android/iOS/Python examples, and StackBlitz editing. Sidebar entries for hand tracking, pose, segmentation, and other tasks open separate demos. The reviewed face interface has no recording/export controls, hairstyle editor, or virtual-landmark editor. A drag-and-drop instruction exists in the image template, but working drag-and-drop was not verified; the inspected image handler explicitly supports the file picker.

## Model outputs and their uses

| Output | Contents | Potential LenzForge use |
| --- | --- | --- |
| Face landmarks | 478 estimated 3D points per detected face, including iris points | Face overlays, attachment anchors, and references for virtual head extensions. |
| Face blendshapes, optional | 52 named expression coefficients | Eyelid, eyebrow, mouth, cheek, and jaw animation for an expression rig. |
| Facial transformation matrix, optional | A 4×4 transform relating the canonical face model to the detected face | Positioning and orienting 3D accessories or a fitted head rig. |

The bundle combines a face detector, face-mesh estimator, and expression estimator. Google's model table lists float16 assets with detector input 192×192, mesh input 256×256, and blendshape input 1×146×2. These internal tensor sizes differ from the camera resolution. The demo uses the versioned `face_landmarker/float16/1/face_landmarker.task` bundle. Updating an SDK package alone does not establish that different model weights are installed. See the [model overview](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker) and [demo model selection](https://github.com/google-ai-edge/mediapipe-samples-web/blob/a0e2a1aad500dc7f116bc9800a686af1b676ca5d/src/tasks/face-landmarker.ts).

Landmark X/Y coordinates are normalized by image dimensions. Z is estimated relative depth, with smaller values closer to the camera and a scale approximately comparable to X. These coordinates are not a metric depth-camera scan. See the [NormalizedLandmark API](https://developers.google.com/edge/api/mediapipe/js/tasks-vision.normalizedlandmark).

Blendshape coefficients describe facial motion, not a person's identity or a reliable psychological state. They can drive a compatible expression rig; the rig and its deformations still need to exist in the application. The [blendshape model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20Blendshape%20V2.pdf) describes its landmark-derived inputs and expression outputs.

The facial transform is a better starting point for rigid 3D attachments than reconstructing all head orientation from two-dimensional distances. Integrating it still requires coordinate-system, camera-projection, mirroring, and scale checks; directly copying it into a Godot node is not a verified integration. The mapping from the canonical face is described in the [FaceLandmarkerOptions API](https://developers.google.com/edge/api/mediapipe/js/tasks-vision.facelandmarkeroptions).

## GPU support depends on the runtime

| Runtime | Support and implications |
| --- | --- |
| Browser Tasks API on this Windows PC | Explicit GPU and CPU delegates work in the public demo. Its worker diagnostics check WebGL2 and graphics-context health. |
| LenzForge's installed Windows Python wheel | CPU works; requesting GPU fails at graph initialization because GPU processing was disabled when the wheel was built. |
| Python support documented by Google | The BaseOptions reference currently limits GPU support to Ubuntu. This statement concerns the Python API, not every MediaPipe runtime. |
| Godot rendering in LenzForge | Uses the GPU for rendering; that does not select the delegate for the separate Python inference process. |

The demo has an explicit GPU-initialization failure path that retries on CPU and reports the fallback. Its browser diagnostics also consider missing/lost WebGL contexts and software rendering. A production integration should expose the **actual active delegate**, including fallback reasons, rather than displaying only the requested setting. See the [base worker](https://github.com/google-ai-edge/mediapipe-samples-web/blob/a0e2a1aad500dc7f116bc9800a686af1b676ca5d/src/workers/base-worker.ts) and Google's [Python BaseOptions documentation](https://ai.google.dev/edge/api/mediapipe/python/mp/tasks/BaseOptions).

GPU selection does not imply every stage runs on the GPU. The reviewed MediaPipe graph passes acceleration options to face detection and landmark estimation, but defaults the blendshape subgraph to CPU XNNPACK. Consequently, an XNNPACK log alone cannot establish the delegate used by the landmark models. In LenzForge, CPU selection is confirmed independently by its omitted delegate option, the installed API's CPU default, and the failed explicit GPU probe. See the upstream [face graph implementation](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/tasks/cc/vision/face_landmarker/face_landmarker_graph.cc); this upstream link is mutable.

## Responsiveness and timing

The browser API offers `IMAGE` and `VIDEO`; webcam frames use `VIDEO`. Its detection calls are synchronous, so placing them on the interface thread can stall interaction. Single-face tracking enables built-in temporal smoothing; increasing the maximum face count above one disables that smoothing. Expression names use the subject's left/right, so mirrored inference input reverses their meaning. Keeping inference input unmirrored and mirroring display is preferable for LenzForge. These behaviors are documented in the [Web guide](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker/web_js).

The public sample addresses responsiveness with a separate worker and transferable `ImageBitmap` inputs. Its normal webcam loop schedules another inference after the previous result, ignores unchanged video frames, and maintains increasing timestamps. Received bitmaps are closed after processing. Images chosen with the file picker are read in the browser; inference is local, although page assets and model downloads use the network. See [vision input handling](https://github.com/google-ai-edge/mediapipe-samples-web/blob/a0e2a1aad500dc7f116bc9800a686af1b676ca5d/src/components/base-vision-task.ts) and the [face worker](https://github.com/google-ai-edge/mediapipe-samples-web/blob/a0e2a1aad500dc7f116bc9800a686af1b676ca5d/src/workers/face-landmarker.worker.ts).

Python additionally supports `LIVE_STREAM`, with asynchronous callbacks and dropping new input when busy. `IMAGE` and `VIDEO` block their calling thread. LenzForge already calls `VIDEO` from a dedicated worker with a latest-frame mailbox, so merely renaming its mode to `LIVE_STREAM` would not demonstrate a speed improvement. See the [Python guide](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker/python) and [LenzForge architecture](ARCHITECTURE.md).

The demo's measured interval surrounds the detection call inside its worker. It excludes capture, transferring the input into the worker, returning the result, and drawing/presentation. The main time badge averages up to ten recent samples; the graph retains fifty. Separate GPU/CPU averages accumulate per route during the page session, including initial samples, and are not automatically a controlled benchmark. Delegate changes reset the rolling window. See the [timing implementation](https://github.com/google-ai-edge/mediapipe-samples-web/blob/a0e2a1aad500dc7f116bc9800a686af1b676ca5d/src/components/inference-timer.ts).

The local sample runs established functionality, not a CPU-versus-GPU speed ranking. Initial GPU work can include compilation and warmup. A useful comparison must use identical inputs and output flags, discard warmup, and measure sustained median and 95th-percentile inference time, capture-to-display latency, dropped frames, and CPU/GPU load. Transfers and competition with Godot rendering can change which implementation feels faster.

One implementation detail should not be copied: the reviewed face worker defaults numeric confidence options using `value || 0.5`. That replaces a deliberately selected zero with 0.5, despite zero being allowed by the slider/API. Future LenzForge controls should validate the range and preserve zero, using an explicit missing-value check.

## What LenzForge already uses

| Capability | Current implementation |
| --- | --- |
| 478 face/iris landmarks | Enabled through the Tasks API adapter; positions reach Godot through LMK1. |
| One face and video tracking | Configured in the processor; the consumer currently takes the first face. Multi-face support needs changes downstream as well as a different model setting. |
| Detection and tracking thresholds | Both set to 0.5; presence uses the API default of 0.5. These are not exposed as current studio controls. |
| Blendshapes and face transform | Already requested and exposed as `blendshapes` and `face_transform` in backend results/JSON. LMK1 does not currently deliver these to Godot. |
| GPU inference | Not implemented in the current Windows backend. |
| Virtual landmarks | Procedural points derived from tracked references; they do not increase the model's measured output count. |
| 3D mannequin and hair | Application rendering and simulation, separate from the Face Landmarker task. |

Evidence: [Tasks adapter](../backend/graphs/tasks_compat.py), [tracking processor](../backend/pipeline/web_processor.py), [output architecture](ARCHITECTURE.md), and [virtual-landmark guide](LANDMARKS.md). The processor's face-point `confidence: 1.0` is a compatibility placeholder, not a measured per-point certainty score.

## Recommended next work

1. **Prototype the proven browser GPU path locally.** Package a worker using the official Tasks API and local model assets. Design how it receives frames and returns timestamped results before integrating it into the desktop pipeline. This is a runtime/transport change, not a Python delegate toggle.
2. **Preserve one camera owner and bounded work.** Keep the latest-frame behavior. Avoid adding a JPEG encode/decode loop just to feed inference; quantify any raw-frame or GPU-transfer overhead. A browser sidecar cannot directly use the current Windows shared-memory transport without a bridge.
3. **Make delegate selection observable.** Report requested versus active CPU/GPU execution, initialization failures, and timings. Retain the working CPU implementation as a fallback while comparing both paths.
4. **Use or disable optional outputs deliberately.** Send the already-computed transform and blendshapes through a versioned desktop protocol for 3D attachments/expression animation, or offer a landmarks-only mode when those outputs are unused. Measure the savings instead of assuming them.
5. **Expose useful tracking controls.** Add the three confidence thresholds with defaults/reset behavior. Keep one face as the default for this single-user grooming workflow and its smoothing benefit.
6. **Validate the full experience.** Compare sustained capture-to-display latency and tracking stability with the same camera, resolution, face count, and output flags. Test face loss/reacquisition, head turns, and concurrent Godot rendering before choosing a new default.

These are proposed implementation steps; this review does not enable a new backend. The browser approach is the strongest first candidate because GPU execution was demonstrated on the existing hardware. A native GPU integration remains an alternative, but requires separate build/runtime and frame-transfer investigation.

## Limits relevant to virtual head landmarks

Face Landmarker does not produce measured points across the entire scalp, behind the ears, or around the back of the head. LenzForge's extra chin, side, and crown points remain fitted estimates anchored to visible facial geometry. A larger face-count setting or confidence change cannot add those measurements.

Face tracking is also distinct from hair segmentation, identity recognition, strand physics, and full-head reconstruction. Severe occlusion, unusual lighting, distance, and extreme viewpoints can reduce model quality; the [Face Mesh V2 model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20MediaPipe%20Face%20Mesh%20V2.pdf) describes the model's intended conditions and limitations. Better rigid head pose and fitting can improve the virtual surface, but unseen geometry still needs a chosen shape model or additional sensing.
