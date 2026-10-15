// LenzForge V2 - API Module
const API_BASE = 'http://localhost:5000/api';

class API {
    static async call(endpoint, method = 'GET', body = null) {
        try {
            const options = {
                method,
                headers: {
                    'Content-Type': 'application/json'
                }
            };
            
            if (body) {
                options.body = JSON.stringify(body);
            }
            
            const response = await fetch(`${API_BASE}${endpoint}`, options);
            const data = await response.json();
            
            if (!response.ok) {
                throw new Error(data.error?.message || 'API call failed');
            }
            
            return data;
        } catch (error) {
            console.error(`API Error (${endpoint}):`, error);
            throw error;
        }
    }
    
    // System endpoints
    static async getStatus() {
        return await this.call('/status');
    }
    
    static async getInfo() {
        return await this.call('/info');
    }
    
    static async startPipeline() {
        return await this.call('/start', 'POST');
    }
    
    static async stopPipeline() {
        return await this.call('/stop', 'POST');
    }
    
    static async restartPipeline() {
        return await this.call('/restart', 'POST');
    }
    
    // Camera endpoints
    static async listCameras() {
        return await this.call('/camera/list');
    }
    
    static async getCurrentCamera() {
        return await this.call('/camera/current');
    }
    
    static async selectCamera(index, resolution = [640, 480], fps = 30) {
        return await this.call('/camera/select', 'POST', {
            camera_index: index,
            resolution,
            fps
        });
    }
    
    static async startCamera() {
        return await this.call('/camera/start', 'POST');
    }
    
    static async stopCamera() {
        return await this.call('/camera/stop', 'POST');
    }
    
    // Tracking endpoints
    static async getTrackingStatus() {
        return await this.call('/tracking/status');
    }
    
    static async enableTracking(types) {
        return await this.call('/tracking/enable', 'POST', types);
    }
    
    static async getTrackingStatistics() {
        return await this.call('/tracking/statistics');
    }
    
    // Effects endpoints
    static async listEffects() {
        return await this.call('/effects/list');
    }
    
    static async getActiveEffects() {
        return await this.call('/effects/active');
    }
    
    static async applyEffect(name, parameters = {}, enabled = true) {
        return await this.call('/effects/apply', 'POST', {
            effect_name: name,
            parameters,
            enabled
        });
    }
    
    static async removeEffect(name) {
        return await this.call('/effects/remove', 'POST', {
            effect_name: name
        });
    }
    
    static async clearEffects() {
        return await this.call('/effects/clear', 'POST');
    }
    
    // Configuration endpoints
    static async getConfig() {
        return await this.call('/config');
    }
    
    static async updateConfig(config) {
        return await this.call('/config', 'POST', config);
    }
    
    static async saveConfig(filename = 'config.json') {
        return await this.call('/config/save', 'POST', { filename });
    }
    
    static async loadConfig(filename) {
        return await this.call('/config/load', 'POST', { filename });
    }
    
    // Logging endpoints
    static async getLogsStatus() {
        return await this.call('/logs/status');
    }
    
    static async setLoggingEnabled(enabled) {
        return await this.call('/logs/enable', 'POST', { enabled });
    }
    
    static async getRecentLogs(limit = 100) {
        return await this.call(`/logs/recent?limit=${limit}`);
    }
    
    static async clearLogs() {
        return await this.call('/logs/clear', 'POST');
    }
}
