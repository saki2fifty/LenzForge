# Hair and beard editor

The desktop **Hair** tab creates beard, mustache, eyebrow, and scalp overlays attached to face landmarks. It includes a native strand solver, tapered colored rendering, an offline mannequin, a saved-look library, and a Blender curve bridge.

![Expanded root controls on the offline mannequin; generated anchors are magenta](images/groom-roots.png)

## Try it

1. Open **Hair**. Use the page dropdown to switch between **Beard**, **Roots**, **Mustache**, **Eyebrows**, **Scalp hair**, **Physics**, **Strands**, and **Library**.
2. Check **Try on mannequin** to design without camera capture or a backend. Drag the mannequin to see the strands respond to movement.
3. On **Beard**, choose Full beard, Goatee, Mustache, or Sideburns and click **Apply beard preset**. On **Roots**, click **Fuller coverage**. On **Scalp hair**, choose Regular, Mohawk, or Afro. Enable eyebrows on their own page.
4. To use your face, uncheck the mannequin, start your webcam, and keep **Face + iris** enabled. **Show hair and beard** controls the complete overlay. Tracking loss hides it and pauses physics; reacquiring a face resumes it.
5. Turn off measured landmark dots with **L**, and generated dots with **Roots → Show generated roots**, for a clearer preview.

Strands hang straight down under gravity by default, even when your head is tilted. Head movement moves the roots while the rest of each strand retains momentum: faster turns produce larger swings. After you stop moving and turn wind off, damping settles the strands downward. Mouth collision can divert strands around the lips.

The C++ extension must be rebuilt after updating an older checkout: close viewers and run `Setup.ps1 -SkipInstall`. The current working beard and visibility are restored when the desktop closes normally. Use the library to retain several designs.

## Expanded roots and regional controls

**Roots** adds generated anchors beyond the measured face outline. Magenta is the default generated-point color; measured landmarks use the existing green overlay. You can change or hide generated-point colors independently. They follow face position, size, and roll. They estimate attachment positions; they do not represent extra detected landmarks.

| Root control | Effect |
| --- | --- |
| Below chin | Extends roots beneath the chin by up to 0.35 face widths. |
| Jaw expansion | Spreads the lower beard outward by up to 0.30 face widths. |
| Toward ears | Extends side roots outward by up to 0.30 face widths. |
| Height around ears | Moves the sideburn coverage from lower cheek toward the upper side of the tracked face. |
| Root layers | 1–6 bands of generated roots across the extension, with small seeded variation. |
| Expanded root share | Fraction of beard roots assigned to the extended regions. Remaining roots retain cheek/chin coverage. |
| Fuller coverage | Applies moderate chin/jaw/ear offsets, raises sideburn coverage, and increases the facial budget to at least 512 strands. Reset coverage clears offsets; it keeps the chosen density. |

**Mustache** provides Natural, Chevron, Handlebar, and Walrus rest shapes. Set coverage width/thickness, density relative to the beard, strand length, lift above the lip, curl, taper, color, and shape hold. Its density redistributes the facial strand budget, so increasing it does not create an unbounded extra simulation. Set **Motion** to Static for a fixed mustache, Styled for a flexible shape, or Free to hang under gravity.

**Eyebrows** provides Natural, Straight, Arched, and Bushy styles, with 16–256 hairs across both brows. Set coverage width, thickness, arch, lift, growth angle, strand length, taper, color, and motion. Roots follow the tracked eyebrow contours. Static is the default.

**Scalp hair** provides these procedural starting points:

| Style | Shape and useful controls |
| --- | --- |
| Regular | Swept top and shorter sides; sweep direction, part position, side length. |
| Mohawk | Narrow central root strip and raised strands; strip width, length, volume. |
| Afro | Rounded root coverage with coiled outward guides; curl, coil frequency, volume, frizz. |

All scalp styles support 32–768 hairs, scalp width, hairline offset, length, volume, curl, clumping, frizz, length variation, taper, root/tip colors, motion, and shape hold. Selecting a preset applies its shape settings and Styled motion. Density, colors, hairline fitting, and custom per-strand guides remain editable. **None** hides scalp hair while retaining its individual edits. The scalp is estimated from the forehead and face width; adjust the hairline/width to fit your head. Coil frequency is limited to one coil per four segments to avoid undersampling; more segments allow finer curls at higher cost.

![Regular swept hairstyle](images/groom-regular.png)
![Mohawk hairstyle](images/groom-mohawk.png)
![Afro hairstyle](images/groom-afro.png)

### Motion modes

- **Free:** no shape spring; gravity, wind, and head-motion inertia determine the fall. Calm strands settle straight down even at a tilted head angle.
- **Styled:** reacts to forces and movement while a shape-hold spring pulls toward the selected or imported guide. Set hold lower for a softer style.
- **Static:** follows face position, scale, and roll without swinging. Gravity and wind do not deform it; integration and constraint work are skipped.

The beard uses **Physics → Preserve styled beard shape** to switch between Free and Styled. Mustache, eyebrows, and scalp have independent motion selectors. Gravity/wind/damping are shared. Mouth avoidance applies to moving beard/mustache strands, not scalp, brows, or static shapes.

## Beard and shared physics controls

| Control | Behavior |
| --- | --- |
| Facial strands | 16–1,024 hairs shared by beard and mustache; default 256. Optional brows and scalp have separate budgets; total maximum is 2,048. |
| Segments per strand | 2–16 joints along each hair; default 8. More segments allow finer bends and cost more CPU time. |
| Beard length | Length relative to tracked face width, with region-specific factors. Mustache, brows, and scalp use their own length controls. |
| Starting / ending width | Taper endpoints in pixels at a 300-pixel-wide face; widths follow face scale. Zero ending width gives a pointed tip. |
| Curl / length variation | Rest-shape curl and seeded variation between strands. |
| Root / tip color | RGBA endpoint colors interpolated along the strand. |
| Regrow roots | Generate new roots and length variation with a new seed. Individual overrides remain associated with stable strand IDs. **Apply beard preset** resets facial edits and keeps the scalp/brow setup. |
| Gravity | Downward acceleration in face widths per second squared, independent of head tilt. Higher gravity speeds the fall and resists wind more strongly. Zero disables gravitational acceleration. |
| Horizontal wind / wind variation | Horizontal acceleration and time-varying gusts. Gusts apply only when wind is nonzero, so zero wind is calm. Positive wind follows camera coordinates, which the mirror option can reflect. |
| Damping | Removes a fraction of velocity each physics step; default 0.025. It controls how long motion persists. Very high damping can make falling sluggish. |
| Preserve styled beard shape | Off by default, including for files saved before this option existed. Enable it to hold beard curls or an imported rest shape against gravity. |
| Beard shape stiffness | Used only with **Preserve styled beard shape**. Pulls toward the original curled or imported shape. |
| Keep moving hair out of mouth | Pushes dynamic beard/mustache points outside an ellipse following the lips. |
| Reset motion | Clears velocity and hangs the strands downward, or restores their rest shape when **Preserve styled shape** is enabled. |

On **Strands**, enable **Select strands in preview**, then click a root in any region. The selected strand is highlighted. Its length multiplier, starting/ending widths, curl, and colors can override its region settings. **Hide this strand** sets its length to zero; **Restore strand defaults** removes its overrides. Turn selection off to drag the mannequin again. Facial IDs retain their original numeric form; brows use `brow:N` and scalp uses `hair:N`. Hiding an optional region keeps its edits. Reducing a region's strand count removes edits outside the new count.

## Save and exchange designs

Open **Library**, enter a name, and click **Save**. Each look includes all regions, root offsets, physics settings, colors, and individual edits. The dropdown lists saved looks with mannequin thumbnails. **Load** opens the selected model, **Save** updates the currently loaded entry, **Copy** creates another entry, and **Delete** removes the selected entry after confirmation. Deleting an entry leaves the current working preview available. After restarting, load an existing entry before saving if you want to replace it.

The library is in Godot's `user://beards`, normally `%APPDATA%\Godot\app_userdata\LenzForge Studio\beards` on Windows. Files use generated IDs so names can contain ordinary punctuation. JSON saves use a temporary file followed by replacement. Thumbnails show a neutral mannequin; no live camera image is stored in them.

**Export** writes a version 2 `.json` file with settings, per-strand overrides, and neutral curve geometry. Version 1 beard files still load, with optional scalp/brow regions disabled. **Import** validates and opens a file; click Save to add it to the library. File size is limited to 16 MB, strand counts and numeric ranges are bounded, and invalid files leave the current look unchanged. The maximum combined export with 65-point custom guides was tested at about 10.2 MB.

### Blender workflow

The optional add-on is [`tools/blender_beard.py`](../tools/blender_beard.py). It has been tested with Blender 5.2.0 LTS.

1. Export a complete look from **Hair → Library** in LenzForge.
2. Install the Python file as a Blender add-on, or open it in Blender's Text Editor and choose **Run Script** for that session.
3. Choose **File → Import → LenzForge beard (.json)**. It creates one Curve object containing the individual poly splines.
4. Edit curve points in the local XY plane. Point radii control thickness; the first and last radii become the viewer's starting and ending widths. Keep the strand count/order, keep splines as Poly, and use 2–65 points per strand. Blender can subdivide existing splines for more control.
5. With that object selected, choose **File → Export → LenzForge beard (.json)**, then import the result in LenzForge.

The viewer resamples imported guides to its selected segment count, scales them to the strand's length, and stores them as physics rest shapes. Use Styled or Static motion to retain regional guides; enable **Preserve styled beard shape** for beard guides. Relative curve bends, length, endpoint widths, existing colors, hidden strands, stable region IDs, and motion settings survive the exchange. Editing an individual strand's **Curl** in LenzForge replaces its imported guide with a procedural curl; **Restore strand defaults** also removes the guide. Add-on version 2 supports both old beard files and combined looks.

Geometry uses one face width as a unit, X right, Y up, Z zero. Root positions are rebound to the same face regions in LenzForge. Blender object transforms, Z depth, intermediate radius changes, materials, and particle hair systems are not imported. Apply desired bends in local XY coordinates; this bridge handles editable poly curves.

## Runtime scope and performance

This is a stylized 2D overlay over the camera preview. Roots follow face position, scale, roll, and local landmark deformation. Scalp and ear extensions estimate regions that the face tracker does not measure. Existing real hair is not removed. There is no 3D head occlusion, hair-to-hair collision, or full skin collision; mouth collision is an ellipse approximation. Extreme profile views and convincing back-of-head hair need a future 3D attachment/rendering system.

Physics runs in the C++ GDExtension at a fixed 120 Hz, with at most four catch-up steps. Roots interpolate between tracking updates; free points retain world-space momentum. Neighboring free points share tension corrections, followed by a length correction pass. Strand points use contiguous arrays; rest directions are prepared only when a design changes. One instanced GPU batch draws all segments with taper and edge antialiasing. There is no scene node or rigid body per strand. Disabled or untracked beards stop simulation. The camera, shared-memory readers, and inference worker stay independent.

On the development Ryzen 5 5500 / RX 7900 XTX machine, the corrected free-hanging solver at the default 256 × 8 size averaged **0.57 ms** for physics plus packed upload preparation. The 20-second webcam run reported 60 FPS rendering and about 60 FPS capture. These costs exclude landmark attachment, GPU completion, and presentation; see [measurements and limits](PERFORMANCE.md#beard-physics), including the earlier solver's maximum-density run.

The expanded 864 × 8 combined look averaged **2.77 ms including root attachment, generated markers, physics, and upload preparation** in an offline animated-face test. The maximum 2,048 × 16 setting averaged 10.76 ms with markers. These synthetic timings exclude camera/inference and GPU completion; see the [combined measurements](PERFORMANCE.md#combined-hair-regions). All regions share one native solver and one hair draw batch.

## Design references

The presets translate recognizable styling features into inexpensive 2D guides; they are not reconstructions of particular people's hair. The Regular preset uses a swept part and shorter sides informed by [Wahl's side-part guide](https://wahlusa.com/how-to/haircutting/mens-haircuts/side-part). The raised Mohawk strip follows the central, upward styling idea illustrated in [Wahl's home haircutting guide](https://wahlusa.com/media/wahl-home-haircutting.pdf). The rounded Afro silhouette and coil controls draw on [Afrocenchix's discussion of natural Afro styles](https://afrocenchix.com/blogs/afrohair/love-your-fro-celebrating-afro-hair-on-world-afro-day).

Guide-based clumping and seeded strand variation are informed by Blender's [Clump Hair Curves](https://docs.blender.org/manual/en/4.4/modeling/geometry_nodes/hair/guides/clump_hair_curves.html) and [Frizz Hair Curves](https://docs.blender.org/manual/en/4.0/modeling/geometry_nodes/hair/deformation/frizz_hair_curves.html) controls. The root system uses the existing [MediaPipe Face Landmarker](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker); no extra detection model is needed.

Desktop snapshots include the beard and studio controls. Source recordings and browser previews do not include the desktop beard. A composed-video/virtual-camera output remains separate work.

## Validation

`tools/check.py` runs profile/library/native physics checks alongside the existing capture tests. It covers deterministic roots, gravity/wind, pinned roots, segment lengths, mouth collision, bounded catch-up, invalid input, hidden strands, face loss, individual overrides, maximum-size files, imported guides, mirroring, and resizing. Dynamics regressions compare gravity/wind strengths, slow/fast head turns, calm settling at a tilted head angle, and equivalent motion delivered at 30/60/120 Hz. Python tests validate the Blender interchange math.

Combined-groom regressions cover extended root positions, rotation/scale behavior, mustache coverage, Static/Free region motion, old-file loading, stable region edits, all three scalp presets, maximum combined allocation/export, and native option validation.

Additional checks requiring a graphics context or Blender:

```powershell
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path viewer --script res://tests/beard_render.gd --quit-after 600
.\buildtools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path viewer --resolution 1440x900 --script res://tests/groom_render.gd
.\buildtools\python-3.15.0\python.exe -B tools\check_blender.py --blender 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
```

The rendered checks exercise pixels, generated-marker colors, presets, visibility, strand selection, controls, and library thumbnails using a mannequin. The Blender check exports all regions from Godot, edits real curves, exports them, then runs the returned guides through native physics. Checks write synthetic artifacts under `artifacts/`. The rendered editor, capture, and performance probes disable settings persistence to preserve the user's working design.
