# Sculpted scalp models

Original LenzForge meshes created in Blender for the approved October 17, 2026 hair studies. The user's reference images informed the styling; no third-party mesh or texture is embedded. Distributed under the repository's MIT license.

| File | Style | Triangles |
| --- | --- | ---: |
| side_swept.glb | Side-swept | 33,626 |
| center_parted.glb | Center-parted | 40,941 |
| long_layered.glb | Long layered | 88,004 |

Each export has one opaque mesh/material surface, smooth normals and flow UVs. Godot may split vertices at UV seams. The runtime uses `scalp_mesh.gdshader` instead of Blender's procedural material, so lighting differs from the Blender previews.

Reference skull in exported coordinates: center `(0, 0.13, -0.10)`, ellipsoid radii `(0.85, 1.27, 0.95)`, +Y up, face toward +Z. Geometry has no node transform. `sculpted_hair.gd` fits that reference to the application's shared head. Keep these conventions when replacing an asset. Blender is only an authoring tool; the viewer loads the bundled GLB files.
