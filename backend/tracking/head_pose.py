"""Expression-resistant similarity alignment; no temporal filtering or latency."""
import numpy as np

# Nose bridge, upper cheeks and temples. Excludes eyelids, eyebrows, lips and chin.
ANCHORS = [4,5,6,122,127,195,197,234,351,356,454,117,119,121,198,346,348,350,420]


def align(reference, measured):
    a, b = reference[ANCHORS], measured[ANCHORS]
    weights = np.ones(len(a))
    for _ in range(3):
        total = weights.sum()
        ca, cb = (a*weights[:, None]).sum(0)/total, (b*weights[:, None]).sum(0)/total
        x, y = a-ca, b-cb
        u, _, vt = np.linalg.svd((x*weights[:, None]).T@y)
        flip = np.diag([1,1,np.linalg.det(vt.T@u.T)])
        rotation = vt.T@flip@u.T
        denominator = (weights*(x*x).sum(1)).sum()
        if denominator < 1e-12: raise ValueError('Head pose is uncertain.')
        scale = (weights*((x@rotation.T)*y).sum(1)).sum()/denominator
        if not np.isfinite(scale) or scale <= 0: raise ValueError('Head pose is uncertain.')
        residual = np.linalg.norm((x@rotation.T)*scale-y,axis=1)
        threshold = max(np.linalg.norm(b[7]-b[10])*.015, 1e-6)
        weights = np.minimum(1,threshold/np.maximum(residual,1e-9))
    return (reference-ca)@rotation.T*scale+cb
