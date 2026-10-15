# LenzForge

**Real-time AR Face Tracking System**

A high-performance augmented reality face tracking system built with Python, C++, MediaPipe, and Godot Engine.

---

## ✨ Features

- **Real-time Face Tracking** - 60 FPS face mesh detection with MediaPipe
- **High-Performance Backend** - Python + C++ hybrid architecture
- **Godot Integration** - AR visualization with GDExtension
- **Shared Memory IPC** - Zero-copy video and landmark streaming
- **Virtual Camera** - Output AR effects to any application
- **Web Interface** - Real-time preview and controls
- **Portable Setup** - Complete automated installation system

---

## 🚀 Quick Start

### Prerequisites
- Windows 10/11 (64-bit)
- 10GB free disk space
- Webcam or USB camera

### Installation

1. **Clone the repository**
```powershell
git clone https://github.com/yourusername/LenzForge.git
cd LenzForge
```

2. **Run automated setup**
```powershell
cd setup_v2
.\000-Setup.ps1
```

The setup will install:
- Python 3.11 (portable)
- MinGW C++ compiler
- Godot Engine 4.3
- MediaPipe & OpenCV
- All dependencies

Setup takes 10-15 minutes and requires ~5GB download.

3. **Start the backend**
```powershell
.\Start-Backend.ps1
```

4. **Open web interface**
- Navigate to http://localhost:5000
- Select your camera
- Start tracking!

---

## 🎮 Godot AR Viewer

Launch the Godot AR viewer:

```powershell
.\buildtools\godot\Godot_v4.3-stable_win64.exe workspace_v2\LenzForge-AR\project.godot
```

Press **F5** to run the AR visualization scene.

---

## 📁 Project Structure

```
LenzForge/
├── setup_v2/              # Automated setup system
│   ├── 000-Setup.ps1      # Main setup script
│   ├── assets/            # Source files for deployment
│   └── ...
├── workspace_v2/
│   ├── LenzForge-Vision/  # Python backend
│   │   └── backend_v2/    # Flask server + MediaPipe
│   └── LenzForge-AR/      # Godot AR viewer
│       └── gdextension/   # C++ video/landmark readers
├── buildtools/            # Portable dev tools
│   ├── python/
│   ├── mingw/
│   └── godot/
├── logs/                  # System logs
├── Start-Backend.ps1      # Launch Flask server
└── LICENSE                # MIT License
```

---

## 🛠️ Development

### Backend Development

```powershell
# Redeploy backend after changes
cd setup_v2
.\030-Deploy-Backend.ps1

# Restart backend
cd ..
.\Start-Backend.ps1
```

### Godot Development

```powershell
# Redeploy Godot project
cd setup_v2
.\081-Deploy-Godot-Project.ps1

# Rebuild GDExtension
.\083-Build-LenzForge-GDExtension.ps1
```

### Verify Installation

```powershell
cd setup_v2
.\099-Verify-Installation.ps1
```

---

## 🎯 Architecture

### Pipeline Overview

```
Camera (USB)
    ↓
MSMF Extension (C++) → NV12 Format
    ↓
VID1 Ring Buffer (Shared Memory)
    ↓
MediaPipe Worker (Python) → Face Mesh
    ↓
LMK1 Ring Buffer (478 Landmarks)
    ↓
├─→ Flask Server → Web Preview (MJPEG)
└─→ Godot GDExtension → AR Viewer
```

### Key Technologies

- **Python 3.11** - Backend & MediaPipe integration
- **C++17** - High-performance capture & IPC
- **Godot 4.3** - AR visualization engine
- **MediaPipe** - Face mesh detection
- **Flask** - Web interface & API
- **Shared Memory** - Zero-copy IPC (QPC-synchronized)

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/AmazingFeature`)
3. **Commit your changes** (`git commit -m 'Add some AmazingFeature'`)
4. **Push to the branch** (`git push origin feature/AmazingFeature`)
5. **Open a Pull Request**

### Areas for Contribution
- Additional AR effects
- Performance optimizations
- Linux/macOS support
- Documentation improvements
- Bug fixes

---

## 🐛 Issues & Support

- **Found a bug?** Open an issue on GitHub
- **Need help?** Check the [documentation](docs/)
- **Want to discuss?** Open a discussion on GitHub

---

## 📊 Performance

- **Face Detection:** 60 FPS @ 1080p
- **MediaPipe Processing:** 15-20ms per frame
- **VID1 Ring Buffer:** 30 FPS (zero-copy)
- **Latency:** ~33ms end-to-end
- **Memory:** ~500MB total

### System Requirements
- **Minimum:** Intel i5-7th gen, 8GB RAM, USB 3.0 camera
- **Recommended:** Intel i7-10th gen, 16GB RAM, USB 3.0 camera
- **Best:** Intel i9/Ryzen 9, 32GB RAM, high-quality USB camera

---

## 📝 License

LenzForge is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

```
Copyright (c) 2025 saki2fifty
```

This means you can:
- ✅ Use it commercially
- ✅ Modify it
- ✅ Distribute it
- ✅ Use it privately

**Just include the copyright notice!**

---

## 🙏 Acknowledgments

- **MediaPipe** - Google's face mesh solution
- **Godot Engine** - Open-source game engine
- **OpenCV** - Computer vision library
- **MinGW-w64** - Windows C++ compiler
- **Flask** - Python web framework

---

## 🗺️ Roadmap

### Current Version (v1.0)
- ✅ Face mesh tracking (478 landmarks)
- ✅ Real-time video streaming
- ✅ Godot AR viewer
- ✅ Web interface

### Upcoming Features
- 🔄 Hand tracking integration
- 🔄 Body pose estimation
- 🔄 Multi-face tracking
- 🔄 GPU acceleration
- 🔄 Linux support
- 🔄 MacOS support

---

*Star ⭐ this repo if you find it useful!*
