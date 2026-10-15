"""OpenCV MSMF capture and shared Tasks inference worker."""
import os

# Avoid slow GPU transform initialization for CPU BGR capture and inference.
# Respect an explicit override for drivers that benefit from these transforms.
os.environ.setdefault('OPENCV_VIDEOIO_MSMF_ENABLE_HW_TRANSFORMS', '0')
