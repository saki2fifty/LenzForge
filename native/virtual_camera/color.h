#pragma once
#include <cstdint>
namespace lenzcam {
// Even dimensions; caller owns and reuses tightly packed input/output buffers.
inline void rgba_to_nv12(const uint8_t* rgba, uint8_t* output, uint32_t frame_width, uint32_t frame_height) {
    // BT.601 limited range, matching the video shader and advertised MF type.
    auto* y_plane = output;
    auto* uv_plane = y_plane + frame_width * frame_height;
    for (uint32_t y = 0; y < frame_height; y += 2) {
        for (uint32_t x = 0; x < frame_width; x += 2) {
            int r = 0, g = 0, b = 0;
            for (uint32_t dy = 0; dy < 2; ++dy) {
                for (uint32_t dx = 0; dx < 2; ++dx) {
                    uint32_t pos = (y + dy) * frame_width + x + dx;
                    const auto* p = rgba + pos * 4;
                    y_plane[pos] = static_cast<uint8_t>(((66*p[0] + 129*p[1] + 25*p[2] + 128) >> 8) + 16);
                    r += p[0]; g += p[1]; b += p[2];
                }
            }
            r = (r + 2) >> 2; g = (g + 2) >> 2; b = (b + 2) >> 2;
            uint32_t uv = (y / 2) * frame_width + x;
            uv_plane[uv] = static_cast<uint8_t>(((-38*r - 74*g + 112*b + 128) >> 8) + 128);
            uv_plane[uv+1] = static_cast<uint8_t>(((112*r - 94*g - 18*b + 128) >> 8) + 128);
        }
    }
}
}
