import numpy as np
import pytest
from graphs.tasks_compat import FaceMesh, Hands, Pose
from pathlib import Path
import cv2
import matplotlib


@pytest.mark.parametrize('model_class', [FaceMesh, Hands, Pose])
def test_current_tasks_load_models_and_process_video(model_class):
    model = model_class()
    try:
        image = np.zeros((256, 256, 3), np.uint8)
        model.process(image)
        first = model.last_timestamp
        model.process(image)
        assert model.last_timestamp > first
    finally:
        model.close()


def test_face_landmarks_blendshapes_and_transform_on_portrait():
    # Matplotlib's bundled public-domain NASA portrait of Grace Hopper.
    image = cv2.imread(str(Path(matplotlib.get_data_path()) / 'sample_data/grace_hopper.jpg'))
    assert image is not None
    model = FaceMesh()
    try:
        result = model.process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        assert len(result.multi_face_landmarks[0].landmark) == 478
        assert len(result.face_blendshapes[0]) == 52
        assert result.facial_transformation_matrixes[0].shape == (4, 4)
    finally:
        model.close()
