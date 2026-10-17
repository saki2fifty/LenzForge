"""Run the actual calibration models on a public-domain portrait; no webcam."""
import json
import os
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'backend'))
os.environ['MPLCONFIGDIR']=str(ROOT/'artifacts/matplotlib')
import cv2
import matplotlib
from capture.frame import VideoFrame
from tracking.calibration import analyzer
source=cv2.imread(str(Path(matplotlib.get_data_path())/'sample_data/grace_hopper.jpg'))
try:
    result=analyzer.analyze(VideoFrame(source,source.shape[1],source.shape[0]),1)
    assert len(result.get('face',[]))==478,result.get('reason')
    assert result.get('contour'),result.get('reason')
    (ROOT/'artifacts/calibration-portrait.json').write_text(json.dumps(result),encoding='utf-8')
    print(json.dumps({key:result[key] for key in ['usable','reason','yaw','pitch']}))
    print('CALIBRATION_MODELS passed; contour points:',len(result['contour']))
finally:
    analyzer.close()
