// Video Preview Module - Draggable embedded viewer with accurate FPS tracking

class VideoPreview {
	static container = null;
	static stream = null;
	static isDragging = false;
	static dragOffset = { x: 0, y: 0 };
	static currentSize = 'small';
	static statsInterval = null;
	static isLocked = false; // Locked when camera running
	static isHidden = false; // Toggle visibility
	
	// FPS Tracking
	static displayFPSCounter = { frames: 0, lastTime: performance.now(), fps: 0 };
	static feedFPS = 0;
	
	static async init() {
		this.container = document.getElementById('videoPreview');
		this.stream = document.getElementById('videoPreviewStream');
		
		if (!this.container || !this.stream) {
			console.error('Video preview elements not found');
			return;
		}
		
		// Make draggable
		this.setupDragging();
		
		// Toggle size on stream click
		this.stream.addEventListener('click', () => this.toggleSize());
		
		// Start FPS tracking
		this.startFPSTracking();
		
		// Check if camera is running on page load
		await this.checkAndRestoreOnPageLoad();
	}
	
	static async checkAndRestoreOnPageLoad() {
		const cameraActive = await this.checkCameraStatus();
		if (cameraActive) {
			// Restore saved state
			const state = this.loadState();
			if (state) {
				await this.restoreState(state);
			}
			// Always show if camera is running
			await this.show();
		}
	}
	
	static async checkCameraStatus() {
		try {
			const response = await fetch('/stream_stats');
			const data = await response.json();
			return data.active || false;
		} catch (error) {
			console.error('Failed to check camera status:', error);
			return false;
		}
	}
	
	static saveState() {
		const state = {
			visible: this.container && this.container.style.display !== 'none',
			hidden: this.isHidden,
			position: {
				left: this.container ? this.container.style.left : '',
				top: this.container ? this.container.style.top : '',
				right: this.container ? this.container.style.right : '',
				bottom: this.container ? this.container.style.bottom : ''
			},
			size: this.currentSize
		};
		localStorage.setItem('videoPreviewState', JSON.stringify(state));
	}
	
	static loadState() {
		const saved = localStorage.getItem('videoPreviewState');
		if (!saved) return null;
		try {
			return JSON.parse(saved);
		} catch (error) {
			console.error('Failed to parse saved state:', error);
			return null;
		}
	}
	
	static async restoreState(state) {
		if (!this.container) return;
		
		// Restore size
		if (state.size) {
			this.currentSize = state.size;
			this.container.className = `video-preview-container size-${state.size}`;
		}
		
		// Restore position
		if (state.position) {
			if (state.position.left) this.container.style.left = state.position.left;
			if (state.position.top) this.container.style.top = state.position.top;
			if (state.position.right) this.container.style.right = state.position.right;
			if (state.position.bottom) this.container.style.bottom = state.position.bottom;
		}
		
		// Restore visibility toggle state
		if (state.hidden) {
			this.isHidden = true;
			this.container.style.opacity = '0';
			this.container.style.pointerEvents = 'none';
		}
	}
	
	static lockVisibility(locked) {
		this.isLocked = locked;
		const closeBtn = this.container ? this.container.querySelector('.video-btn-close') : null;
		if (closeBtn) {
			closeBtn.disabled = locked;
			closeBtn.style.opacity = locked ? '0.5' : '1';
			closeBtn.style.cursor = locked ? 'not-allowed' : 'pointer';
			closeBtn.title = locked ? 'Stop camera to close' : 'Close';
		}
	}
	
	static async show() {
		if (!this.container) return;
		
		// Load saved state or use defaults
		const state = this.loadState();
		
		if (state && state.position && (state.position.left || state.position.right)) {
			// Use saved position
			if (state.position.left) this.container.style.left = state.position.left;
			if (state.position.top) this.container.style.top = state.position.top;
			if (state.position.right) this.container.style.right = state.position.right;
			if (state.position.bottom) this.container.style.bottom = state.position.bottom;
		} else {
			// Default position: bottom-right corner
			this.container.style.right = '20px';
			this.container.style.bottom = '20px';
			this.container.style.left = 'auto';
			this.container.style.top = 'auto';
		}
		
		// Restore or set initial size
		if (state && state.size) {
			this.currentSize = state.size;
		} else {
			this.currentSize = 'small';
		}
		this.container.className = `video-preview-container size-${this.currentSize}`;
		
		// Restore visibility toggle state
		if (state && state.hidden) {
			this.isHidden = true;
			this.container.style.opacity = '0';
			this.container.style.pointerEvents = 'none';
		} else {
			this.isHidden = false;
			this.container.style.opacity = '1';
			this.container.style.pointerEvents = 'auto';
		}
		
		// Load video feed
		this.stream.src = '/video_feed?t=' + Date.now();
		
		// Start stats updates
		this.startStatsUpdates();
		
		// Show container
		this.container.style.display = 'block';
		
		// Lock visibility (can't close while running)
		this.lockVisibility(true);
		
		// Save state
		this.saveState();
	}
	
	static hide() {
		if (!this.container) return;
		
		// Check if locked (camera running)
		if (this.isLocked) {
			console.log('Cannot close preview while camera is running');
			return;
		}
		
		this.container.style.display = 'none';
		this.stream.src = '';
		this.stopStatsUpdates();
		this.saveState();
	}
	
	static toggleVisibility() {
		if (!this.container) return;
		
		this.isHidden = !this.isHidden;
		
		if (this.isHidden) {
			// Hide preview (fade out)
			this.container.style.opacity = '0';
			this.container.style.pointerEvents = 'none';
		} else {
			// Show preview (fade in)
			this.container.style.opacity = '1';
			this.container.style.pointerEvents = 'auto';
		}
		
		// Update toggle button icon
		const toggleBtn = this.container.querySelector('.video-btn-toggle');
		if (toggleBtn) {
			toggleBtn.textContent = this.isHidden ? '👁️' : '🙈';
			toggleBtn.title = this.isHidden ? 'Show Preview' : 'Hide Preview';
		}
		
		this.saveState();
	}
	
	static toggleSize() {
		if (!this.container) return;
		
		if (this.currentSize === 'small') {
			this.currentSize = 'medium';
			this.container.className = 'video-preview-container size-medium';
		} else {
			this.currentSize = 'small';
			this.container.className = 'video-preview-container size-small';
		}
		
		this.saveState();
	}
	
	static setupDragging() {
		const header = this.container.querySelector('.video-preview-header');
		
		header.addEventListener('mousedown', (e) => {
			this.isDragging = true;
			
			const rect = this.container.getBoundingClientRect();
			this.dragOffset.x = e.clientX - rect.left;
			this.dragOffset.y = e.clientY - rect.top;
			
			this.container.style.cursor = 'grabbing';
		});
		
		document.addEventListener('mousemove', (e) => {
			if (!this.isDragging) return;
			
			e.preventDefault();
			
			let x = e.clientX - this.dragOffset.x;
			let y = e.clientY - this.dragOffset.y;
			
			// Keep within viewport
			const rect = this.container.getBoundingClientRect();
			const maxX = window.innerWidth - rect.width;
			const maxY = window.innerHeight - rect.height;
			
			x = Math.max(0, Math.min(x, maxX));
			y = Math.max(0, Math.min(y, maxY));
			
			this.container.style.left = x + 'px';
			this.container.style.top = y + 'px';
			this.container.style.right = 'auto';
			this.container.style.bottom = 'auto';
		});
		
		document.addEventListener('mouseup', () => {
			if (this.isDragging) {
				this.isDragging = false;
				this.container.style.cursor = 'move';
				this.saveState(); // Save position after drag
			}
		});
	}
	
	static startFPSTracking() {
		// Track display FPS using requestAnimationFrame
		const trackDisplayFPS = () => {
			const now = performance.now();
			this.displayFPSCounter.frames++;
			
			if (now - this.displayFPSCounter.lastTime >= 1000) {
				this.displayFPSCounter.fps = this.displayFPSCounter.frames;
				this.displayFPSCounter.frames = 0;
				this.displayFPSCounter.lastTime = now;
				
				// Update display
				const displayEl = document.getElementById('displayFPS');
				if (displayEl) {
					displayEl.textContent = this.displayFPSCounter.fps + ' FPS';
				}
			}
			
			requestAnimationFrame(trackDisplayFPS);
		};
		
		trackDisplayFPS();
	}
	
	static startStatsUpdates() {
		this.updateStats(); // Initial update
		
		this.statsInterval = setInterval(() => {
			this.updateStats();
		}, 1000);
	}
	
	static stopStatsUpdates() {
		if (this.statsInterval) {
			clearInterval(this.statsInterval);
			this.statsInterval = null;
		}
	}
	
	static async updateStats() {
		try {
			const response = await fetch('/stream_stats');
			const data = await response.json();
			
			// Update feed FPS
			const feedFPS = data.fps || 0;
			const feedEl = document.getElementById('feedFPS');
			if (feedEl) {
				feedEl.textContent = feedFPS.toFixed(1) + ' FPS';
			}
			
			// Update resolution
			const width = data.width || 0;
			const height = data.height || 0;
			const resEl = document.getElementById('videoResolution');
			if (resEl) {
				resEl.textContent = `${width}×${height}`;
			}
			
			// Update status indicator
			const statusDot = document.getElementById('videoPreviewStatus');
			const statusText = document.getElementById('videoPreviewStatusText');
			
			if (data.active) {
				if (statusDot) statusDot.className = 'video-status-dot active';
				if (statusText) statusText.textContent = 'Live';
			} else {
				if (statusDot) statusDot.className = 'video-status-dot';
				if (statusText) statusText.textContent = 'No Feed';
			}
			
		} catch (error) {
			console.error('Failed to update video stats:', error);
			const feedEl = document.getElementById('feedFPS');
			const resEl = document.getElementById('videoResolution');
			if (feedEl) feedEl.textContent = '-- FPS';
			if (resEl) resEl.textContent = '--';
		}
	}
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
	VideoPreview.init();
});
