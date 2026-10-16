import {FilesetResolver, FaceLandmarker, HandLandmarker, PoseLandmarker} from '/runtime/vision_bundle.mjs';

let socket, fileset, config, features, face, hands, pose;
let renderer = '';
let delegate = 'GPU';
let lastTimestamp = -1;
let modelGeneration = 0;
let sequence = Promise.resolve();
const encoder = new TextEncoder();

function options(kind) {
  const base = {
    baseOptions: {modelAssetPath: `/models/${kind}.task?model=${encodeURIComponent(config[kind + '_model'])}`, delegate},
    runningMode: 'VIDEO', minTrackingConfidence: config.tracking_confidence,
  };
  if (kind === 'face') return {...base, numFaces: config.num_faces,
    minFaceDetectionConfidence: config.detection_confidence,
    minFacePresenceConfidence: config.presence_confidence,
    outputFaceBlendshapes: config.blendshapes,
    outputFacialTransformationMatrixes: config.face_transform};
  if (kind === 'hand') return {...base, numHands: 2,
    minHandDetectionConfidence: config.detection_confidence, minHandPresenceConfidence: config.presence_confidence};
  return {...base, numPoses: 1, minPoseDetectionConfidence: config.detection_confidence,
    minPosePresenceConfidence: config.presence_confidence, outputSegmentationMasks: false};
}

async function updateTask(task, enabled, kind, factory) {
  if (!enabled) { task?.close(); return undefined; }
  if (task) { await task.setOptions(options(kind)); return task; }
  const canvas = new OffscreenCanvas(1, 1);
  const gl = canvas.getContext('webgl2');
  if (!gl || gl.isContextLost()) throw new Error('WebGL2 GPU context is unavailable');
  const debug = gl.getExtension('WEBGL_debug_renderer_info');
  const device = debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
  if (delegate === 'GPU' && /swiftshader|llvmpipe|software rasterizer/i.test(device)) throw new Error('Browser is using software graphics');
  renderer = device;
  const loader = {...fileset, wasmLoaderPath: `${fileset.wasmLoaderPath}?generation=${++modelGeneration}`};
  return factory.createFromOptions(loader, {...options(kind), canvas});
}

async function configure(message) {
  delegate = message.delegate ?? 'GPU';
  config = message.config;
  features = message.features;
  fileset ??= await FilesetResolver.forVisionTasks('/runtime/wasm', true);
  face = await updateTask(face, features.face || features.iris, 'face', FaceLandmarker);
  hands = await updateTask(hands, features.hands, 'hand', HandLandmarker);
  pose = await updateTask(pose, features.pose, 'pose', PoseLandmarker);
  socket.send(JSON.stringify({type: 'ready', delegate, renderer}));
}

function detect(buffer) {
  const header = new DataView(buffer);
  if (header.getUint32(0, true) !== 0x3147464c) throw new Error('Invalid frame header');
  const id = header.getUint32(4, true), width = header.getUint32(8, true), height = header.getUint32(12, true);
  const timestamp = Math.max(lastTimestamp + .001, header.getFloat64(16, true));
  lastTimestamp = timestamp;
  const image = new ImageData(new Uint8ClampedArray(buffer, 24), width, height);
  const start = performance.now();
  const f = face?.detectForVideo(image, timestamp);
  const h = hands?.detectForVideo(image, timestamp);
  const p = pose?.detectForVideo(image, timestamp);
  const elapsed = performance.now() - start;
  const faces = f?.faceLandmarks ?? [], handPoints = h?.landmarks ?? [], body = p?.landmarks?.[0] ?? [];
  const metadata = {face_counts: faces.map(points => points.length),
    hand_sides: (h?.handedness ?? []).map(categories => categories[0].categoryName.toLowerCase()), pose_count: body.length};
  if (config.blendshapes && faces.length) {
    metadata.blendshapes = Object.fromEntries((f.faceBlendshapes?.[0]?.categories ?? []).map(c => [c.categoryName, c.score]));
  }
  if (config.face_transform && faces.length) {
    const matrix = f.facialTransformationMatrixes?.[0]?.data ?? [];
    // Web returns column-major storage; preserve the Python API's row arrays.
    metadata.face_transform = Array.from({length: 4}, (_, r) => Array.from({length: 4}, (_, c) => matrix[c * 4 + r]));
  }
  const encoded = encoder.encode(JSON.stringify(metadata));
  const metaSize = (encoded.length + 3) & ~3;
  const count = faces.reduce((n, points) => n + points.length * 3, 0) + handPoints.length * 63 + body.length * 4;
  const output = new ArrayBuffer(16 + metaSize + count * 4);
  const outHeader = new DataView(output);
  outHeader.setUint32(0, id, true); outHeader.setUint32(4, metaSize, true); outHeader.setFloat64(8, elapsed, true);
  const metaBytes = new Uint8Array(output, 16, metaSize);
  metaBytes.fill(32); metaBytes.set(encoded);
  const floats = new Float32Array(output, 16 + metaSize);
  let index = 0;
  for (const points of [...faces, ...handPoints]) for (const point of points) {
    floats[index++] = point.x; floats[index++] = point.y; floats[index++] = point.z;
  }
  for (const point of body) {
    floats[index++] = point.x; floats[index++] = point.y; floats[index++] = point.z; floats[index++] = point.visibility ?? 0;
  }
  socket.send(output);
}

self.onmessage = ({data}) => {
  socket = new WebSocket(data.origin.replace('http:', 'ws:') + '/session/' + data.token);
  socket.binaryType = 'arraybuffer';
  socket.onmessage = ({data}) => {
    // Model changes and inference share one ordered queue, never overlapping.
    sequence = sequence.then(async () => {
      if (typeof data === 'string') await configure(JSON.parse(data));
      else detect(data);
    }).catch(error => socket.send(JSON.stringify({error: String(error.message ?? error)})));
  };
  socket.onclose = () => { face?.close(); hands?.close(); pose?.close(); self.close(); };
};
