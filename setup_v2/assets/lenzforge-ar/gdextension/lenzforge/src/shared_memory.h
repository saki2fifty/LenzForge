#ifndef LENZFORGE_SHARED_MEMORY_H
#define LENZFORGE_SHARED_MEMORY_H

#include <windows.h>
#include <string>
#include <cstdint>

namespace lenzforge {

class SharedMemory {
public:
	SharedMemory();
	~SharedMemory();

	bool open(const std::string& name, size_t expected_size = 0);
	void close();
	
	bool is_open() const { return memory_ptr != nullptr; }
	const uint8_t* data() const { return memory_ptr; }
	size_t size() const { return memory_size; }
	const std::string& name() const { return memory_name; }

private:
	HANDLE file_handle;
	uint8_t* memory_ptr;
	size_t memory_size;
	std::string memory_name;

	SharedMemory(const SharedMemory&) = delete;
	SharedMemory& operator=(const SharedMemory&) = delete;
};

} // namespace lenzforge

#endif // LENZFORGE_SHARED_MEMORY_H
