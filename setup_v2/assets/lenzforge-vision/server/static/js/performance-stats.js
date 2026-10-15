// Performance Stats Module - Real-time performance monitoring with graphs

class PerformanceStatsModule {
    static chart = null;
    static interval = null;
    static pollRate = 1000;
    static maxDataPoints = 60;
    static enabled = true;  // Performance monitoring enabled by default
    
    static init() {
        this.setupChart();
        this.setupToggle();
        if (this.enabled) {
            this.startPolling();
        }
    }
    
    static setupToggle() {
        const toggle = document.getElementById('perfMonitorToggle');
        if (toggle) {
            toggle.checked = this.enabled;
            toggle.addEventListener('change', (e) => {
                this.enabled = e.target.checked;
                if (this.enabled) {
                    console.log('[Performance] Monitoring enabled');
                    this.startPolling();
                } else {
                    console.log('[Performance] Monitoring disabled - stopping all polls');
                    this.stopPolling();
                    this.clearDisplay();
                }
            });
        }
    }
    
    static clearDisplay() {
        // Clear all stat displays
        const stats = ['CPU', 'Memory', 'BackendFPS', 'FrameTime', 'Latency', 'DropRate',
                      'ProcessMemory', 'Threads', 'MediaPipeFPS', 'LandmarkCount',
                      'VID1Seq', 'LMK1Seq'];
        stats.forEach(stat => {
            const elem = document.getElementById(`stat${stat}`);
            if (elem) elem.textContent = '--';
        });
        
        // Clear bars
        const bars = ['CPU', 'Memory', 'BackendFPS', 'FrameTime', 'Latency', 'DropRate'];
        bars.forEach(bar => {
            const elem = document.getElementById(`bar${bar}`);
            if (elem) elem.style.width = '0%';
        });
    }
    
    static setupChart() {
        const ctx = document.getElementById('performanceChart');
        if (!ctx) {
            console.error('Performance chart canvas not found');
            return;
        }
        
        this.chart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [
                    {
                        label: 'Backend FPS',
                        data: [],
                        borderColor: '#00f0ff',
                        backgroundColor: 'rgba(0, 240, 255, 0.1)',
                        borderWidth: 2,
                        tension: 0.4,
                        fill: true
                    },
                    {
                        label: 'CPU %',
                        data: [],
                        borderColor: '#b74fff',
                        backgroundColor: 'rgba(183, 79, 255, 0.1)',
                        borderWidth: 2,
                        tension: 0.4,
                        fill: true
                    },
                    {
                        label: 'Latency (ms)',
                        data: [],
                        borderColor: '#ff006e',
                        backgroundColor: 'rgba(255, 0, 110, 0.1)',
                        borderWidth: 2,
                        tension: 0.4,
                        fill: true,
                        yAxisID: 'y1'
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                animation: false,
                interaction: {
                    mode: 'index',
                    intersect: false
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                        labels: {
                            color: '#ffffff',
                            font: {
                                size: 11
                            }
                        }
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        titleColor: '#ffffff',
                        bodyColor: '#ffffff',
                        borderColor: 'rgba(255, 255, 255, 0.1)',
                        borderWidth: 1
                    }
                },
                scales: {
                    x: {
                        display: true,
                        grid: {
                            color: 'rgba(255, 255, 255, 0.1)'
                        },
                        ticks: {
                            color: '#ffffff',
                            font: {
                                size: 10
                            },
                            maxRotation: 0,
                            autoSkip: true,
                            maxTicksLimit: 10
                        }
                    },
                    y: {
                        type: 'linear',
                        display: true,
                        position: 'left',
                        beginAtZero: true,
                        max: 100,
                        grid: {
                            color: 'rgba(255, 255, 255, 0.1)'
                        },
                        ticks: {
                            color: '#ffffff',
                            font: {
                                size: 10
                            }
                        }
                    },
                    y1: {
                        type: 'linear',
                        display: true,
                        position: 'right',
                        beginAtZero: true,
                        grid: {
                            drawOnChartArea: false
                        },
                        ticks: {
                            color: '#ffffff',
                            font: {
                                size: 10
                            }
                        }
                    }
                }
            }
        });
    }
    
    static async updateStats() {
        if (!this.enabled) return;  // Don't poll if disabled
        
        try {
            // Fetch from all 4 specialized endpoints
            const [systemRes, cameraRes, mediapipeRes, ringbufferRes] = await Promise.all([
                fetch('/api/system/stats'),
                fetch('/api/camera/stats'), 
                fetch('/api/mediapipe/stats'),
                fetch('/api/ringbuffer/stats')
            ]);
            
            const systemData = await systemRes.json();
            const cameraData = await cameraRes.json();
            const mediapipeData = await mediapipeRes.json();
            const ringbufferData = await ringbufferRes.json();
            
            // Extract values with fallbacks
            const system = systemData.data || {};
            const camera = cameraData.data || {};
            const mediapipe = mediapipeData.data || {};
            const ringbuffer = ringbufferData.data || {};
            
            // System stats
            const cpu = system.cpu_percent || 0;
            const memory = system.memory_mb || 0;
            const processMemory = system.process_memory_mb || 0;
            const threads = system.process_threads || 0;
            
            // Camera stats
            const backendFPS = camera.fps || 0;
            const frameTime = camera.frame_time_ms || 0;
            const dropRate = camera.drop_rate_percent || 0;
            
            // MediaPipe stats
            const mediapipeFPS = mediapipe.processing_fps || 0;
            const landmarkCount = mediapipe.landmark_count || 0;
            const faceDetected = mediapipe.face_detected || false;
            
            // Ring buffer stats
            const vid1Seq = ringbuffer.vid1 ? ringbuffer.vid1.write_sequence : 0;
            const lmk1Seq = ringbuffer.lmk1 ? ringbuffer.lmk1.write_sequence : 0;
            
            // Estimated latency (frame time + processing time)
            const latency = frameTime + (mediapipe.processing_time_ms || 0);
            
            // Update stat boxes - Basic stats
            this.updateStatValue('statCPU', cpu.toFixed(1) + '%');
            this.updateStatValue('statMemory', memory.toFixed(0) + ' MB');
            this.updateStatValue('statBackendFPS', backendFPS.toFixed(1));
            this.updateStatValue('statFrameTime', frameTime.toFixed(1) + ' ms');
            this.updateStatValue('statLatency', latency.toFixed(0) + ' ms');
            this.updateStatValue('statDropRate', dropRate.toFixed(1) + '%');
            
            // Update stat boxes - Additional stats
            this.updateStatValue('statProcessMemory', processMemory.toFixed(0) + ' MB');
            this.updateStatValue('statThreads', threads.toString());
            this.updateStatValue('statMediaPipeFPS', mediapipeFPS.toFixed(1));
            this.updateStatValue('statLandmarkCount', landmarkCount.toString());
            this.updateStatValue('statFaceDetected', faceDetected ? 'Yes' : 'No');
            this.updateStatValue('statVID1Seq', vid1Seq.toString());
            this.updateStatValue('statLMK1Seq', lmk1Seq.toString());
            
            // Update progress bars
            this.updateBar('barCPU', cpu, 100);
            this.updateBar('barMemory', memory, 2048); // Max 2GB
            this.updateBar('barBackendFPS', backendFPS, 60);
            this.updateBar('barFrameTime', frameTime, 100);
            this.updateBar('barLatency', latency, 200);
            this.updateBar('barDropRate', dropRate, 100);
            
            // Update chart
            if (this.chart) {
                const timestamp = new Date().toLocaleTimeString('en-US', { 
                    hour12: false, 
                    hour: '2-digit', 
                    minute: '2-digit',
                    second: '2-digit'
                });
                
                this.chart.data.labels.push(timestamp);
                this.chart.data.datasets[0].data.push(backendFPS);
                this.chart.data.datasets[1].data.push(cpu);
                this.chart.data.datasets[2].data.push(latency);
                
                // Keep only last N points
                if (this.chart.data.labels.length > this.maxDataPoints) {
                    this.chart.data.labels.shift();
                    this.chart.data.datasets.forEach(ds => ds.data.shift());
                }
                
                this.chart.update('none'); // Update without animation
            }
            
        } catch (error) {
            console.error('Failed to update performance stats:', error);
        }
    }
    
    static updateStatValue(elementId, value) {
        const elem = document.getElementById(elementId);
        if (elem) elem.textContent = value;
    }
    
    static updateBar(barId, value, max) {
        const bar = document.getElementById(barId);
        if (!bar) return;
        
        const percentage = Math.min((value / max) * 100, 100);
        bar.style.width = percentage + '%';
        
        // Color coding
        if (percentage < 50) {
            bar.style.background = 'linear-gradient(90deg, #00ff88, #00cc6a)';
        } else if (percentage < 80) {
            bar.style.background = 'linear-gradient(90deg, #ffaa00, #ff8800)';
        } else {
            bar.style.background = 'linear-gradient(90deg, #ff3366, #cc0033)';
        }
    }
    
    static startPolling() {
        if (this.interval) {
            clearInterval(this.interval);
        }
        
        // Initial update
        this.updateStats();
        
        // Start polling
        this.interval = setInterval(() => {
            this.updateStats();
        }, this.pollRate);
    }
    
    static stopPolling() {
        if (this.interval) {
            clearInterval(this.interval);
            this.interval = null;
        }
    }
    
    static changePollRate(newRate) {
        this.pollRate = parseInt(newRate);
        console.log('Poll rate changed to:', this.pollRate, 'ms');
        this.startPolling();
    }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
    PerformanceStatsModule.init();
});
