#pragma once
#include "protocol.h"
#include <mfapi.h>
#include <mfidl.h>
#include <mferror.h>
#include <mfvirtualcamera.h>
#include <ks.h>
#include <ksmedia.h>
#include <ksproxy.h>
#include <wrl.h>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <vector>
#include <deque>
#include <chrono>
#include <algorithm>
#include <cstdio>
#include <memory>

using Microsoft::WRL::ComPtr;
using Microsoft::WRL::RuntimeClass;
using Microsoft::WRL::RuntimeClassFlags;
using Microsoft::WRL::ClassicCom;
using Microsoft::WRL::FtmBase;
using Microsoft::WRL::Make;
#define LF_CHECK(expr) do { HRESULT lf_hr = (expr); if (FAILED(lf_hr)) { fprintf(stderr,"LenzForge camera %s:%d: 0x%08lx (%s)\n",__FILE__,__LINE__,lf_hr,#expr); return lf_hr; } } while (false)
namespace lenzcam {
inline std::atomic<long> objects{0};
struct Tracked {
    Tracked() { ++objects; }
    ~Tracked() { --objects; }
};
// Snapshot the queue under its owner's lock, then release the lock before GetEvent
// can block. Shutdown must remain able to wake any blocked event consumer.
#define LF_EVENTS \
    HRESULT STDMETHODCALLTYPE GetEvent(DWORD f, IMFMediaEvent** e) override { auto q = queue(); return q ? q->GetEvent(f,e) : MF_E_SHUTDOWN; } \
    HRESULT STDMETHODCALLTYPE BeginGetEvent(IMFAsyncCallback* c, IUnknown* s) override { auto q = queue(); return q ? q->BeginGetEvent(c,s) : MF_E_SHUTDOWN; } \
    HRESULT STDMETHODCALLTYPE EndGetEvent(IMFAsyncResult* r, IMFMediaEvent** e) override { auto q = queue(); return q ? q->EndGetEvent(r,e) : MF_E_SHUTDOWN; } \
    HRESULT STDMETHODCALLTYPE QueueEvent(MediaEventType t, REFGUID g, HRESULT h, const PROPVARIANT* v) override { auto q = queue(); return q ? q->QueueEventParamVar(t,g,h,v) : MF_E_SHUTDOWN; }
}
