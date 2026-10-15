/*
 * VID1 Ring Buffer Test Reader
 * 
 * Tests the VID1 v1 NV12 frame ring buffer implementation.
 * Reads frames from shared memory and validates protocol compliance.
 * 
 * Build:
 *   g++ -O2 -o test_vid1_reader test_vid1_reader.cpp -std=c++17
 * 
 * Run:
 *   ./test_vid1_reader [ring_name] [frame_count]
 *   
 * Example:
 *   ./test_vid1_reader LenzForge_Video_NV12 100
 */

#include <windows.h>
#include <iostream>
#include <iomanip>
#include <chrono>
#include <thread>
#include "../ipc/vid1_header.h"

class VID1Reader {
private:
    HANDLE hMapFile;
    void* pBuf;
    VidHeader* header;
    uint32_t last_rd_seq;
    
public:
    VID1Reader(const char* name) : hMapFile(NULL), pBuf(NULL), header(NULL), last_rd_seq(0) {
        // Open existing file mapping
        hMapFile = OpenFileMappingA(
            FILE_MAP_READ,
            FALSE,
            name
        );
        
        if (hMapFile == NULL) {
            throw std::runtime_error("Failed to open file mapping");
        }
        
        // Map view of file
        pBuf = MapViewOfFile(
            hMapFile,
            FILE_MAP_READ,
            0,
            0,
            0  // Map entire file
        );
        
        if (pBuf == NULL) {
            CloseHandle(hMapFile);
            throw std::runtime_error("Failed to map view of file");
        }
        
        header = static_cast<VidHeader*>(pBuf);
        
        // Validate header
        if (header->magic != VID1_MAGIC) {
            throw std::runtime_error("Invalid magic number");
        }
        
        if (header->version != VID1_VERSION) {
            throw std::runtime_error("Invalid version");
        }
        
        // Initialize rd_seq to current wr_seq
        last_rd_seq = header->wr_seq;
    }
    
    ~VID1Reader() {
        if (pBuf) {
            UnmapViewOfFile(pBuf);
        }
        if (hMapFile) {
            CloseHandle(hMapFile);
        }
    }
    
    VidHeader* get_header() {
        return header;
    }
    
    bool has_new_frame() {
        return header->wr_seq > last_rd_seq;
    }
    
    bool read_frame(uint64_t& ts_qpc, uint32_t& frame_id) {
        if (!has_new_frame()) {
            return false;
        }
        
        // Get slot index
        uint32_t slot_idx = last_rd_seq % header->slot_count;
        
        // Get slot header
        uint8_t* base = static_cast<uint8_t*>(pBuf);
        VidSlotHeader* slot = reinterpret_cast<VidSlotHeader*>(
            base + VID1_SLOT_OFFSET(header, slot_idx)
        );
        
        // Wait for valid flag (with timeout)
        int timeout_ms = 100;
        int wait_count = 0;
        while (slot->valid == 0 && wait_count < timeout_ms) {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
            wait_count++;
        }
        
        if (slot->valid == 0) {
            return false;  // Timeout
        }
        
        // Read slot header
        ts_qpc = slot->ts_qpc;
        frame_id = slot->frame_id;
        
        // Note: In real reader, would copy Y and UV planes here
        // For test, we just validate stride handling exists
        uint8_t* y_plane = base + VID1_SLOT_Y_OFFSET(header, slot_idx);
        uint8_t* uv_plane = base + VID1_SLOT_UV_OFFSET(header, slot_idx);
        
        // Increment rd_seq
        last_rd_seq++;
        
        return true;
    }
    
    uint32_t get_delta() {
        return header->wr_seq - last_rd_seq;
    }
};

void print_header(VidHeader* hdr) {
    std::cout << "VID1 Reader Test\n";
    std::cout << "================\n";
    std::cout << "Header: magic=VID1 version=" << hdr->version << "\n";
    std::cout << "Resolution: " << hdr->w << "x" << hdr->h << "\n";
    std::cout << "Slots: " << hdr->slot_count << "\n";
    std::cout << "Slot stride: " << hdr->slot_stride << " bytes\n";
    std::cout << "Y stride: " << hdr->y_stride << " bytes\n";
    std::cout << "UV stride: " << hdr->uv_stride << " bytes\n";
    std::cout << "QPC Freq: " << hdr->qpc_freq << " Hz\n";
    std::cout << "\n";
}

int main(int argc, char* argv[]) {
    const char* ring_name = "LenzForge_Video_NV12";
    int frame_count = 100;
    
    if (argc > 1) {
        ring_name = argv[1];
    }
    if (argc > 2) {
        frame_count = std::atoi(argv[2]);
    }
    
    try {
        VID1Reader reader(ring_name);
        VidHeader* hdr = reader.get_header();
        
        print_header(hdr);
        
        std::cout << "Reading " << frame_count << " frames...\n";
        std::cout << std::fixed << std::setprecision(3);
        
        uint64_t first_ts = 0;
        uint64_t last_ts = 0;
        uint32_t last_frame_id = 0;
        int frames_read = 0;
        int consecutive_timeouts = 0;
        
        auto start_time = std::chrono::high_resolution_clock::now();
        
        while (frames_read < frame_count) {
            uint64_t ts_qpc;
            uint32_t frame_id;
            
            if (reader.read_frame(ts_qpc, frame_id)) {
                consecutive_timeouts = 0;
                
                if (frames_read == 0) {
                    first_ts = ts_qpc;
                    std::cout << "Frame " << frames_read 
                              << ": id=" << frame_id 
                              << " ts=" << ts_qpc 
                              << " delta=0.000s\n";
                } else {
                    double delta_s = (double)(ts_qpc - last_ts) / hdr->qpc_freq;
                    
                    // Check monotonic frame_id
                    if (frame_id != last_frame_id + 1) {
                        std::cerr << "WARNING: Non-monotonic frame_id! "
                                  << "Expected " << (last_frame_id + 1) 
                                  << ", got " << frame_id << "\n";
                    }
                    
                    // Check reasonable delta (20-50ms for 30fps)
                    if (delta_s < 0.015 || delta_s > 0.100) {
                        std::cerr << "WARNING: Unusual delta: " << delta_s << "s\n";
                    }
                    
                    if (frames_read % 10 == 0 || frames_read < 5) {
                        std::cout << "Frame " << frames_read 
                                  << ": id=" << frame_id 
                                  << " ts=" << ts_qpc 
                                  << " delta=" << delta_s << "s"
                                  << " (delta=" << reader.get_delta() << ")\n";
                    }
                }
                
                last_ts = ts_qpc;
                last_frame_id = frame_id;
                frames_read++;
                
            } else {
                // No frame available, wait a bit
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
                consecutive_timeouts++;
                
                if (consecutive_timeouts > 1000) {
                    std::cerr << "ERROR: Timeout waiting for frames (waited 1s)\n";
                    return 1;
                }
            }
        }
        
        auto end_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
            end_time - start_time
        );
        
        // Calculate FPS
        double elapsed_qpc_s = (double)(last_ts - first_ts) / hdr->qpc_freq;
        double fps_qpc = (frames_read - 1) / elapsed_qpc_s;
        double fps_wall = (double)(frames_read * 1000) / duration.count();
        
        std::cout << "\nTest Results:\n";
        std::cout << "=============\n";
        std::cout << "Frames read: " << frames_read << "\n";
        std::cout << "Elapsed (QPC): " << elapsed_qpc_s << " seconds\n";
        std::cout << "Elapsed (wall): " << (duration.count() / 1000.0) << " seconds\n";
        std::cout << "Average FPS (QPC): " << fps_qpc << "\n";
        std::cout << "Average FPS (wall): " << fps_wall << "\n";
        std::cout << "Final delta: " << reader.get_delta() << " frames\n";
        
        // Pass/fail criteria
        bool passed = true;
        
        if (fps_qpc < 28.0) {
            std::cout << "\nFAIL: FPS too low (<28)\n";
            passed = false;
        }
        
        if (reader.get_delta() > 3) {
            std::cout << "\nFAIL: Delta too high (>3)\n";
            passed = false;
        }
        
        if (passed) {
            std::cout << "\nTest PASSED ✓\n";
            return 0;
        } else {
            std::cout << "\nTest FAILED ✗\n";
            return 1;
        }
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }
}
