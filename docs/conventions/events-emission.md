# Events emission (`XWF_AddEvent` / `XWF_GetEvent`)

!!! warning "Cross-run dedup must bucket the timestamp — `XWF_GetEvent` drifts the FILETIME"
    The event store round-trips a 64-bit FILETIME through a **double**, so the value you read back
    via `XWF_GetEvent` differs from what you passed to `XWF_AddEvent` by tens of µs to a few ms. A
    dedup key built from the raw FILETIME quad-word therefore **never matches** on a second run — so
    "skip events already in the timeline" silently fails and every re-run re-adds everything. Bucket
    the timestamp (whole seconds) on **both** the add side and the read-back side.

**Background:** [xways-events-api.md](../xways-events-api.md) — the double-conversion drift, the
`nEvtType` subcode→Type map, and `lpDescr`'s real ceiling (~254 bytes). Forensic-license only;
`XT_Python.dll` does **not** expose `XWF_AddEvent`/`XWF_GetEvent`, so events ⇒ C++.

**Threading:** emit from `XT_Prepare`/`XT_Finalize` on X-Ways' thread — see
[threading model](threading-model.md). Never from a worker thread.

**Reference implementation:**
[xways-linux-logs](https://github.com/kev365/xways-linux-logs) (`xways-linux-logs.cpp` →
`MakeDedupKey`, `LoadExistingEventKeys`, and the `XWF_AddEvent` call site).

## Pattern

Build the dedup key from `(nEvtType, bucketed-timestamp, descr)`, using the **same** `MakeDedupKey`
for read-back keys (`LoadExistingEventKeys` → `XWF_GetEvent`) and add-time keys, so they match:

```cpp
static std::string MakeDedupKey(DWORD evtType, FILETIME ft, const std::string& descr) {
    ULARGE_INTEGER u; u.LowPart = ft.dwLowDateTime; u.HighPart = ft.dwHighDateTime;
    uint64_t sec = u.QuadPart / 10000000ULL;        // 100-ns ticks → seconds (wider than the drift)
    return std::to_string(evtType) + "|" + std::to_string(sec) + "|" + descr;
}

EventInfo e = {};
e.iSize     = (LONG)sizeof(EventInfo);
e.hEvidence = hEvidence;
e.nEvtType  = et;            // numeric subcode — see xways-events-api.md
e.nFlags    = 0;
e.TimeStamp = ts;           // FILETIME (UTC)
e.nItemID   = id;
e.nOfs      = -1;
e.lpDescr   = const_cast<char*>(descr.c_str());   // UTF-8, keep alive until the call returns
LONG rv = XWF_AddEvent(&e);  // 1 = added, 2 = added-but-filtered, 0 = stop emitting
```

## Do / Don't

- **Do** bucket the FILETIME in the dedup key, identically on add and read-back.
- **Do** cap `lpDescr` (~254 bytes) on a UTF-8 boundary; keep the backing `std::string` alive across
  the call.
- **Do** treat `XWF_AddEvent` returning `0` as "stop emitting" (the store is full / declined).
- **Don't** compare raw FILETIME quad-words across runs — they won't match.
- **Don't** call `XWF_AddEvent`/`XWF_GetEvent` from a worker thread.
- **Don't** invent `nEvtType` values — use the documented subcodes ([xways-events-api.md](../xways-events-api.md));
  custom numeric types only filter cleanly from v21.9 Preview 1 (≥25000 → "Other", ≤65535).

See also: [Threading model](threading-model.md), [xways-events-api.md](../xways-events-api.md).
