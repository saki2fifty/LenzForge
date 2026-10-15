// List Media Foundation devices without activating them or acquiring a camera.
// The order is the same MFEnumDeviceSources order used by OpenCV CAP_MSMF.
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <iostream>
#include <string>

static std::string attribute(IMFActivate *device, REFGUID key) {
    wchar_t *value = nullptr;
    UINT32 length = 0;
    if (FAILED(device->GetAllocatedString(key, &value, &length))) return {};
    int size = WideCharToMultiByte(CP_UTF8, 0, value, length, nullptr, 0, nullptr, nullptr);
    std::string result(size, '\0');
    WideCharToMultiByte(CP_UTF8, 0, value, length, result.data(), size, nullptr, nullptr);
    CoTaskMemFree(value);
    return result;
}

static void json_string(const std::string &value) {
    const char *hex = "0123456789abcdef";
    std::cout << '"';
    for (unsigned char c : value) {
        if (c == '"' || c == '\\') std::cout << '\\' << c;
        else if (c < 32) std::cout << "\\u00" << hex[c >> 4] << hex[c & 15];
        else std::cout << c;
    }
    std::cout << '"';
}

int main() {
    HRESULT com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(com)) return 1;
    HRESULT startup = MFStartup(MF_VERSION, MFSTARTUP_LITE);
    HRESULT result = startup;
    IMFAttributes *attributes = nullptr;
    IMFActivate **devices = nullptr;
    UINT32 count = 0;
    if (SUCCEEDED(result)) result = MFCreateAttributes(&attributes, 1);
    if (SUCCEEDED(result)) result = attributes->SetGUID(
        MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE, MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
    if (SUCCEEDED(result)) result = MFEnumDeviceSources(attributes, &devices, &count);
    if (SUCCEEDED(result)) {
        std::cout << '[';
        for (UINT32 i = 0; i < count; ++i) {
            if (i) std::cout << ',';
            auto name = attribute(devices[i], MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME);
            std::cout << "{\"index\":" << i << ",\"name\":";
            json_string(name.empty() ? "Camera " + std::to_string(i) : name);
            std::cout << ",\"device_id\":";
            json_string(attribute(devices[i], MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK));
            std::cout << '}';
        }
        std::cout << "]\n";
    } else {
        std::cerr << "Media Foundation enumeration failed (0x" << std::hex
                  << static_cast<unsigned long>(result) << ")\n";
    }
    for (UINT32 i = 0; i < count; ++i) devices[i]->Release();
    CoTaskMemFree(devices);
    if (attributes) attributes->Release();
    if (SUCCEEDED(startup)) MFShutdown();
    CoUninitialize();
    return FAILED(result) ? 1 : 0;
}
