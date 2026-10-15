// LenzForge V2 - Main Application
class LenzForgeApp {
    constructor() {
        this.state = {
            connected: false,
            pipelineRunning: false,
            currentSection: 'dashboard',
            stats: { fps: 0, uptime: 0, memory: 0, cpu: 0 }
        };
        
        this.init();
    }
    
    init() {
        this.setupPipelineControls();
        this.checkConnection();
        this.startPolling();
        this.loadAllData();
    }
    
    // Load all data since everything is visible
    loadAllData() {
        CameraModule.load();
        TrackingModule.load();
        EffectsModule.load();
        ConfigModule.load();
        SettingsModule.loadLoggingConfig();
        SettingsModule.initCustomSelects();
    }
    
    setupPipelineControls() {
        document.getElementById('startPipeline')?.addEventListener('click', () => this.startPipeline());
        document.getElementById('stopPipeline')?.addEventListener('click', () => this.stopPipeline());
        document.getElementById('restartPipeline')?.addEventListener('click', () => this.restartPipeline());
    }
    
    async checkConnection() {
        try {
            await API.getStatus();
            this.state.connected = true;
        } catch {
            this.state.connected = false;
        }
        this.updateConnectionStatus();
    }
    
    updateConnectionStatus() {
        const indicator = document.getElementById('statusIndicator');
        if (indicator) {
            if (this.state.connected) {
                indicator.classList.add('connected');
                indicator.querySelector('.text').textContent = 'Connected';
            } else {
                indicator.classList.remove('connected');
                indicator.querySelector('.text').textContent = 'Disconnected';
            }
        }
    }
    
    startPolling() {
        setInterval(() => {
            this.checkConnection();
            if (this.state.connected) this.updateStats();
        }, 2000);
    }
    
    async updateStats() {
        try {
            const status = await API.getStatus();
            this.state.stats = {
                fps: status.backend?.fps || 0,
                uptime: status.uptime_seconds || 0,
                memory: status.memory_usage_mb || 0,
                cpu: status.cpu_usage_percent || 0
            };
            this.state.pipelineRunning = status.status === 'running';
            this.updateDashboardStats();
            this.updatePipelineButtons();
        } catch (error) {
            // Silent fail
        }
    }
    
    updateDashboardStats() {
        const updates = {
            headerFps: this.state.stats.fps.toFixed(1),
            headerUptime: Utils.formatUptime(this.state.stats.uptime),
            headerMemory: `${this.state.stats.memory.toFixed(0)} MB`,
            headerCpu: `${this.state.stats.cpu.toFixed(1)}%`
        };
        
        Object.entries(updates).forEach(([id, value]) => {
            const el = document.getElementById(id);
            if (el) el.textContent = value;
        });
        
        // Update system status badge
        const statusBadge = document.getElementById('systemStatus');
        if (statusBadge) {
            if (this.state.pipelineRunning) {
                statusBadge.className = 'status-badge online';
                statusBadge.innerHTML = '<span class="status-dot"></span> Online';
            } else {
                statusBadge.className = 'status-badge offline';
                statusBadge.innerHTML = '<span class="status-dot"></span> Offline';
            }
        }
    }
    
    updatePipelineButtons() {
        const start = document.getElementById('startPipeline');
        const stop = document.getElementById('stopPipeline');
        if (start) start.disabled = this.state.pipelineRunning;
        if (stop) stop.disabled = !this.state.pipelineRunning;
    }
    
    async startPipeline() {
        try {
            await API.startPipeline();
            Utils.showNotification('Pipeline started', 'success');
            this.state.pipelineRunning = true;
            this.updatePipelineButtons();
        } catch (error) {
            Utils.showNotification(error.message, 'danger');
        }
    }
    
    async stopPipeline() {
        try {
            await API.stopPipeline();
            Utils.showNotification('Pipeline stopped', 'success');
            this.state.pipelineRunning = false;
            this.updatePipelineButtons();
        } catch (error) {
            Utils.showNotification(error.message, 'danger');
        }
    }
    
    async restartPipeline() {
        try {
            await API.restartPipeline();
            Utils.showNotification('Pipeline restarted', 'success');
            this.state.pipelineRunning = true;
            this.updatePipelineButtons();
        } catch (error) {
            Utils.showNotification(error.message, 'danger');
        }
    }
    
    async loadDashboard() {
        await this.updateStats();
    }
}

// Initialize app when DOM is ready
let app;
document.addEventListener('DOMContentLoaded', () => {
    app = new LenzForgeApp();
});
