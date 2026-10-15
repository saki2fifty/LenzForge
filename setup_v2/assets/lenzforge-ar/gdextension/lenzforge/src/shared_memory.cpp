#include "shared_memory.h"
#include <iostream>

namespace lenzforge {

SharedMemory::SharedMemory()
	: file_handle(NULL)
	, memory_ptr(nullptr)
	, memory_size(0)
	, memory_name("")
{
}

SharedMemory::~SharedMemory() {
	close();
}

bool SharedMemory::open(const std::string& name, size_t expected_size) {
	if (is_open()) {
		std::cerr << "[SharedMemory] Already open: " << memory_name << std::endl;
		return false;
	}

	if (name.empty()) {
		std::cerr << "[SharedMemory] Empty memory name" << std::endl;
		return false;
	}

	// Convert to wide string for Windows API
	int wname_len = MultiByteToWideChar(CP_UTF8, 0, name.c_str(), -1, NULL, 0);
	if (wname_len == 0) {
		std::cerr << "[SharedMemory] Failed to convert name to wide string" << std::endl;
		return false;
	}

	wchar_t* wname = new wchar_t[wname_len];
	MultiByteToWideChar(CP_UTF8, 0, name.c_str(), -1, wname, wname_len);

	// Open existing shared memory
	file_handle = OpenFileMappingW(
		FILE_MAP_READ,  // Read-only access
		FALSE,          // Do not inherit handle
		wname           // Name of mapping object
	);

	delete[] wname;

	if (file_handle == NULL) {
		DWORD error = GetLastError();
		std::cerr << "[SharedMemory] Failed to open '" << name 
		          << "' (error " << error << ")" << std::endl;
		return false;
	}

	// Map view of file
	memory_ptr = static_cast<uint8_t*>(MapViewOfFile(
		file_handle,
		FILE_MAP_READ,  // Read-only access
		0,              // High-order DWORD of file offset
		0,              // Low-order DWORD of file offset
		0               // Map entire file
	));

	if (memory_ptr == nullptr) {
		DWORD error = GetLastError();
		std::cerr << "[SharedMemory] Failed to map view (error " << error << ")" << std::endl;
		CloseHandle(file_handle);
		file_handle = NULL;
		return false;
	}

	// Get the actual size
	MEMORY_BASIC_INFORMATION info;
	if (VirtualQuery(memory_ptr, &info, sizeof(info)) == 0) {
		std::cerr << "[SharedMemory] Failed to query memory size" << std::endl;
		UnmapViewOfFile(memory_ptr);
		CloseHandle(file_handle);
		file_handle = NULL;
		memory_ptr = nullptr;
		return false;
	}

	memory_size = info.RegionSize;
	memory_name = name;

	// Verify expected size if provided
	if (expected_size > 0 && memory_size < expected_size) {
		std::cerr << "[SharedMemory] Size mismatch: expected " << expected_size 
		          << " but got " << memory_size << std::endl;
		close();
		return false;
	}

	std::cout << "[SharedMemory] Opened '" << name << "' (" << memory_size << " bytes)" << std::endl;
	return true;
}

void SharedMemory::close() {
	if (memory_ptr != nullptr) {
		UnmapViewOfFile(memory_ptr);
		memory_ptr = nullptr;
	}

	if (file_handle != NULL) {
		CloseHandle(file_handle);
		file_handle = NULL;
	}

	memory_size = 0;
	memory_name.clear();
}

} // namespace lenzforge
