const {test} = require('node:test');
const assert = require('node:assert/strict');
const PreferenceQueue = require('../backend/server/static/js/preferences.js');
const storage = () => ({value: null, getItem() { return this.value; }, setItem(_key, value) { this.value = value; }});
function ready(queue) { clearTimeout(queue.timer); queue.timer = null; }

test('saves immediately, coalesces edits, and restores an offline selection', async () => {
  const disk = storage(), sent = [];
  const queue = new PreferenceQueue(disk, async (path, value) => { sent.push([path, value]); return {}; }, () => {}, () => {});
  queue.set('/tracking', {backend: 'gpu', confidence: 0});
  queue.set('/tracking', {model: 'custom', enabled: false});
  assert.equal(sent.length, 0);
  const restored = new PreferenceQueue(disk, queue.send, () => {}, () => {});
  ready(queue);
  await restored.flush();
  assert.deepEqual(sent, [['/tracking', {backend: 'gpu', confidence: 0, model: 'custom', enabled: false}]]);
  assert.deepEqual(JSON.parse(disk.value).pending, {});
});

test('an older response cannot erase an edit made while it was in flight', async () => {
  const disk = storage(), acknowledged = [];
  let complete;
  const queue = new PreferenceQueue(disk, () => new Promise(resolve => { complete = resolve; }),
    (_path, result) => acknowledged.push(result), () => {});
  queue.set('/tracking', {confidence: .5}); ready(queue);
  const running = queue.flush();
  queue.set('/tracking', {confidence: .9}); ready(queue);
  complete({confidence: .5}); await running;
  assert.deepEqual(acknowledged, []);
  assert.equal(JSON.parse(disk.value).pending['/tracking'].confidence, .9);
  const latest = queue.flush(); complete({confidence: .9}); await latest;
  assert.deepEqual(acknowledged, [{confidence: .9}]);
});

test('failed requests remain on disk; invalid model selections wait for a change', async () => {
  const disk = storage(), errors = [];
  const queue = new PreferenceQueue(disk, async () => { throw Object.assign(new Error('Download model first'), {status: 400}); },
    () => {}, error => errors.push(error));
  queue.set('/tracking', {model: 'pose_heavy'}); ready(queue);
  await queue.flush(); await queue.flush();
  assert.equal(errors.length, 1);
  assert.equal(JSON.parse(disk.value).pending['/tracking'].model, 'pose_heavy');
  queue.set('/tracking', {model: 'pose_lite'}); ready(queue);
  assert.equal(queue.blocked.size, 0);
});

test('a rejected older selection cannot block the newer valid selection', async () => {
  let reject;
  const queue = new PreferenceQueue(storage(), () => new Promise((_resolve, fail) => { reject = fail; }), () => {}, () => {});
  queue.set('/tracking', {model: 'missing'}); ready(queue);
  const running = queue.flush();
  queue.set('/tracking', {model: 'installed'}); ready(queue);
  reject(Object.assign(new Error('Missing old model'), {status: 400})); await running;
  assert.equal(queue.blocked.size, 0);
  assert.equal(queue.data.pending['/tracking'].model, 'installed');
});
