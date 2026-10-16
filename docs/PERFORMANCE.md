# Performance measurements

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
- Let VSync pace Godot without an additional software frame cap. Capture defaults to 60 fps, with 30 and 24 still available.

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

The runs are separate observations, not a controlled claim that adding a beard improves preview FPS. Delivery and VSync phase vary as described above. Defaults remain 256 strands and 8 segments to preserve headroom. Disabling the beard stops simulation; loss of a tracked face hides it and pauses work. Counts and physics catch-up are bounded.

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

Mean frame intervals were approximately 16.66 ms in all five cases. This is a short synthetic measurement, not a live-camera FPS guarantee; CPU timings exclude GPU completion and presentation. Individual frames varied, and the maximum setting leaves considerably less time for the rest of the studio. Default facial density remains 256, brows 96 when enabled, and scalp hair 512 when enabled. Static eyebrows skip force/constraint work. All regions share one solver and one hair draw batch; generated dots use one additional batch. No new tracking model or Python inference is introduced.

Profile reconstruction took about 24–27 ms at the combined default and 72 ms at maximum, once per settings change. Root-marker indices and rest guides are cached between changes. [Raw measurements](performance/groom-combined.json).

To reproduce without touching camera capture or saved designs:

```powershell
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path viewer --resolution 1000x700 --script res://tests/groom_performance.gd
```

The report is written to `artifacts/groom-performance.json`.

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
