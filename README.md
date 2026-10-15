# LenzForge Studio

A local Windows camera and AR workspace with a Godot desktop viewer, browser controls, and MediaPipe face, iris, hand, and body tracking. Python owns capture and inference; a C++ GDExtension brings video and face landmarks into Godot through shared memory.

![Godot desktop studio displaying the synthetic demo source](docs/images/studio.png)

## Start here

Requires Windows 10/11 x64, an internet connection for initial setup, and several GB of free disk space. A webcam is optional: the demo source exercises video, controls, recording, and both previews without opening a camera.

```powershell
git clone https://github.com/saki2fifty/LenzForge.git
cd LenzForge
.\Setup.ps1
```

Setup downloads a project-local Python, Godot, C++ compiler, bindings, and three tracking models. It installs locked Python packages and builds debug and release native extensions. No system Python or compiler installation is required. The initial build can take several minutes. Re-running setup reuses downloaded tools and incremental builds.

In one PowerShell terminal:

```powershell
.\Start-Backend.ps1
# Or start with the synthetic source already running:
.\Start-Backend.ps1 -Demo
```

In another terminal:

```powershell
.\Start-Viewer.ps1
```

Browser controls are at **http://127.0.0.1:5000**. Choose a camera or **Demo pattern**, then select **Start capture**. Stop capture before scanning for another physical camera. Close the backend with Ctrl+C. Use `Start-Viewer.ps1 -Editor` to edit the Godot project.

The desktop viewer expects port 5000. `Start-Backend.ps1 -Port 5001` is available for browser-only development; change `BACKEND` in `viewer/studio.gd` if using a different desktop port.

## What works

- One background capture owner and one inference worker, shared by both interfaces. Capture runs without an open browser.
- Face tracking with 478 landmarks, 52 blendshape scores, and a face transform; optional hand and body tracking. Hand/body results appear in the browser and JSON exports. The desktop overlay currently displays face/iris points.
- GPU NV12 color conversion, mirror, four desktop looks, exposure, and customizable landmark points. Video continues when tracking cannot detect a face; stale overlays disappear.
- Responsive dark studio interfaces, measured frame/inference statistics, source controls, and a camera-free demo.
- Browser preview effects and JPEG quality control. Preview effects are independent between the desktop and browser.
- Source recording to playable MJPEG AVI with timestamped landmark JSONL in `recordings/`. Recording memory stays bounded; files grow with recording duration.
- Browser source-image and landmark exports. Desktop snapshots capture the complete studio window in Godot's `user://captures` directory; the UI reports the full saved path.
- Persistent desktop look, mirror, and landmark visibility. Shortcuts: **L** landmarks, **M** mirror, **F11** fullscreen.

**Recordings keep the original camera source**, without preview looks, mirror, or overlays. Virtual-camera output is not connected end to end; the earlier GOD1 writer is retained as a foundation. Background segmentation and face-specific effects remain experimental and are withheld from the new browser effect picker.

## Toolchain

Stable versions checked on October 15, 2026:

| Component | Version |
| --- | --- |
| Godot | 4.7.2 stable |
| godot-cpp | 10.0.0 stable, targeting the 4.7 API |
| Python | 3.15.0 |
| MediaPipe | 1.1.1, Tasks API |
| OpenCV contrib | 5.0.0.93 |
| NumPy | 2.5.4 |
| Flask / Waitress | 3.1.3 / 3.0.2 |
| GCC / SCons | 16.2.0 / 4.11.1 |

[`toolchain.json`](toolchain.json) pins native tooling. [`requirements.txt`](requirements.txt) pins direct runtime dependencies; [`requirements.lock.txt`](requirements.lock.txt) includes all resolved runtime and development packages for Windows x64/Python 3.15. Only one OpenCV wheel is installed. Setup verifies the Godot archive SHA-256 and runs `pip check`.

Release references: [Godot](https://godotengine.org/download/windows/), [godot-cpp](https://github.com/godotengine/godot-cpp/releases), [Python](https://www.python.org/downloads/windows/), [MediaPipe](https://pypi.org/project/mediapipe/), [OpenCV contrib](https://pypi.org/project/opencv-contrib-python/).

## Repository layout

```text
backend/             Capture, Tasks inference, IPC writers, HTTP API, browser studio
viewer/              Active Godot project and C++ GDExtension
tools/               Portable bootstrap and validation tools
tests/               Backend, model, protocol, and recording regression tests
docs/                Current architecture and API notes
docs/archive/        Historical plans and analyses
legacy/              Original setup and superseded backend components
viewer/legacy/       Original Godot scenes/scripts, excluded by .gdignore
```

Run and edit `backend/` and `viewer/` directly. Setup no longer copies sources into a second workspace. Existing local `workspace_v2/` and older tool downloads are left intact, ignored by Git, and unused by the launchers. Generated tools, models, recordings, caches, and binaries are not committed.

## Validation

After setup:

```powershell
.\buildtools\python-3.15.0\python.exe -B tools\check.py
```

This runs Python regression tests, a Godot headless import/startup, and an integration probe that sends known video/landmarks from Python through the compiled native readers. The Windows GitHub Actions workflow runs the same checks.

Local validation also rendered both interfaces and exercised face inference on a public-domain portrait bundled with Matplotlib. A 1280×720 synthetic source delivered approximately 29.7 fps at a 30 fps target on the development PC. That is a demo-throughput measurement, not a guarantee of webcam or face-tracking performance. Physical camera compatibility and the full range of retained effects still need hardware/manual coverage.

See [architecture and modernization decisions](docs/ARCHITECTURE.md) and [supported API](docs/API.md). Historical documents describe earlier plans and are not current feature guarantees.

## Troubleshooting

- **Missing native extension or DLL:** rerun `Setup.ps1`. For a code-only rebuild use `Setup.ps1 -SkipInstall`; close running viewers first.
- **Missing model:** rerun setup. Alternatively set `LENZFORGE_MODELS` to a directory containing the three `.task` files listed in `tools/bootstrap.py`.
- **Camera unavailable:** close other applications using it, verify Windows camera permissions, and try Demo pattern to separate capture issues from viewer issues. Hardware may negotiate a different resolution or frame rate.
- **Backend offline:** keep its terminal open and verify port 5000 is available. The service binds to loopback by default.
- **Slow tracking:** use a lower capture resolution or the performance API; inference resolution changes apply on the next capture start. The mailbox replaces old work rather than accumulating latency.

## License

Project source is MIT licensed; see [LICENSE](LICENSE). Downloaded engines, packages, compilers, and models retain their upstream licenses. Model and inference dependencies are downloaded only during setup, and camera frames are processed locally.
