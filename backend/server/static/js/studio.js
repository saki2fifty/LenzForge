'use strict';
const $ = id => document.getElementById(id);
let recording = false;
let lastSource = null;
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
  await api('/api/camera/select', {camera_index:Number($('source').value), resolution:$('resolution').value.split(',').map(Number), fps:Number($('fps').value)});
  $('message').textContent = 'Capture started. You can also open the desktop viewer.';
});
$('stop').onclick = () => action(async () => { await api('/api/camera/stop', {}); $('message').textContent = 'Capture stopped.'; });
$('scan').onclick = () => action(async () => {
  const result = await api('/api/camera/list');
  $('source').replaceChildren(...result.cameras.map(camera => new Option(camera.name, camera.index)));
  $('message').textContent = 'Source list updated.';
});
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
      $('message').textContent = 'Source connected. Adjust your look or start a recording.';
    }
    $('connection').textContent = data.camera_active ? '● Source live' : '● Backend connected';
    $('capture-fps').textContent = data.fps.toFixed(1);
    $('points').textContent = data.tracking.landmark_count || '0';
    $('inference').textContent = (data.tracking.last_inference_ms || 0).toFixed(1);
    $('dropped').textContent = data.tracking.frames_dropped || '0';
    document.querySelectorAll('[data-tracking]').forEach(input => {
      const feature = input.dataset.tracking === 'face_mesh' ? 'face' : input.dataset.tracking;
      if (feature in (data.tracking.features || {})) input.checked = data.tracking.features[feature];
    });
    recording = data.recording;
    $('record').textContent = recording ? '■ Stop recording' : '● Record source';
    if (data.tracking.error || data.error) $('message').textContent = data.tracking.error || data.error;
  } catch (_) { $('connection').textContent = 'Backend offline'; }
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
