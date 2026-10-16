import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
sys.path.insert(0, str(ROOT))
os.environ['MPLCONFIGDIR'] = str(ROOT / 'artifacts' / 'matplotlib')

# Ordinary protocol/API tests do not need a real browser. GPU lifecycle and
# fallback tests select their own backend; tools/check_tracking.py exercises
# the actual browser and models on supported hardware.
import pytest
from pipeline import tracking_config


@pytest.fixture(autouse=True)
def isolated_tracking_settings(monkeypatch):
    monkeypatch.setattr(tracking_config, '_config', tracking_config.TrackingConfig(backend='cpu'))
    monkeypatch.setattr(tracking_config, '_revision', 0)
