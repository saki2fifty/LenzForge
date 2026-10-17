# Performance measurements

## GPU virtual-camera transfer and head calibration

Measured October 17 on the same Ryzen 5 5500 / RX 7900 XTX workstation, Godot 4.7.2 Compatibility rendering, AMD driver 26.6.4. Sequential 20-second runs, 5-second warmup, synthetic 1280×720 portrait at 60 fps, actual CPU face inference at width 640, 1,024 × 8 facial strands, off-screen rendered viewer, isolated settings and an active Windows camera client. The CPU comparison forces the original output transport with `LENZFORGE_CAMERA_CPU=1`; tracking stays on CPU in **both** runs.

| Measurement | CPU camera transport | Shared GPU textures |
| --- | ---: | ---: |
| Distinct matched preview fps | 59.984 | 60.002 |
| Renderer fps | 120 | 120 |
| Preview intervals >50 ms / mismatched presentations | 0 / 0 | 0 / 0 |
| Output handoff median / p95 | 1.784 / 2.137 ms | 1.802 / 2.545 ms |
| Publisher CPU color conversion median / p95 | 2.681 / 3.084 ms | Removed; conversion runs on GPU |
| Hair physics/upload median | 1.028 ms | 1.031 ms |
| Preview interval p95 | 25.022 ms | 25.114 ms |

The improvement is removal of full RGBA readback/CPU handoff and the publisher's CPU color-conversion stage, **not an observed preview FPS or render-thread latency gain**. GL/D3D synchronization still costs time; its p95 was higher in this run. The GPU path reports zero publisher CPU conversion time because that stage no longer executes, not because GPU conversion is free. These timings do not measure aggregate system CPU, GPU energy, display scanout or receiving-app latency. Output handoff is sampled at preview presentation and can repeat a recent measurement.

The Frame Server video processor converts shared RGBA textures to NV12. CPU-only clients still need NV12 readback in that service; GPU-backed samples can remain on the GPU. Unsupported interop uses the original bounded CPU transport. No tracking quality, simulation settings, strand counts or source rate were reduced. [CPU report](performance/2026-10-17-camera-cpu-transport.json), [GPU report](performance/2026-10-17-camera-gpu-transport.json), [implementation and reproduction commands](VIRTUAL_CAMERA.md).

The calibration wizard performs separate CPU analysis only while collecting poses, capped below four requests per second. The fit is a one-time bounded search over four head parameters. Normal preview runs no additional segmenter or optimizer, retains the same shared surface topology, and refreshes hair bindings only when its shape changes. The runs above include the new code with calibration closed. They do not measure a calibration session's temporary CPU load or establish personal-fit accuracy. See [calibration behavior and limits](CALIBRATION.md).

## Custom virtual camera: local validation

The installed custom Windows camera now passes normal-user startup and discovery, independent Media Foundation reception, close/reopen, and composed-image validation. Two 180-frame receiving runs measured **60.000 and 60.013 fps** at 1280 × 720. The received image contains the mannequin and styled hair, without studio controls. Native source-reader checks also cover 30/60 fps, COM activation/attribute/lifetime, and RGBA-to-NV12 color/chroma. These checks establish compatibility with the Windows Media Foundation consumer used here; individual calling apps still need their own validation. See [setup and test commands](VIRTUAL_CAMERA.md).

A final 20-second synthetic portrait run with CPU tracking, 1,024 × 8 facial strands, and virtual-camera output **off** retained **59.99 matched preview fps**, a 120 fps render rate, zero frame intervals over 50 ms, and zero frame/landmark mismatches. Hair physics/upload median was 1.115 ms. The output viewport is absent while off, so this confirms the normal preview still runs at its intended rate; it does not measure the cost of output readback/conversion or Windows consumption. [Raw report](performance/2026-10-17-virtual-camera-disabled.json).

With an independent Windows client consuming the virtual camera, the same 20-second workload retained **59.99 matched preview fps**, 120 render fps, zero intervals over 50 ms, zero mismatches, and no replaced pending output frames. Median output readback plus handoff was **1.878 ms** (p95 2.594 ms); native RGBA-to-NV12 conversion on its worker was **2.689 ms** (p95 3.433 ms). Hair physics/upload median was 1.138 ms. Preview interval p95 was 25.235 ms, so preserving average throughput does not imply perfectly even pacing. Output timings are sampled at preview presentation and can repeat a recent output measurement; they are not end-to-end camera-app latency measurements. Runs were sequential on the same workstation using a synthetic portrait, not a physical webcam. [Active-output report](performance/2026-10-17-virtual-camera-enabled.json).

Registration initially exposed a startup bug: Windows queries source metadata inside the normal publisher process, where creating global shared memory requires privileges it does not have. Transport allocation now happens only when the Frame Server starts streaming. A regression check activates the COM source and reads its formats without allocating the transport. Installation requires elevation once; normal startup and reception were verified without it.

## October 17: restoring preview throughput

Baseline `ca89eb6` reproduced the reported 30 fps ceiling on the same Ryzen 5 5500 / RX 7900 XTX / 60 Hz Windows workstation. The current defaults use 1,024 facial strands × 8 segments and solid 3D head collision, a larger workload than the older 256-strand measurements below.

Two causes were isolated. With hair hidden, the Windows Compatibility renderer still ran at **30 fps with VSync enabled**. The camera source continued at 60 fps. Disabling VSync alone, using the original serial solver, restored **59.88 distinct preview frames/sec**, but rendered 409 frames/sec unnecessarily. With hair enabled, presentation stalls also caused the 120 Hz solver to execute more catch-up steps per render frame, compounding the slowdown. This identifies the presentation path on this machine, not a general limitation of all VSync implementations or a MediaPipe GPU/CPU problem.

The fix defaults to **Responsive** pacing: VSync off, rendering capped at 120 fps. **Look → Preview pacing** also offers **Display synchronized** and **Low power (up to 60 fps)**, with automatic persistence. Rendering above camera rate improves the opportunity to pick up a newly published frame; it does not create extra camera frames or make a 60 Hz monitor display 120 unique frames/sec.

The solver now uses the main thread plus up to three persistent native C++ workers for independent strand ranges. Small workloads run serially. No strand counts, simulation frequency, constraint iterations, collision sweeps, or tracking quality were reduced. Mesh/attachment loops cache validated packed-array pointers, and native depth projection replaces the GDScript depth-copy loop.

### Full preview pipeline

Sequential runs used the public-domain portrait bundled with Matplotlib, synthetic 1280×720 capture at 60 fps, actual CPU face inference at width 640, the real studio/HTTP/shared-memory path, and the debug native extension. No browser or recording was active. Settings were isolated. The table uses off-screen rendered windows to keep window placement consistent; these are texture submissions, not measured display scanout.

| Measurement | Before, no hair | Before, 1,024 × 8 | After, 1,024 × 8 |
| --- | ---: | ---: | ---: |
| Measurement window | 8 s | 10 s | 20 s |
| Distinct preview frames/sec | 29.88 | 22.50 | **59.98** |
| Renderer FPS at end | 30 | 22 | 120 |
| Capture FPS | 60.0 | 60.0 | 60.0 |
| Preview interval p95 | 34.64 ms | 46.29 ms | **16.98 ms** |
| Preview gaps >50 ms | 0 | 1 | 0 |
| Capture-read to texture-submission p95 | — | 17.00 ms | **7.37 ms** |
| Hair step + packing/upload CPU median | — | 9.40 ms | 1.08 ms |

Hair CPU time in this table depends on the number of physics steps per rendered frame. Use the fixed-step comparison below to assess simulation speed separately from pacing. The final run processed 1,200 source frames in 20.006 seconds, with 60 fps tracking. Video upload remained about 0.33 ms median; replacing the capture pipeline was not justified by its cost.

Raw reports: [before, no hair](performance/2026-10-17-before-nohair.json), [before, hair](performance/2026-10-17-before-portrait.json), [VSync-only experiment, original solver](performance/2026-10-17-before-unsynced.json), [final off-screen run](performance/2026-10-17-after-portrait.json). Baseline counters used intervals divided by requested duration (one fewer than frame count); updated counters use actual elapsed wall time and frame count. This small counting difference does not account for the throughput improvement.

A separate [on-screen final run](performance/2026-10-17-after-visible.json) measured **60.03 preview fps**, 17.08 ms p95 frame interval, and zero gaps over 50 ms across another 20 seconds. The [on-screen baseline](performance/2026-10-17-before-visible.json) also reproduced the slowdown (21.0 preview fps), so moving the test window off-screen was not its sole cause. An [intermediate worker-only/120 fps run](performance/2026-10-17-worker-cap120.json) had four long gaps, including a 451 ms outlier; their cause was not isolated. Neither final 20-second run reproduced them. These are short sequential observations under desktop load, not a guarantee of stall-free operation, physical-camera throughput or sensor-to-screen latency. No physical webcam was opened for these October 17 comparisons.

### Fixed-step CPU cost

The headless `frame_budget_probe.gd` rotates the canonical head through yaw/pitch, warms 40 updates and measures 180. Automatic hair processing is disabled: each sample explicitly advances two 120 Hz steps, independent of renderer speed. Tracking time here means the viewer callback (head geometry, depth map, attachment), **not MediaPipe inference**. These stage timings measure elapsed time on the calling thread, including worker synchronization, not summed processor time or power consumption. Total also includes buffer generation and upload preparation; GPU completion is excluded.

| Workload | Simulation median before → after | Simulation p95 before → after | Total CPU median before → after |
| --- | ---: | ---: | ---: |
| 1,024 × 8, collision disabled for diagnosis | 1.68 → 0.49 ms | 1.93 → 0.80 ms | 3.40 → 1.75 ms |
| 1,024 × 8, full head collision | **4.96 → 1.23 ms** | 7.29 → 1.56 ms | **8.36 → 3.70 ms** |
| 2,048 × 16, beard/brows/Afro with head collision | **14.28 → 4.04 ms** | 15.47 → 4.64 ms | **18.08 → 7.30 ms** |

Raw stages: [before](performance/2026-10-17-frame-budget-before.json), [after](performance/2026-10-17-frame-budget-after.json). Default simulation time fell about 75%; maximum combined simulation fell about 72%. `parallel_physics.gd` compares entire output buffers exactly between serial/parallel execution, including turns, mixed regional motion, forces, count/segment changes, small-workload fallback, and worker shutdown. Existing collision, occlusion, dynamics, persistence and layout checks also pass.

Reproduce after `Setup.ps1 -SkipInstall`:

```powershell
.\buildtools\python-3.15.0\python.exe tools/benchmark.py --portrait --beard --beard-strands 1024 --fps 60 --tracking-backend cpu --warmup 5 --seconds 20 --offscreen --output artifacts/preview-current.json
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path viewer --script res://tests/frame_budget_probe.gd -- current
```

The second command writes `artifacts/frame-budget-current.json`. To isolate pacing on the current build, append `--vsync on --frame-cap 0` or `--vsync off --frame-cap 120` to the first command. Omit `--offscreen` for an on-screen window, or replace `--portrait` with `--camera <index>` for a physical device. Benchmarks run sequentially and neither load nor save personal designs. They do not record camera images.

### Facial layering follow-up

The height-based beard/mustache ordering uses a cached permutation during native buffer packing. Sorting runs only when root placement changes; the simulation and single draw batch remain intact. On October 17, a sequential 20-second run of the same off-screen portrait/CPU/1,024 × 8 benchmark measured **59.97 distinct preview fps**, **17.23 ms p95 frame interval**, zero gaps over 50 ms, and **1.30 ms median / 1.84 ms p95** for hair physics plus upload preparation. This preserves the recovered throughput; the single run is not an isolated measurement of sorting overhead. [Raw report](performance/2026-10-17-strand-layering.json).

`tests/strand_layering.gd` checks stable root-height order, measured/virtual reassignment, indexed selection, invalid permutations and resizing. Run it with `--render` to additionally check actual overlap pixels in the 2D preview and 3D mannequin, mirroring and head occlusion.

### Strand depth and sideburn follow-up

The live hair overlay now uses a transparent 3D viewport and the same instanced GPU depth/color shader as the mannequin. This adds a depth pass and one composite; it avoids per-frame CPU sorting and retains the native packed buffer. Ear-front sideburns reuse the existing strand budget and cached surface bindings. Opaque strand intersections are resolved per pixel; head masking uses the original physical depths.

Two sequential 20-second runs used the same portrait/CPU/1,024 × 8 workload on October 17:

| Run | Distinct preview fps | Interval p95 | Gaps >50 ms | Hair physics/upload CPU median / p95 |
| --- | ---: | ---: | ---: | ---: |
| Initial depth renderer | 60.03 | 17.08 ms | 0 | 1.14 / 1.47 ms |
| Final renderer, corrected alpha composite | 59.93 | 17.00 ms | 1 (50.23 ms) | 1.09 / 1.32 ms |

The final blend correction prevents applying alpha twice at transparent hair edges. The preceding root-height-only run measured 59.97 fps and 1.30 / 1.84 ms. These runs show maintained throughput on this workstation, not a measured renderer speedup: they include desktop variation and changed root placement. The final run's single long interval was not isolated to a cause; its largest recorded hair update was 4.99 ms. This is not a stall-free guarantee. CPU timing excludes GPU completion; preview counters measure texture submissions rather than monitor scanout. No physical webcam was used. [Initial report](performance/2026-10-17-strand-depth.json), [final report](performance/2026-10-17-strand-depth-final.json).

Rendered checks cover crossing endpoint depths, near/equal/far strands, mirrored live output, opaque head masking, transparent strands/taper space, color fidelity, and the mannequin. `tests/sideburn_render.gd` renders default front, ±60° and ±90° views and verifies that far-side sideburns produce no visible pixels behind the solid head. Placement tests check both ears, rotation, explicit attachment priority and saved controls. Reproduce the GPU checks with:

```powershell
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path viewer --script res://tests/strand_layering.gd -- --render
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path viewer --script res://tests/sideburn_render.gd
```

### Matched attachments and beard boundary

The viewer previously uploaded the newest video frame while drawing landmarks from an older capture. Its hair callback also ran before the readers, adding a render-frame delay. The native reader now retrieves the exact captured frame for each face result from the existing VID1 ring, using both frame ID and QPC timestamp. Readers run before attachment simulation/upload. A pinned root updates even when no fixed physics step runs, while the previous physics root preserves substep interpolation and free-joint inertia.

There is no additional FIFO or pose extrapolation. Missing or overwritten pairs clear overlays; a 150 ms result timeout resumes raw video. Frame locking follows completed tracking, so a slow delegate now limits matched preview throughput. Inference time moves the whole image later instead of letting its face overlays trail newer video. This fixes presentation skew, not model localization errors, internal model smoothing, camera blur or physical display latency.

Four sequential runs used the same workstation, 20-second public-domain portrait fixture, 5-second warmup, 1280×720 synthetic capture at 60 fps, 640-pixel face inference and 1,024 × 8 hair. Settings were isolated and no physical camera was opened. Baseline: `b0fa99d`.

| Measurement | Before CPU | Matched CPU | Before GPU | Matched GPU |
| --- | ---: | ---: | ---: | ---: |
| Distinct preview fps | 60.03 | 59.98 | 58.63 | 48.28 |
| Tracking results received / second | 59.93 | 59.98 | 46.73 | 48.28 |
| Video age at upload, median | 6.48 ms | 13.29 ms | 6.01 ms | 27.81 ms |
| Landmark age at callback, median | 16.46 ms | 15.72 ms | 29.57 ms | 30.08 ms |
| Preview interval p95 | 17.08 ms | 24.93 ms | 18.14 ms | 41.58 ms |
| Preview intervals >50 ms | 0 | 0 | 6 | 16 |
| Hair physics/upload CPU median | 1.07 ms | 1.16 ms | 1.14 ms | 1.06 ms |
| Mismatched rendered video/face timestamps | Not instrumented | **0** | Not instrumented | **0** |

The final GPU run's longest interval was 133.47 ms; it remained slower and less regular than CPU. Auto/CPU is the faster choice on this workstation. No inference/model settings or strand counts were reduced. These short sequential runs include desktop variation and changed beard placement; they are not an isolated native-reader speed test. Video and landmark ages above are recorded at different callbacks and must not be subtracted as a frame-pair skew measurement. The new skew metric samples the actual presented pair before drawing. CPU hair timings exclude GPU completion; preview counters measure texture submissions, not display scanout.

Raw reports: [before CPU](performance/2026-10-17-attachment-before-cpu.json), [matched CPU](performance/2026-10-17-attachment-after-cpu.json), [before GPU](performance/2026-10-17-attachment-before-gpu.json), [matched GPU](performance/2026-10-17-attachment-after-gpu.json). Reproduce with the existing full-pipeline command, changing `--tracking-backend cpu` to `gpu` for the second delegate.

`tools/check_attachment_sync.py` drives a separate moving canonical face, rapid translation/yaw reversals, 8–45 ms processing delays, 280 ms stalls, face loss and recovery. Frame IDs are independently encoded in NV12 pixels and read back from the uploaded texture. The final six-second run checked **599 matched render frames and 215 source textures**, with **zero failures**, including two timeout/recovery events. It also checks pinned-root positions before drawing, ring wraps, wrong timestamps/IDs and atomic rejection. This is a deterministic transport/attachment fixture without AI; it does not establish real-camera landmark accuracy.

`tests/beard_boundary.gd` verifies that automatic beard roots stay in front of the measured 234/454 rear edge under different head fits, maximum wrap widths, lower virtual and legacy offset modes. Head-shape edits refit cached bindings; normal tracking performs only sampling. Explicit per-strand landmark assignments remain available. `sideburn_render.gd` verifies both profile views and hidden far-side strands. The full regression suite passes, including unchanged 30/60/120 Hz motion response and serial/parallel physics parity.

```powershell
.\buildtools\python-3.15.0\python.exe tools/check_attachment_sync.py
```

## Earlier measurements

The October 16 [CPU/GPU tracking comparison](GPU_TRACKING.md#measurements) covers the browser worker, CPU fallback/Auto selection, and the complete viewer with a 512-strand beard. The older camera measurements below describe the October 15 capture optimization and use a different input/test setup.

Measured October 15, 2026 on Windows, Ryzen 5 5500, Radeon RX 7900 XTX, a 60 Hz display, and a NexiGo N960E FHD Webcam at 1280×720. Face/iris tracking and the desktop landmark overlay were enabled. No browser client or recording was active. The measurements use the actual Godot studio, its Start capture button, HTTP controls, and compiled shared-memory readers.

| Measurement | Before, requested 30 fps | Optimized, requested 30 fps | Optimized, requested 60 fps |
| --- | ---: | ---: | ---: |
| Measurement window | 10 seconds | 10 seconds | 20 seconds |
| Distinct preview frames/sec | 21.7 | 29.8 | 50.8 |
| Capture delivery/sec | ~21.9¹ | 29.92 | 60.05 |
| Tracking frames/sec | 21.74 | 29.79 | 59.74 |
| Preview interval p95 | 57.22 ms | 48.65 ms | 34.23 ms |
| Preview gaps over 50 ms | 71 | 9 | 1 |
| Gaps over 50 ms per second | 7.1 | 0.9 | 0.05 |
| Capture-read to texture submission, mean | Not instrumented | 9.13 ms | 8.36 ms |
| Capture-read to texture submission, p95 | Not instrumented | 17.64 ms | 15.59 ms |
| Snapshot/upload CPU time, mean | Not instrumented | 0.43 ms | 0.38 ms |

¹ The original build only exposed preview-worker throughput, used here as an approximation of capture throughput. The new capture counter measures hardware reads directly. Raw timing reports: [before 30 fps](performance/before-30.json), [optimized 30 fps](performance/after-30.json), [optimized 60 fps](performance/after-60.json). The 30 fps optimized run predates the final batched overlay; the 60 fps run includes it.

These are short development runs, not repeated controlled trials. Camera delivery, face motion, lighting, desktop load, and VSync phase vary. The 60 fps column also changes the requested camera rate; the 30 fps columns provide a comparison at the same setting. No camera images or recordings are included in these reports.

## Changes behind the improvement

- Removed the extra software wait after physical camera reads. The device already paces delivery; Windows event-wait overshoot was reducing throughput.
- Requested native NV12 from MSMF and copied its planes straight to shared memory. Tracking resizes Y/UV before RGB conversion. Full-resolution BGR is produced only for consumers that need it.
- Kept a validated BGR fallback, with reusable conversion buffers, for incompatible camera formats/layouts. Camera-reported frame rate is retained when the driver negotiates a lower rate.
- Removed an intermediate full-frame snapshot copy in the native video reader; reused image/texture objects and avoided resetting unchanged shader bindings. Snapshot validation checks the copied slot rather than discarding it because another slot received a newer frame.
- Replaced hundreds of antialiased circle draw commands with one instanced landmark batch. Synthetic rendered tests verify circle shape, mirroring, letterboxing, resizing, and hiding.
- At that time, let VSync pace Godot without an additional software frame cap. This was superseded by the October 17 pacing fix above. Capture defaults to 60 fps, with 30 and 24 still available.

The latest-frame policy prioritizes responsiveness. A 60 Hz display can receive fewer distinct camera frames than the camera produces when arrival times fluctuate: older frames are skipped instead of building a playback queue. The measured 8.36 ms starts **after the camera read completes** and ends at texture submission; it excludes sensor exposure, driver queues, GPU completion, and display scanout. It is not sensor-to-screen latency.

DirectShow/MJPEG, global timer-period changes, and reduced OpenCV thread counts did not improve this machine's measured delivery and were not adopted. A native shared-D3D-texture capture/render path could reduce copying further, but current snapshot/upload CPU time is under half a millisecond on average. Driver delivery and display scheduling are the larger remaining limits observed here.

## Beard physics

Two initial beard runs (commit `84daf2b`) used the same webcam, 720p/60 FPS setting, face tracking, and landmark overlay, with the native beard enabled. Both used the debug viewer extension built by Setup; no browser or recording was active.

| Measurement | Default: 256 strands × 8 segments | Maximum: 1,024 strands × 16 segments |
| --- | ---: | ---: |
| Capture delivery/sec | 60.00 | 60.02 |
| Tracking frames/sec | 59.60 | 59.56 |
| Renderer FPS at end of run | 60 | 60 |
| Distinct preview frames/sec | 53.05 | 51.55 |
| Physics + packed upload preparation, mean | 0.67 ms | 5.42 ms |
| Physics + packed upload preparation, p95 | 0.79 ms | 6.92 ms |
| Physics + packed upload preparation, max | 1.42 ms | 10.33 ms |
| Capture-read to texture submission, mean | 8.26 ms | 8.23 ms |
| Beard-active timing samples | 1,040 | 1,014 |

Raw reports: [default beard](performance/beard-256.json), [maximum beard](performance/beard-1024.json). Timing is sampled on newly delivered camera frames while a face is live; brief detection gaps pause physics and are excluded from the beard cost distribution. The beard timer includes native stepping, instance-buffer generation, and buffer assignment. It excludes landmark-to-root attachment, GPU completion, and display scanout. Renderer FPS is an end-of-run counter, not a guarantee that every frame met its deadline.

The runs are separate observations, not a controlled claim that adding a beard improves preview FPS. Delivery and VSync phase vary as described above. Defaults at the time were 256 strands and 8 segments. Disabling the beard stops simulation; loss of a tracked face hides it and pauses work. Counts and physics catch-up are bounded.

To profile a beard, append `--beard --beard-strands 256 --beard-segments 8` to the benchmark below. The maximum supported values are 1,024 and 16. The command changes only its temporary viewer session; it does not overwrite the user's saved design.

After the free-hanging physics correction, another 20-second run at 256 × 8 measured **0.57 ms mean / 0.68 ms p95** for physics and upload preparation, **60 renderer FPS**, **59.93 capture FPS**, and **52.2 distinct preview frames/sec**. All 1,045 delivered frames had a live beard sample (the interval counter is one smaller). The [raw report](performance/beard-free.json) uses the same timing boundaries. This is another short observation, not a controlled performance comparison with the earlier solver.

## Combined hair regions

The expanded editor was measured on the same Ryzen 5 5500 / RX 7900 XTX using an animated synthetic face, Godot's debug extension, a 60 Hz display, and 120 Hz physics. Each case warmed up for 30 frames and measured 240 frames. These runs did **not** open a webcam or run inference. They include root attachment and generated-marker updates, unlike the older beard-only timer above.

| Configuration | Attachment + markers, mean | Physics + upload preparation, mean | Total CPU, mean / p95 |
| --- | ---: | ---: | ---: |
| Beard only, 256 × 8 | 0.34 ms | 0.55 ms | 0.89 / 1.09 ms |
| Beard + eyebrows + Afro, 864 × 8 | 1.05 ms | 1.59 ms | 2.64 / 3.03 ms |
| Same, generated markers visible | 1.19 ms | 1.57 ms | 2.77 / 3.16 ms |
| Maximum combined, 2,048 × 16 | 2.44 ms | 8.31 ms | 10.75 / 11.70 ms |
| Maximum with markers visible | 2.65 ms | 8.10 ms | 10.76 / 11.56 ms |

Mean frame intervals were approximately 16.66 ms in all five cases. This is a short synthetic measurement, not a live-camera FPS guarantee; CPU timings exclude GPU completion and presentation. Individual frames varied, and the maximum setting leaves considerably less time for the rest of the studio. Defaults at the time were 256 facial strands, 96 brows when enabled, and 512 scalp strands when enabled. Static eyebrows skip force/constraint work. All regions share one solver and one hair draw batch; generated dots use one additional batch. No new tracking model or Python inference is introduced.

Profile reconstruction took about 24–27 ms at the combined default and 72 ms at maximum, once per settings change. Root-marker indices and rest guides are cached between changes. [Raw measurements](performance/groom-combined.json).

To reproduce without touching camera capture or saved designs:

```powershell
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path viewer --resolution 1000x700 --script res://tests/groom_performance.gd
```

The report is written to `artifacts/groom-performance.json`.

## Virtual head landmarks

The virtual-head path was measured with the same hardware and 864 hairs × 8 segments, using synthetic yaw, pitch, roll, translation, and relative landmark depth. Each case warmed up for 30 frames and sampled 240 frames. No camera or inference was started.

| Reference geometry | Root fitting + markers, mean | Physics + upload, mean | Total CPU, mean / p95 |
| --- | ---: | ---: | ---: |
| Original attachment | 1.25 ms | 1.57 ms | 2.82 / 3.31 ms |
| 380 virtual points, guide dots hidden | 1.78 ms | 1.54 ms | 3.33 / 3.86 ms |
| 380 virtual points, guide dots shown | 1.87 ms | 1.55 ms | 3.42 / 4.09 ms |
| 1,628 virtual points, guide dots shown | 3.15 ms | 1.60 ms | 4.76 / 5.93 ms |

The default visible grid added about **0.60 ms mean CPU per frame** in this short synthetic comparison. Hair count is unchanged across cases. Grid topology and root interpolation weights are cached; only projection, attachment, and the optional marker buffer update during tracking. A denser grid costs more fitting work without adding simulated hairs. These timings exclude fixture generation, camera/inference, GPU completion, and presentation. They are not a live-camera frame-rate guarantee. [Raw report](performance/virtual-head.json).

Reproduce with:

```powershell
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path viewer --resolution 1000x700 --script res://tests/groom_performance.gd -- virtual
```

The report is written to `artifacts/virtual-head-performance.json`.

## Independent face/head extensions

The **Landmarks** tab has a separate overlay that works with hair disabled. On the same Ryzen 5 5500 / Radeon RX 7900 XTX system, an animated synthetic face produced these CPU projection and marker-upload preparation times (30 warmup frames, then 240 samples per case):

| Extension configuration | Mean CPU/update | p95 CPU/update |
| --- | --- | --- |
| Disabled | 0.025 ms | 0.031 ms |
| 288 points, dots hidden | 0.098 ms | 0.118 ms |
| 288 points, dots visible | 0.206 ms | 0.246 ms |
| 1,728 points, dots visible | 0.803 ms | 0.907 ms |

This is the independent landmark layer's cost, without hair simulation. Bindings and offsets are cached in packed arrays; fresh tracking results update the positions and one instanced marker batch. Hidden dots retain reference positions but skip the render upload. Disabling extensions skips projection. No additional inference runs. Timings exclude fixture generation, camera/inference, GPU completion, and presentation; they are not an end-to-end latency or frame-rate guarantee. [Raw report](performance/landmark-extensions.json).

Reproduce without a camera or backend:

```powershell
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path viewer --resolution 1440x900 --script res://tests/extensions_performance.gd
```

The report is written to `artifacts/landmark-extensions-performance.json`. `extensions_probe.gd` checks directional extents, depth/rotation, invalid input, bounded density, independent visibility, and stale tracking. `extensions_render.gd` exercises the actual tab, orange pixels with hair off, mirror alignment, live depth forwarding, and settings persistence at both 1440×900 and 1024×720.

Regional contour shaping is also cached when settings change. A follow-up comparison used 110° wrap on the forehead, both sides, and chin, with a lowered forehead start and inset side starts. The per-tracking-result projection/upload path is unchanged:

| Contour configuration | Mean CPU/update | p95 CPU/update |
| --- | --- | --- |
| 288 straight points | 0.226 ms | 0.282 ms |
| 288 rounded points | 0.218 ms | 0.282 ms |
| 1,728 rounded points | 0.926 ms | 1.107 ms |

The small default-count difference is ordinary run variation, not a speedup claim. The same synthetic fixture, sample counts, hardware, and exclusions apply. [Raw contour report](performance/landmark-contours.json). Add `-- contours` to the command above to reproduce it; the output is `artifacts/landmark-contours-performance.json`. Regional tests also check independent starting positions, inward side offsets, backward progression, inward wrapping past 90°, pose projection, saved contours, and older settings.

## Reproduce

Close other camera applications, build with `Setup.ps1 -SkipInstall`, then run:

```powershell
.\buildtools\python-3.15.0\python.exe -B tools\benchmark.py --camera 1 --fps 60 --seconds 20 --output artifacts\performance.json
```

Use the index returned by `/api/camera/list` for your webcam; `--camera -1` uses the synthetic source. The command starts an isolated backend on a free port and a rendered Godot window, warms up, measures, and closes both. It saves timing/statistics only. `--no-overlay` leaves tracking running while hiding dots; `--frame-cap 60` allows comparison with the previous software cap. Avoid concurrent benchmarks because they contend for the camera and CPU/GPU.

`tools/check.py` covers backend regressions, native reader interoperability, and the actual Start capture flow. To run the additional rendered overlay check:

```powershell
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path viewer --script res://tests/landmarks_probe.gd --quit-after 300
```

Success prints `LANDMARKS_RENDER_PASS` without engine/script errors. This check uses synthetic points and requires a graphics context; the default headless CI checks import its code but do not validate rendered pixels.

## Shared head surface

Measured October 16, 2026 using Godot 4.7.2 and the same Windows workstation. Baseline: `56fa98f`. The fixture rotates the canonical face through yaw/pitch, warms up for 30 updates, then records 240. It measures the actual studio callback (shared head construction, depth rasterization/upload preparation, virtual guides and hair attachment), followed by native strand simulation and upload preparation.

| Workload | Landmark update median before → after | Landmark update p95 before → after | Physics/upload median before → after |
| --- | ---: | ---: | ---: |
| 512 strands × 8 segments, 288 guides | 2.235 → 1.282 ms | 2.746 → 1.522 ms | 0.898 → 0.942 ms |
| 2,048 strands × 16 segments, 1,728 guides | 9.609 → 2.388 ms | 13.699 → 2.730 ms | 7.030 → 7.102 ms |

Median landmark-result CPU time fell by about **43% / 75%**. Physics cost remained similar; the change removes duplicate fitting/projection work rather than reducing strand quality. One fixed 1,198-vertex surface now supplies landmarks, roots, mannequin geometry and live occlusion. Native packed barycentric sampling replaces per-frame dictionary-heavy root fitting.

Settings responsiveness was measured separately. The intermediate exhaustive fitter took **303.501 ms** to switch to the maximum-density look and guide layout. Exact nearest-triangle search with bounding-volume pruning reduced this to **98.101 ms**, including all strand/rest-guide rebuilding. Force-only changes previously rebuilt those arrays in **74.222 ms**; direct validated gravity/wind/turbulence/damping updates now took **0.610 ms**, preserving current strand positions. These edit measurements compare two implementations within this change, not the baseline commit.

These short synthetic CPU measurements exclude camera capture, AI inference, GPU completion and presentation. They do not establish a live-camera FPS gain. Maximum-density placement changes still rebuild the groom and can take around a tenth of a second; ordinary force edits avoid that work. [Raw before/after report](performance/shared-head-surface.json).

```powershell
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path viewer --script res://tests/surface_performance.gd -- current
```

The fixture disables settings persistence and writes `artifacts/surface-performance-current.json`. The older virtual-head-grid measurements above describe the retired separate-grid implementation.

## Physical head collision

Measured October 16, 2026 on the same workstation with Godot 4.7.2. Baseline `80c557f` used 2D motion and mouth-only collision. The new path simulates in 3D, fits a solid collider to the shared head, and checks entire strand links as well as joints. The same synthetic yaw/pitch fixture uses 30 warmup updates and 240 measured updates; the two runs were isolated. These are the historical 512-strand comparison settings, not the current 1,024-strand project defaults.

| Workload | Physics/upload median before → after | Physics/upload p95 before → after | Tracking callback median before → after |
| --- | ---: | ---: | ---: |
| 512 × 8 | 0.979 → 2.275 ms | 1.185 → 2.510 ms | 1.277 → 2.390 ms |
| 2,048 × 16, all regions | 7.723 → 14.659 ms | 8.724 → 15.956 ms | 1.721 → 2.927 ms |

Collision adds work; this is a functionality improvement, not a speedup over having no head barrier. Directional triangle bins handle point contacts and short link sweeps; a refitted BVH handles sweeps crossing cube-face seams. Queries allocate no memory, catch-up remains capped, and each endpoint's depth fits in the existing 16-float segment buffer. The separate root-depth textures are no longer uploaded. Force-only edits still bypass rebuilding the groom (0.629 ms in this run).

The maximum workload's combined CPU cost exceeds a 16.7 ms frame budget before camera/inference or presentation; use fewer strands/segments for that budget. These short headless CPU measurements exclude camera capture, AI inference, GPU completion and presentation and do not establish live FPS. [Raw before/after report](performance/head-collision.json).

## Independent mustache forces and lower beard roots

Measured October 17, 2026 against `393dcad` on the same workstation, using the existing synthetic yaw/pitch fixture (30 warmup, 240 measured samples). The comparison retains the original force values for both regions; the updated look enables the new lower virtual root distribution. Counts, guide density and segment resolution are unchanged.

| Workload | Physics/upload median before → after | Physics/upload p95 before → after | Tracking callback median before → after |
| --- | ---: | ---: | ---: |
| 512 × 8 | 2.400 → 2.277 ms | 3.085 → 3.089 ms | 2.487 → 2.444 ms |
| 2,048 × 16, all regions | 16.551 → 16.040 ms | 18.240 → 17.937 ms | 3.210 → 3.164 ms |

These short runs show similar costs, not a demonstrated speedup. Force selection happens once per strand, and constant acceleration is computed before the joint loop. Lower beard roots reuse cached head-triangle bindings and the existing strand budget. Changing mustache wind at maximum density took **0.618 ms**, versus **116.577 ms** to rebuild maximum-density placement; force edits preserve positions and velocity.

Maximum density still costs roughly 19.2 ms for these two CPU stages combined, exceeding a 60 fps frame budget before capture, inference or presentation. The 512-strand fixture is a comparison workload, not the current 1,024-facial-strand default. [Raw before/after report](performance/regional-hair.json).
