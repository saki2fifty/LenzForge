#ifndef LENZFORGE_LMK1_HEADER_H
#define LENZFORGE_LMK1_HEADER_H

#include <cstdint>

namespace lenzforge {

#define LMK1_MAGIC 0x314B4D4C  // 'LMK1' in little-endian
#define LMK1_VERSION 2

struct LmkHeader {
	uint32_t magic;
	uint32_t version;
	uint32_t slot_count;
	uint32_t slot_stride;
	volatile uint32_t wr_seq;
	volatile uint32_t rd_seq;
	uint8_t coord_space;
	uint8_t reserved1[3];
	uint32_t src_w;
	uint32_t src_h;
	uint64_t qpc_freq;
	uint32_t graph_id;
	uint32_t streams_mask;
	uint32_t session_id;
	uint32_t reserved[3];
};

struct LmkSlotHeader {
	uint64_t ts_qpc;
	uint32_t frame_id;
	volatile uint32_t valid;
	uint32_t block_count;
	uint32_t reserved;
};

struct LmkBlockHeader {
	uint16_t stream_id;
	uint16_t elem_count;
	uint16_t elem_stride;
	uint16_t flags;
};

struct Landmark {
	float x, y, z;
};

constexpr size_t LMK1_HEADER_SIZE = 64;
constexpr size_t LMK1_SLOT_HEADER_SIZE = 32;  // FIXED: Python backend uses 32, not 24!
constexpr size_t LMK1_BLOCK_HEADER_SIZE = 8;

} // namespace lenzforge

#endif // LENZFORGE_LMK1_HEADER_H
