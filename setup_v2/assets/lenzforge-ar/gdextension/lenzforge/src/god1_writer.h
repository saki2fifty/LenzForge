#ifndef GOD1_WRITER_H
#define GOD1_WRITER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <string>
#include <atomic>
#include <chrono>

#ifdef _WIN32
#include <windows.h>
#endif

namespace godot {

// GOD1 Protocol Constants
const uint32_t GOD1_MAGIC = 0x31444F47;  // "GOD1" in little endian
const uint32_t GOD1_VERSION = 1;
const uint32_t GOD1_HEADER_SIZE = 256;
const uint32_t GOD1_SLOT_HEADER_SIZE = 32;
const uint32_t GOD1_NUM_SLOTS = 8;

// Pixel format constants
const uint32_t GOD1_FORMAT_RGB24 = 0;
const uint32_t GOD1_FORMAT_NV12 = 1;

// Slot header flags
const uint32_t GOD1_FLAG_VALID = 0x01;
const uint32_t GOD1_FLAG_COMPLETE = 0x02;

// GOD1 Global Header (256 bytes)
#pragma pack(push, 1)
struct GOD1Header {
	char magic[8];               // "GOD1\0\0\0\0"
	uint32_t version;            // Protocol version (1)
	uint32_t frame_width;        // Frame width in pixels
	uint32_t frame_height;       // Frame height in pixels
	uint32_t format;             // Pixel format (0=RGB24, 1=NV12)
	uint32_t num_slots;          // Number of slots (8)
	uint32_t slot_size;          // Size of each slot in bytes
	
	// Writer state (Godot)
	std::atomic<uint32_t> write_index;    // Current write slot (0-7)
	std::atomic<uint64_t> total_frames;   // Total frames written
	std::atomic<uint64_t> dropped_frames; // Frames dropped (overwrite)
	
	// Reader state (Backend)
	std::atomic<uint32_t> read_index;     // Last read slot (0-7)
	std::atomic<uint64_t> total_reads;    // Total frames read
	
	// Performance metrics
	uint64_t avg_write_time_us;  // Average write time (microseconds)
	uint64_t max_write_time_us;  // Max write time (microseconds)
	
	uint8_t padding[184];        // Reserved for future use
};

// GOD1 Slot Header (32 bytes)
struct GOD1SlotHeader {
	uint64_t frame_id;           // Monotonic frame counter
	uint64_t timestamp_qpc;      // QueryPerformanceCounter timestamp
	uint32_t data_size;          // Actual frame data size in bytes
	uint32_t flags;              // Bit flags (VALID, COMPLETE)
	uint64_t write_timestamp;    // When write started (for diagnostics)
	uint8_t padding[8];          // Reserved
};
#pragma pack(pop)

class GOD1Writer : public RefCounted {
	GDCLASS(GOD1Writer, RefCounted);

private:
#ifdef _WIN32
	HANDLE file_mapping;
	void* mapped_memory;
#endif
	
	GOD1Header* header_ptr;
	uint8_t* buffer_base;
	bool is_initialized;
	
	uint32_t frame_width;
	uint32_t frame_height;
	uint32_t pixel_format;
	uint64_t frame_counter;
	
	// Performance tracking
	std::chrono::high_resolution_clock::time_point last_write_time;
	std::vector<uint64_t> write_times_us;
	
	// Helper methods
	bool create_shared_memory(const std::string& name, size_t size);
	void initialize_header();
	uint64_t get_qpc_timestamp();
	void update_performance_stats(uint64_t write_time_us);
	PackedByteArray convert_rgba_to_rgb24(const PackedByteArray& rgba_data);

protected:
	static void _bind_methods();

public:
	GOD1Writer();
	~GOD1Writer();
	
	// Initialization
	bool init(int width, int height, int format = GOD1_FORMAT_RGB24);
	void shutdown();
	bool is_ready() const { return is_initialized; }
	
	// Frame writing
	bool write_frame(const Ref<Image>& image);
	bool write_frame_from_viewport(Node* viewport_node);
	
	// Status queries
	int get_frame_width() const { return frame_width; }
	int get_frame_height() const { return frame_height; }
	int get_pixel_format() const { return pixel_format; }
	uint64_t get_total_frames() const;
	uint64_t get_dropped_frames() const;
	Dictionary get_stats() const;
};

} // namespace godot

#endif // GOD1_WRITER_H
