#include "media_source.h"
namespace lenzcam {
// IMFActivate inherits IMFAttributes; forward the attribute store supplied by
// Frame Server, including the per-user transport identity set at registration.
class Activation final : public RuntimeClass<RuntimeClassFlags<ClassicCom>, Microsoft::WRL::ChainInterfaces<IMFActivate, IMFAttributes>, FtmBase>, public Tracked {
    ComPtr<IMFAttributes> attrs;
    ComPtr<Source> source;
    std::mutex mutex;
public:
    HRESULT initialize() { return MFCreateAttributes(&attrs, 8); }
    HRESULT STDMETHODCALLTYPE ActivateObject(REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        std::lock_guard guard(mutex);
        if (!source) {
            auto created = Make<Source>();
            if (!created) return E_OUTOFMEMORY;
            HRESULT hr = created->initialize(attrs.Get());
            if (FAILED(hr)) { created->Shutdown(); return hr; }
            source = created;
        }
        return source->QueryInterface(iid, out);
    }
    HRESULT STDMETHODCALLTYPE ShutdownObject() override {
        std::lock_guard guard(mutex);
        if (source) source->Shutdown();
        source.Reset(); return S_OK;
    }
    HRESULT STDMETHODCALLTYPE DetachObject() override { std::lock_guard guard(mutex); source.Reset(); return S_OK; }
    HRESULT STDMETHODCALLTYPE GetItem(REFGUID k, PROPVARIANT* v) override { return attrs->GetItem(k,v); }
    HRESULT STDMETHODCALLTYPE GetItemType(REFGUID k, MF_ATTRIBUTE_TYPE* v) override { return attrs->GetItemType(k,v); }
    HRESULT STDMETHODCALLTYPE CompareItem(REFGUID k, REFPROPVARIANT v, BOOL* r) override { return attrs->CompareItem(k,v,r); }
    HRESULT STDMETHODCALLTYPE Compare(IMFAttributes* a, MF_ATTRIBUTES_MATCH_TYPE t, BOOL* r) override { return attrs->Compare(a,t,r); }
    HRESULT STDMETHODCALLTYPE GetUINT32(REFGUID k, UINT32* v) override { return attrs->GetUINT32(k,v); }
    HRESULT STDMETHODCALLTYPE GetUINT64(REFGUID k, UINT64* v) override { return attrs->GetUINT64(k,v); }
    HRESULT STDMETHODCALLTYPE GetDouble(REFGUID k, double* v) override { return attrs->GetDouble(k,v); }
    HRESULT STDMETHODCALLTYPE GetGUID(REFGUID k, GUID* v) override { return attrs->GetGUID(k,v); }
    HRESULT STDMETHODCALLTYPE GetStringLength(REFGUID k, UINT32* v) override { return attrs->GetStringLength(k,v); }
    HRESULT STDMETHODCALLTYPE GetString(REFGUID k, LPWSTR v, UINT32 n, UINT32* r) override { return attrs->GetString(k,v,n,r); }
    HRESULT STDMETHODCALLTYPE GetAllocatedString(REFGUID k, LPWSTR* v, UINT32* n) override { return attrs->GetAllocatedString(k,v,n); }
    HRESULT STDMETHODCALLTYPE GetBlobSize(REFGUID k, UINT32* n) override { return attrs->GetBlobSize(k,n); }
    HRESULT STDMETHODCALLTYPE GetBlob(REFGUID k, UINT8* v, UINT32 n, UINT32* r) override { return attrs->GetBlob(k,v,n,r); }
    HRESULT STDMETHODCALLTYPE GetAllocatedBlob(REFGUID k, UINT8** v, UINT32* n) override { return attrs->GetAllocatedBlob(k,v,n); }
    HRESULT STDMETHODCALLTYPE GetUnknown(REFGUID k, REFIID i, LPVOID* v) override { return attrs->GetUnknown(k,i,v); }
    HRESULT STDMETHODCALLTYPE SetItem(REFGUID k, REFPROPVARIANT v) override { return attrs->SetItem(k,v); }
    HRESULT STDMETHODCALLTYPE DeleteItem(REFGUID k) override { return attrs->DeleteItem(k); }
    HRESULT STDMETHODCALLTYPE DeleteAllItems() override { return attrs->DeleteAllItems(); }
    HRESULT STDMETHODCALLTYPE SetUINT32(REFGUID k, UINT32 v) override { return attrs->SetUINT32(k,v); }
    HRESULT STDMETHODCALLTYPE SetUINT64(REFGUID k, UINT64 v) override { return attrs->SetUINT64(k,v); }
    HRESULT STDMETHODCALLTYPE SetDouble(REFGUID k, double v) override { return attrs->SetDouble(k,v); }
    HRESULT STDMETHODCALLTYPE SetGUID(REFGUID k, REFGUID v) override { return attrs->SetGUID(k,v); }
    HRESULT STDMETHODCALLTYPE SetString(REFGUID k, LPCWSTR v) override { return attrs->SetString(k,v); }
    HRESULT STDMETHODCALLTYPE SetBlob(REFGUID k, const UINT8* v, UINT32 n) override { return attrs->SetBlob(k,v,n); }
    HRESULT STDMETHODCALLTYPE SetUnknown(REFGUID k, IUnknown* v) override { return attrs->SetUnknown(k,v); }
    HRESULT STDMETHODCALLTYPE LockStore() override { return attrs->LockStore(); }
    HRESULT STDMETHODCALLTYPE UnlockStore() override { return attrs->UnlockStore(); }
    HRESULT STDMETHODCALLTYPE GetCount(UINT32* n) override { return attrs->GetCount(n); }
    HRESULT STDMETHODCALLTYPE GetItemByIndex(UINT32 n, GUID* k, PROPVARIANT* v) override { return attrs->GetItemByIndex(n,k,v); }
    HRESULT STDMETHODCALLTYPE CopyAllItems(IMFAttributes* a) override { return attrs->CopyAllItems(a); }
};
class Factory final : public RuntimeClass<RuntimeClassFlags<ClassicCom>, IClassFactory>, public Tracked {
public:
    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (outer) return CLASS_E_NOAGGREGATION;
        auto activation = Make<Activation>();
        if (!activation) return E_OUTOFMEMORY;
        LF_CHECK(activation->initialize());
        return activation->QueryInterface(iid, out);
    }
    HRESULT STDMETHODCALLTYPE LockServer(BOOL lock) override { if (lock) ++objects; else --objects; return S_OK; }
};
}
STDAPI DllGetClassObject(REFCLSID clsid, REFIID iid, void** out) {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (clsid != lenzcam::source_clsid) return CLASS_E_CLASSNOTAVAILABLE;
    auto factory = Make<lenzcam::Factory>();
    return factory ? factory->QueryInterface(iid, out) : E_OUTOFMEMORY;
}
STDAPI DllCanUnloadNow() { return lenzcam::objects == 0 ? S_OK : S_FALSE; }
