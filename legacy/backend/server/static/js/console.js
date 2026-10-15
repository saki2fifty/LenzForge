// LenzForge V2 - Console System
class ConsoleManager {
	constructor() {
		this.logs = [];
		this.paused = false;
		this.compact = true;
		this.filters = {
			DEBUG: true,
			INFO: true,
			WARNING: true,
			ERROR: true
		};
		this.searchTerm = '';
		this.autoScroll = true;
		this.regexFilter = '';
		this.maxLogs = 5000;
		this.socket = null;
	}

	init() {
		this.setupUI();
		this.setupControls();
		this.loadRecent();
		this.connectWebSocket();
	}

	setupUI() {
		const consoleHTML = `
			<div class="console-panel" id="consolePanel">
				<div class="console-header">
					<h3>System Console</h3>
					<div class="console-controls">
						<button class="console-btn" id="consolePause" title="Pause/Resume">
							<span class="pause-icon">⏸️</span>
							<span class="resume-icon" style="display: none;">▶️</span>
						</button>
						<button class="console-btn" id="consoleCompact" title="Toggle Compact Mode">
							📦
						</button>
						<button class="console-btn" id="consoleClear" title="Clear Logs">
							🗑️
						</button>
						<button class="console-btn" id="consoleCopy" title="Copy Logs">
							📋
						</button>
						<input type="search" 
							   id="consoleSearch" 
							   class="console-search" 
							   placeholder="Search logs...">
					</div>
				</div>
				<div class="console-filters">
					<label class="filter-label">
						<input type="checkbox" checked data-level="DEBUG">
						<span class="level-badge level-debug">DEBUG</span>
					</label>
					<label class="filter-label">
						<input type="checkbox" checked data-level="INFO">
						<span class="level-badge level-info">INFO</span>
					</label>
					<label class="filter-label">
						<input type="checkbox" checked data-level="WARNING">
						<span class="level-badge level-warning">WARNING</span>
					</label>
					<label class="filter-label">
						<input type="checkbox" checked data-level="ERROR">
						<span class="level-badge level-error">ERROR</span>
					</label>
					<label class="filter-label" style="flex: 1; max-width: 200px;">
						<input type="text" 
							   id="regexFilter" 
							   class="console-search" 
							   placeholder="RegEx filter..."
							   style="width: 100%; padding: 4px 8px; font-size: 12px;">
					</label>
					<label class="filter-label">
						<input type="checkbox" id="autoScrollToggle" checked>
						<span>Auto-scroll</span>
					</label>
				</div>
				<div class="console-body" id="consoleOutput"></div>
				<div class="console-footer">
					<span id="consoleCount">0 logs</span>
					<span id="consoleFiltered"></span>
				</div>
			</div>
			<div class="performance-toggle glass-card" style="margin-top: 15px; padding: 15px;">
				<label style="display: flex; justify-content: space-between; align-items: center; cursor: pointer;">
					<div>
						<span style="font-size: 14px; font-weight: 500; color: var(--text-primary);">System Logging</span>
						<p style="margin: 4px 0 0 0; font-size: 12px; color: var(--text-muted);">
							Disable to save ~5-10% CPU resources
						</p>
					</div>
					<label class="switch">
						<input type="checkbox" id="loggingEnabledToggle" checked>
						<span class="slider"></span>
					</label>
				</label>
			</div>
		`;

		// Insert after tracking control card
		const cards = document.querySelectorAll('.glass-card');
		const trackingCard = Array.from(cards).find(card => 
			card.querySelector('.card-title')?.textContent.includes('Tracking Control')
		);
		if (trackingCard) {
			trackingCard.insertAdjacentHTML('afterend', consoleHTML);
		} else {
			// Fallback: insert at end of container
			document.querySelector('.container')?.insertAdjacentHTML('beforeend', consoleHTML);
		}
	}

	setupControls() {
		// Pause/Resume
		document.getElementById('consolePause').addEventListener('click', () => {
			this.paused = !this.paused;
			const pauseIcon = document.querySelector('.pause-icon');
			const resumeIcon = document.querySelector('.resume-icon');
			if (this.paused) {
				pauseIcon.style.display = 'none';
				resumeIcon.style.display = 'inline';
			} else {
				pauseIcon.style.display = 'inline';
				resumeIcon.style.display = 'none';
			}
		});

		// Compact mode
		document.getElementById('consoleCompact').addEventListener('click', () => {
			this.compact = !this.compact;
			document.getElementById('consoleOutput').classList.toggle('compact', this.compact);
			this.render();
		});

		// Clear logs
		document.getElementById('consoleClear').addEventListener('click', async () => {
			if (confirm('Clear all logs?')) {
				await API.clearLogs();
				this.logs = [];
				this.render();
			}
		});

		// Copy logs
		document.getElementById('consoleCopy').addEventListener('click', () => {
			const text = this.logs.map(log => 
				`[${log.timestamp}] ${log.level} [${log.module}] ${log.message}`
			).join('\n');
			navigator.clipboard.writeText(text);
			Utils.showNotification('Logs copied to clipboard', 'success');
		});

		// Search
		document.getElementById('consoleSearch').addEventListener('input', (e) => {
			this.searchTerm = e.target.value.toLowerCase();
			this.render();
		});

		// Filter checkboxes
		document.querySelectorAll('.console-filters input[data-level]').forEach(checkbox => {
			checkbox.addEventListener('change', (e) => {
				const level = e.target.dataset.level;
				this.filters[level] = e.target.checked;
				this.render();
			});
		});

		// RegEx filter
		document.getElementById('regexFilter').addEventListener('input', (e) => {
			this.regexFilter = e.target.value;
			this.render();
		});
		
		// Auto-scroll toggle
		document.getElementById('autoScrollToggle').addEventListener('change', (e) => {
			this.autoScroll = e.target.checked;
		});
		
		// Performance logging toggle
		document.getElementById('loggingEnabledToggle').addEventListener('change', async (e) => {
			const enabled = e.target.checked;
			try {
				await API.setLoggingEnabled(enabled);
				const message = enabled ? 
					'Logging enabled' : 
					'Logging disabled (~5-10% CPU saved)';
				Utils.showNotification(message, 'success');
			} catch (error) {
				Utils.showNotification('Failed to toggle logging', 'danger');
				e.target.checked = !enabled; // Revert on error
			}
		});
	}

	connectWebSocket() {
		// Connect to Socket.IO for real-time logs
		this.socket = io('/logs');
		
		this.socket.on('connect', () => {
			console.log('Console WebSocket connected');
		});

		this.socket.on('log', (data) => {
			this.addLog(data);
		});

		this.socket.on('disconnect', () => {
			console.log('Console WebSocket disconnected');
		});
	}

	async loadRecent() {
		try {
			const response = await API.getRecentLogs();
			this.logs = response.logs || [];
			this.render();
		} catch (error) {
			console.error('Failed to load recent logs:', error);
		}
	}

	addLog(log) {
		if (this.paused) return;

		this.logs.push(log);
		
		// Limit log buffer
		if (this.logs.length > this.maxLogs) {
			this.logs.shift();
		}

		this.render();
	}

	render() {
		const output = document.getElementById('consoleOutput');
		if (!output) return;

		// Filter logs
		const filtered = this.logs.filter(log => {
			// RegEx filter
			if (this.regexFilter) {
				try {
					const regex = new RegExp(this.regexFilter, 'i');
					const searchable = `${log.level} ${log.module} ${log.message}`;
					if (!regex.test(searchable)) return false;
				} catch (e) {
					// Invalid regex, fall back to string match
					const searchable = `${log.level} ${log.module} ${log.message}`.toLowerCase();
					if (!searchable.includes(this.regexFilter.toLowerCase())) return false;
				}
			}
			
			// Level filter
			if (!this.filters[log.level]) return false;
			
			// Search filter
			if (this.searchTerm) {
				const searchable = `${log.level} ${log.module} ${log.message}`.toLowerCase();
				if (!searchable.includes(this.searchTerm)) return false;
			}
			
			return true;
		});

		// Render logs
		const html = filtered.map(log => this.renderLogEntry(log)).join('');
		output.innerHTML = html || '<div class="empty-console">No logs to display</div>';

		// Auto-scroll to bottom
		if (this.autoScroll) {
			output.scrollTop = output.scrollHeight;
		}

		// Update footer
		document.getElementById('consoleCount').textContent = `${this.logs.length} logs`;
		if (filtered.length !== this.logs.length) {
			document.getElementById('consoleFiltered').textContent = 
				`(${filtered.length} shown)`;
		} else {
			document.getElementById('consoleFiltered').textContent = '';
		}
	}

	renderLogEntry(log) {
		const time = new Date(log.timestamp).toLocaleTimeString('en-US', {
			hour12: false,
			hour: '2-digit',
			minute: '2-digit',
			second: '2-digit',
			fractionalSecondDigits: 3
		});

		const levelClass = `log-level-${log.level.toLowerCase()}`;
		
		if (this.compact) {
			return `
				<div class="log-entry ${levelClass}">
					<span class="log-time">${time}</span>
					<span class="log-level">${log.level}</span>
					<span class="log-message">${this.escapeHtml(log.message)}</span>
				</div>
			`;
		} else {
			return `
				<div class="log-entry ${levelClass} expanded">
					<div class="log-meta">
						<span class="log-time">${time}</span>
						<span class="log-level">${log.level}</span>
						<span class="log-module">${log.module}</span>
					</div>
					<div class="log-message">${this.escapeHtml(log.message)}</div>
				</div>
			`;
		}
	}

	escapeHtml(text) {
		const div = document.createElement('div');
		div.textContent = text;
		return div.innerHTML;
	}
}

// Initialize console when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
	window.consoleManager = new ConsoleManager();
	window.consoleManager.init();
});
