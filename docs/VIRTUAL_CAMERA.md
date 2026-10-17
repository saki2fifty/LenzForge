# LenzForge Virtual Camera

The camera button in the top toolbar sends the composed preview to a native Windows camera device. It includes the current mirror/look, hair, shading, head/strand occlusion, visible landmark guides, and other preview content. Studio panels, the toolbar, and mannequin navigation controls are excluded. The 3D mannequin can also be sent.

## One-time setup

Requires **Windows 11, build 22000 or newer, x64**. Building the camera also requires Visual Studio Build Tools with **Desktop development with C++** and the **Windows SDK 10.0.26100.0**. The ordinary viewer/backend toolchain remains unchanged.

From the project folder:

```powershell
./native/virtual_camera/build.ps1 -Test
```

Then run this once in an **Administrator PowerShell**:

```powershell
./native/virtual_camera/Install.ps1
```

Installation copies `LenzForgeCamera.dll` to `%ProgramFiles%\LenzForge\VirtualCamera` and registers its COM class under `HKLM\SOFTWARE\Classes\CLSID\{A7CBB740-1ED1-49F1-9444-90A2EAD037D6}`. This is a user-mode Media Foundation component, not a kernel driver. Normal streaming runs as the current user and does not require elevation. Close camera clients and stop output before updating the installed DLL.

## Use

1. Start capture in LenzForge, or enable the mannequin.
2. Click the **camera icon** in the top toolbar. **ON** means output is enabled; its tooltip reports Starting, Ready, or Live.
3. Select **LenzForge Windows Virtual Camera** in the receiving app. Windows adds the “Windows Virtual Camera” suffix to the registered LenzForge name.
4. Click the camera icon again to stop. Closing the viewer also stops output and removes its session camera.

The device offers **1280 × 720 NV12 at 30 or 60 fps**. Other aspect ratios fit inside this output without stretching. Output carries video only; choose a microphone separately in the receiving app. Output starts off on each launch, like camera capture and recording. It does not change saved appearance or tracking preferences.

The shared preview content is rendered directly into the output viewport; this is not a desktop screenshot. Window borders, other applications, and overlapping windows cannot be captured through this path. Hair/mannequin textures retain their existing preview resolution limits. Minimizing the viewer can affect rendering cadence; keep it rendering while broadcasting.

If camera access is denied, enable **Windows Settings → Privacy & security → Camera → Let desktop apps access your camera**. If the component is missing, the toolbar reports the installation command. Only one LenzForge viewer can publish per user; a second viewer reports that the camera is already in use. Device discovery/format support in individual calling apps still needs app-specific validation.

## Performance and implementation

- Godot shares the existing preview canvas with an output-only `SubViewport`. Tracking, hair simulation, and root fitting run once.
- The output viewport renders at most 60 times per second. It stays disabled when there is no active camera consumer; there is no image readback in that state or while output is off.
- Compatibility rendering requires synchronous GPU-to-CPU readback. This is a real extra cost, not a zero-copy GPU path. Only the fixed-size output texture is read back, not the full application window.
- A C++ worker converts RGBA to BT.601 limited-range NV12 and publishes to a three-slot shared-memory transport. There is only one replaceable pending RGBA frame; slow output cannot build a FIFO of stale frames.
- The Media Foundation source supplies pooled samples to Windows Camera Frame Server. A high-resolution waitable timer paces delivery without a process-wide timer-resolution change. Frames older than 500 ms, invalid publications, and stopped output produce black rather than retaining a stale face.
- The mapping uses the owning Windows user's SID and an unpredictable per-session GUID. Its ACL permits that user, Local Service, and SYSTEM. The camera is registered for the current user with session lifetime.
- The Microsoft SDK DLL and MinGW Godot extension communicate through a small versioned C ABI. The camera uses a static C++ runtime and adds no Python package or browser worker.

Native source and rendered composition checks:

```powershell
./native/virtual_camera/build.ps1 -Test
./buildtools/python-3.15.0/python.exe tools/check_virtual_camera.py
# After installation: open, receive, close, and reopen through Windows camera discovery.
./buildtools/python-3.15.0/python.exe tools/check_virtual_camera.py --installed
# Matched full-pipeline comparison with a synthetic portrait; no physical webcam is opened.
./buildtools/python-3.15.0/python.exe tools/benchmark.py --portrait --beard --beard-strands 1024 --tracking-backend cpu --seconds 20 --warmup 5 --offscreen --virtual-camera --output artifacts/virtual-camera-performance.json
```

To uninstall, stop output and close camera clients, then run in Administrator PowerShell:

```powershell
./native/virtual_camera/Install.ps1 -Uninstall
```

References: Microsoft's [virtual-camera API](https://learn.microsoft.com/en-us/windows/win32/api/mfvirtualcamera/nf-mfvirtualcamera-mfcreatevirtualcamera), [camera sample and deployment instructions](https://github.com/microsoft/Windows-Camera/tree/master/Samples/VirtualCamera), and Godot's [shared viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html). Camera interface/attribute usage follows the Microsoft sample; its [MIT notice](../native/virtual_camera/MICROSOFT-LICENSE.txt) is included.
