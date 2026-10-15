#include "lmk1_reader.h"
#include <godot_cpp/core/class_db.hpp>
#include <cstring>
#include <vector>
#include <limits>
#include <godot_cpp/variant/utility_functions.hpp>

namespace lenzforge {

LMK1Reader::LMK1Reader()
	: reading(false)
	, landmark_count(0)
	, face_detected(false)
	, last_frame_id(0)
	, last_timestamp(0)
{
}

LMK1Reader::~LMK1Reader() {
	stop_reading();
}

void LMK1Reader::_bind_methods() {
	godot::ClassDB::bind_method(godot::D_METHOD("start_reading"), &LMK1Reader::start_reading, DEFVAL(godot::String("LenzForge_Landmarks")));
	godot::ClassDB::bind_method(godot::D_METHOD("stop_reading"), &LMK1Reader::stop_reading);
	godot::ClassDB::bind_method(godot::D_METHOD("is_reading"), &LMK1Reader::is_reading);
	godot::ClassDB::bind_method(godot::D_METHOD("get_landmarks"), &LMK1Reader::get_landmarks);
	godot::ClassDB::bind_method(godot::D_METHOD("get_landmark_count"), &LMK1Reader::get_landmark_count);
	godot::ClassDB::bind_method(godot::D_METHOD("has_face"), &LMK1Reader::has_face);
	godot::ClassDB::bind_method(godot::D_METHOD("get_timestamp"), &LMK1Reader::get_timestamp);

	ADD_SIGNAL(godot::MethodInfo("landmarks_ready",
		godot::PropertyInfo(godot::Variant::ARRAY, "landmarks"),
		godot::PropertyInfo(godot::Variant::INT, "frame_id"),
        godot::PropertyInfo(godot::Variant::INT, "timestamp")));
	ADD_SIGNAL(godot::MethodInfo("face_lost"));
}

void LMK1Reader::_ready() {
	godot::UtilityFunctions::print("[LMK1Reader] Ready");
}

void LMK1Reader::_process(double delta) {
	if (!reading) {
		return;
	}

	read_latest_landmarks();
}

bool LMK1Reader::start_reading(const godot::String &name) {
    mapping_name = name.utf8().get_data();
	if (reading) {
		godot::UtilityFunctions::print("[LMK1Reader] Already reading");
		return true;
	}

	if (!open_shared_memory()) {
		godot::UtilityFunctions::print("[LMK1Reader] Failed to open shared memory");
		return false;
	}

	reading = true;
	last_frame_id = std::numeric_limits<uint32_t>::max();
	face_detected = false;

	godot::UtilityFunctions::print("[LMK1Reader] Started reading");
	return true;
}

void LMK1Reader::stop_reading() {
	if (!reading) {
		return;
	}

	reading = false;
	memory.close();
	landmarks.clear();
	face_detected = false;

	godot::UtilityFunctions::print("[LMK1Reader] Stopped reading");
}

godot::Array LMK1Reader::get_landmarks() const {
	return landmarks;
}

bool LMK1Reader::open_shared_memory() {
	if (!memory.open(mapping_name)) {
		return false;
	}

	const uint8_t* data = memory.data();
	const LmkHeader* header = reinterpret_cast<const LmkHeader*>(data);

	if (header->magic != LMK1_MAGIC) {
		godot::UtilityFunctions::print("[LMK1Reader] Invalid magic: ", header->magic);
		memory.close();
		return false;
	}

	if (header->version != LMK1_VERSION) {
		godot::UtilityFunctions::print("[LMK1Reader] Invalid version: ", header->version);
		memory.close();
		return false;
	}

	godot::UtilityFunctions::print("[LMK1Reader] Opened LMK1 ring (",
	                               header->slot_count, " slots)");
	return true;
}

void LMK1Reader::read_latest_landmarks() {
    const uint8_t* data = memory.data();
    const auto* header = reinterpret_cast<const LmkHeader*>(data);
    const uint32_t sequence = header->wr_seq;
    MemoryBarrier();
    if (!sequence || !header->slot_count || !header->qpc_freq) return;
    const size_t offset = LMK1_HEADER_SIZE + size_t((sequence - 1) % header->slot_count) * header->slot_stride;
    if (offset + header->slot_stride > memory.size() || header->slot_stride < LMK1_SLOT_HEADER_SIZE) return;
    const auto* slot = reinterpret_cast<const LmkSlotHeader*>(data + offset);
    if (!slot->valid || slot->frame_id == last_frame_id) return;
    const uint32_t frame_id = slot->frame_id;
    const uint64_t timestamp = slot->ts_qpc;
    std::vector<uint8_t> snapshot(header->slot_stride);
    std::memcpy(snapshot.data(), data + offset, snapshot.size());
    MemoryBarrier();
    if (!slot->valid || slot->frame_id != frame_id || header->wr_seq != sequence) return;
    const auto* copied = reinterpret_cast<const LmkSlotHeader*>(snapshot.data());
    last_frame_id = frame_id;
    last_timestamp = (timestamp / header->qpc_freq) * 1000000ULL +
                     ((timestamp % header->qpc_freq) * 1000000ULL) / header->qpc_freq;
    if (copied->block_count == 0) {
        face_detected = false;
        landmark_count = 0;
        landmarks.clear();
        emit_signal("face_lost");
        return;
    }
    if (snapshot.size() < LMK1_SLOT_HEADER_SIZE + LMK1_BLOCK_HEADER_SIZE) return;
    const auto* block = reinterpret_cast<const LmkBlockHeader*>(snapshot.data() + LMK1_SLOT_HEADER_SIZE);
    const size_t payload = LMK1_SLOT_HEADER_SIZE + LMK1_BLOCK_HEADER_SIZE;
    if (block->elem_stride < sizeof(Landmark) || block->elem_count > 478 ||
        payload + size_t(block->elem_count) * block->elem_stride > snapshot.size()) return;
    landmarks.clear();
    for (int i = 0; i < block->elem_count; ++i) {
        Landmark point;
        std::memcpy(&point, snapshot.data() + payload + size_t(i) * block->elem_stride, sizeof(point));
        landmarks.append(godot::Vector3(point.x, point.y, point.z));
    }
    landmark_count = block->elem_count;
    face_detected = landmark_count > 0;
    emit_signal("landmarks_ready", landmarks, (int64_t)frame_id, (int64_t)last_timestamp);
}

} // namespace lenzforge
