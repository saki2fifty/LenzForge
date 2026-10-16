'use strict';
const $ = id => document.getElementById(id);
let recording = false;
let lastSource = null;
let discoveryAttempted = false;
let trackingDirty = false;
let trackingRevision = -1;
const trackingForm = $('tracking-settings');
trackingForm.addEventListener('input', () => { trackingDirty = true; });
function acceptTracking(config, revision) {
  for (const [key, value] of Object.entries(config || {})) {
    const field = trackingForm.elements.namedItem(key);
    if (!field) continue;
    if (field.type === 'checkbox') field.checked = value;
    else field.value = value;
  }
  trackingDirty = false; trackingRevision = revision;
}
trackingForm.onsubmit = event => {
  event.preventDefault();
  const values = {};
  for (const field of trackingForm.elements) {
    if (!field.name) continue;
    values[field.name] = field.type === 'checkbox' ? field.checked : field.name === 'backend' ? field.value : Number(field.value);
  }
  action(async () => {
    const result = await api('/api/tracking/configure', values);
    acceptTracking(result.config, result.revision);
    $('message').textContent = 'Tracking settings applied.';
  });
};
$('tracking-reset').onclick = () => action(async () => {
  const result = await api('/api/tracking/reset', {});
  acceptTracking(result.config, result.revision);
});
async function api(path, data) {
  const response = await fetch(path, data === undefined ? {} : {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(data)
  });
  const result = await response.json();
  if (!response.ok || result.success === false) throw new Error(result.error?.message || result.error || 'Request failed');
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
  const selected = options.find(option => previous?.dataset.deviceId
    ? option.dataset.deviceId === previous.dataset.deviceId
    : option.value === (previous?.value || String(lastSource)));
  $('source').value = selected?.value ?? '';
  $('start').disabled = !$('source').value;
  $('message').textContent = result.cameras.some(camera => camera.index >= 0)
    ? 'Select your webcam by name, then click Start capture.'
    : 'No cameras found. Connect a webcam and click Find cameras, or choose Demo pattern.';
}
$('scan').onclick = () => action(findCameras);
$('source').onchange = () => {
  $('start').disabled = !$('source').value;
  $('message').textContent = 'Click Start capture to use ' + $('source').selectedOptions[0].text + '.';
};
document.querySelectorAll('[data-tracking]').forEach(input => input.onchange = () => action(async () => {
  const changes = {[input.dataset.tracking]:input.checked};
  if (input.dataset.tracking === 'face_mesh') changes.iris = input.checked;
  await api('/api/tracking/enable', changes); $('message').textContent = 'Tracking updated.';
}));
$('record').onclick = () => action(async () => {
  const result = await api('/api/export/recording/' + (recording ? 'stop' : 'start'), {});
  recording = result.recording;
  $('message').textContent = (recording ? 'Recording source to ' : 'Saved ') + result.files.join(', ');
});
$('apply').onclick = () => action(async () => {
  await api('/api/effects/clear', {});
  if ($('effect').value) await api('/api/effects/apply', {effect_name:$('effect').value});
  $('message').textContent = 'Browser preview effect updated.';
});
$('clear').onclick = () => action(async () => { await api('/api/effects/clear', {}); $('effect').value = ''; $('message').textContent = 'Effects reset.'; });
$('quality').oninput = () => { $('quality-value').textContent = $('quality').value; };
$('quality').onchange = () => action(async () => {
  await api('/api/performance/config', {preview_quality:Number($('quality').value)});
  $('message').textContent = 'Preview quality updated.';
});
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
    if (!trackingDirty && trackingRevision !== tracking.settings_revision) acceptTracking(tracking.settings, tracking.settings_revision);
    let runtime = (tracking.active_backend || 'Waiting for capture').toUpperCase();
    if (tracking.phase && tracking.phase !== 'ready') runtime += ' · ' + tracking.phase.replaceAll('_', ' ');
    if (tracking.fallback_reason) runtime += ' · fallback: ' + tracking.fallback_reason;
    runtime += `\n${(tracking.round_trip_p50_ms || 0).toFixed(1)} ms median / ${(tracking.round_trip_p95_ms || 0).toFixed(1)} ms p95`;
    if (tracking.comparison) runtime += `\nAuto: CPU ${tracking.comparison.cpu_p50_ms.toFixed(1)} / GPU ${tracking.comparison.gpu_p50_ms.toFixed(1)} ms`;
    $('tracking-runtime').textContent = runtime;
    document.querySelectorAll('[data-tracking]').forEach(input => {
      const feature = input.dataset.tracking === 'face_mesh' ? 'face' : input.dataset.tracking;
      if (feature in (data.tracking.features || {})) input.checked = data.tracking.features[feature];
    });
    recording = data.recording;
    $('record').textContent = recording ? '■ Stop recording' : '● Record source';
    if (data.error) $('connection').textContent = 'Capture error';
    if (data.tracking.error || data.error) $('message').textContent = data.error || data.tracking.error;
    if (!discoveryAttempted) {
      discoveryAttempted = true;
      try { await findCameras(); } catch (error) { $('message').textContent = error.message; }
    }
  } catch (_) { $('connection').textContent = 'Backend offline'; discoveryAttempted = false; }
}
async function updateLoop() { await poll(); setTimeout(updateLoop, document.hidden ? 4000 : 1000); }
api('/api/effects/list').then(result => {
  // Segmentation-dependent effects are withheld until the pipeline supplies a mask.
  for (const [category, effects] of Object.entries(result.categories)) {
    if (category === 'Background' || category === 'Face') continue;
    const group = document.createElement('optgroup'); group.label = category;
    for (const effect of effects) group.append(new Option(effect.name.replace(/Effect$/, '').replace(/([a-z])([A-Z])/g, '$1 $2'), effect.name));
    $('effect').append(group);
  }
}).catch(error => { $('message').textContent = error.message; });
updateLoop();
