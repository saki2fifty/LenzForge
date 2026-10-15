#include "vid1_reader.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
#include <cstring>

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
	godot::ClassDB::bind_method(godot::D_METHOD("start_reading"), &VID1Reader::start_reading);
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
	fps_counter++;
	if (fps_timer >= 1.0) {
		current_fps = fps_counter;
		fps_counter = 0;
		fps_timer = 0.0;
	}
}

bool VID1Reader::start_reading() {
	if (reading) {
		godot::UtilityFunctions::print("[VID1Reader] Already reading");
		return true;
	}

	if (!open_shared_memory()) {
		godot::UtilityFunctions::print("[VID1Reader] Failed to open shared memory");
		return false;
	}

	reading = true;
	last_frame_id = 0;
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
	if (!memory.open("LenzForge_Video_NV12")) {
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

	width = header->w;
	height = header->h;

	godot::UtilityFunctions::print("[VID1Reader] Opened VID1 ring: ", width, "x", height, 
	                               " (", header->slot_count, " slots)");
	return true;
}

void VID1Reader::read_latest_frame() {
	const uint8_t* data = memory.data();
	const VidHeader* header = reinterpret_cast<const VidHeader*>(data);

	uint32_t wr_seq = header->wr_seq;
	if (wr_seq == 0) {
		return;
	}

	uint32_t slot_idx = (wr_seq - 1) % header->slot_count;
	size_t slot_offset = VID1_HEADER_SIZE + slot_idx * header->slot_stride;
	
	if (slot_offset + VID1_SLOT_HEADER_SIZE > memory.size()) {
		return;
	}

	const VidSlotHeader* slot = reinterpret_cast<const VidSlotHeader*>(data + slot_offset);

	if (slot->valid == 0) {
		return;
	}

	if (slot->frame_id == last_frame_id) {
		return;
	}

	size_t y_offset = slot_offset + VID1_SLOT_HEADER_SIZE;
	size_t uv_offset = y_offset + header->y_stride * header->h;
	
	if (uv_offset + header->uv_stride * (header->h / 2) > memory.size()) {
		return;
	}

	const uint8_t* y_data = data + y_offset;
	const uint8_t* uv_data = data + uv_offset;

	create_nv12_textures(y_data, uv_data, width, height,
	                     header->y_stride, header->uv_stride);

	last_frame_id = slot->frame_id;
	last_timestamp = slot->ts_qpc;
	
	emit_signal("frame_ready", y_texture, uv_texture, 
	            (int64_t)slot->frame_id, (int64_t)slot->ts_qpc);
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
