# Virtual face and head landmarks

Open the desktop **Landmarks** tab, between **Look** and **Hair**. Virtual points are enabled by default and appear in orange around the complete face outline. They work with **Show hair and beard** turned off.

![Independent orange landmarks above the head, around the sides, and below the chin, with no hair](images/landmark-extensions.png)

Start the camera with **Face + iris** enabled, or select **Try on mannequin** in this tab. The status reports the measured and virtual point counts and explains when it is waiting for a face. On the mannequin, the synthetic inputs are labeled “reference.”

| Control | Effect |
| --- | --- |
| Extend face / head landmarks | Enable or disable the independent virtual reference data. |
| Show virtual landmarks | Show or hide the orange dots while retaining active reference data. |
| Above head | Extend beyond the tracked forehead toward the top of the head. |
| Below chin | Extend the lower outline down below the chin. |
| Left side / Right side | Independently extend the temples, cheeks, and jaw outward. Left/right refer to the unmirrored camera image and follow head rotation. |
| Front / back | Negative values extend toward the front; positive values extend behind the face. Turn or tilt the head to see the depth offset in the preview. |
| Outward layers | Number of progressively farther rings, from 1 to 12. |
| Points around face | Samples per ring, from 36 to 144. |
| Point size / color | Appearance of virtual dots, separate from measured points and hair roots. |
| Reset extensions | Restore the visible, enabled default fit. |

Reach values use face widths. For example, **Below chin = 0.2** places the outer lower row one fifth of the tracked face width below the chin. The intermediate rings fill the distance from the measured outline to the outer extension. Default density is **72 × 4 = 288** points; the maximum is **144 × 12 = 1,728**. Changing density does not add hair strands or tracking work in the backend.

The lower part of this tab contains the measured-landmark visibility, size, and color controls. **L** toggles measured dots only. General virtual points, measured points, and hair visibility are independent. Extension settings persist across normal viewer restarts, separately from saved hairstyles. Existing hair-root fitting remains under **Hair → Root surface**.

The outline follows MediaPipe's [face-oval connections](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/tasks/python/vision/face_landmarker.py). Each virtual point interpolates between adjacent tracked outline landmarks, then adds an offset in a head-relative frame. Existing relative depth drives yaw and pitch; the same frame follows roll, translation, and scale. These are estimated references, not newly measured anatomy, and the preview has no full-head depth occlusion. Invalid or lost tracking clears the virtual data instead of leaving floating points behind.

For other overlays, `viewer/tracking/face_extensions.gd` exposes `ids` and `points` separately from the measured 478-point array. Positions are in source-image pixels before mirroring/letterboxing. IDs use `extension:<ring>:<column>` and remain stable during movement and extent changes; density changes alter the sampling layout. Topology and offsets are rebuilt only when fitting changes. Each tracking result projects packed arrays once; visible dots use one instanced batch. No hair simulation or additional model is needed.
