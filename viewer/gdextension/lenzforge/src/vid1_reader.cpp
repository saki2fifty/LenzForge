#include "vid1_reader.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
#include <cstring>
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
	godot::ClassDB::bind_method(godot::D_METHOD("get_frame_age_ms"), &VID1Reader::get_frame_age_ms);
	godot::ClassDB::bind_method(godot::D_METHOD("get_upload_ms"), &VID1Reader::get_upload_ms);
	godot::ClassDB::bind_method(godot::D_METHOD("present_frame", "frame_id", "timestamp_us"), &VID1Reader::present_frame);
	godot::ClassDB::bind_method(godot::D_METHOD("set_frame_locked", "enabled"), &VID1Reader::set_frame_locked);
	godot::ClassDB::bind_method(godot::D_METHOD("is_frame_locked"), &VID1Reader::is_frame_locked);
	godot::ClassDB::bind_method(godot::D_METHOD("get_frame_id"), &VID1Reader::get_frame_id);
	ADD_SIGNAL(godot::MethodInfo("synchronization_lost"));

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

	if (frame_locked) {
		matched_age += delta;
		if (matched_age > .15) {
			frame_locked = false;
			emit_signal("synchronization_lost");
		}
	}
	if (!frame_locked) read_latest_frame();

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
	frame_locked = false;
	matched_age = 0;
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
	frame_locked = false;
	memory.close();
	y_texture.unref();
	uv_texture.unref();
	y_image.unref();
	uv_image.unref();
	last_timestamp = 0;

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
    upload_frame(offset);
}

bool VID1Reader::present_frame(int64_t frame_id, int64_t timestamp_us) {
    if (!reading || frame_id < 0 || uint64_t(frame_id) > UINT32_MAX || timestamp_us <= 0) return false;
    const auto* header = reinterpret_cast<const VidHeader*>(memory.data());
    if (!header->qpc_freq || !header->slot_count || header->slot_count > 128 || header->slot_stride < VID1_SLOT_HEADER_SIZE) return false;
    LARGE_INTEGER now, frequency;
    QueryPerformanceCounter(&now); QueryPerformanceFrequency(&frequency);
    const double age_us = double(now.QuadPart)*1000000.0/frequency.QuadPart - timestamp_us;
    if (age_us < -1000 || age_us > 150000 || (frame_locked && uint64_t(timestamp_us) < last_timestamp)) return false;
    // Reuse the producer's bounded history. Never queue video behind inference,
    // guess a pose for a newer frame, or upload a mismatched frame on failure.
    for (uint32_t i=0; i<header->slot_count; ++i) {
        const size_t offset = VID1_HEADER_SIZE + size_t(i)*header->slot_stride;
        if (offset + VID1_SLOT_HEADER_SIZE > memory.size()) return false;
        const auto* slot = reinterpret_cast<const VidSlotHeader*>(memory.data()+offset);
        if (!slot->valid || slot->frame_id != uint32_t(frame_id)) continue;
        if (!upload_frame(offset,frame_id,uint64_t(timestamp_us))) return false;
        frame_locked = true; matched_age = 0;
        return true;
    }
    return false;
}

bool VID1Reader::upload_frame(size_t offset, int64_t expected_id, uint64_t expected_timestamp) {
    const uint8_t* data = memory.data();
    const auto* header = reinterpret_cast<const VidHeader*>(data);
    if (!header->qpc_freq) return false;
    const size_t bytes = size_t(header->y_stride) * height + size_t(header->uv_stride) * (height / 2);
    if (header->y_stride < uint32_t(width) || header->uv_stride < uint32_t(width) ||
        bytes + VID1_SLOT_HEADER_SIZE > header->slot_stride ||
        offset + VID1_SLOT_HEADER_SIZE + bytes > memory.size()) return false;
    const auto* slot = reinterpret_cast<const VidSlotHeader*>(data + offset);
    if (!slot->valid) return false;
    MemoryBarrier();
    const uint32_t frame_id = slot->frame_id;
    const uint64_t timestamp = slot->ts_qpc;
    const uint64_t timestamp_us = (timestamp / header->qpc_freq) * 1000000ULL +
                                 ((timestamp % header->qpc_freq) * 1000000ULL) / header->qpc_freq;
    if (expected_id >= 0 && (frame_id != uint32_t(expected_id) || timestamp_us != expected_timestamp)) return false;
    if (frame_id == last_frame_id && timestamp_us == last_timestamp) return expected_id >= 0;
    LARGE_INTEGER started, finished, frequency;
    QueryPerformanceCounter(&started);
    QueryPerformanceFrequency(&frequency);
    // Snapshot directly into the packed upload planes. This removes the full
    // intermediate frame allocation/copy. Strided producers remain supported.
    const auto* source_y = data + offset + VID1_SLOT_HEADER_SIZE;
    const auto* source_uv = source_y + size_t(header->y_stride) * height;
    // Images retain these arrays. Fresh arrays avoid copying last frame's
    // pixels through copy-on-write before overwriting them with the new frame.
    godot::PackedByteArray y_packed, uv_packed;
    y_packed.resize(width * height);
    uv_packed.resize(width * height / 2);
    uint8_t* dest_y = y_packed.ptrw();
    uint8_t* dest_uv = uv_packed.ptrw();
    if (header->y_stride == uint32_t(width)) std::memcpy(dest_y, source_y, width * height);
    else for (int row = 0; row < height; ++row)
        std::memcpy(dest_y + row * width, source_y + row * header->y_stride, width);
    if (header->uv_stride == uint32_t(width)) std::memcpy(dest_uv, source_uv, width * height / 2);
    else for (int row = 0; row < height / 2; ++row)
        std::memcpy(dest_uv + row * width, source_uv + row * header->uv_stride, width);
    MemoryBarrier();
    // A newer publication in another slot does not invalidate this snapshot.
    if (!slot->valid || slot->frame_id != frame_id || slot->ts_qpc != timestamp) return false;
    if (y_image.is_null()) { y_image.instantiate(); uv_image.instantiate(); }
    y_image->set_data(width, height, false, godot::Image::FORMAT_R8, y_packed);
    uv_image->set_data(width / 2, height / 2, false, godot::Image::FORMAT_RG8, uv_packed);
    if (y_texture.is_null()) {
        y_texture = godot::ImageTexture::create_from_image(y_image);
        uv_texture = godot::ImageTexture::create_from_image(uv_image);
    } else {
        y_texture->update(y_image);
        uv_texture->update(uv_image);
    }
    QueryPerformanceCounter(&finished);
    upload_ms = double(finished.QuadPart - started.QuadPart) * 1000.0 / frequency.QuadPart;
    last_frame_id = frame_id;
    last_timestamp = timestamp_us;
    ++fps_counter;
    emit_signal("frame_ready", y_texture, uv_texture, (int64_t)frame_id, (int64_t)last_timestamp);
    return true;
}

double VID1Reader::get_frame_age_ms() const {
    if (!last_timestamp) return 0.0;
    LARGE_INTEGER now, frequency;
    QueryPerformanceCounter(&now);
    QueryPerformanceFrequency(&frequency);
    const double now_us = double(now.QuadPart) * 1000000.0 / frequency.QuadPart;
    return std::max(0.0, (now_us - double(last_timestamp)) / 1000.0);
}

} // namespace lenzforge
