"""Windows interlocked publication for aligned shared-memory protocol fields."""
import ctypes
from pathlib import Path

_library = Path(__file__).resolve().parents[1] / 'native' / 'ipc_atomic.dll'
_exchange = None
if _library.is_file():
    _exchange = ctypes.CDLL(str(_library)).lenzforge_publish_u32
    _exchange.argtypes = [ctypes.POINTER(ctypes.c_long), ctypes.c_long]
    _exchange.restype = None
_barrier = ctypes.WinDLL('kernel32').FlushProcessWriteBuffers
_barrier.argtypes = []
_barrier.restype = None


def publish_u32(buffer, offset, value):
    if offset % 4:
        raise ValueError('Interlocked fields must be 4-byte aligned')
    field = ctypes.c_long.from_buffer(buffer, offset)
    if _exchange:
        _exchange(ctypes.byref(field), ctypes.c_long(value & 0xffffffff))
    else:
        # Conservative fallback before setup builds the tiny, Python-ABI-independent DLL.
        _barrier()
        field.value = ctypes.c_long(value & 0xffffffff).value
