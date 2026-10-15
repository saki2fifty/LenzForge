#include "god1_writer.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/viewport_texture.hpp>


#include <cstring>
#include <algorithm>

using namespace godot;

GOD1Writer::GOD1Writer() :
#ifdef _WIN32
	file_mapping(nullptr),
	mapped_memory(nullptr),
#endif
	header_ptr(nullptr),
	buffer_base(nullptr),
	is_initialized(false),
	frame_width(0),
	frame_height(0),
	pixel_format(GOD1_FORMAT_RGB24),
	frame_counter(0) {
}

GOD1Writer::~GOD1Writer() {
	shutdown();
}

void GOD1Writer::_bind_methods() {
	// Initialization methods
	ClassDB::bind_method(D_METHOD("init", "width", "height", "format"), &GOD1Writer::init, DEFVAL(GOD1_FORMAT_RGB24));
	ClassDB::bind_method(D_METHOD("shutdown"), &GOD1Writer::shutdown);
	ClassDB::bind_method(D_METHOD("is_ready"), &GOD1Writer::is_ready);

	// Frame writing methods
	ClassDB::bind_method(D_METHOD("write_frame", "image"), &GOD1Writer::write_frame);
	ClassDB::bind_method(D_METHOD("write_frame_from_viewport", "viewport_node"), &GOD1Writer::write_frame_from_viewport);

	// Status query methods
	ClassDB::bind_method(D_METHOD("get_frame_width"), &GOD1Writer::get_frame_width);
	ClassDB::bind_method(D_METHOD("get_frame_height"), &GOD1Writer::get_frame_height);
	ClassDB::bind_method(D_METHOD("get_pixel_format"), &GOD1Writer::get_pixel_format);
	ClassDB::bind_method(D_METHOD("get_total_frames"), &GOD1Writer::get_total_frames);
	ClassDB::bind_method(D_METHOD("get_dropped_frames"), &GOD1Writer::get_dropped_frames);
	ClassDB::bind_method(D_METHOD("get_stats"), &GOD1Writer::get_stats);

	// Constants
	BIND_ENUM_CONSTANT(GOD1_FORMAT_RGB24);
	BIND_ENUM_CONSTANT(GOD1_FORMAT_NV12);
}

bool GOD1Writer::init(int width, int height, int format) {
	if (is_initialized) {
		UtilityFunctions::print("[GOD1Writer] Already initialized");
		return false;
	}

	if (width <= 0 || height <= 0) {
		UtilityFunctions::print("[GOD1Writer] Invalid dimensions: ", width, "x", height);
		return false;
	}

	if (format != GOD1_FORMAT_RGB24 && format != GOD1_FORMAT_NV12) {
		UtilityFunctions::print("[GOD1Writer] Invalid format: ", format);
		return false;
	}

	frame_width = width;
	frame_height = height;
	pixel_format = format;
	frame_counter = 0;

	// Calculate memory requirements
	size_t frame_data_size;
	if (pixel_format == GOD1_FORMAT_RGB24) {
		frame_data_size = width * height * 3;  // RGB24: 3 bytes per pixel
	} else {
		frame_data_size = width * height * 3 / 2;  // NV12: 1.5 bytes per pixel
	}

	size_t slot_size = GOD1_SLOT_HEADER_SIZE + frame_data_size;
	size_t total_size = GOD1_HEADER_SIZE + (slot_size * GOD1_NUM_SLOTS);

	// Create shared memory
	if (!create_shared_memory("Global\\LenzForge_GodotOutput", total_size)) {
		UtilityFunctions::print("[GOD1Writer] Failed to create shared memory");
		return false;
	}

	// Initialize header
	initialize_header();

	is_initialized = true;

	UtilityFunctions::print("[GOD1Writer] Initialized");
	UtilityFunctions::print("  Resolution: ", width, "x", height);
	UtilityFunctions::print("  Format: ", (format == GOD1_FORMAT_RGB24 ? "RGB24" : "NV12"));
	UtilityFunctions::print("  Slot Size: ", slot_size, " bytes");
	UtilityFunctions::print("  Total Size: ", total_size, " bytes (", total_size / 1024 / 1024, " MB)");

	return true;
}

void GOD1Writer::shutdown() {
	if (!is_initialized) {
		return;
	}

#ifdef _WIN32
	if (mapped_memory) {
		UnmapViewOfFile(mapped_memory);
		mapped_memory = nullptr;
	}

	if (file_mapping) {
		CloseHandle(file_mapping);
		file_mapping = nullptr;
	}
#endif

	header_ptr = nullptr;
	buffer_base = nullptr;
	is_initialized = false;

	UtilityFunctions::print("[GOD1Writer] Shutdown complete");
}

bool GOD1Writer::create_shared_memory(const std::string& name, size_t size) {
#ifdef _WIN32
	// Create file mapping (shared memory)
	file_mapping = CreateFileMappingA(
		INVALID_HANDLE_VALUE,  // Use paging file
		nullptr,               // Security attributes
		PAGE_READWRITE,        // Read/write access
		(DWORD)(size >> 32),   // High-order DWORD of size
		(DWORD)(size & 0xFFFFFFFF),  // Low-order DWORD of size
		name.c_str()           // Name of mapping object
	);

	if (!file_mapping) {
		UtilityFunctions::print("[GOD1Writer] CreateFileMapping failed: ", (int64_t)GetLastError());
		return false;
	}

	// Map view of file
	mapped_memory = MapViewOfFile(
		file_mapping,
		FILE_MAP_ALL_ACCESS,
		0,  // High-order DWORD of offset
		0,  // Low-order DWORD of offset
		0   // Map entire file
	);

	if (!mapped_memory) {
		UtilityFunctions::print("[GOD1Writer] MapViewOfFile failed: ", (int64_t)GetLastError());
		CloseHandle(file_mapping);
		file_mapping = nullptr;
		return false;
	}

	// Set pointers
	buffer_base = static_cast<uint8_t*>(mapped_memory);
	header_ptr = reinterpret_cast<GOD1Header*>(buffer_base);

	// Zero out memory
	std::memset(mapped_memory, 0, size);

	return true;
#else
	UtilityFunctions::print("[GOD1Writer] Shared memory only supported on Windows");
	return false;
#endif
}

void GOD1Writer::initialize_header() {
	if (!header_ptr) {
		return;
	}

	// Set magic number
	std::memcpy(header_ptr->magic, "GOD1\0\0\0\0", 8);

	// Set basic info
	header_ptr->version = GOD1_VERSION;
	header_ptr->frame_width = frame_width;
	header_ptr->frame_height = frame_height;
	header_ptr->format = pixel_format;
	header_ptr->num_slots = GOD1_NUM_SLOTS;

	// Calculate slot size
	size_t frame_data_size;
	if (pixel_format == GOD1_FORMAT_RGB24) {
		frame_data_size = frame_width * frame_height * 3;
	} else {
		frame_data_size = frame_width * frame_height * 3 / 2;
	}
	header_ptr->slot_size = GOD1_SLOT_HEADER_SIZE + frame_data_size;

	// Initialize atomic vars
	header_ptr->write_index.store(0, std::memory_order_release);
	header_ptr->total_frames.store(0, std::memory_order_release);
	header_ptr->dropped_frames.store(0, std::memory_order_release);
	header_ptr->read_index.store(0, std::memory_order_release);
	header_ptr->total_reads.store(0, std::memory_order_release);

	// Clear performance metrics
	header_ptr->avg_write_time_us = 0;
	header_ptr->max_write_time_us = 0;

	// Clear padding
	std::memset(header_ptr->padding, 0, sizeof(header_ptr->padding));
}

uint64_t GOD1Writer::get_qpc_timestamp() {
#ifdef _WIN32
	LARGE_INTEGER qpc;
	QueryPerformanceCounter(&qpc);
	return qpc.QuadPart;
#else
	return 0;
#endif
}

void GOD1Writer::update_performance_stats(uint64_t write_time_us) {
	write_times_us.push_back(write_time_us);

	// Keep last 100 samples
	if (write_times_us.size() > 100) {
		write_times_us.erase(write_times_us.begin());
	}

	// Calculate average
	uint64_t sum = 0;
	for (uint64_t time : write_times_us) {
		sum += time;
	}
	header_ptr->avg_write_time_us = sum / write_times_us.size();

	// Update max
	header_ptr->max_write_time_us = std::max(header_ptr->max_write_time_us, write_time_us);
}

PackedByteArray GOD1Writer::convert_rgba_to_rgb24(const PackedByteArray& rgba_data) {
	int pixel_count = frame_width * frame_height;
	PackedByteArray rgb_data;
	rgb_data.resize(pixel_count * 3);

	const uint8_t* rgba_ptr = rgba_data.ptr();
	uint8_t* rgb_ptr = rgb_data.ptrw();

	for (int i = 0; i < pixel_count; i++) {
		rgb_ptr[i * 3 + 0] = rgba_ptr[i * 4 + 0];  // R
		rgb_ptr[i * 3 + 1] = rgba_ptr[i * 4 + 1];  // G
		rgb_ptr[i * 3 + 2] = rgba_ptr[i * 4 + 2];  // B
		// Alpha channel discarded
	}

	return rgb_data;
}

bool GOD1Writer::write_frame(const Ref<Image>& image) {
	if (!is_initialized) {
		return false;
	}

	if (image.is_null()) {
		return false;
	}

	auto write_start = std::chrono::high_resolution_clock::now();

	// Verify image dimensions match
	if (image->get_width() != (int)frame_width || image->get_height() != (int)frame_height) {
		UtilityFunctions::print("[GOD1Writer] Image dimensions mismatch: ",
			image->get_width(), "x", image->get_height(), " vs ",
			frame_width, "x", frame_height);
		return false;
	}

	// Get current write slot
	uint32_t write_idx = header_ptr->write_index.load(std::memory_order_acquire);
	uint32_t slot_offset = GOD1_HEADER_SIZE + (write_idx * header_ptr->slot_size);

	// Get slot pointers
	uint8_t* slot_ptr = buffer_base + slot_offset;
	GOD1SlotHeader* slot_header = reinterpret_cast<GOD1SlotHeader*>(slot_ptr);
	uint8_t* slot_data = slot_ptr + GOD1_SLOT_HEADER_SIZE;

	// Clear flags to indicate write in progress
	slot_header->flags = 0;

	// Get image data
	PackedByteArray image_data = image->get_data();

	// Convert format if needed
	PackedByteArray frame_data;
	if (pixel_format == GOD1_FORMAT_RGB24) {
		// Image is RGBA, convert to RGB24
		if (image->get_format() == Image::FORMAT_RGBA8) {
			frame_data = convert_rgba_to_rgb24(image_data);
		} else {
			// Wrong format
			UtilityFunctions::print("[GOD1Writer] Unsupported image format: ", image->get_format());
			return false;
		}
	} else {
		// NV12 format - not yet implemented
		UtilityFunctions::print("[GOD1Writer] NV12 format not yet implemented");
		return false;
	}

	// Write frame data to slot
	const uint8_t* frame_ptr = frame_data.ptr();
	std::memcpy(slot_data, frame_ptr, frame_data.size());

	// Update slot header
	slot_header->frame_id = frame_counter++;
	slot_header->timestamp_qpc = get_qpc_timestamp();
	slot_header->data_size = frame_data.size();
	slot_header->write_timestamp = get_qpc_timestamp();

	// Set flags to indicate frame is valid and complete
	slot_header->flags = GOD1_FLAG_VALID | GOD1_FLAG_COMPLETE;

	// Move to next slot
	uint32_t next_write_idx = (write_idx + 1) % GOD1_NUM_SLOTS;
	header_ptr->write_index.store(next_write_idx, std::memory_order_release);

	// Update frame counter
	header_ptr->total_frames.fetch_add(1, std::memory_order_release);

	// Update performance stats
	auto write_end = std::chrono::high_resolution_clock::now();
	auto write_duration = std::chrono::duration_cast<std::chrono::microseconds>(write_end - write_start);
	update_performance_stats(write_duration.count());

	return true;
}

bool GOD1Writer::write_frame_from_viewport(Node* viewport_node) {
	if (!is_initialized) {
		return false;
	}

	if (!viewport_node) {
		return false;
	}

	// Cast to Viewport
	Viewport* viewport = Object::cast_to<Viewport>(viewport_node);
	if (!viewport) {
		UtilityFunctions::print("[GOD1Writer] Node is not a Viewport");
		return false;
	}

	// Get viewport texture
	Ref<ViewportTexture> vp_texture = viewport->get_texture();
	if (vp_texture.is_null()) {
		UtilityFunctions::print("[GOD1Writer] Failed to get viewport texture");
		return false;
	}

	// Get image from texture
	Ref<Image> image = vp_texture->get_image();
	if (image.is_null()) {
		UtilityFunctions::print("[GOD1Writer] Failed to get image from viewport texture");
		return false;
	}

	// Write the frame
	return write_frame(image);
}

uint64_t GOD1Writer::get_total_frames() const {
	if (!is_initialized || !header_ptr) {
		return 0;
	}
	return header_ptr->total_frames.load(std::memory_order_acquire);
}

uint64_t GOD1Writer::get_dropped_frames() const {
	if (!is_initialized || !header_ptr) {
		return 0;
	}
	return header_ptr->dropped_frames.load(std::memory_order_acquire);
}

Dictionary GOD1Writer::get_stats() const {
	Dictionary stats;

	if (!is_initialized || !header_ptr) {
		stats["initialized"] = false;
		return stats;
	}

	stats["initialized"] = true;
	stats["frame_width"] = frame_width;
	stats["frame_height"] = frame_height;
	stats["pixel_format"] = pixel_format == GOD1_FORMAT_RGB24 ? "RGB24" : "NV12";
	stats["total_frames"] = (int64_t)header_ptr->total_frames.load(std::memory_order_acquire);
	stats["dropped_frames"] = (int64_t)header_ptr->dropped_frames.load(std::memory_order_acquire);
	stats["write_index"] = (int)header_ptr->write_index.load(std::memory_order_acquire);
	stats["read_index"] = (int)header_ptr->read_index.load(std::memory_order_acquire);
	stats["avg_write_time_us"] = (int64_t)header_ptr->avg_write_time_us;
	stats["max_write_time_us"] = (int64_t)header_ptr->max_write_time_us;
	stats["avg_write_time_ms"] = header_ptr->avg_write_time_us / 1000.0;
	stats["max_write_time_ms"] = header_ptr->max_write_time_us / 1000.0;

	return stats;
}
