# Desktop effects

Open the right-hand **Effects** tab and choose **Face & skin**, **Background**, or **Color & finish** from its dropdown. **Enable effects** bypasses the whole effects layer; **Reset effects** restores neutral colors and turns blur and facial effects off. Sliders show their numeric values.

Choose **Background** and enable **Background blur** to keep people sharp while softening the room behind them. The default uses fast person detection, up to 30 masks/s, confidence 0.65 and a small 0.5-mask-pixel inset.

The tab also includes black-and-white, sepia, negative and posterize filters, plus saturation, contrast, warmth and vignette. These adjustments layer over the **Look** preset. Changes autosave under `[effects] settings` in `studio.cfg` and restore after restarting. The Effects tab fits alongside the existing tabs, including at 960 × 640.

Effects apply to live camera video and its virtual-camera composition. Rendered hair, landmarks and the mannequin retain their own materials. Source recording still saves the original camera video. Browser effects remain a separate set of controls.

## Face and skin

Choose **Face & skin → Natural skin preset** for a moderate starting point, or enable **Enable facial effects** and adjust individual controls. Face tracking must be enabled in Capture. Facial effects are off by default and work independently of background blur.

| Control | Behavior |
| --- | --- |
| Skin smoothing | Softens small texture variations within the tracked face; zero bypasses smoothing. |
| Preserve detail | Higher values preserve more high-contrast detail; lower values soften more aggressively. |
| Face brightness | Brightens or darkens the face region without changing the room. |
| Face warmth | Adds a warmer or cooler face tone. |
| Cheek blush / Blush color | Places a soft tint around the tracked cheek anchors. |
| Lip tint / Lip color | Colors the lip ring while retaining luminance detail and excluding the mouth opening. |

The Natural skin preset uses smoothing 0.45, detail preservation 0.65, brightness +0.025 and warmth +0.005, with blush and lip tint off. **Reset facial effects** resets only this group, leaving the background and global color adjustments intact. The controls, colors and selected Effects page autosave and restore.

These effects reuse the existing face landmarks. A small GPU mask excludes the eyes, eyebrows and mouth from skin smoothing; a separate lip region keeps lip tint out of the mouth opening. The smoothing shader uses eight nearby samples with color-difference weights to retain strong edges. Sampling is limited to the face's bounds and skips smoothing taps when its strength is zero. No additional AI model, person segmentation request, full-frame CPU filter or camera readback is required. A disabled facial group allocates no mask viewport on startup.

The mask is applied only to the matching camera-frame timestamp. Tracking loss, camera-frame mismatch, mannequin mode and the master bypass disable it; stale results are never dragged across newer video. Mirroring and the composed virtual camera use the same material. Face adjustments run before the Look/global color filters, so a global black-and-white filter also desaturates blush and lip tint.

The mask describes facial anatomy, not an AI classification of skin. Real beard texture, glasses, a hand over the face, fine hairs, extreme turns and imperfect landmarks can affect the result. Higher **Preserve detail** and lower smoothing help keep texture natural. The face outline covers the measured facial region, not the entire scalp or body.

## Background separation

The backend uses Google's [MediaPipe Image Segmenter](https://developers.google.com/edge/mediapipe/solutions/vision/image_segmenter) with either landscape SelfieSegmenter (**Fast**, 256 × 144) or square SelfieSegmenter (**Balanced**, 256 × 256). Balanced retains more vertical detail but requires more inference work; it does not guarantee better classification of every object. Both run on CPU in a separate, demand-driven worker, independently of the selected CPU/GPU face tracker. OpenCV downsizes and converts camera input; refinement, room matching and blur run in custom Godot GPU shaders.

On first use, the backend downloads the selected model into `models/` (or `LENZFORGE_MODELS`), verifies SHA-256, and installs it atomically. It then works offline. No camera images are uploaded to the model host or saved by this feature.

| Mode | Pinned Google model | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| Fast | [Landscape float16 v1](https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter_landscape/float16/1/selfie_segmenter_landscape.tflite) | 250,177 | `490e9ea734313e0de10fa0cd9e3c6133e36ea4db2b7a49bde9ef019f72796b8e` |
| Balanced | [Square float16 v1](https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/1/selfie_segmenter.tflite) | 249,537 | `191ac9529ae506ee0beefa6b2c945a172dab9d07d1e802a290a4e4038226658b` |

## Reducing clear background patches

**Reduce background leaks** applies confidence 0.75, inset 1.0, softness 0.08 and up to 60 masks/s. It preserves the selected detection model. Adjust individual controls if fine hair or fingers become blurred:

| Control | What it changes | Tradeoff |
| --- | --- | --- |
| Person confidence | Raise to blur pixels the AI is less certain belong to you. | Excessive values can blur fine hair or fingers. |
| Edge inset | Contracts the sharp outline by 0–4 mask pixels. | Large values trim the person too; start around 0.5–1.0. |
| Edge softness | Softens the confidence transition. | It cannot correct confidently misclassified objects. |
| Mask rate | 15 for lower CPU use, 30 balanced, or 60 for fast motion. | Actual cadence is limited by the camera and inference speed. |
| Person detection | Fast landscape or Balanced square model. | Balanced costs more CPU and may still misclassify a wall object. |

For a sign, chair or other room object that repeatedly stays sharp, use **Learn empty room · 5 s**. Click it and step completely outside the camera's view before the countdown ends. When the status says **Room learned**, return. A small GPU reference lets matching background colors stay blurred even if the AI calls them a person. It is checked on every displayed camera frame, so newly uncovered background does not have to wait for the next person mask.

**Room tolerance** controls the color match. Raise it slightly if static wall details remain clear; lower it if similar-colored clothes start blurring. **Use learned room** bypasses this correction without relearning. **Forget learned room** discards it. The reference is held only in memory for the current capture session and is cleared when blur/capture stops, the source or resolution changes, or the app restarts. Learn again after moving the camera or changing room lighting. All control choices still autosave; the room image and countdown do not.

The room must be empty during capture: including yourself in the reference can cause matching parts of your body to blur. Similar foreground/background colors, moving room objects, camera auto-exposure changes, fine hair and fast motion remain difficult cases. These controls reduce leakage; they cannot guarantee a perfect cutout in every scene.

## Performance and behavior

Only one latest mask is retained. Capture and face tracking never wait for segmentation; duplicate source frames are not processed twice. Desktop polling has one request in flight at up to 60 Hz and carries only a 36/64 KiB mask plus its capture timestamp. Inference independently respects the selected 15/30/60 Hz cap. Capture-generation and model checks reject old results; switching models drops in-flight work. Masks older than 150 ms relative to displayed video, or not refreshed within 250 ms, stop blurring until a fresh mask arrives.

Godot first refines the mask at its small native dimensions, including optional room matching. It prefilters a quarter-size background texture, applies a horizontal blur there, and composites the vertical blur into the existing video shader. Foreground colors are excluded from blur sampling to reduce edge halos. Intermediate textures update only with new video frames. Learning the room reads back one 256 × 144 reference; ongoing cleanup does not read back camera frames or run a second AI model. Color-only effects need no segmentation. Disabling blur, entering the mannequin or stopping capture stops mask requests; an explicit stop and a two-second lease release the worker even if the viewer disconnects unexpectedly. Already-running inference or a first-use download can finish before its resources are released.

See [measured performance](PERFORMANCE.md#desktop-background-blur).

After installing this update, restart **both the backend and viewer**. If the tab reports that it needs the updated backend, restart `Start-Backend.ps1`. If the model download fails, the original sharp video continues; toggle blur off/on to retry.
