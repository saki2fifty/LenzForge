# LenzForge V2 Documentation

**Complete documentation for the LenzForge AR tracking system.**

This documentation covers the v2 implementation built from scratch in October 2025.

---

## Documentation Structure

### Getting Started
- **[Quick Start Guide](QUICK_START.md)** - Get up and running in 10 minutes
- **[Installation Guide](INSTALLATION.md)** - Detailed setup instructions
- **[Configuration Guide](CONFIGURATION.md)** - Customize your setup

### System Documentation
- **[Architecture Overview](ARCHITECTURE.md)** - System design and components
- **[Backend Documentation](BACKEND.md)** - Python backend details
- **[IPC System](IPC_SYSTEM.md)** - Ring buffer communication
- **[Effects Library](EFFECTS.md)** - 47 effects reference
- **[GDExtension](GDEXTENSION.md)** - C++ reader implementation
- **[Godot Project](GODOT_PROJECT.md)** - Godot 4.2 integration

### Development
- **[Integration Guide](INTEGRATION.md)** - Connect components
- **[API Reference](API_REFERENCE.md)** - HTTP API endpoints
- **[Technical Specifications](TECHNICAL.md)** - Protocols and formats
- **[Performance Guide](PERFORMANCE.md)** - Optimization tips

### Reference
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues
- **[FAQ](FAQ.md)** - Frequently asked questions
- **[Changelog](CHANGELOG.md)** - Version history

---

## System Overview

### What is LenzForge V2?

LenzForge V2 is a high-performance AR face tracking system with:

- **Real-time Tracking**: 30 FPS with MediaPipe (Face, Iris, Hands, Pose)
- **Low-Latency IPC**: <5ms ring buffer communication
- **47 Effects**: Professional image processing library
- **Godot Integration**: C++ GDExtension for visualization
- **Production Ready**: Validated, documented, tested

### Key Features

1. **Multi-Modal Tracking**
   - Face Mesh: 478 landmarks with iris refinement
   - Iris: 10 landmarks (5 per eye)
   - Hands: 42 landmarks (21 per hand × 2)
   - Pose: 33 body landmarks

2. **Effects Library**
   - 10 categories, 47 effects, 147 parameters
   - Real-time capable (most <15ms @ 640×480)
   - Chaining support for complex pipelines

3. **IPC Performance**
   - Latency: <5ms end-to-end
   - Bandwidth: 5.56 MB/s (32x reduction)
   - Zero frame drops in validation

4. **Portable & Documented**
   - 100% self-contained in setup_v2/
   - Comprehensive documentation
   - All dependencies included

---

## Quick Links

### Most Common Tasks

**First Time Setup**:
```powershell
cd setup_v2
.\00-Setup.ps1
```

**Deploy Backend**:
```powershell
.\06-Deploy-Backend.ps1
```

**Build GDExtension**:
```powershell
.\20-Build-GDExtension.ps1
```

**Run Tests**:
```powershell
python test_backend_v2.py
```

---

## System Requirements

### Minimum
- Windows 10/11 (64-bit)
- Intel i5 or AMD Ryzen 5
- 8 GB RAM
- 2 GB free disk space
- Webcam (720p or better)

### Recommended
- Windows 11 (64-bit)
- Intel i7/i9 or AMD Ryzen 7/9
- 16 GB RAM
- SSD storage
- Webcam (1080p)
- Dedicated GPU (optional, for future)

---

## Project Structure

```
setup_v2/
├── docs/              # This documentation
├── assets/
│   ├── backend_v2/    # Python backend
│   ├── godot-extension/  # C++ GDExtension
│   └── godot-lenzforge/  # Godot project
└── *.ps1             # Setup scripts
```

---

## Support & Contributing

### Getting Help
1. Check [Troubleshooting](TROUBLESHOOTING.md)
2. Review [FAQ](FAQ.md)
3. Check documentation for your specific component

### Reporting Issues
Include:
- LenzForge version
- Windows version
- Error messages
- Steps to reproduce

---

## License

See LICENSE file in project root.

---

## Version

**Current Version**: 2.0.0
**Release Date**: October 25, 2025
**Status**: Production Ready

---

**Next**: Start with the [Quick Start Guide](QUICK_START.md) →
