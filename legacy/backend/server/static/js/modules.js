// LenzForge V2 - Feature Modules

// Camera Module
class CameraModule {
    static savedPreferences = {};
    
    static async load() {
        try {
            // Load saved preferences first
            await this.loadPreferences();
            
            const data = await API.listCameras();
            console.log('Camera data:', data);
            this.render(data.cameras || []);
        } catch (error) {
            console.error('Camera load error:', error);
            const container = document.getElementById('cameraList');
            if (container) {
                container.innerHTML = `<p style="color: var(--error); text-align: center; padding: 20px;">Error: ${error.message || 'Failed to load cameras'}</p>`;
            }
        }
    }
    
    static async loadPreferences() {
        try {
            const response = await fetch('/api/configuration');
            const config = await response.json();
            this.savedPreferences = config.camera_preferences || {};
        } catch (error) {
            console.error('Failed to load camera preferences:', error);
            this.savedPreferences = {};
        }
    }
    
    static async savePreference(cameraIndex, resolution, fps) {
        try {
            this.savedPreferences[cameraIndex] = { resolution, fps };
            
            const response = await fetch('/api/configuration', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    camera_preferences: this.savedPreferences
                })
            });
            
            if (!response.ok) {
                throw new Error('Failed to save preferences');
            }
        } catch (error) {
            console.error('Failed to save camera preference:', error);
        }
    }
    
    static render(cameras) {
        const container = document.getElementById('cameraList');
        if (!container) return;
        
        // Add rescan button at top
        let html = `
            <div style="margin-bottom: 15px;">
                <button class="btn btn-secondary" onclick="CameraModule.load()" style="width: 100%;">
                    🔄 Rescan Cameras
                </button>
            </div>
        `;
        
        if (cameras.length === 0) {
            html += '<p style="color: var(--text-muted); text-align: center; padding: 20px;">No cameras detected</p>';
            container.innerHTML = html;
            return;
        }
        
        // Render each camera with side-by-side layout
        html += cameras.map(cam => {
            const hasCapabilities = cam.supported_resolutions && cam.supported_resolutions.length > 0;
            const pref = this.savedPreferences[cam.index] || {};
            const isRunning = cam.is_active || false;
            
            return `
                <div class="camera-card-sidebyside ${isRunning ? 'camera-running' : ''}" data-camera-index="${cam.index}">
                    <div class="camera-header-full">
                        <span class="camera-name">${cam.name}</span>
                        <span class="camera-status-badge" style="display: ${isRunning ? 'inline-block' : 'none'};">● Running</span>
                    </div>
                    
                    <div class="camera-body-grid">
                        <div class="camera-controls-left">
                            <label class="control-label">Resolution</label>
                            ${hasCapabilities ? `
                                <select class="camera-select-modern" id="res_${cam.index}" onchange="CameraModule.onResolutionChange(${cam.index}, ${JSON.stringify(cam.supported_resolutions).replace(/"/g, '&quot;')})">
                                    ${cam.supported_resolutions.map(res => 
                                        `<option value="${res.width}x${res.height}" ${pref.resolution === `${res.width}x${res.height}` ? 'selected' : ''}>${res.width}×${res.height}</option>`
                                    ).join('')}
                                </select>
                            ` : `
                                <select class="camera-select-modern" id="res_${cam.index}" onchange="CameraModule.onResolutionChange(${cam.index}, null)">
                                    <option value="640x480" ${pref.resolution === '640x480' ? 'selected' : ''}>640×480</option>
                                    <option value="1280x720" ${pref.resolution === '1280x720' ? 'selected' : ''}>1280×720</option>
                                    <option value="1920x1080" ${pref.resolution === '1920x1080' ? 'selected' : ''}>1920×1080</option>
                                </select>
                            `}
                            
                            <label class="control-label">Frame Rate</label>
                            ${hasCapabilities ? `
                                <select class="camera-select-modern" id="fps_${cam.index}" onchange="CameraModule.onFPSChange(${cam.index})">
                                    <!-- Populated by updateFPSOptions -->
                                </select>
                            ` : `
                                <select class="camera-select-modern" id="fps_${cam.index}" onchange="CameraModule.onFPSChange(${cam.index})">
                                    <option value="30" ${pref.fps === 30 ? 'selected' : ''}>30 FPS</option>
                                </select>
                            `}
                            
                            <div class="control-buttons">
                                <button class="btn-control btn-start" id="startBtn_${cam.index}" onclick="CameraModule.start(${cam.index})" ${isRunning ? 'disabled' : ''}>
                                    ▶ Start
                                </button>
                                <button class="btn-control btn-stop" id="stopBtn_${cam.index}" onclick="CameraModule.stop(${cam.index})" ${!isRunning ? 'disabled' : ''}>
                                    ⏹ Stop
                                </button>
                            </div>
                        </div>
                        
                        <div class="camera-preview-right">
                            <div class="preview-box ${isRunning ? 'preview-active' : 'preview-stopped'}">
                                ${isRunning ? `
                                    <img class="preview-feed" id="feed_${cam.index}" src="/video_feed?t=${Date.now()}" alt="Camera Feed">
                                ` : `
                                    <div class="preview-placeholder">
                                        <div class="placeholder-icon">📹</div>
                                        <div class="placeholder-text">Camera Stopped</div>
                                    </div>
                                `}
                                <div class="preview-stats" style="display: ${isRunning ? 'flex' : 'none'};">
                                    <span id="preview_fps_${cam.index}">-- FPS</span>
                                    <span class="stats-sep">|</span>
                                    <span id="preview_res_${cam.index}">--</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
        
        container.innerHTML = html;
        
        // Initialize FPS options for cameras with capabilities
        cameras.forEach(cam => {
            if (cam.supported_resolutions && cam.supported_resolutions.length > 0) {
                this.updateFPSOptions(cam.index, cam.supported_resolutions);
            }
        });
        
        // Start stats updates for running cameras
        cameras.forEach(cam => {
            if (cam.is_active) {
                this.startPreviewStats(cam.index);
            }
        });
    }
    
    static updateFPSOptions(cameraIndex, resolutions) {
        const resSelect = document.getElementById(`res_${cameraIndex}`);
        const fpsSelect = document.getElementById(`fps_${cameraIndex}`);
        
        if (!resSelect || !fpsSelect) return;
        
        const [width, height] = resSelect.value.split('x').map(Number);
        const resolution = resolutions.find(r => r.width === width && r.height === height);
        
        const pref = this.savedPreferences[cameraIndex] || {};
        const savedFPS = pref.fps;
        
        if (resolution && resolution.fps_options) {
            fpsSelect.innerHTML = resolution.fps_options
                .map(fps => `<option value="${fps}" ${fps === savedFPS ? 'selected' : ''}>${fps} FPS</option>`)
                .join('');
        }
    }
    
    static onResolutionChange(cameraIndex, resolutions) {
        if (resolutions) {
            this.updateFPSOptions(cameraIndex, resolutions);
        }
        
        const resSelect = document.getElementById(`res_${cameraIndex}`);
        const fpsSelect = document.getElementById(`fps_${cameraIndex}`);
        
        if (resSelect && fpsSelect) {
            const resolution = resSelect.value;
            const fps = parseInt(fpsSelect.value);
            this.savePreference(cameraIndex, resolution, fps);
        }
    }
    
    static onFPSChange(cameraIndex) {
        const resSelect = document.getElementById(`res_${cameraIndex}`);
        const fpsSelect = document.getElementById(`fps_${cameraIndex}`);
        
        if (resSelect && fpsSelect) {
            const resolution = resSelect.value;
            const fps = parseInt(fpsSelect.value);
            this.savePreference(cameraIndex, resolution, fps);
        }
    }
    
	static async start(index) {
		try {
			const resSelect = document.getElementById(`res_${index}`);
			const fpsSelect = document.getElementById(`fps_${index}`);
			
			let resolution = [640, 480];
			let fps = 30;
			
			if (resSelect && fpsSelect) {
				const [width, height] = resSelect.value.split('x').map(Number);
				resolution = [width, height];
				fps = parseInt(fpsSelect.value);
			}
			
			// Select and start camera
			await API.selectCamera(index, resolution, fps);
			await API.startCamera();
			
			Utils.showNotification(`Camera started: ${resolution[0]}×${resolution[1]} @ ${fps} FPS`, 'success');
			
			// Update UI to show live feed
			const previewBox = document.querySelector(`[data-camera-index="${index}"] .preview-box`);
			if (previewBox) {
				previewBox.classList.remove('preview-stopped');
				previewBox.classList.add('preview-active');
				
				// Replace placeholder with live feed
				previewBox.innerHTML = `
					<img class="preview-feed" id="feed_${index}" src="/video_feed?t=${Date.now()}" alt="Camera Feed">
					<div class="preview-stats" style="display: flex;">
						<span id="preview_fps_${index}">-- FPS</span>
						<span class="stats-sep">|</span>
						<span id="preview_res_${index}">--</span>
					</div>
				`;
			}
			
			// Update button states
			this.updateCameraButtons(index, true);
			
			// Start preview stats
			this.startPreviewStats(index);
		} catch (error) {
			Utils.showNotification('Failed to start camera: ' + error.message, 'danger');
		}
	}
	
	static async stop(index) {
		try {
			// Stop camera
			await API.stopCamera();
			
			Utils.showNotification('Camera stopped', 'success');
			
			// Update UI to show placeholder
			const previewBox = document.querySelector(`[data-camera-index="${index}"] .preview-box`);
			if (previewBox) {
				previewBox.classList.remove('preview-active');
				previewBox.classList.add('preview-stopped');
				
				// Replace live feed with placeholder
				previewBox.innerHTML = `
					<div class="preview-placeholder">
						<div class="placeholder-icon">📹</div>
						<div class="placeholder-text">Camera Stopped</div>
					</div>
				`;
			}
			
			// Stop preview stats
			this.stopPreviewStats(index);
			
			// Update button states
			this.updateCameraButtons(index, false);
		} catch (error) {
			Utils.showNotification('Failed to stop camera: ' + error.message, 'danger');
		}
	}
	
	static startPreviewStats(index) {
		// Stop any existing interval
		if (this.previewStatsIntervals && this.previewStatsIntervals[index]) {
			clearInterval(this.previewStatsIntervals[index]);
		}
		
		if (!this.previewStatsIntervals) {
			this.previewStatsIntervals = {};
		}
		
		this.previewStatsIntervals[index] = setInterval(async () => {
			try {
				const response = await fetch('/stream_stats');
				const data = await response.json();
				
				const fpsEl = document.getElementById(`preview_fps_${index}`);
				const resEl = document.getElementById(`preview_res_${index}`);
				
				if (fpsEl) fpsEl.textContent = (data.fps || 0).toFixed(1) + ' FPS';
				if (resEl) resEl.textContent = `${data.width || 0}×${data.height || 0}`;
			} catch (error) {
				console.error('Failed to update preview stats:', error);
			}
		}, 1000);
	}
	
	static stopPreviewStats(index) {
		if (this.previewStatsIntervals && this.previewStatsIntervals[index]) {
			clearInterval(this.previewStatsIntervals[index]);
			delete this.previewStatsIntervals[index];
		}
	}
	
	static updateCameraButtons(index, isRunning) {
		const startBtn = document.getElementById(`startBtn_${index}`);
		const stopBtn = document.getElementById(`stopBtn_${index}`);
		const card = document.querySelector(`[data-camera-index="${index}"]`);
		
		if (startBtn) startBtn.disabled = isRunning;
		if (stopBtn) stopBtn.disabled = !isRunning;
		
		if (card) {
			if (isRunning) {
				card.classList.add('camera-running');
				if (!card.querySelector('.camera-status-badge')) {
					const badge = document.createElement('div');
					badge.className = 'camera-status-badge';
					badge.textContent = '⚫ Running';
					card.insertBefore(badge, card.firstChild);
				}
			} else {
				card.classList.remove('camera-running');
				const badge = card.querySelector('.camera-status-badge');
				if (badge) badge.remove();
			}
		}
	}
}

// Tracking Module
class TrackingModule {
    static async load() {
        try {
            const status = await API.getTrackingStatus();
            this.render(status);
        } catch (error) {
            Utils.showNotification('Failed to load tracking status', 'danger');
        }
    }
    
    static render(status) {
        const container = document.getElementById('trackingStatus');
        if (!container) return;
        
        const types = ['face_mesh', 'iris', 'hands', 'pose'];
        container.innerHTML = types.map(type => {
            const data = status[type] || {};
            return `
                <div class="card">
                    <div class="card-header">
                        <h4>${this.formatName(type)}</h4>
                        <div class="toggle-switch ${data.enabled ? 'active' : ''}" 
                             onclick="TrackingModule.toggle('${type}', ${!data.enabled})">
                        </div>
                    </div>
                    <div class="card-body">
                        <p><strong>FPS:</strong> ${(data.fps || 0).toFixed(1)}</p>
                        <p><strong>Detection:</strong> ${(data.detection_rate || 0).toFixed(1)}%</p>
                        <p><strong>Landmarks:</strong> ${data.landmark_count || 0}</p>
                    </div>
                </div>
            `;
        }).join('');
    }
    
    static async toggle(type, enabled) {
        try {
            await API.enableTracking({ [type]: enabled });
            this.load();
        } catch (error) {
            Utils.showNotification(error.message, 'danger');
        }
    }
    
    static formatName(type) {
        return type.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
    }
}

// Effects Module
class EffectsModule {
    static activeEffects = [];
    
    static async load() {
        try {
            const data = await API.listEffects();
            console.log('Effects data:', data);
            
            // Check if error in response
            if (data.error) {
                throw new Error(data.error.message || 'API returned error');
            }
            
            const active = await API.getActiveEffects();
            this.activeEffects = active.active_effects || [];
            this.render(data.categories || {});
            this.renderActive();
        } catch (error) {
            console.error('Effects load error:', error);
            const container = document.getElementById('effectsList');
            if (container) {
                container.innerHTML = `<p style="color: red; text-align: center; padding: 20px; font-size: 11px;">Error: ${error.message || 'Failed to load effects'}</p>`;
            }
            // Also update count to show error
            const countEl = document.getElementById('effectsCount');
            if (countEl) countEl.textContent = '0';
        }
    }
    
    static render(categories) {
        const container = document.getElementById('effectsList');
        if (!container) return;
        
        let html = '<div class="effects-grid">';
        for (const [category, effects] of Object.entries(categories)) {
            effects.forEach(effect => {
                const effectName = effect.name.replace('Effect', '');
                html += `
                    <div class="effect-card" onclick="EffectsModule.apply('${effect.name}')">
                        <div class="effect-name">${effectName}</div>
                        <div class="effect-category">${category}</div>
                    </div>
                `;
            });
        }
        html += '</div>';
        container.innerHTML = html;
        
        // Update count
        const count = Object.values(categories).reduce((sum, effects) => sum + effects.length, 0);
        const countEl = document.getElementById('effectsCount');
        if (countEl) countEl.textContent = count;
    }
    
    static renderActive() {
        const container = document.getElementById('activeEffects');
        if (!container) return;
        
        if (this.activeEffects.length === 0) {
            container.innerHTML = '<div class="empty-state"><p>No active effects</p></div>';
            return;
        }
        
        container.innerHTML = this.activeEffects.map(effect => `
            <div class="chain-item">
                <div class="chain-info">
                    <div class="chain-name">${effect.name}</div>
                    <div class="chain-params">${Object.keys(effect.parameters || {}).length} parameters</div>
                </div>
                <div class="chain-actions">
                    <button class="btn btn-sm btn-danger" onclick="EffectsModule.remove('${effect.name}')">Remove</button>
                </div>
            </div>
        `).join('');
    }
    
    static async apply(name) {
        try {
            await API.applyEffect(name);
            Utils.showNotification(`Applied ${name}`, 'success');
            this.load();
        } catch (error) {
            Utils.showNotification(error.message, 'danger');
        }
    }
    
    static async remove(name) {
        try {
            await API.removeEffect(name);
            Utils.showNotification(`Removed ${name}`, 'success');
            this.load();
        } catch (error) {
            Utils.showNotification(error.message, 'danger');
        }
    }
    
    static async clear() {
        try {
            await API.clearEffects();
            Utils.showNotification('All effects cleared', 'success');
            this.load();
        } catch (error) {
            Utils.showNotification(error.message, 'danger');
        }
    }
}

// Configuration Module
class ConfigModule {
    static currentConfig = {};
    
    static async load() {
        try {
            this.currentConfig = await API.getConfig();
            this.render();
        } catch (error) {
            Utils.showNotification('Failed to load configuration', 'danger');
        }
    }
    
    static render() {
        const container = document.getElementById('configForm');
        if (!container) return;
        
        container.innerHTML = `
            <div class="form-group">
                <label class="form-label">Camera Index</label>
                <input type="number" class="form-input" id="configCameraIndex" value="${this.currentConfig.camera_index || 0}">
            </div>
            <div class="form-group">
                <label class="form-label">Resolution Width</label>
                <input type="number" class="form-input" id="configWidth" value="${this.currentConfig.resolution?.[0] || 640}">
            </div>
            <div class="form-group">
                <label class="form-label">Resolution Height</label>
                <input type="number" class="form-input" id="configHeight" value="${this.currentConfig.resolution?.[1] || 480}">
            </div>
            <div class="form-group">
                <label class="form-label">Target FPS</label>
                <input type="number" class="form-input" id="configFps" value="${this.currentConfig.target_fps || 30}">
            </div>
            <button class="btn btn-primary" onclick="ConfigModule.save()">Save Configuration</button>
        `;
    }
    
    static async save() {
        try {
            const config = {
                camera_index: parseInt(document.getElementById('configCameraIndex').value),
                resolution: [
                    parseInt(document.getElementById('configWidth').value),
                    parseInt(document.getElementById('configHeight').value)
                ],
                target_fps: parseInt(document.getElementById('configFps').value)
            };
            
            await API.updateConfig(config);
            Utils.showNotification('Configuration saved', 'success');
            this.load();
        } catch (error) {
            Utils.showNotification(error.message, 'danger');
        }
    }
}

// Settings Module
class SettingsModule {
    static toggleExpand(headerElement) {
        const content = headerElement.nextElementSibling;
        const icon = headerElement.querySelector('.expand-icon');
        
        if (content && icon) {
            content.classList.toggle('collapsed');
            icon.textContent = content.classList.contains('collapsed') ? '▼' : '▲';
        }
    }
    
    static async loadLoggingConfig() {
        try {
            const response = await fetch('/api/logging/config');
            const config = await response.json();
            
            const masterToggle = document.getElementById('masterLogging');
            if (masterToggle) {
                masterToggle.checked = config.master_enabled !== false;
            }
            
            document.querySelectorAll('.log-category').forEach(toggle => {
                const category = toggle.dataset.category;
                if (config.categories && category in config.categories) {
                    toggle.checked = config.categories[category];
                }
                toggle.addEventListener('change', () => this.updateLoggingCategory());
            });
        } catch (error) {
            console.error('Failed to load logging config:', error);
        }
    }
    
    static initCustomSelects() {
        document.querySelectorAll('.custom-select').forEach(selectEl => {
            const trigger = selectEl.querySelector('.select-trigger');
            const options = selectEl.querySelector('.select-options');
            
            if (!trigger || !options) return;
            
            // Toggle dropdown
            trigger.addEventListener('click', (e) => {
                e.stopPropagation();
                
                // Close other dropdowns
                document.querySelectorAll('.custom-select.open').forEach(other => {
                    if (other !== selectEl) other.classList.remove('open');
                });
                
                selectEl.classList.toggle('open');
            });
            
            // Handle option selection
            options.querySelectorAll('.select-option').forEach(option => {
                option.addEventListener('click', (e) => {
                    e.stopPropagation();
                    
                    // Update selected state
                    options.querySelectorAll('.select-option').forEach(opt => 
                        opt.classList.remove('selected')
                    );
                    option.classList.add('selected');
                    
                    // Update trigger text
                    const span = trigger.querySelector('span');
                    if (span) span.textContent = option.textContent;
                    
                    // Store value
                    selectEl.dataset.value = option.dataset.value;
                    
                    // Close dropdown
                    selectEl.classList.remove('open');
                    
                    // Notify change
                    this.onSelectChange(selectEl.id, option.dataset.value);
                });
            });
        });
        
        // Close dropdowns when clicking outside
        document.addEventListener('click', () => {
            document.querySelectorAll('.custom-select.open').forEach(selectEl => {
                selectEl.classList.remove('open');
            });
        });
    }
    
    static onSelectChange(selectId, value) {
        console.log(`${selectId} changed to:`, value);
        // Store preferences (future implementation)
        // Will be used to configure camera settings
    }
    
    static async updateLoggingMaster() {
        try {
            const master = document.getElementById('masterLogging');
            const enabled = master ? master.checked : true;
            
            const categories = {};
            document.querySelectorAll('.log-category').forEach(toggle => {
                categories[toggle.dataset.category] = toggle.checked;
            });
            
            const response = await fetch('/api/logging/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    master_enabled: enabled,
                    categories
                })
            });
            
            if (!response.ok) {
                throw new Error('Failed to update logging config');
            }
            
            Utils.showNotification(
                enabled ? 'Logging enabled' : 'Logging disabled',
                'success'
            );
        } catch (error) {
            console.error('Failed to update master logging:', error);
            Utils.showNotification('Failed to update logging config', 'danger');
        }
    }
    
    static async updateLoggingCategory() {
        try {
            const master = document.getElementById('masterLogging');
            const masterEnabled = master ? master.checked : true;
            
            const categories = {};
            document.querySelectorAll('.log-category').forEach(toggle => {
                categories[toggle.dataset.category] = toggle.checked;
            });
            
            const response = await fetch('/api/logging/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    master_enabled: masterEnabled,
                    categories
                })
            });
            
            if (!response.ok) {
                throw new Error('Failed to update logging config');
            }
            
            Utils.showNotification('Logging config updated', 'success');
        } catch (error) {
            console.error('Failed to update logging category:', error);
            Utils.showNotification('Failed to update logging config', 'danger');
        }
    }
}

// Performance Module
class PerformanceModule {
    static currentConfig = {};
    
    static async load() {
        try {
            const response = await fetch('/api/performance/config');
            const data = await response.json();
            
            if (data.success) {
                this.currentConfig = data.config;
                this.updateUI();
            }
        } catch (error) {
            console.error('Failed to load performance config:', error);
        }
    }
    
    static updateUI() {
        // Update form controls
        const mpRes = document.getElementById('mediapipeResolution');
        if (mpRes) mpRes.value = this.currentConfig.mediapipe_max_width || 640;
        
        const previewFps = document.getElementById('previewFps');
        if (previewFps) {
            previewFps.value = this.currentConfig.preview_max_fps || 30;
            document.getElementById('previewFpsValue').textContent = previewFps.value;
        }
        
        const previewQuality = document.getElementById('previewQuality');
        if (previewQuality) {
            previewQuality.value = this.currentConfig.preview_quality || 85;
            document.getElementById('previewQualityValue').textContent = previewQuality.value;
        }
        
        const previewScale = document.getElementById('previewScale');
        if (previewScale) {
            previewScale.value = this.currentConfig.preview_scale || 1.0;
            const percent = Math.round(previewScale.value * 100);
            document.getElementById('previewScaleValue').textContent = percent + '%';
        }
        
        const tripleBuffer = document.getElementById('tripleBuffer');
        if (tripleBuffer) tripleBuffer.checked = this.currentConfig.enable_triple_buffer !== false;
        
        const queueSize = document.getElementById('queueSize');
        if (queueSize) {
            queueSize.value = this.currentConfig.max_queue_size || 3;
            document.getElementById('queueSizeValue').textContent = queueSize.value;
        }
    }
    
    static updateSliderValue(slider, valueId, isPercent = false) {
        const valueEl = document.getElementById(valueId);
        if (valueEl) {
            if (isPercent) {
                const percent = Math.round(slider.value * 100);
                valueEl.textContent = percent + '%';
            } else {
                valueEl.textContent = slider.value;
            }
        }
    }
    
    static async updateSettings() {
        try {
            const config = {
                mediapipe_max_width: parseInt(document.getElementById('mediapipeResolution').value),
                preview_max_fps: parseInt(document.getElementById('previewFps').value),
                preview_quality: parseInt(document.getElementById('previewQuality').value),
                preview_scale: parseFloat(document.getElementById('previewScale').value),
                enable_triple_buffer: document.getElementById('tripleBuffer').checked,
                max_queue_size: parseInt(document.getElementById('queueSize').value)
            };
            
            const response = await fetch('/api/performance/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(config)
            });
            
            const data = await response.json();
            
            if (data.success) {
                this.currentConfig = data.config;
                Utils.showNotification('Performance settings updated', 'success');
                
                // Update preset label to "Custom"
                const presetLabel = document.getElementById('perfPreset');
                if (presetLabel) presetLabel.textContent = 'Custom';
            } else {
                throw new Error(data.error || 'Failed to update settings');
            }
        } catch (error) {
            console.error('Failed to update performance settings:', error);
            Utils.showNotification('Failed to update settings: ' + error.message, 'danger');
        }
    }
    
    static async applyPreset(presetName) {
        try {
            const response = await fetch(`/api/performance/preset/${presetName}`, {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                this.currentConfig = data.config;
                this.updateUI();
                
                // Update preset label
                const presetLabel = document.getElementById('perfPreset');
                const presets = {
                    'maximum_quality': 'Max Quality',
                    'balanced': 'Balanced',
                    'maximum_performance': 'Max Speed',
                    'low_bandwidth': 'Low Bandwidth'
                };
                if (presetLabel) presetLabel.textContent = presets[presetName] || presetName;
                
                Utils.showNotification(`Applied ${presets[presetName]} preset`, 'success');
            } else {
                throw new Error(data.error || 'Failed to apply preset');
            }
        } catch (error) {
            console.error('Failed to apply preset:', error);
            Utils.showNotification('Failed to apply preset: ' + error.message, 'danger');
        }
    }
}
