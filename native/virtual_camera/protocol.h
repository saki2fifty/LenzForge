#pragma once
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <cstdint>
#include <string>
#include <sddl.h>
#include <objbase.h>

namespace lenzcam {
// A fixed, versioned ABI shared by the user process and Windows Camera Frame Server.
// Neither side trusts lengths or pointers supplied through shared memory.
inline constexpr uint32_t width = 1280, height = 720;
inline constexpr uint32_t pixels = width * height, bytes = pixels * 3 / 2;
inline constexpr uint32_t magic = 0x3143464c; // LFC1
inline constexpr wchar_t clsid_text[] = L"{A7CBB740-1ED1-49F1-9444-90A2EAD037D6}";
inline constexpr GUID source_clsid = {0xa7cbb740,0x1ed1,0x49f1,{0x94,0x44,0x90,0xa2,0xea,0xd0,0x37,0xd6}};
inline constexpr GUID owner_sid_key = {0xd8fe0ac8,0x5fba,0x48b6,{0xa4,0x50,0x77,0x29,0x69,0x23,0xc1,0x31}};
inline constexpr GUID session_key = {0xb0caa337,0x8f45,0x4d47,{0xaa,0xda,0xd8,0x96,0x44,0xb1,0x59,0x20}};

struct alignas(64) Slot {
    volatile LONG64 sequence;
    uint64_t timestamp_ms;
    uint8_t padding[48];
    uint8_t nv12[bytes];
};
struct alignas(64) SharedFrames {
    uint32_t signature, version, frame_width, frame_height;
    volatile LONG published, producing;
    volatile LONG64 consumer_tick;
    GUID gpu_session;
    volatile LONG gpu_ready, gpu_published;
    volatile LONG gpu_error;
    uint8_t padding[4];
    Slot slots[3];
};
static_assert(offsetof(SharedFrames, slots) == 64);
static_assert(offsetof(Slot, nv12) == 64);
inline std::wstring mapping_name(const std::wstring& sid, const GUID& session) {
    wchar_t id[40]{};
    StringFromGUID2(session,id,40);
    return L"Global\\LenzForge.Camera." + sid + L"." + id;
}
inline std::wstring current_sid() {
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return {};
    DWORD length = 0;
    GetTokenInformation(token, TokenUser, nullptr, 0, &length);
    std::string storage(length, '\0');
    std::wstring result;
    if (GetTokenInformation(token, TokenUser, storage.data(), length, &length)) {
        wchar_t* text = nullptr;
        if (ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(storage.data())->User.Sid, &text)) {
            result = text;
            LocalFree(text);
        }
    }
    CloseHandle(token);
    return result;
}
inline bool valid(const SharedFrames* frames) {
    return frames && frames->signature == magic && frames->version == 1 &&
        frames->frame_width == width && frames->frame_height == height;
}
inline std::wstring texture_name(const std::wstring& sid, const GUID& session, int slot) {
    return mapping_name(sid,session) + L".Texture." + std::to_wstring(slot);
}

// Stable C ABI: the Godot extension uses MinGW; the camera uses the Windows SDK.
struct Status {
    uint32_t size = sizeof(Status);
    int32_t state = 0; // 0 stopped, 1 starting, 2 ready, 3 failed
    int32_t error = 0;
    uint32_t consumer = 0;
    uint64_t sent = 0, replaced = 0;
    double conversion_ms = 0;
    int32_t gpu = 0;
    int32_t gpu_error = 0;
};
using StartFn = void* (__cdecl*)();
using StopFn = void (__cdecl*)(void*);
using StatusFn = void (__cdecl*)(void*, Status*);
using SubmitFn = bool (__cdecl*)(void*, const uint8_t*, uint32_t);
using TextureFn = bool (__cdecl*)(void*, uint32_t);
using ResetTextureFn = void (__cdecl*)(void*);
}
