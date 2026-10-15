#include <windows.h>

__declspec(dllexport) void lenzforge_publish_u32(volatile LONG *address, LONG value) {
    InterlockedExchange(address, value);
}
