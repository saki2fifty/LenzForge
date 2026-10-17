# Guided head calibration

Start camera capture, then click **Calibrate head** in the top toolbar (the head inside corner brackets), or use **Landmarks → Calibrate head…**. The wizard collects front, left, right, slightly up and slightly down views. Its preview is unmirrored; follow the arrows shown there. Keep one face and the entire head visible, relax your expression, and hold each pose until the progress bar fills.

Optional reveal steps ask you to gently hold hair back from the forehead/temples and move beard hair aside at each jaw. Keep fingers behind the outline and avoid pressing or stretching skin. Skip a view if the skin remains covered. This can improve visible-contour evidence; it cannot reveal the skull through hair. At least two accepted views with different angles are required to fit.

Green dots show candidate exposed skin edges. The detector follows the connected face/scalp outline, including skin against clothing or a chair. Above the nose bridge it can extend into skin-colored scalp that the segmenter labels as an accessory. Hair boundaries, detected hands and artificial image/crop edges are excluded. Orange boxes exclude detected hands. These are model estimates: hands can be missed, and facial hair can be misclassified. The segmenter has no dedicated beard class. A missing green contour is not an instruction to press hair harder. Covered areas retain a prior estimate instead of treating the outside of a hairstyle as the skull.

After capture, choose a captured view to review its blue fitted outline. Adjust **Head depth**, **Crown height**, **Side fullness**, and **Under-jaw fullness** if needed. **Save head fit** applies and autosaves the result. Cancel keeps the previous fit. **Reset saved fit** restores the project head-shape defaults. Calibration does not change hair colors/forces, guide visibility, tracking delegate, selected models, or capture settings.

Crown and lower-face contours receive separate weight in fitting so dense cheek samples cannot overwhelm a short scalp arc. If no usable crown arc was observed, automatic fitting leaves crown height unchanged and the review explicitly says it remains an estimate. Reveal the scalp and retry, or adjust Crown height manually.

## What changes

The result reshapes the existing shared head surface used by virtual landmarks, hair roots, object attachments, the mannequin, occlusion and physical hair collisions. The 478 measured face coordinates and attachment IDs remain unchanged. Hair bindings refresh when the shape changes; they are not searched again on every frame.

The cranium uses a saved neutral reference and follows a robust similarity transform fitted to 19 nose, upper-cheek and temple anchors. Eyelids, brows, mouth and chin are excluded from the pose solve. Blinks and mouth motion therefore do not reshape the crown. The first two virtual rings blend into the expressive face; the remaining skull stays rigid. The C++ implementation caches skull geometry and fits each current frame directly, without adding temporal smoothing or a delayed frame queue. Tracking noise in the remaining anchors can still affect pose.

Older version-1 profiles retain their shape parameters and use the first tracked face as a temporary neutral reference. **Recalibrate once after updating** to capture the improved scalp contour and save a neutral reference that survives restarts. Keep a relaxed expression for the front view.

This is a coarse four-parameter fit to multiple visible silhouettes, **not a depth scan or an exact skull reconstruction**. Hidden scalp, covered jaw regions and the back of the head remain estimated. Single-camera perspective, lighting, segmentation, expression and MediaPipe's estimated depth limit accuracy. Review the result from several views, especially with a thick beard or voluminous hair.

## Processing, model and storage

- Analysis runs only on wizard requests, at most about four samples per second, separately from normal tracking. Six fresh, steady, correctly oriented samples qualify a pose. Repeated frames, poor pose, blurred/cropped faces and insufficient exposed outline do not advance the bar.
- The wizard uses separate official Face Landmarker and Hand Landmarker instances plus Google's multiclass selfie segmenter on CPU. It preserves the application's selected tracking models and delegate. Its extra analysis can temporarily consume CPU while calibrating.
- First use downloads the approximately 16 MB `selfie_multiclass_256x256.tflite` model into `models/` (or `LENZFORGE_MODELS`). SHA-256 is verified before loading: `c6748b1253a99067ef71f7e26ca71096cd449baefa8f101900ea23016507e0e0`.
- Model instances are released after fitting or canceling, or after 60 seconds without analysis if the viewer disappears. No segmentation or silhouette optimization runs during ordinary preview. The native pose solve transforms cached geometry with the same vertex/triangle counts.
- Images and per-view observations stay in local process memory during the wizard; they are not uploaded or saved by the application. The version-2 profile retains four shape parameters, 478 normalized reference points and crown-evidence status in `[calibration] profile` in [`studio.cfg`](SETTINGS.md#storage). Depth/crown also use the existing view preferences. Personal profiles are not committed to GitHub.

Validation includes synthetic multi-view fitting, crown-evidence gating, bald-scalp/hair/hand mask cases, immediate rotation with independently deformed eyelids/brows/mouth, unchanged measured anchors and attachment IDs, complete pose/skip/cancel flow, saved-profile restoration in a fresh viewer process, and actual model inference on a public-domain portrait. User-supplied screenshots also exercise the reported missing-crown case locally. A controlled accuracy study across real people/head shapes has not been performed.

Sources: Google's [Image Segmenter overview and class definitions](https://ai.google.dev/edge/mediapipe/solutions/vision/image_segmenter), [multiclass selfie model](https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_multiclass_256x256/float32/1/selfie_multiclass_256x256.tflite), and [Face Landmarker guide](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker).
