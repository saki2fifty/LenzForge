"""
High-precision timestamp using QueryPerformanceCounter (Windows)

This module provides nanosecond-precision timing for frame synchronization
between Python backend and Godot frontend via shared memory rings.
"""
import ctypes
from ctypes import wintypes

# Load Windows kernel32
kernel32 = ctypes.windll.kernel32

# Define QPC functions
QueryPerformanceCounter = kernel32.QueryPerformanceCounter
QueryPerformanceCounter.argtypes = [ctypes.POINTER(wintypes.LARGE_INTEGER)]
QueryPerformanceCounter.restype = wintypes.BOOL

QueryPerformanceFrequency = kernel32.QueryPerformanceFrequency
QueryPerformanceFrequency.argtypes = [ctypes.POINTER(wintypes.LARGE_INTEGER)]
QueryPerformanceFrequency.restype = wintypes.BOOL

class QPCTimer:
    """High-precision timer using QueryPerformanceCounter"""
    
    def __init__(self):
        self._freq = wintypes.LARGE_INTEGER()
        if not QueryPerformanceFrequency(ctypes.byref(self._freq)):
            raise RuntimeError("QueryPerformanceFrequency failed")
        self.frequency = self._freq.value
    
    def get_ticks(self) -> int:
        """Get current QPC ticks (64-bit integer)"""
        counter = wintypes.LARGE_INTEGER()
        if not QueryPerformanceCounter(ctypes.byref(counter)):
            raise RuntimeError("QueryPerformanceCounter failed")
        return counter.value
    
    def ticks_to_seconds(self, ticks: int) -> float:
        """Convert QPC ticks to seconds"""
        return ticks / self.frequency
    
    def ticks_to_ms(self, ticks: int) -> float:
        """Convert QPC ticks to milliseconds"""
        return (ticks * 1000.0) / self.frequency
    
    def ticks_to_us(self, ticks: int) -> float:
        """Convert QPC ticks to microseconds"""
        return (ticks * 1000000.0) / self.frequency
    
    def seconds_to_ticks(self, seconds: float) -> int:
        """Convert seconds to QPC ticks"""
        return int(seconds * self.frequency)
    
    def ms_to_ticks(self, ms: float) -> int:
        """Convert milliseconds to QPC ticks"""
        return int((ms / 1000.0) * self.frequency)

# Global timer instance (singleton pattern)
_qpc = None

def get_qpc_timer() -> QPCTimer:
    """Get global QPC timer instance (singleton)"""
    global _qpc
    if _qpc is None:
        _qpc = QPCTimer()
    return _qpc

def get_qpc_ticks() -> int:
    """Quick function to get current QPC ticks"""
    return get_qpc_timer().get_ticks()

def get_qpc_frequency() -> int:
    """Quick function to get QPC frequency"""
    return get_qpc_timer().frequency
