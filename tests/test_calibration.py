import json
from pathlib import Path
import cv2
import numpy as np
import pytest
from tracking.calibration import shell, fit_shape, stable_shell, exposed_outline, frame_basis
from tracking.head_pose import align


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


def test_rigid_skull_ignores_expressions_and_follows_immediate_pose():
    neutral=reference()*20
    shape=[.7,.3,1.1,1]
    baseline=stable_shell(neutral,neutral,shape).reshape(20,36,3)[2:]
    for yaw in [0,60,-90,180,-135]:
        angle=np.radians(yaw)
        rotation=np.array([[np.cos(angle),0,np.sin(angle)],[0,1,0],[-np.sin(angle),0,np.cos(angle)]])
        expressive=neutral.copy()
        expressive[[10,151,9,338,109],1]-=18
        expressive[[152,377,400,13,14],1]+=30
        expressive[[159,145,386,374],1]+=12
        expressive=(expressive@rotation.T)*1.3+[320,240,10]
        actual=stable_shell(neutral,expressive,shape).reshape(20,36,3)[2:]
        np.testing.assert_allclose(actual,baseline@rotation.T*1.3+[320,240,10],atol=1e-7)
    displaced=neutral.copy(); displaced[117]+=[35,25,10]
    # A locally deformed cheek should not pull the entire crown with it.
    assert np.linalg.norm(align(neutral,displaced)-neutral,axis=1).max()<2


def test_crown_requires_observed_upper_outline():
    observations=[observation([.8,.3,1.12,1.08],yaw) for yaw in [0,45,-45]]
    for item in observations:
        face=np.array(item['face']); points=np.array(item['contour'])
        _,_,down,_,_=frame_basis(face)
        item['contour']=points[((points-face[10,:2])@down[:2])>5].tolist()
    fitted=fit_shape(observations,[.65,.44,1,1])
    assert not fitted['crown_observed']
    assert fitted['crown']==.44
    assert fitted['version']==2
    ref=np.array(fitted['reference'])
    assert ref.shape==(478,3)
    assert np.linalg.norm(ref[454]-ref[234])==pytest.approx(1)


def test_bald_scalp_misclassified_as_accessory_is_found_but_hair_is_not():
    face=reference()*15+[160,220,0]
    rgb=np.zeros((400,320,3),np.uint8); rgb[:]=[25,35,45]
    mask=np.zeros((400,320),np.uint8)
    cv2.ellipse(mask,(160,175),(105,145),0,0,360,1,-1)
    rgb[mask!=0]=[185,140,115]
    masks=np.zeros((6,400,320),np.float32); masks[0]=1-mask
    upper=(np.indices(mask.shape)[0]<105)&(mask!=0)
    masks[3]=mask; masks[3,upper]=0; masks[5,upper]=1
    points=exposed_outline(rgb,masks,face,np.zeros_like(mask))
    assert points[:,1].min()<40, 'Recover visible scalp even if labeled accessory'
    masks[5,upper]=0; masks[1,upper]=1
    points=exposed_outline(rgb,masks,face,np.zeros_like(mask))
    assert points[:,1].min()>105, 'Do not fit the outside of hair or its skin boundary'
    blocked=np.zeros_like(mask); blocked[:180]=1
    points=exposed_outline(rgb,masks,face,blocked)
    assert len(points) and points[:,1].min()>183, 'Do not fit an artificial hand cutoff'
