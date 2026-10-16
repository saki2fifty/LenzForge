'use strict';
// A durable, coalescing queue. Older responses never acknowledge newer edits.
class PreferenceQueue {
  constructor(storage, send, acknowledge, report) {
    this.storage = storage;
    this.send = send;
    this.acknowledge = acknowledge;
    this.report = report;
    this.key = 'lenzforge.studio.v1';
    this.blocked = new Set();
    this.running = false;
    this.timer = null;
    this.data = {pending: {}};
    try {
      const saved = JSON.parse(storage.getItem(this.key) || 'null');
      if (saved && typeof saved === 'object' && !Array.isArray(saved)) this.data = saved;
    } catch (error) { report('Could not read browser settings: ' + error.message); }
    if (!this.data.pending || typeof this.data.pending !== 'object') this.data.pending = {};
  }
  save() {
    try { this.storage.setItem(this.key, JSON.stringify(this.data)); }
    catch (error) { this.report('Could not save browser settings: ' + error.message); }
  }
  set(path, values) {
    this.data.pending[path] = {...this.data.pending[path], ...values};
    this.blocked.delete(path);
    this.save();
    clearTimeout(this.timer);
    this.timer = setTimeout(() => { this.timer = null; this.flush(); }, 350);
  }
  async flush() {
    if (this.running || this.timer) return;
    this.running = true;
    try {
      for (const path of Object.keys(this.data.pending)) {
        if (this.blocked.has(path) || !Object.hasOwn(this.data.pending, path)) continue;
        const values = this.data.pending[path], sent = JSON.stringify(values);
        try {
          const result = await this.send(path, values);
          if (JSON.stringify(this.data.pending[path]) === sent) {
            delete this.data.pending[path];
            this.save();
            this.acknowledge(path, result);
          }
        } catch (error) {
          if (error.status >= 400 && JSON.stringify(this.data.pending[path]) === sent) this.blocked.add(path);
          this.report(error.message);
          break;
        }
      }
    } finally { this.running = false; }
  }
}
if (typeof module !== 'undefined') module.exports = PreferenceQueue;
