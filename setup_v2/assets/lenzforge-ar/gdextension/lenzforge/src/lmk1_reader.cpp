#include "lmk1_reader.h"
#include <godot_cpp/core/class_db.hpp>
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
	godot::ClassDB::bind_method(godot::D_METHOD("start_reading"), &LMK1Reader::start_reading);
	godot::ClassDB::bind_method(godot::D_METHOD("stop_reading"), &LMK1Reader::stop_reading);
	godot::ClassDB::bind_method(godot::D_METHOD("is_reading"), &LMK1Reader::is_reading);
	godot::ClassDB::bind_method(godot::D_METHOD("get_landmarks"), &LMK1Reader::get_landmarks);
	godot::ClassDB::bind_method(godot::D_METHOD("get_landmark_count"), &LMK1Reader::get_landmark_count);
	godot::ClassDB::bind_method(godot::D_METHOD("has_face"), &LMK1Reader::has_face);
	godot::ClassDB::bind_method(godot::D_METHOD("get_timestamp"), &LMK1Reader::get_timestamp);

	ADD_SIGNAL(godot::MethodInfo("landmarks_ready",
		godot::PropertyInfo(godot::Variant::ARRAY, "landmarks"),
		godot::PropertyInfo(godot::Variant::INT, "frame_id")));
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

bool LMK1Reader::start_reading() {
	if (reading) {
		godot::UtilityFunctions::print("[LMK1Reader] Already reading");
		return true;
	}

	if (!open_shared_memory()) {
		godot::UtilityFunctions::print("[LMK1Reader] Failed to open shared memory");
		return false;
	}

	reading = true;
	last_frame_id = 0;
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
	if (!memory.open("LenzForge_Landmarks")) {
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
	const LmkHeader* header = reinterpret_cast<const LmkHeader*>(data);

	uint32_t wr_seq = header->wr_seq;
	if (wr_seq == 0) {
		return;
	}

	// DEBUG: Print header info
	static int debug_counter = 0;
	bool print_debug = (debug_counter++ % 30 == 0); // Print every 30th frame
	
	if (print_debug) {
		godot::UtilityFunctions::print("[LMK1Reader DEBUG] === Frame Debug ===");
		godot::UtilityFunctions::print("  wr_seq: ", wr_seq);
		godot::UtilityFunctions::print("  slot_count: ", header->slot_count);
		godot::UtilityFunctions::print("  slot_stride: ", header->slot_stride);
		godot::UtilityFunctions::print("  src_w: ", header->src_w, " src_h: ", header->src_h);
		godot::UtilityFunctions::print("  coord_space: ", (int)header->coord_space);
	}

	uint32_t slot_idx = (wr_seq - 1) % header->slot_count;
	size_t slot_offset = LMK1_HEADER_SIZE + slot_idx * header->slot_stride;

	if (slot_offset + LMK1_SLOT_HEADER_SIZE > memory.size()) {
		if (print_debug) {
			godot::UtilityFunctions::print("  ERROR: slot_offset out of bounds");
		}
		return;
	}

	const LmkSlotHeader* slot = reinterpret_cast<const LmkSlotHeader*>(data + slot_offset);

	if (print_debug) {
		godot::UtilityFunctions::print("  slot_idx: ", slot_idx);
		godot::UtilityFunctions::print("  slot_offset: ", (int)slot_offset);
		godot::UtilityFunctions::print("  slot->valid: ", slot->valid);
		godot::UtilityFunctions::print("  slot->frame_id: ", slot->frame_id);
		godot::UtilityFunctions::print("  slot->block_count: ", slot->block_count);
	}

	if (slot->valid == 0) {
		if (print_debug) {
			godot::UtilityFunctions::print("  Slot not valid, skipping");
		}
		return;
	}

	if (slot->frame_id == last_frame_id) {
		return;
	}

	last_frame_id = slot->frame_id;
	last_timestamp = slot->ts_qpc;

	if (slot->block_count == 0) {
		if (face_detected) {
			face_detected = false;
			landmark_count = 0;
			landmarks.clear();
			emit_signal("face_lost");
			if (print_debug) {
				godot::UtilityFunctions::print("  Face lost (block_count=0)");
			}
		}
		return;
	}

	size_t block_offset = slot_offset + LMK1_SLOT_HEADER_SIZE;
	
	if (block_offset + LMK1_BLOCK_HEADER_SIZE > memory.size()) {
		if (print_debug) {
			godot::UtilityFunctions::print("  ERROR: block_offset out of bounds");
		}
		return;
	}

	const LmkBlockHeader* block = reinterpret_cast<const LmkBlockHeader*>(data + block_offset);

	if (print_debug) {
		godot::UtilityFunctions::print("  block_offset: ", (int)block_offset);
		godot::UtilityFunctions::print("  block->stream_id: ", block->stream_id);
		godot::UtilityFunctions::print("  block->elem_count: ", block->elem_count);
		godot::UtilityFunctions::print("  block->elem_stride: ", block->elem_stride);
		godot::UtilityFunctions::print("  block->flags: ", block->flags);
	}

	int elem_count = block->elem_count;
	size_t data_offset = block_offset + LMK1_BLOCK_HEADER_SIZE;

	if (data_offset + elem_count * sizeof(Landmark) > memory.size()) {
		if (print_debug) {
			godot::UtilityFunctions::print("  ERROR: data extends beyond memory bounds");
			godot::UtilityFunctions::print("    data_offset: ", (int)data_offset);
			godot::UtilityFunctions::print("    needed: ", (int)(elem_count * sizeof(Landmark)));
			godot::UtilityFunctions::print("    memory.size: ", (int)memory.size());
		}
		return;
	}

	const Landmark* lmk_data = reinterpret_cast<const Landmark*>(data + data_offset);

	// DEBUG: Print raw bytes of first landmark
	if (print_debug && elem_count > 0) {
		const uint8_t* raw_bytes = reinterpret_cast<const uint8_t*>(lmk_data);
		godot::UtilityFunctions::print("  Raw bytes of first landmark (12 bytes):");
		godot::String hex_str = "    ";
		for (int i = 0; i < 12; i++) {
			char buf[4];
			snprintf(buf, sizeof(buf), "%02X ", raw_bytes[i]);
			hex_str += godot::String(buf);
		}
		godot::UtilityFunctions::print(hex_str);
	}

	landmarks.clear();
	for (int i = 0; i < elem_count; i++) {
		godot::Vector3 point(lmk_data[i].x, lmk_data[i].y, lmk_data[i].z);
		landmarks.append(point);
	}

	landmark_count = elem_count;
	face_detected = true;

	// Debug: Print first 3 landmarks with more detail
	if (print_debug && elem_count >= 3) {
		godot::UtilityFunctions::print("  First 3 landmarks (as floats):");
		godot::UtilityFunctions::print("    [0]: x=", lmk_data[0].x, " y=", lmk_data[0].y, " z=", lmk_data[0].z);
		godot::UtilityFunctions::print("    [1]: x=", lmk_data[1].x, " y=", lmk_data[1].y, " z=", lmk_data[1].z);
		godot::UtilityFunctions::print("    [2]: x=", lmk_data[2].x, " y=", lmk_data[2].y, " z=", lmk_data[2].z);
		godot::UtilityFunctions::print("  Total landmarks: ", elem_count);
	}

	emit_signal("landmarks_ready", landmarks, (int64_t)slot->frame_id);
}

} // namespace lenzforge
