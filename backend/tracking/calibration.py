"""On-demand calibration analysis. No extra inference runs during normal capture."""
import base64
import hashlib
import threading
import time
import urllib.request

import cv2
import numpy as np

MODEL = 'selfie_multiclass_256x256.tflite'
MODEL_SHA = 'c6748b1253a99067ef71f7e26ca71096cd449baefa8f101900ea23016507e0e0'
MODEL_URL = 'https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_multiclass_256x256/float32/1/' + MODEL
OUTLINE = [10,338,297,332,284,251,389,356,454,323,361,288,397,365,379,378,400,377,152,148,176,149,150,136,172,58,132,93,234,127,162,21,54,103,67,109]
LIMITS = np.array([[.25, 1.0], [0., .5], [.8, 1.25], [.8, 1.2]])


def frame_basis(face):
    right = face[454] - face[234]
    width = np.linalg.norm(right)
    if not np.isfinite(face).all() or width < 20:
        raise ValueError('Move closer until your face fills more of the preview.')
    right /= width
    down = face[152] - face[10]
    down -= right * down.dot(right)
    length = np.linalg.norm(down)
    if length < 1: raise ValueError('Face orientation is uncertain.')
    down /= length
    return width, right, down, np.cross(right, down), (face[234]+face[454])*.5


def shell(face, shape):
    width, right, down, back, center = frame_basis(face)
    local = face[OUTLINE] - center
    x, y, z = local@right, local@down, local@back
    t = np.arange(1, 21)[:, None]/20
    radial, reach, bend = np.cos(t*np.pi/2), np.sin(t*np.pi/2), np.sin(t*np.pi)
    depth, crown, sides, jaw = shape
    xx = x*radial*(1+(sides-1)*bend)
    yy = y*radial + np.maximum(y, 0)*radial*(jaw-1)*bend - np.maximum(-y/width, 0)**2*crown*4*width*bend
    zz = z*(1-reach)+depth*width*reach
    return (center+xx[..., None]*right+yy[..., None]*down+zz[..., None]*back).reshape(-1, 3)


def fit_shape(observations, initial):
    """Fit only exposed silhouette evidence; retain priors for covered regions."""
    if not 2 <= len(observations) <= 12: raise ValueError('Capture at least two different views before fitting.')
    start = np.asarray(initial, dtype=float)
    if start.shape != (4,) or not np.isfinite(start).all(): raise ValueError('Invalid initial head shape.')
    start = np.clip(start, LIMITS[:, 0], LIMITS[:, 1])
    checked, orientations = [], []
    for item in observations:
        face, contour = np.asarray(item['face'], dtype=float), np.asarray(item['contour'], dtype=float)
        if face.shape != (478,3) or contour.ndim != 2 or contour.shape[1] != 2 or not 8 <= len(contour) <= 160:
            raise ValueError('Invalid calibration observation.')
        if not np.isfinite(contour).all() or np.abs(face).max()>10000 or np.abs(contour).max()>10000:
            raise ValueError('Invalid calibration coordinates.')
        width, _, _, back, _ = frame_basis(face)
        orientations.append(back)
        checked.append((face, contour, width))
    if all(np.dot(orientations[0], direction) > np.cos(np.radians(15)) for direction in orientations[1:]):
        raise ValueError('Capture different head angles, at least 15 degrees apart.')
    def cost(shape):
        errors = []
        for face, contour, width in checked:
            vertices = np.vstack((face[:468],shell(face,shape)))
            hull = cv2.convexHull(vertices[:, :2].astype(np.float32))
            distances = np.array([cv2.pointPolygonTest(hull,(float(p[0]),float(p[1])),True) for p in contour])/width
            # Robust loss: a stray mask edge cannot pull the whole skull outward.
            errors.append(np.mean(np.sqrt(distances**2+.01**2)-.01))
        return float(np.mean(errors)+.025*np.sum((shape-start)**2))
    value, best = start.copy(), cost(start)
    for scale in [1, .5, .25, .125, .0625]:
        steps = np.array([.12,.06,.08,.06])*scale
        for _ in range(3):
            changed = False
            for axis in range(4):
                for direction in [-1,1]:
                    candidate = value.copy()
                    candidate[axis] = np.clip(candidate[axis]+direction*steps[axis], *LIMITS[axis])
                    score = cost(candidate)
                    if score < best-1e-7: value, best, changed = candidate, score, True
            if not changed: break
    return {'version':1,'depth':float(value[0]),'crown':float(value[1]),'sides':float(value[2]),'jaw':float(value[3]),
            'views':len(checked),'fit_error':best,'estimated':True}


class Analyzer:
    def __init__(self):
        self.lock = threading.Lock()
        self.tasks = None
        self.last_used = 0.0
        self.expiry = None
        self.expiry_generation = 0

    def _close_tasks(self):
        if self.tasks:
            for task in self.tasks: task.close()
            self.tasks = None

    def _expire(self, generation):
        # Also release models if the viewer exits without sending /stop. This
        # timer exists only while calibration models are allocated, not in tracking.
        with self.lock:
            if generation != self.expiry_generation: return
            self.expiry = None
            remaining = 60-(time.monotonic()-self.last_used)
            if remaining <= 0: self._close_tasks()
            elif self.tasks: self._schedule_expiry(remaining)

    def _schedule_expiry(self, delay=60):
        self.expiry = threading.Timer(delay,self._expire,args=(self.expiry_generation,))
        self.expiry.daemon = True
        self.expiry.start()

    def close(self):
        with self.lock:
            self.expiry_generation += 1
            if self.expiry: self.expiry.cancel(); self.expiry = None
            self._close_tasks()

    def _load(self):
        if self.tasks: return
        from mediapipe.tasks.python import BaseOptions, vision
        from tracking.models import library
        directory = library.directory
        directory.mkdir(parents=True, exist_ok=True)
        path = directory/MODEL
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != MODEL_SHA:
            temporary = path.with_suffix('.download')
            try:
                with urllib.request.urlopen(MODEL_URL, timeout=30) as response, temporary.open('wb') as target:
                    total = 0
                    while chunk := response.read(1024*1024):
                        total += len(chunk)
                        if total > 20*1024*1024: raise ValueError('Calibration model download exceeds its size limit.')
                        target.write(chunk)
                if hashlib.sha256(temporary.read_bytes()).hexdigest() != MODEL_SHA: raise ValueError('Calibration model verification failed.')
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)
        opened=[]
        try:
            opened.append(vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
                base_options=BaseOptions(model_asset_path=str(library.resolve('face_landmarker','face'))),num_faces=2)))
            opened.append(vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
                base_options=BaseOptions(model_asset_path=str(library.resolve('hand_landmarker','hand'))),num_hands=2)))
            opened.append(vision.ImageSegmenter.create_from_options(vision.ImageSegmenterOptions(
                base_options=BaseOptions(model_asset_path=str(path)),output_confidence_masks=True)))
        except Exception:
            for task in opened: task.close()
            raise
        self.tasks=opened

    def analyze(self, frame, frame_id):
        if not self.lock.acquire(blocking=False): raise RuntimeError('Calibration is already analyzing a frame.')
        try:
            self._load()
            import mediapipe as mp
            width=640; height=max(2,round(frame.height*width/frame.width)//2*2)
            rgb=frame.tracking_rgb(width,height)
            image=mp.Image(image_format=mp.ImageFormat.SRGB,data=np.ascontiguousarray(rgb))
            detected=self.tasks[0].detect(image)
            encoded=cv2.imencode('.jpg',cv2.cvtColor(rgb,cv2.COLOR_RGB2BGR),[cv2.IMWRITE_JPEG_QUALITY,80])[1]
            result={'frame_id':frame_id,'size':[width,height],'image':base64.b64encode(encoded).decode(),
                    'usable':False,'contour':[],'blocked':[],'reason':'Keep exactly one face visible.'}
            if len(detected.face_landmarks)!=1: return result
            face=np.array([[p.x*width,p.y*height,p.z*width] for p in detected.face_landmarks[0]])
            span,right,down,back,center=frame_basis(face)
            result.update(face=face.tolist(),yaw=float(np.degrees(np.arctan2(back[0],back[2]))),
                          pitch=float(np.degrees(np.arctan2(back[1],back[2]))))
            # Keep the skin/background edge. Skin/hair interfaces are hairlines,
            # not observations of the skull, and must not be fitted as its outline.
            segmentation=self.tasks[2].segment(image)
            masks=[cv2.resize(mask.numpy_view(),(width,height)) for mask in segmentation.confidence_masks]
            skin=(masks[2]+masks[3])>.7
            background=masks[0]>.7
            edge=skin & (cv2.dilate(background.astype(np.uint8),np.ones((7,7),np.uint8))>0)
            blocked=np.zeros((height,width),np.uint8)
            hands=self.tasks[1].detect(image)
            for hand in hands.hand_landmarks:
                points=np.array([[p.x*width,p.y*height] for p in hand])
                lo=np.floor(points.min(0)-span*.15).astype(int); hi=np.ceil(points.max(0)+span*.15).astype(int)
                cv2.rectangle(blocked,tuple(lo),tuple(hi),1,-1)
                result['blocked'].append([int(lo[0]),int(lo[1]),int(hi[0]),int(hi[1])])
            yy,xx=np.indices(edge.shape)
            roi=(xx>center[0]-span*1.1)&(xx<center[0]+span*1.1)&(yy>face[10,1]-span*.75)&(yy<face[152,1]+span*.12)
            edge &= roi & (blocked==0)
            y,x=np.where(edge)
            points=np.column_stack((x,y))[::max(1,len(x)//120+1)]
            lo=np.maximum(np.floor(face[:468,:2].min(0)).astype(int),0)
            hi=np.minimum(np.ceil(face[:468,:2].max(0)).astype(int),[width,height])
            crop=rgb[lo[1]:hi[1],lo[0]:hi[0]]
            blur=cv2.Laplacian(cv2.cvtColor(crop,cv2.COLOR_RGB2GRAY),cv2.CV_64F).var() if crop.size else 0
            clipped=lo[0]<=2 or lo[1]<=2 or hi[0]>=width-2 or hi[1]>=height-2
            result['contour']=points.tolist()
            result['usable']=len(points)>=12 and blur>12 and not clipped and abs(result['yaw'])<70 and abs(result['pitch'])<40
            result['reason']='Keep the whole head in view.' if clipped else 'Hold still and improve lighting; the face looks blurred.' if blur<=12 else 'Hold still; clear skin outline found.' if result['usable'] else 'Expose more of the head outline; keep fingers away from the highlighted edge.'
            return result
        finally:
            self.last_used = time.monotonic()
            if self.tasks and self.expiry is None: self._schedule_expiry()
            self.lock.release()


analyzer=Analyzer()
