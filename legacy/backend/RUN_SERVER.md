# LenzForge V2 - Web UI Quick Start

## Running the Server

### 1. Install Flask Dependencies (First Time Only)

```powershell
.\setup_v2\04-Install-Flask-Dependencies.ps1
```

This installs:
- Flask 3.0.0
- Flask-CORS 4.0.0
- Flask-SocketIO 5.3.5
- python-socketio 5.10.0
- psutil 5.9.6

### 2. Deploy Backend (If Not Already Done)

```powershell
.\setup_v2\06-Deploy-Backend.ps1
```

This copies backend_v2 to workspace/cpp-viewer/

### 3. Start the Web Server

```powershell
.\setup_v2\07-Run-Web-Server.ps1
```

### 4. Access the UI

Open your browser to: **http://localhost:5000**

---

## Features

### Dashboard
- Real-time FPS, uptime, memory, CPU stats
- Pipeline controls (Start/Stop/Restart)
- Auto-updates every 2 seconds

### Camera Control
- List all available cameras
- Select and configure cameras
- Real-time camera status

### Tracking Control
- Enable/disable face mesh, iris, hands, pose
- View detection rates and FPS
- Toggle switches for each tracking type

### Effects Studio
- Browse 47 effects by category
- Apply effects with one click
- Manage active effects chain
- Clear all effects

### Configuration
- Adjust camera settings
- Set resolution and FPS
- Save/load configurations

---

## Keyboard Shortcuts

- **Theme Toggle**: Click sun/moon icon in header
- **Navigation**: Click sidebar items

---

## API Endpoints (30 Total)

All accessible at `http://localhost:5000/api/...`

### System (5)
- GET `/status` - System status
- GET `/info` - System information  
- POST `/start` - Start pipeline
- POST `/stop` - Stop pipeline
- POST `/restart` - Restart pipeline

### Camera (4)
- GET `/camera/list` - List cameras
- GET `/camera/current` - Current camera
- POST `/camera/select` - Select camera
- POST `/camera/configure` - Configure camera

### Tracking (6)
- GET `/tracking/status` - Tracking status
- POST `/tracking/enable` - Enable tracking
- GET `/tracking/landmarks` - Get landmarks
- POST `/tracking/configure` - Configure tracking
- GET `/tracking/statistics` - Get statistics
- POST `/tracking/reset` - Reset tracking

### Effects (8)
- GET `/effects/list` - List all effects
- GET `/effects/active` - Active effects
- POST `/effects/apply` - Apply effect
- POST `/effects/configure` - Configure effect
- POST `/effects/enable` - Enable/disable effect
- POST `/effects/remove` - Remove effect
- POST `/effects/clear` - Clear all effects
- POST `/effects/chain` - Set effect chain

### Configuration (4)
- GET `/config` - Get configuration
- POST `/config` - Update configuration
- POST `/config/save` - Save configuration
- POST `/config/load` - Load configuration

### Export (3)
- GET `/export/frame` - Export frame
- GET `/export/landmarks` - Export landmarks
- POST `/export/recording/start` - Start recording
- POST `/export/recording/stop` - Stop recording
- GET `/export/recording/status` - Recording status

---

## Troubleshooting

### Port Already in Use
```powershell
# Kill process on port 5000
netstat -ano | findstr :5000
taskkill /PID <PID> /F
```

### Module Not Found
```powershell
# Ensure you're in the correct directory
cd d:\temp\_LenzForge
```

### Can't Connect
1. Verify server is running
2. Check firewall settings
3. Try http://127.0.0.1:5000 instead

---

## Development

### File Structure
```
setup_v2/assets/backend_v2/server/
├── __init__.py
├── app.py                  # Flask application
├── routes/                 # API routes (6 modules)
├── static/
│   ├── css/
│   │   ├── main.css       # Main styles
│   │   └── components.css # UI components
│   └── js/
│       ├── api.js         # API client
│       ├── utils.js       # Utilities
│       ├── modules.js     # Feature modules
│       └── app.js         # Main app
└── templates/
    └── index.html          # Web UI
```

### Modular Architecture
- **api.js**: API communication layer
- **utils.js**: Helper functions
- **modules.js**: Camera, Tracking, Effects, Config modules
- **app.js**: Main application controller

---

## Next Steps

1. **Test the UI**: Access http://localhost:5000
2. **Integrate with Pipeline**: Connect to actual backend_v2 pipeline
3. **Add WebSocket**: Real-time video streaming
4. **Performance Monitor**: Add graphs and charts
5. **Save Presets**: Effect chains and configurations

---

**Status**: ✅ UI Complete and Ready to Test!
