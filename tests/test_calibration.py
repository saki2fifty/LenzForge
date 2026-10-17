import json
from pathlib import Path
import cv2
import numpy as np
import pytest
from tracking.calibration import shell, fit_shape


def reference():
    points=np.array(json.loads((Path(__file__).resolve().parents[1]/'viewer/mannequin/assets/canonical_face.json').read_text())['vertices'])
    points*=np.array([1,-1,-1])
    return np.vstack((points,np.repeat(points[1:2],10,axis=0)))


def observation(shape,yaw,pitch=0):
    face=reference()
    y,p=np.radians([yaw,pitch])
    rotation=np.array([[np.cos(y),0,np.sin(y)],[0,1,0],[-np.sin(y),0,np.cos(y)]]) @ np.array([[1,0,0],[0,np.cos(p),-np.sin(p)],[0,np.sin(p),np.cos(p)]])
    face=(face@rotation.T)*20+np.array([320,240,0])
    hull=cv2.convexHull(np.vstack((face[:468],shell(face,shape)))[:,:2].astype(np.float32))[:,0]
    contour=np.vstack([hull[i]*(1-t)+hull[(i+1)%len(hull)]*t for i in range(len(hull)) for t in [0,.5]])
    return {'face':face.tolist(),'contour':contour[:160].tolist()}


def test_multiview_fitting_reduces_error_and_recovers_depth():
    expected=[.8,.3,1.12,1.08]
    observations=[observation(expected,angle,pitch) for angle,pitch in [(0,0),(45,0),(-45,0),(0,20)]]
    fitted=fit_shape(observations,[.65,.2,1,1])
    assert abs(fitted['depth']-.8)<.06
    assert abs(fitted['crown']-.3)<.06
    assert fitted['views']==4
    assert fitted['estimated']


def test_invalid_and_insufficient_observations_rejected():
    with pytest.raises(ValueError): fit_shape([], [.65,.2,1,1])
    bad=observation([.65,.2,1,1],0)
    bad['face'][0][0]=float('nan')
    with pytest.raises(ValueError): fit_shape([bad,bad], [.65,.2,1,1])
    same=observation([.65,.2,1,1],0)
    with pytest.raises(ValueError,match='different head angles'): fit_shape([same,same],[.65,.2,1,1])


def test_api_rejects_missing_camera_and_malformed_fit(monkeypatch):
    from server.app import create_app
    from server.routes import streaming
    monkeypatch.setattr(streaming,'_active_camera',None)
    client=create_app({'TESTING':True}).test_client()
    assert client.post('/api/calibration/sample').status_code==409
    for payload in [{}, {'observations':[{},{}]}, {'observations':None}, []]:
        assert client.post('/api/calibration/fit',json=payload).status_code==400
    assert client.post('/api/calibration/stop').status_code==200


def test_skin_outline_start_is_unchanged_by_virtual_shape():
    face=reference()*20
    changed=shell(face,[.85,.35,1.2,1.1])
    assert np.isfinite(changed).all()
    assert changed.shape==(720,3)
    assert not np.allclose(changed,shell(face,[.65,.2,1,1]))
