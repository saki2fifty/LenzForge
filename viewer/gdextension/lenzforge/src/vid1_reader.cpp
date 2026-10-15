#include "vid1_reader.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
#include <cstring>
#include <vector>
#include <limits>

namespace lenzforge {

VID1Reader::VID1Reader()
	: reading(false)
	, width(0)
	, height(0)
	, last_frame_id(0)
	, last_timestamp(0)
	, fps_timer(0.0)
	, fps_counter(0)
	, current_fps(0)
{
}

VID1Reader::~VID1Reader() {
	stop_reading();
}

void VID1Reader::_bind_methods() {
	godot::ClassDB::bind_method(godot::D_METHOD("start_reading"), &VID1Reader::start_reading, DEFVAL(godot::String("LenzForge_Video_NV12")));
	godot::ClassDB::bind_method(godot::D_METHOD("stop_reading"), &VID1Reader::stop_reading);
	godot::ClassDB::bind_method(godot::D_METHOD("is_reading"), &VID1Reader::is_reading);
	godot::ClassDB::bind_method(godot::D_METHOD("get_width"), &VID1Reader::get_width);
	godot::ClassDB::bind_method(godot::D_METHOD("get_height"), &VID1Reader::get_height);
	godot::ClassDB::bind_method(godot::D_METHOD("get_fps"), &VID1Reader::get_fps);
	godot::ClassDB::bind_method(godot::D_METHOD("get_timestamp"), &VID1Reader::get_timestamp);

	ADD_SIGNAL(godot::MethodInfo("frame_ready",
		godot::PropertyInfo(godot::Variant::OBJECT, "y_texture"),
		godot::PropertyInfo(godot::Variant::OBJECT, "uv_texture"),
		godot::PropertyInfo(godot::Variant::INT, "frame_id"),
		godot::PropertyInfo(godot::Variant::INT, "timestamp")));
}

void VID1Reader::_ready() {
	godot::UtilityFunctions::print("[VID1Reader] Ready");
}

void VID1Reader::_process(double delta) {
	if (!reading) {
		return;
	}

	read_latest_frame();

	fps_timer += delta;

	if (fps_timer >= 1.0) {
		current_fps = fps_counter;
		fps_counter = 0;
		fps_timer = 0.0;
	}
}

bool VID1Reader::start_reading(const godot::String &name) {
    mapping_name = name.utf8().get_data();
	if (reading) {
		godot::UtilityFunctions::print("[VID1Reader] Already reading");
		return true;
	}

	if (!open_shared_memory()) {
		godot::UtilityFunctions::print("[VID1Reader] Failed to open shared memory");
		return false;
	}

	reading = true;
	last_frame_id = std::numeric_limits<uint32_t>::max();
	fps_timer = 0.0;
	fps_counter = 0;
	current_fps = 0;

	godot::UtilityFunctions::print("[VID1Reader] Started reading at ", width, "x", height);
	return true;
}

void VID1Reader::stop_reading() {
	if (!reading) {
		return;
	}

	reading = false;
	memory.close();
	y_texture.unref();
	uv_texture.unref();

	godot::UtilityFunctions::print("[VID1Reader] Stopped reading");
}

bool VID1Reader::open_shared_memory() {
	if (!memory.open(mapping_name)) {
		return false;
	}

	const uint8_t* data = memory.data();
	const VidHeader* header = reinterpret_cast<const VidHeader*>(data);

	if (header->magic != VID1_MAGIC) {
		godot::UtilityFunctions::print("[VID1Reader] Invalid magic: ", header->magic);
		memory.close();
		return false;
	}

	if (header->version != VID1_VERSION) {
		godot::UtilityFunctions::print("[VID1Reader] Invalid version: ", header->version);
		memory.close();
		return false;
	}

	if (header->w == 0 || header->h == 0 || header->w > 3840 || header->h > 2160 ||
        header->w % 2 || header->h % 2) { memory.close(); return false; }
	width = header->w;
	height = header->h;

	godot::UtilityFunctions::print("[VID1Reader] Opened VID1 ring: ", width, "x", height,
	                               " (", header->slot_count, " slots)");
	return true;
}

void VID1Reader::read_latest_frame() {
    const uint8_t* data = memory.data();
    const auto* header = reinterpret_cast<const VidHeader*>(data);
    const uint32_t sequence = header->wr_seq;
    MemoryBarrier();
    if (!sequence || !header->slot_count || !header->qpc_freq) return;
    const size_t offset = VID1_HEADER_SIZE + size_t((sequence - 1) % header->slot_count) * header->slot_stride;
    const size_t bytes = size_t(header->y_stride) * height + size_t(header->uv_stride) * (height / 2);
    if (header->y_stride < uint32_t(width) || header->uv_stride < uint32_t(width) ||
        bytes + VID1_SLOT_HEADER_SIZE > header->slot_stride ||
        offset + VID1_SLOT_HEADER_SIZE + bytes > memory.size()) return;
    const auto* slot = reinterpret_cast<const VidSlotHeader*>(data + offset);
    if (!slot->valid || slot->frame_id == last_frame_id) return;
    const uint32_t frame_id = slot->frame_id;
    const uint64_t timestamp = slot->ts_qpc;
    // Snapshot before upload. A writer may wrap around while this reader is copying.
    std::vector<uint8_t> snapshot(bytes);
    std::memcpy(snapshot.data(), data + offset + VID1_SLOT_HEADER_SIZE, bytes);
    MemoryBarrier();
    if (!slot->valid || slot->frame_id != frame_id || header->wr_seq != sequence) return;
    create_nv12_textures(snapshot.data(), snapshot.data() + size_t(header->y_stride) * height,
                        width, height, header->y_stride, header->uv_stride);
    last_frame_id = frame_id;
    last_timestamp = (timestamp / header->qpc_freq) * 1000000ULL +
                     ((timestamp % header->qpc_freq) * 1000000ULL) / header->qpc_freq;
    ++fps_counter;
    emit_signal("frame_ready", y_texture, uv_texture, (int64_t)frame_id, (int64_t)last_timestamp);
}

void VID1Reader::create_nv12_textures(const uint8_t* y_data, const uint8_t* uv_data,
                                      int frame_width, int frame_height,
                                      int y_stride, int uv_stride) {
	// Create Y plane texture (R8 format - single channel)
	godot::PackedByteArray y_packed;
	y_packed.resize(frame_width * frame_height);
	uint8_t* y_ptr = y_packed.ptrw();

	// Copy Y plane row by row (respecting stride)
	for (int y = 0; y < frame_height; y++) {
		std::memcpy(y_ptr + y * frame_width,
		            y_data + y * y_stride,
		            frame_width);
	}

	godot::Ref<godot::Image> y_image = godot::Image::create_from_data(
		frame_width, frame_height, false, godot::Image::FORMAT_R8, y_packed);

	// Create UV plane texture (RG8 format - two channels, half resolution)
	int uv_width = frame_width / 2;
	int uv_height = frame_height / 2;
	godot::PackedByteArray uv_packed;
	uv_packed.resize(uv_width * uv_height * 2);
	uint8_t* uv_ptr = uv_packed.ptrw();

	// Copy UV plane row by row (respecting stride)
	for (int y = 0; y < uv_height; y++) {
		std::memcpy(uv_ptr + y * uv_width * 2,
		            uv_data + y * uv_stride,
		            uv_width * 2);
	}

	godot::Ref<godot::Image> uv_image = godot::Image::create_from_data(
		uv_width, uv_height, false, godot::Image::FORMAT_RG8, uv_packed);

	// Create or update textures
	if (y_texture.is_null()) {
		y_texture = godot::ImageTexture::create_from_image(y_image);
		uv_texture = godot::ImageTexture::create_from_image(uv_image);
	} else {
		y_texture->update(y_image);
		uv_texture->update(uv_image);
	}
}

} // namespace lenzforge
