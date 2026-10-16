'use strict';
const $ = id => document.getElementById(id);
let recording = false;
let lastSource = null;
let discoveryAttempted = false;
let trackingDirty = false;
let trackingRevision = -1;
let modelSignature = '';
const trackingForm = $('tracking-settings');
const preferences = new PreferenceQueue({
  getItem: key => localStorage.getItem(key),
  setItem: (key, value) => localStorage.setItem(key, value)
}, api, (path, result) => {
  if ((path === '/api/tracking/configure' || path === '/api/tracking/reset') && !preferences.data.pending['/api/tracking/configure']) acceptTracking(result.config, result.revision);
  $('message').textContent = 'Settings saved.';
}, message => { $('message').textContent = message; });
for (const id of ['resolution', 'fps', 'import-kind']) {
  if (preferences.data[id] !== undefined) $(id).value = preferences.data[id];
  $(id).addEventListener('change', () => { preferences.data[id] = $(id).value; preferences.save(); });
}
for (const kind of ['face', 'hand', 'pose']) {
  const label = document.createElement('label');
  label.textContent = `${kind[0].toUpperCase() + kind.slice(1)} model`;
  label.htmlFor = `model-${kind}`;
  const picker = document.createElement('select');
  picker.id = label.htmlFor; picker.name = `${kind}_model`;
  const defaultId = `${kind}_landmarker${kind === 'pose' ? '_lite' : ''}`;
  picker.add(new Option(defaultId, defaultId));
  const download = document.createElement('button');
  download.type = 'button'; download.textContent = `Download selected ${kind} model`;
  download.onclick = () => action(() => api('/api/tracking/models/download', {id: picker.value}));
  $('model-selectors').append(label, picker, download);
}
function updateModels(library) {
  if (!library) return;
  const signature = JSON.stringify(library.models);
  if (signature !== modelSignature) {
    modelSignature = signature;
    preferences.blocked.delete('/api/tracking/configure');
    for (const kind of ['face', 'hand', 'pose']) {
      const picker = $(`model-${kind}`), selected = picker.value;
      picker.replaceChildren();
      for (const model of library.models.filter(item => item.kind === kind)) {
        picker.add(new Option(`${model.label} · ${model.installed ? 'installed' : 'download'}`, model.id));
      }
      if (![...picker.options].some(item => item.value === selected)) picker.add(new Option(selected + ' · unavailable', selected));
      picker.value = selected;
    }
  }
  const job = library.job;
  if (job.state !== 'idle') $('model-job').textContent = `${job.label} · ${job.state}` +
    (job.state === 'downloading' ? ` · ${(job.received / 1048576).toFixed(1)} / ${(job.total / 1048576).toFixed(1)} MB` :
      job.error ? `: ${job.error}` : job.state === 'ready' ? '. Selected models apply automatically.' : '');
}
$('import-model').onclick = () => action(async () => {
  const file = $('model-file').files[0];
  if (!file || file.size > 100 * 1048576) throw new Error('Choose a .task bundle under 100 MB.');
  const data = new FormData(); data.set('file', file); data.set('kind', $('import-kind').value);
  const response = await fetch('/api/tracking/models/import', {method: 'POST', body: data});
  const result = await response.json();
  if (!response.ok) throw new Error(result.error?.message || 'Import failed');
  $('message').textContent = 'Validating model…';
});
trackingForm.addEventListener('input', () => {
  trackingDirty = true;
  if (trackingForm.checkValidity()) preferences.set('/api/tracking/configure', trackingValues());
});
function acceptTracking(config, revision) {
  for (const [key, value] of Object.entries(config || {})) {
    const field = trackingForm.elements.namedItem(key);
    if (!field) continue;
    if (field.type === 'checkbox') field.checked = value;
    else {
      if (key.endsWith('_model') && ![...field.options].some(option => option.value === value)) field.add(new Option(value + ' · unavailable', value));
      field.value = value;
    }
  }
  trackingDirty = false; trackingRevision = revision;
  preferences.data.tracking = config;
  preferences.save();
}
function trackingValues() {
  const values = {};
  for (const field of trackingForm.elements) {
    if (!field.name) continue;
    values[field.name] = field.type === 'checkbox' ? field.checked : field.name === 'backend' || field.name.endsWith('_model') ? field.value : Number(field.value);
  }
  return values;
}
trackingForm.onsubmit = event => {
  event.preventDefault(); trackingDirty = true;
  preferences.set('/api/tracking/configure', trackingValues());
};
$('tracking-reset').onclick = () => {
  delete preferences.data.pending['/api/tracking/configure'];
  preferences.set('/api/tracking/reset', {});
};
if (preferences.data.tracking) acceptTracking(preferences.data.tracking, -1);
if (preferences.data.pending['/api/tracking/configure']) {
  acceptTracking(preferences.data.pending['/api/tracking/configure'], -1);
  trackingDirty = true;
}
async function api(path, data) {
  const response = await fetch(path, data === undefined ? {} : {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(data)
  });
  const result = await response.json();
  if (!response.ok || result.success === false) {
    const error = new Error(result.error?.message || result.error || 'Request failed');
    error.status = response.status; throw error;
  }
  return result;
}
async function action(callback) {
  try { $('message').textContent = 'Working…'; await callback(); await poll(); }
  catch (error) { $('message').textContent = error.message; }
}
$('start').onclick = () => action(async () => {
  if (!$('source').value) return;
  await api('/api/camera/select', {camera_index:Number($('source').value), device_id:$('source').selectedOptions[0]?.dataset.deviceId, resolution:$('resolution').value.split(',').map(Number), fps:Number($('fps').value)});
  $('message').textContent = 'Capture started. You can also open the desktop viewer.';
});
$('stop').onclick = () => action(async () => { await api('/api/camera/stop', {}); $('message').textContent = 'Capture stopped.'; });
async function findCameras() {
  const result = await api('/api/camera/list');
  const previous = $('source').selectedOptions[0];
  const placeholder = new Option('Choose your camera…', '');
  placeholder.disabled = true;
  const options = result.cameras.map(camera => {
    const option = new Option(camera.name, camera.index);
    option.dataset.deviceId = camera.device_id || '';
    return option;
  });
  $('source').replaceChildren(placeholder, ...options);
  const saved = preferences.data.camera;
  const deviceId = previous?.dataset.deviceId || saved?.deviceId;
  const selected = options.find(option => deviceId
    ? option.dataset.deviceId === deviceId
    : option.value === (previous?.value || saved?.index || String(lastSource)));
  $('source').value = selected?.value ?? '';
  $('start').disabled = !$('source').value;
  $('message').textContent = result.cameras.some(camera => camera.index >= 0)
    ? 'Select your webcam by name, then click Start capture.'
    : 'No cameras found. Connect a webcam and click Find cameras, or choose Demo pattern.';
}
$('scan').onclick = () => action(findCameras);
$('source').onchange = () => {
  preferences.data.camera = {index: $('source').value, deviceId: $('source').selectedOptions[0]?.dataset.deviceId};
  preferences.save();
  $('start').disabled = !$('source').value;
  $('message').textContent = 'Click Start capture to use ' + $('source').selectedOptions[0].text + '.';
};
document.querySelectorAll('[data-tracking]').forEach(input => input.onchange = () => {
  const changes = {[input.dataset.tracking]:input.checked};
  if (input.dataset.tracking === 'face_mesh') changes.iris = input.checked;
  preferences.set('/api/tracking/enable', changes);
});
$('record').onclick = () => action(async () => {
  const result = await api('/api/export/recording/' + (recording ? 'stop' : 'start'), {});
  recording = result.recording;
  $('message').textContent = (recording ? 'Recording source to ' : 'Saved ') + result.files.join(', ');
});
$('apply').onclick = $('effect').onchange = () => {
  preferences.set('/api/effects/chain', {effects: $('effect').value ? [{name: $('effect').value}] : []});
};
$('clear').onclick = () => { $('effect').value = ''; $('apply').onclick(); };
$('quality').oninput = () => {
  $('quality-value').textContent = $('quality').value;
  preferences.set('/api/performance/config', {preview_quality:Number($('quality').value)});
};
async function poll() {
  try {
    const data = await api('/api/status');
    if (data.camera_active && data.camera_index !== lastSource) {
      lastSource = data.camera_index;
      $('source').value = String(data.camera_index);
      $('start').disabled = !$('source').value;
      $('message').textContent = 'Source connected. Adjust your look or start a recording.';
    }
    $('connection').textContent = data.camera_active ? (data.camera_index === -1 ? '● Demo active' : '● Camera live') : '● Backend connected';
    $('capture-fps').textContent = data.fps.toFixed(1);
    $('points').textContent = data.tracking.landmark_count || '0';
    $('inference').textContent = (data.tracking.last_inference_ms || 0).toFixed(1);
    $('dropped').textContent = data.tracking.frames_dropped || '0';
    const tracking = data.tracking;
    updateModels(tracking.library);
    if (!trackingDirty && !preferences.data.pending['/api/tracking/reset'] && trackingRevision !== tracking.settings_revision) acceptTracking(tracking.settings, tracking.settings_revision);
    let runtime = (tracking.active_backend || 'Waiting for capture').toUpperCase();
    if (tracking.phase && tracking.phase !== 'ready') runtime += ' · ' + tracking.phase.replaceAll('_', ' ');
    if (tracking.fallback_reason) runtime += ' · fallback: ' + tracking.fallback_reason;
    runtime += `\n${(tracking.round_trip_p50_ms || 0).toFixed(1)} ms median / ${(tracking.round_trip_p95_ms || 0).toFixed(1)} ms p95`;
    if (tracking.comparison) runtime += `\nAuto: CPU ${tracking.comparison.cpu_p50_ms.toFixed(1)} / GPU ${tracking.comparison.gpu_p50_ms.toFixed(1)} ms`;
    $('tracking-runtime').textContent = runtime;
    document.querySelectorAll('[data-tracking]').forEach(input => {
      const feature = input.dataset.tracking === 'face_mesh' ? 'face' : input.dataset.tracking;
      const pending = preferences.data.pending['/api/tracking/enable'];
      if (pending && input.dataset.tracking in pending) input.checked = pending[input.dataset.tracking];
      else if (feature in (data.tracking.features || {})) input.checked = data.tracking.features[feature];
    });
    recording = data.recording;
    $('record').textContent = recording ? '■ Stop recording' : '● Record source';
    if (data.error) $('connection').textContent = 'Capture error';
    if (data.tracking.error || data.error) $('message').textContent = data.error || data.tracking.error;
    if (!discoveryAttempted) {
      discoveryAttempted = true;
      try { await findCameras(); } catch (error) { $('message').textContent = error.message; }
    }
    await preferences.flush();
  } catch (_) { $('connection').textContent = 'Backend offline'; discoveryAttempted = false; }
}
async function updateLoop() { await poll(); setTimeout(updateLoop, document.hidden ? 4000 : 1000); }
api('/api/effects/list').then(async result => {
  // Segmentation-dependent effects are withheld until the pipeline supplies a mask.
  for (const [category, effects] of Object.entries(result.categories)) {
    if (category === 'Background' || category === 'Face') continue;
    const group = document.createElement('optgroup'); group.label = category;
    for (const effect of effects) group.append(new Option(effect.name.replace(/Effect$/, '').replace(/([a-z])([A-Z])/g, '$1 $2'), effect.name));
    $('effect').append(group);
  }
  const active = await api('/api/effects/active');
  $('effect').value = (preferences.data.pending['/api/effects/chain']?.effects || active.active_effects)[0]?.name || '';
}).catch(error => { $('message').textContent = error.message; });
api('/api/performance/config').then(result => {
  $('quality').value = preferences.data.pending['/api/performance/config']?.preview_quality ?? result.config.preview_quality;
  $('quality-value').textContent = $('quality').value;
}).catch(error => { $('message').textContent = error.message; });
updateLoop();
