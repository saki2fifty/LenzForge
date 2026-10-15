#ifndef LENZFORGE_LMK1_READER_H
#define LENZFORGE_LMK1_READER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <vector>
#include "shared_memory.h"
#include "lmk1_header.h"

namespace lenzforge {

class LMK1Reader : public godot::Node {
	GDCLASS(LMK1Reader, godot::Node)

public:
	LMK1Reader();
	~LMK1Reader();

	void _ready() override;
	void _process(double delta) override;

	bool start_reading(const godot::String &name);
	void stop_reading();
	bool is_reading() const { return reading; }

	godot::Array get_landmarks() const;
	int get_landmark_count() const { return landmark_count; }
	bool has_face() const { return face_detected; }
	int64_t get_timestamp() const { return last_timestamp; }

protected:
	static void _bind_methods();

private:
	SharedMemory memory;
    std::string mapping_name;
	bool reading;

	int landmark_count;
	bool face_detected;
	uint32_t last_frame_id;
	uint64_t last_timestamp;

	godot::Array landmarks;
	std::vector<uint8_t> snapshot;

	bool open_shared_memory();
	void read_latest_landmarks();
};

} // namespace lenzforge

#endif // LENZFORGE_LMK1_READER_H
