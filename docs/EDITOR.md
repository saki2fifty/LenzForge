# Editing the studio in Godot

Import [`viewer/project.godot`](../viewer/project.godot), double-click [`studio.tscn`](../viewer/studio.tscn) in the FileSystem dock, then select **2D**. The interface is saved as ordinary scene nodes: opening it shows the layout without starting capture, tracking, effects processing, or strand simulation.

If you already had the old root-only scene open, accept Godot's **Reload** prompt. Alternatively, close the scene tab without saving the stale version and reopen `studio.tscn`. Select the root and press **F** to frame it if the layout is outside the visible canvas.

## Finding controls

Expand **LenzForgeStudio → Layout → Studio** in the Scene dock.

| Scene branch | What it contains |
| --- | --- |
| `Header` | Branding, connection status, browser button |
| `Body/LeftPanel` | Camera, resolution, frame rate, capture and tracking switches |
| `Body/Workspace/QuickToolbar` | Landmark, occlusion, mannequin, clippers, virtual camera, calibration and model shortcuts |
| `Body/Workspace/PreviewPanel` | Video, overlays, and the empty preview state |
| `Body/RightPanel/SidebarTabs` | Look, Landmarks, Hair, Tracking, and Effects |
| `Message` | Status text along the bottom |

Select a control to change its **Text**, **Theme Overrides**, tooltip, minimum size, or container sizing in the Inspector. Select `SidebarTabs` and change **Current Tab** to inspect each main page. The actual camera image and simulated mannequin appear when the project runs.

## Layout and hidden pages

Containers arrange their children. Adjust container separation, margins, size flags, or **Custom Minimum Size** instead of dragging a container-managed control to an arbitrary pixel position. `LeftPanel` and `RightPanel` minimum widths set their normal desktop widths; compact windows cap them at 188 and 296 pixels respectively.

Hair, Effects, and regional Landmarks contain several subpages. In the editor, use the Scene dock visibility toggle to hide the currently displayed page and reveal the one you want. Hair pages are beneath `BeardPanel`; Effects pages are beneath `EffectsPanel`. The corresponding dropdown switches these pages when the app runs.

Save the scene with **Ctrl+S**. **F6** runs this scene; **F5** runs the project. Start the backend separately for live camera controls, or use the mannequin without capture.

## Appearance versus saved preferences

Text, themes, margins, and layout come from the scene. Startup binds those existing controls instead of replacing them, so visual edits survive. Dynamic labels such as connection state, timing, and the recording button still change during operation.

Runtime preferences remain separate: selected tabs, models, effects, hair values, camera choices, and other saved settings are restored from the user's configuration. Changing a slider's saved scene value does not replace those preferences or the application's configuration defaults.

Scripts use `scene_refs` metadata on the root and panel nodes to connect behavior once at startup. Changing displayed text is safe. If you rename, move, or remove a referenced node, update the corresponding NodePath in that metadata as well. Action keys are stable identifiers even when a button's displayed caption changes. Keep option ordering aligned with its script's semantic values.

Camera/model lists, file dialogs, calibration steps, render buffers, and simulations are populated at runtime. Editing their underlying behavior still requires their scripts. UI reference binding adds no per-frame lookup work.

## Verification

`tools/check.py` includes the authored-layout check: it edits a caption and panel width, packs and reloads the scene, and confirms startup preserves both without duplicating controls. It also exercises effect actions and sliders, independent mustache physics, repeated root controls, and tracking values. Existing tests cover preference restoration, quick controls, capture, and layout down to 960 × 640.
