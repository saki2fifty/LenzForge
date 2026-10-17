#ifndef LENZFORGE_VID1_READER_H
#define LENZFORGE_VID1_READER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include "shared_memory.h"
#include "vid1_header.h"

namespace lenzforge {

class VID1Reader : public godot::Node {
	GDCLASS(VID1Reader, godot::Node)

public:
	VID1Reader();
	~VID1Reader();

	void _ready() override;
	void _process(double delta) override;

	bool start_reading(const godot::String &name);
	void stop_reading();
	bool is_reading() const { return reading; }

	int get_width() const { return width; }
	int get_height() const { return height; }
	int get_fps() const { return current_fps; }
	uint64_t get_timestamp() const { return last_timestamp; }
	double get_frame_age_ms() const;
	double get_upload_ms() const { return upload_ms; }
	bool present_frame(int64_t frame_id, int64_t timestamp_us);
	void set_frame_locked(bool enabled) { frame_locked = enabled; matched_age = 0; }
	bool is_frame_locked() const { return frame_locked; }
	int64_t get_frame_id() const { return last_frame_id; }

protected:
	static void _bind_methods();

private:
	SharedMemory memory;
    std::string mapping_name;
	bool reading;

	int width;
	int height;
	uint32_t last_frame_id;
	uint64_t last_timestamp;

	double fps_timer;
	int fps_counter;
	int current_fps;

	// GPU textures (Y plane = R8, UV plane = RG8)
	godot::Ref<godot::ImageTexture> y_texture;
	godot::Ref<godot::ImageTexture> uv_texture;
	godot::Ref<godot::Image> y_image;
	godot::Ref<godot::Image> uv_image;
	double upload_ms = 0.0;
	bool frame_locked = false;
	double matched_age = 0.0;

	bool open_shared_memory();
	void read_latest_frame();
	bool upload_frame(size_t offset, int64_t expected_id = -1, uint64_t expected_timestamp = 0);
};

} // namespace lenzforge

#endif // LENZFORGE_VID1_READER_H
