#pragma once

#include <stdint.h>

#define VID1_MAGIC 0x31444956  // 'VID1' in little-endian
#define VID1_VERSION 1

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t magic;           // 'VID1' = 0x31444956
    uint32_t version;         // 1
    uint32_t slot_count;      // 8..12
    uint32_t slot_stride;     // calculated: slot header + Y + UV
    volatile uint32_t wr_seq; // Writer sequence number
    volatile uint32_t rd_seq; // Reader sequence number
    uint32_t w, h;            // Frame dimensions
    uint32_t y_stride;        // Y plane stride (bytes per row)
    uint32_t uv_stride;       // UV plane stride (bytes per row)
    uint64_t qpc_freq;        // QueryPerformanceFrequency
    uint32_t reserved[6];     // Must be 0
} VidHeader;

typedef struct {
    uint64_t ts_qpc;          // Capture timestamp (QPC ticks)
    uint32_t frame_id;        // Monotonic counter
    volatile uint32_t valid;  // 0→1 flip with release/acquire fences
    uint32_t reserved[2];     // Must be 0
    // Followed by:
    // uint8_t Y[y_stride * h];
    // uint8_t UV[uv_stride * (h/2)];
} VidSlotHeader;

// Helper macros
#define VID1_HEADER_SIZE 64
#define VID1_SLOT_HEADER_SIZE 32

#define VID1_SLOT_OFFSET(hdr, idx) \
    (VID1_HEADER_SIZE + (idx) * (hdr)->slot_stride)

#define VID1_SLOT_Y_OFFSET(hdr, idx) \
    (VID1_SLOT_OFFSET(hdr, idx) + VID1_SLOT_HEADER_SIZE)

#define VID1_SLOT_UV_OFFSET(hdr, idx) \
    (VID1_SLOT_Y_OFFSET(hdr, idx) + (hdr)->y_stride * (hdr)->h)

#ifdef __cplusplus
}
#endif
