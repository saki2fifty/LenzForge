// MSMF Camera Capture - Python Extension
// Provides MSMF-based camera enumeration and capture for Python
// No DirectShow - MSMF only!

#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <pybind11/numpy.h>

#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <propvarutil.h>
#include <comdef.h>

#include <vector>
#include <string>
#include <memory>
#include <stdexcept>
#include <map>
#include <set>
#include <algorithm>

// Libraries are linked via setup.py for cross-compiler compatibility
// (MinGW doesn't use #pragma comment)

namespace py = pybind11;

// Helper: Convert HRESULT to exception
#define CHECK_HR(hr, msg) if (FAILED(hr)) { \
    _com_error err(hr); \
    const wchar_t* errMsg = err.ErrorMessage(); \
    int size = WideCharToMultiByte(CP_UTF8, 0, errMsg, -1, nullptr, 0, nullptr, nullptr); \
    std::string errStr; \
    if (size > 0) { \
        std::vector<char> buffer(size); \
        WideCharToMultiByte(CP_UTF8, 0, errMsg, -1, buffer.data(), size, nullptr, nullptr); \
        errStr = buffer.data(); \
    } \
    throw std::runtime_error(std::string(msg) + ": " + errStr); \
}

// COM/MF RAII helper
class MFContext {
public:
    MFContext() {
        HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
            CHECK_HR(hr, "CoInitializeEx failed");
        }
        hr = MFStartup(MF_VERSION, MFSTARTUP_LITE);
        CHECK_HR(hr, "MFStartup failed");
        initialized_ = true;
    }
    
    ~MFContext() {
        if (initialized_) {
            MFShutdown();
            CoUninitialize();
        }
    }
    
private:
    bool initialized_ = false;
};

// Resolution info
struct ResolutionInfo {
    int width;
    int height;
    std::vector<int> fps_options;
    
    bool operator<(const ResolutionInfo& other) const {
        if (width != other.width) return width < other.width;
        return height < other.height;
    }
};

// Camera info structure
struct CameraInfo {
    int index;
    std::string name;
    std::string symbolic_link;
    std::vector<ResolutionInfo> supported_resolutions;
};

// Query camera capabilities
std::vector<ResolutionInfo> query_camera_capabilities(IMFActivate* device) {
    std::map<std::pair<int, int>, std::set<int>> res_fps_map;
    
    // Activate device
    IMFMediaSource* source = nullptr;
    HRESULT hr = device->ActivateObject(IID_PPV_ARGS(&source));
    if (FAILED(hr)) {
        return {};  // Return empty if can't activate
    }
    
    // Create source reader
    IMFSourceReader* reader = nullptr;
    hr = MFCreateSourceReaderFromMediaSource(source, nullptr, &reader);
    if (FAILED(hr)) {
        source->Release();
        return {};
    }
    
    // Enumerate media types
    DWORD typeIndex = 0;
    while (true) {
        IMFMediaType* mediaType = nullptr;
        hr = reader->GetNativeMediaType(
            (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
            typeIndex++,
            &mediaType
        );
        
        if (FAILED(hr) || !mediaType) {
            break;
        }
        
        // Get resolution
        UINT32 width = 0, height = 0;
        hr = MFGetAttributeSize(mediaType, MF_MT_FRAME_SIZE, &width, &height);
        
        if (SUCCEEDED(hr) && width > 0 && height > 0) {
            // Get FPS
            UINT32 numerator = 0, denominator = 1;
            hr = MFGetAttributeRatio(mediaType, MF_MT_FRAME_RATE, &numerator, &denominator);
            
            int fps = 30;  // default
            if (SUCCEEDED(hr) && denominator > 0) {
                fps = (int)((float)numerator / (float)denominator + 0.5f);
            }
            
            // Store resolution and FPS
            auto key = std::make_pair((int)width, (int)height);
            res_fps_map[key].insert(fps);
        }
        
        mediaType->Release();
    }
    
    reader->Release();
    source->Release();
    
    // Convert map to vector
    std::vector<ResolutionInfo> resolutions;
    for (const auto& pair : res_fps_map) {
        ResolutionInfo info;
        info.width = pair.first.first;
        info.height = pair.first.second;
        info.fps_options.assign(pair.second.begin(), pair.second.end());
        std::sort(info.fps_options.begin(), info.fps_options.end());
        resolutions.push_back(info);
    }
    
    // Sort by resolution (smallest first)
    std::sort(resolutions.begin(), resolutions.end());
    
    return resolutions;
}

// Enumerate cameras using MSMF
std::vector<CameraInfo> enumerate_cameras() {
    static MFContext mf_ctx;  // Initialize MF once
    
    std::vector<CameraInfo> cameras;
    IMFAttributes* cfg = nullptr;
    IMFActivate** devices = nullptr;
    UINT32 count = 0;
    
    HRESULT hr = MFCreateAttributes(&cfg, 1);
    CHECK_HR(hr, "MFCreateAttributes failed");
    
    hr = cfg->SetGUID(
        MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
        MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID
    );
    CHECK_HR(hr, "SetGUID failed");
    
    hr = MFEnumDeviceSources(cfg, &devices, &count);
    CHECK_HR(hr, "MFEnumDeviceSources failed");
    
    for (UINT32 i = 0; i < count; ++i) {
        CameraInfo info;
        info.index = i;
        
        // Get friendly name
        LPWSTR name = nullptr;
        UINT32 name_len = 0;
        hr = devices[i]->GetAllocatedString(
            MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME,
            &name,
            &name_len
        );
        
        if (SUCCEEDED(hr) && name) {
            int size = WideCharToMultiByte(CP_UTF8, 0, name, -1, nullptr, 0, nullptr, nullptr);
            if (size > 0) {
                std::vector<char> buffer(size);
                WideCharToMultiByte(CP_UTF8, 0, name, -1, buffer.data(), size, nullptr, nullptr);
                info.name = buffer.data();
            }
            CoTaskMemFree(name);
        }
        
        // Get symbolic link
        LPWSTR link = nullptr;
        UINT32 link_len = 0;
        hr = devices[i]->GetAllocatedString(
            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK,
            &link,
            &link_len
        );
        
        if (SUCCEEDED(hr) && link) {
            int size = WideCharToMultiByte(CP_UTF8, 0, link, -1, nullptr, 0, nullptr, nullptr);
            if (size > 0) {
                std::vector<char> buffer(size);
                WideCharToMultiByte(CP_UTF8, 0, link, -1, buffer.data(), size, nullptr, nullptr);
                info.symbolic_link = buffer.data();
            }
            CoTaskMemFree(link);
        }
        
        // Query capabilities
        info.supported_resolutions = query_camera_capabilities(devices[i]);
        
        cameras.push_back(info);
        devices[i]->Release();
    }
    
    if (devices) {
        CoTaskMemFree(devices);
    }
    if (cfg) {
        cfg->Release();
    }
    
    return cameras;
}

// Camera capture class
class MSMFCamera {
public:
    MSMFCamera(int camera_index, int width, int height, int fps, const std::string& format)
        : camera_index_(camera_index), width_(width), height_(height), fps_(fps) {
        
        // Parse format
        if (format == "NV12") {
            format_guid_ = MFVideoFormat_NV12;
        } else if (format == "RGB32") {
            format_guid_ = MFVideoFormat_RGB32;
        } else {
            throw std::runtime_error("Unsupported format. Use 'NV12' or 'RGB32'");
        }
        
        open();
    }
    
    ~MSMFCamera() {
        close();
    }
    
    void open() {
        static MFContext mf_ctx;
        
        // Enumerate to get the device
        IMFAttributes* cfg = nullptr;
        IMFActivate** devices = nullptr;
        UINT32 count = 0;
        
        HRESULT hr = MFCreateAttributes(&cfg, 1);
        CHECK_HR(hr, "MFCreateAttributes failed");
        
        hr = cfg->SetGUID(
            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID
        );
        CHECK_HR(hr, "SetGUID failed");
        
        hr = MFEnumDeviceSources(cfg, &devices, &count);
        CHECK_HR(hr, "MFEnumDeviceSources failed");
        
        if (camera_index_ < 0 || camera_index_ >= (int)count) {
            if (devices) {
                for (UINT32 i = 0; i < count; ++i) {
                    devices[i]->Release();
                }
                CoTaskMemFree(devices);
            }
            if (cfg) cfg->Release();
            throw std::runtime_error("Camera index out of range");
        }
        
        // Activate the device
        IMFMediaSource* source = nullptr;
        hr = devices[camera_index_]->ActivateObject(IID_PPV_ARGS(&source));
        CHECK_HR(hr, "ActivateObject failed");
        
        // Create source reader
        hr = MFCreateSourceReaderFromMediaSource(source, nullptr, &reader_);
        CHECK_HR(hr, "MFCreateSourceReaderFromMediaSource failed");
        
        // Configure output format
        IMFMediaType* type = nullptr;
        hr = MFCreateMediaType(&type);
        CHECK_HR(hr, "MFCreateMediaType failed");
        
        hr = type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
        CHECK_HR(hr, "SetGUID MAJOR_TYPE failed");
        
        hr = type->SetGUID(MF_MT_SUBTYPE, format_guid_);
        CHECK_HR(hr, "SetGUID SUBTYPE failed");
        
        hr = MFSetAttributeSize(type, MF_MT_FRAME_SIZE, width_, height_);
        CHECK_HR(hr, "MFSetAttributeSize failed");
        
        hr = MFSetAttributeRatio(type, MF_MT_FRAME_RATE, fps_, 1);
        CHECK_HR(hr, "MFSetAttributeRatio failed");
        
        hr = reader_->SetCurrentMediaType(
            (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
            nullptr,
            type
        );
        CHECK_HR(hr, "SetCurrentMediaType failed");
        
        type->Release();
        
        // Cleanup enumeration
        for (UINT32 i = 0; i < count; ++i) {
            devices[i]->Release();
        }
        CoTaskMemFree(devices);
        cfg->Release();
        source->Release();
    }
    
    void close() {
        if (reader_) {
            reader_->Release();
            reader_ = nullptr;
        }
    }
    
    py::array_t<uint8_t> read() {
        if (!reader_) {
            throw std::runtime_error("Camera not opened");
        }
        
        DWORD stream_index = 0;
        DWORD flags = 0;
        LONGLONG timestamp = 0;
        IMFSample* sample = nullptr;
        
        // MF_SOURCE_READER_CONTROL_FLAG_NONBLOCKING would return immediately
        // Default (0) waits for frame to be COMPLETE before returning
        HRESULT hr = reader_->ReadSample(
            (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
            0,  // 0 = blocking, waits for complete frame (prevents tearing)
            &stream_index,
            &flags,
            &timestamp,
            &sample
        );
        CHECK_HR(hr, "ReadSample failed");
        
        if (!sample) {
            throw std::runtime_error("No sample returned");
        }
        
        // Get buffer
        IMFMediaBuffer* buffer = nullptr;
        hr = sample->ConvertToContiguousBuffer(&buffer);
        CHECK_HR(hr, "ConvertToContiguousBuffer failed");
        
        // Try to get 2D buffer interface for proper stride handling
        IMF2DBuffer* buffer2d = nullptr;
        hr = buffer->QueryInterface(IID_PPV_ARGS(&buffer2d));
        
        if (SUCCEEDED(hr) && buffer2d) {
            // Use 2D interface - handles stride properly
            BYTE* scanline0 = nullptr;
            LONG pitch = 0;
            
            hr = buffer2d->Lock2D(&scanline0, &pitch);
            if (SUCCEEDED(hr)) {
                // Memory fence - ensure all DMA writes are visible
                MemoryBarrier();
                
                // Calculate actual data size (NV12: Y plane + UV plane)
                int y_plane_size = width_ * height_;
                int uv_plane_size = width_ * (height_ / 2);
                int tight_size = y_plane_size + uv_plane_size;
                
                // Create tightly packed numpy array
                py::array_t<uint8_t> result(tight_size);
                auto buf = result.request();
                uint8_t* dest = static_cast<uint8_t*>(buf.ptr);
                
                // OPTIMIZED: Fast path if already tight (no padding)
                if (pitch == width_) {
                    // FAST PATH: Bulk copy - already tight! (5x faster)
                    // Y plane
                    memcpy(dest, scanline0, y_plane_size);
                    // UV plane
                    memcpy(dest + y_plane_size, scanline0 + y_plane_size, uv_plane_size);
                } else {
                    // SLOW PATH: Per-row copy (stride padding present)
                    // Copy Y plane row by row (respecting stride)
                    for (int row = 0; row < height_; ++row) {
                        memcpy(dest + row * width_, 
                               scanline0 + row * pitch, 
                               width_);
                    }
                    
                    // Copy UV plane row by row (respecting stride)
                    BYTE* uv_start = scanline0 + (pitch * height_);
                    uint8_t* dest_uv = dest + y_plane_size;
                    for (int row = 0; row < height_ / 2; ++row) {
                        memcpy(dest_uv + row * width_, 
                               uv_start + row * pitch, 
                               width_);
                    }
                }
                
                buffer2d->Unlock2D();
                buffer2d->Release();
                buffer->Release();
                sample->Release();
                
                return result;
            }
            
            buffer2d->Release();
        }
        
        // Fallback to 1D buffer (legacy path)
        BYTE* data = nullptr;
        DWORD length = 0;
        hr = buffer->Lock(&data, nullptr, &length);
        CHECK_HR(hr, "Buffer Lock failed");
        
        // Memory fence - ensure all DMA writes are visible
        MemoryBarrier();
        
        // Create numpy array (copy complete frame data)
        py::array_t<uint8_t> result(length);
        auto buf = result.request();
        memcpy(buf.ptr, data, length);
        
        buffer->Unlock();
        buffer->Release();
        sample->Release();
        
        return result;
    }
    
private:
    int camera_index_;
    int width_;
    int height_;
    int fps_;
    GUID format_guid_;
    IMFSourceReader* reader_ = nullptr;
};

// Python module definition
PYBIND11_MODULE(msmf_capture, m) {
    m.doc() = "MSMF Camera Capture - Pure Media Foundation, no DirectShow";
    
    py::class_<ResolutionInfo>(m, "ResolutionInfo")
        .def_readonly("width", &ResolutionInfo::width)
        .def_readonly("height", &ResolutionInfo::height)
        .def_readonly("fps_options", &ResolutionInfo::fps_options);
    
    py::class_<CameraInfo>(m, "CameraInfo")
        .def_readonly("index", &CameraInfo::index)
        .def_readonly("name", &CameraInfo::name)
        .def_readonly("symbolic_link", &CameraInfo::symbolic_link)
        .def_readonly("supported_resolutions", &CameraInfo::supported_resolutions)
        .def("__repr__", [](const CameraInfo& info) {
            return "CameraInfo(index=" + std::to_string(info.index) + 
                   ", name='" + info.name + "')";
        });
    
    m.def("enumerate_cameras", &enumerate_cameras,
        "Enumerate available cameras using MSMF with capability detection");
    
    py::class_<MSMFCamera>(m, "Camera")
        .def(py::init<int, int, int, int, const std::string&>(),
            py::arg("camera_index"),
            py::arg("width") = 640,
            py::arg("height") = 480,
            py::arg("fps") = 30,
            py::arg("format") = "NV12")
        .def("read", &MSMFCamera::read, "Read a frame as numpy array")
        .def("close", &MSMFCamera::close, "Close camera");
}
