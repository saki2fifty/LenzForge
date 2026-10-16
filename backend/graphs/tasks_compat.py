"""Result adapters for the current MediaPipe Tasks video API.

Keeps existing graph consumers' data schema without using the removed Solutions
API. Models are installed by Setup.ps1 or explicitly through the model library.
"""
import os
from pathlib import Path
import time
from types import SimpleNamespace
os.environ.setdefault('MPLCONFIGDIR', str(Path(__file__).resolve().parents[2] / 'artifacts' / 'matplotlib'))
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python
from mediapipe.tasks.python import vision


def model_path(name):
    override = os.environ.get('LENZFORGE_MODELS')
    roots = [Path(override)] if override else [p / 'models' for p in Path(__file__).resolve().parents]
    for root in roots:
        candidate = root / name
        if candidate.is_file():
            return str(candidate)
    raise FileNotFoundError(f'Missing {name}. Run Setup.ps1 or set LENZFORGE_MODELS.')


def landmark_list(points):
    return SimpleNamespace(landmark=points) if points else None


class VideoTask:
    def __init__(self):
        self.last_timestamp = -1

    def detect(self, rgb):
        timestamp = max(self.last_timestamp + 1, time.monotonic_ns() // 1_000_000)
        self.last_timestamp = timestamp
        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb))
        return self.task.detect_for_video(image, timestamp)

    def close(self):
        self.task.close()


class FaceMesh(VideoTask):
    def __init__(self, max_num_faces=1, min_detection_confidence=0.5, min_tracking_confidence=0.5,
                 min_presence_confidence=0.5, output_blendshapes=True, output_transform=True, model=None, **_):
        super().__init__()
        self.task = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
            base_options=python.BaseOptions(model_asset_path=model or model_path('face_landmarker.task')),
            running_mode=vision.RunningMode.VIDEO, num_faces=max_num_faces,
            min_face_detection_confidence=min_detection_confidence,
            min_face_presence_confidence=min_presence_confidence,
            min_tracking_confidence=min_tracking_confidence,
            output_face_blendshapes=output_blendshapes, output_facial_transformation_matrixes=output_transform))

    def process(self, rgb):
        result = self.detect(rgb)
        return SimpleNamespace(multi_face_landmarks=[landmark_list(p) for p in result.face_landmarks],
            face_blendshapes=result.face_blendshapes,
            facial_transformation_matrixes=result.facial_transformation_matrixes)


class Hands(VideoTask):
    def __init__(self, max_num_hands=2, min_detection_confidence=0.5, min_tracking_confidence=0.5, min_presence_confidence=0.5, model=None, **_):
        super().__init__()
        self.task = vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
            base_options=python.BaseOptions(model_asset_path=model or model_path('hand_landmarker.task')),
            running_mode=vision.RunningMode.VIDEO, num_hands=max_num_hands,
            min_hand_detection_confidence=min_detection_confidence,
            min_hand_presence_confidence=min_presence_confidence,
            min_tracking_confidence=min_tracking_confidence))

    def process(self, rgb):
        result = self.detect(rgb)
        return SimpleNamespace(
            multi_hand_landmarks=[landmark_list(p) for p in result.hand_landmarks],
            multi_hand_world_landmarks=[landmark_list(p) for p in result.hand_world_landmarks],
            multi_handedness=[SimpleNamespace(classification=[SimpleNamespace(
                label=c.category_name, score=c.score, index=c.index) for c in categories])
                for categories in result.handedness])


class Pose(VideoTask):
    def __init__(self, min_detection_confidence=0.5, min_tracking_confidence=0.5, min_presence_confidence=0.5, enable_segmentation=False, model=None, **_):
        super().__init__()
        self.task = vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
            base_options=python.BaseOptions(model_asset_path=model or model_path('pose_landmarker_lite.task')),
            running_mode=vision.RunningMode.VIDEO,
            min_pose_detection_confidence=min_detection_confidence,
            min_pose_presence_confidence=min_presence_confidence,
            min_tracking_confidence=min_tracking_confidence,
            output_segmentation_masks=enable_segmentation))

    def process(self, rgb):
        result = self.detect(rgb)
        return SimpleNamespace(
            pose_landmarks=landmark_list(result.pose_landmarks[0]) if result.pose_landmarks else None,
            pose_world_landmarks=landmark_list(result.pose_world_landmarks[0]) if result.pose_world_landmarks else None,
            segmentation_mask=result.segmentation_masks[0].numpy_view().copy() if result.segmentation_masks else None)


solutions = SimpleNamespace(face_mesh=SimpleNamespace(FaceMesh=FaceMesh),
    hands=SimpleNamespace(Hands=Hands), pose=SimpleNamespace(Pose=Pose))
