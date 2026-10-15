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

	bool start_reading();
	void stop_reading();
	bool is_reading() const { return reading; }

	int get_width() const { return width; }
	int get_height() const { return height; }
	int get_fps() const { return current_fps; }
	uint64_t get_timestamp() const { return last_timestamp; }

protected:
	static void _bind_methods();

private:
	SharedMemory memory;
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

	bool open_shared_memory();
	void read_latest_frame();
	void create_nv12_textures(const uint8_t* y_data, const uint8_t* uv_data,
	                          int frame_width, int frame_height,
	                          int y_stride, int uv_stride);
};

} // namespace lenzforge

#endif // LENZFORGE_VID1_READER_H
