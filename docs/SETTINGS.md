# Automatic settings

Changes save automatically and restore when the desktop viewer or backend starts again. MediaPipe edits also apply automatically; **Apply tracking settings** remains available to retry GPU initialization. You do not need to click it to save.

The desktop saves after 350 ms without another edit and flushes remaining changes on normal exit. Browser controls immediately retain pending edits locally, then send them after the same short delay. This combines slider movements into one update instead of repeatedly saving or rebuilding models. Saving never runs in the capture or inference loop.

## What is retained

- Camera selection by stable device ID, resolution, and frame rate. An unplugged camera remains the saved choice; another camera is not selected automatically.
- MediaPipe processing mode, input width, face count, all confidence thresholds, optional outputs, face/hand/pose model IDs, and tracking feature toggles.
- Appearance preset, exposure, mirror, preview pacing, master landmark-guide visibility, measured landmark visibility/color/size, head occlusion, depth, and crown height.
- A saved [head calibration profile](CALIBRATION.md), including side and under-jaw fullness, 478 normalized neutral reference points and whether the crown edge was observed. The wizard's draft applies only after **Save head fit**; ordinary autosave then retains it in `[calibration] profile` in `studio.cfg`. Captured calibration images are not saved. Older profiles still load; recalibration adds the persistent neutral reference.
- Generated scalp hairstyle (None, Regular, Mohawk or Afro), mesh shape, hairline, base/highlight colors and coverage. The mesh is regenerated on load; legacy scalp-strand edits are preserved in older files but do not drive the object.
- All virtual landmark settings and colors, all hair/beard/mustache/eyebrow/scalp controls, gravity/wind/damping, per-strand edits, and the working look name.
- [Clippers](BEARD.md#clippers) cuts, including each retained strand's length, cut-tip width/color and rest guide. These are part of the working look; tool activation, loose cuttings and undo history are temporary.
- Clippers Line/Buzz selection and Buzz blade width, in `[tools] clippers_mode` / `clippers_width`. Restored preferences never start the motor. Spatial facial cuts retain three-dimensional `guide3d` overrides in the look document.
- Independent mustache forces, collision and length variation, plus automatic lower beard coverage and wrap depth. Older looks initialize missing mustache fields from their previously shared values; later edits remain separate.
- Hair visibility, mannequin mode/rotation/zoom, strand edit mode, active panels, library selection, model controls, window size, and fullscreen/maximized mode.
- Browser preview effect chains (including enabled state and parameter values), JPEG quality, preview frame rate, and preview scale.

Capture, recording, and virtual-camera output are actions: reopening the app restores their controls but does not start capture, recording, or broadcasting. Named hair-library entries still use **Save** or **Copy**; autosave preserves your current working look without overwriting a named preset. The loaded library entry is remembered, so **Save** can update it after a restart.

**Look → Preview pacing** defaults to **Responsive (up to 120 fps)**, which disables VSync and bounds rendering while polling new camera frames frequently. **Display synchronized** uses VSync with no software cap; it can prevent tearing but may reduce throughput on some drivers. **Low power (up to 60 fps)** disables VSync and lowers render work. These settings affect rendering, not camera FPS or MediaPipe model quality. Hover over the preview metrics to see renderer FPS and hair CPU time separately from distinct camera frames.

## Storage

On Windows, both application preference files are in:

```text
%APPDATA%\Godot\app_userdata\LenzForge Studio\
```

For this installation:

```text
C:\Users\micha\AppData\Roaming\Godot\app_userdata\LenzForge Studio\studio.cfg
C:\Users\micha\AppData\Roaming\Godot\app_userdata\LenzForge Studio\backend.json
```

`studio.cfg` contains desktop settings and pending backend edits. `backend.json` contains the backend's validated tracking, model, feature, preview, and effect preferences. Both use temporary files and replacement; the viewer also retains the previous `studio.cfg.bak`. Save errors appear in the UI rather than reporting success. Malformed backend JSON is preserved as `backend.invalid.json`; other valid sections and settings are restored independently when a stored value is unsupported.

Browser-only choices and unsent edits use browser local storage under `lenzforge.studio.v1`, separately for each browser profile and site address. Use the same address when reopening browser controls; `localhost` and `127.0.0.1` have separate local storage. Applied backend settings are shared with the desktop regardless of browser profile.

Downloaded model files remain in the project's `models/` directory (or `LENZFORGE_MODELS`), including custom model metadata in `library.json`. Preferences store model IDs, not another copy of those files. A selection awaiting download is retained by the viewer/browser and activates when the model becomes available. If an already-selected model file is removed, backend startup reports it and restores the other valid settings; reinstall/import the missing model to use it again.

Offline edits remain pending and retry when the backend reconnects. A delayed response cannot overwrite a newer edit. Invalid requests wait for another edit or a model-library change rather than retrying continuously. Backend settings are restored before capture workers are created.

For isolated development/tests, set `LENZFORGE_SETTINGS_DIR` to a different directory for both processes. Flask tests can also provide `SETTINGS_PATH`; ordinary `TESTING` apps use an in-memory store. Benchmarks do not load or save personal preferences.
