# Automatic settings

Changes save automatically and restore when the desktop viewer or backend starts again. MediaPipe edits also apply automatically; **Apply tracking settings** remains available to retry GPU initialization. You do not need to click it to save.

The desktop saves after 350 ms without another edit and flushes remaining changes on normal exit. Browser controls immediately retain pending edits locally, then send them after the same short delay. This combines slider movements into one update instead of repeatedly saving or rebuilding models. Saving never runs in the capture or inference loop.

## What is retained

- Camera selection by stable device ID, resolution, and frame rate. An unplugged camera remains the saved choice; another camera is not selected automatically.
- MediaPipe processing mode, input width, face count, all confidence thresholds, optional outputs, face/hand/pose model IDs, and tracking feature toggles.
- Appearance preset, exposure, mirror, master landmark-guide visibility, measured landmark visibility/color/size, head occlusion, depth, and crown height.
- All virtual landmark settings and colors, all hair/beard/mustache/eyebrow/scalp controls, gravity/wind/damping, per-strand edits, and the working look name.
- Hair visibility, mannequin mode/rotation/zoom, strand edit mode, active panels, library selection, model controls, window size, and fullscreen/maximized mode.
- Browser preview effect chains (including enabled state and parameter values), JPEG quality, preview frame rate, and preview scale.

Capture and recording are actions: reopening the app restores their controls but does not start a camera or recording. Named hair-library entries still use **Save** or **Copy**; autosave preserves your current working look without overwriting a named preset. The loaded library entry is remembered, so **Save** can update it after a restart.

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
