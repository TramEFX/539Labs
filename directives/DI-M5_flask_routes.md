# DI-M5: Modify Flask Routes

539 Labs LLC | HQH-539 Demo Engine Integration
**Status: ACTIVE — Awaiting Grok implementation**
Created: June 10, 2026

---

## Objective

Modify `E:\539Labs\demo\app.py` to:
1. Import and gate `xsim_bridge`
2. Add a runtime hardware/software mode toggle (no Flask restart required)
3. Route `/api/hash` through XSim when hardware mode is active (STD mode only)
4. Return timing metadata in all hash responses
5. Keep `/api/encrypt` and `/api/decrypt` Python-only (SALT_KDF incompatible with RTL)

**Design decision (confirmed by Orchestrator):**
XSim backend applies to `/api/hash` only, and only when `mode == "STD"` (the default).
All other routes and all non-STD modes remain Python regardless of hardware mode setting.

---

## Changes to app.py — Full Diff

### 1. New imports (add after existing imports)

```python
# XSim bridge — imported conditionally; XSimError only available if XSIM_AVAILABLE
import os as _os
XSIM_AVAILABLE = _os.getenv("HQH539_USE_XSIM", "false").lower() == "true"
if XSIM_AVAILABLE:
    import xsim_bridge
    from xsim_bridge import XSimError
```

**Note:** `app.py` already imports `os` (used in `/api/encrypt`). Use `_os` alias for the
env-var check, or simply reuse the existing `os` import — whichever Grok prefers. The
important constraint: `xsim_bridge` is only imported when `XSIM_AVAILABLE` is True. This
ensures `HQH539_USE_XSIM=false` (the default) runs cleanly on any machine without Vivado.

### 2. Runtime mode state (add after BENCHMARK_DATA block)

```python
# Runtime hardware/software toggle — changed via /api/set_mode without restarting Flask
# Only effective when XSIM_AVAILABLE is True
_use_xsim_runtime = False

def _hardware_mode_active():
    """True iff XSim is available AND the runtime toggle is on."""
    return XSIM_AVAILABLE and _use_xsim_runtime
```

### 3. New helper: compute_hash_xsim (add after compute_trace)

```python
def compute_hash_xsim(message_bytes, salt_bytes):
    """
    XSim path for /api/hash.
    Phase 1 in Python; Phases 2+3 via XSim RTL.
    Returns (digest, timing_dict) — no trace available in hardware mode.
    """
    seed = int.from_bytes(
        hashlib.sha3_512(message_bytes + salt_bytes).digest(), 'big'
    )
    seed_hex = hex(seed)[2:].zfill(128)
    timing = xsim_bridge.hqh539_via_xsim_timed(seed_hex)
    return timing['digest'], timing
```

### 4. Modify /api/hash

Replace the existing `/api/hash` route body with:

```python
@app.route('/api/hash', methods=['POST'])
def api_hash():
    data    = request.get_json()
    msg     = data['message'].encode('utf-8')
    mode    = data.get('mode', 'STD')
    salt    = resolve_salt(mode)

    # Use XSim when: hardware mode active AND mode is STD (only mode RTL supports)
    if _hardware_mode_active() and mode.upper() == 'STD':
        try:
            digest, timing = compute_hash_xsim(msg, salt)
            return jsonify({
                'digest':        digest,
                'trace':         None,        # not available in hardware mode
                'phase_boundary': 18,
                'hardware':      True,
                'sim_cycles':    timing['sim_cycles'],
                'sim_us':        timing['sim_us'],
                'wall_ms':       timing['wall_ms'],
            })
        except XSimError as e:
            return jsonify({'error': str(e)}), 500

    # Python path (default)
    trace, digest = compute_trace(msg, salt)
    return jsonify({
        'digest':        digest,
        'trace':         trace,
        'phase_boundary': 18,
        'hardware':      False,
    })
```

### 5. Add /api/set_mode and /api/get_mode (add before /api/benchmarks)

```python
@app.route('/api/set_mode', methods=['POST'])
def api_set_mode():
    """Switch between software and hardware simulation mode at runtime."""
    global _use_xsim_runtime
    data       = request.get_json()
    requested  = data.get('mode', 'software')   # 'software' | 'hardware'
    if requested == 'hardware' and not XSIM_AVAILABLE:
        return jsonify({
            'mode':  'software',
            'error': 'Hardware mode unavailable: HQH539_USE_XSIM not set'
        }), 400
    _use_xsim_runtime = (requested == 'hardware')
    return jsonify({'mode': 'hardware' if _use_xsim_runtime else 'software'})


@app.route('/api/get_mode', methods=['GET'])
def api_get_mode():
    """Return current simulation mode and availability."""
    return jsonify({
        'mode':      'hardware' if _hardware_mode_active() else 'software',
        'available': XSIM_AVAILABLE,
    })
```

### 6. /api/encrypt and /api/decrypt — NO CHANGES

Leave both routes exactly as they are. They use `hqh539_kdf` with `SALT_KDF`, which is
incompatible with the RTL's hardcoded `SALT_STD`. They are Python-only permanently.
Do not add XSim branching to these routes.

---

## Verification Test (Grok runs after writing)

**Test A — Software mode (should always work):**

Start Flask: `python app.py` (without `HQH539_USE_XSIM=true`)

```python
import requests, json

r = requests.post("http://localhost:5391/api/hash",
                  json={"message": "hello", "mode": "STD"})
d = r.json()
assert d['hardware'] == False
assert len(d['digest']) > 0
assert d['trace'] is not None and len(d['trace']) == 540
print("Test A PASS:", d['digest'][:16], "...")
```

**Test B — Hardware mode (requires `HQH539_USE_XSIM=true`):**

Restart Flask with env var: `$env:HQH539_USE_XSIM="true"; python app.py`

```python
import requests, time

# Enable hardware mode
r = requests.post("http://localhost:5391/api/set_mode", json={"mode": "hardware"})
assert r.json()['mode'] == 'hardware', f"set_mode failed: {r.json()}"

# Hash in hardware mode
t0 = time.perf_counter()
r = requests.post("http://localhost:5391/api/hash",
                  json={"message": "hello", "mode": "STD"})
wall = time.perf_counter() - t0
d = r.json()
assert d['hardware'] == True,         f"hardware flag wrong: {d}"
assert d['trace'] is None,            f"trace should be None in hardware mode: {d}"
assert d.get('sim_cycles') == 9225,   f"sim_cycles wrong: {d}"
assert len(d['digest']) == 128,       f"digest length wrong: {d}"
print(f"Test B PASS: {d['digest'][:16]}... wall={wall:.1f}s sim_us={d['sim_us']}")

# Verify same digest as Python mode
requests.post("http://localhost:5391/api/set_mode", json={"mode": "software"})
r2 = requests.post("http://localhost:5391/api/hash",
                   json={"message": "hello", "mode": "STD"})
assert r2.json()['digest'] == d['digest'], "DIGEST MISMATCH between hardware and software modes"
print("Test B digest cross-check PASS")
```

**Test C — get_mode endpoint:**
```python
r = requests.get("http://localhost:5391/api/get_mode")
print("get_mode:", r.json())   # {'mode': 'software', 'available': True/False}
```

**Test D — set_mode rejects hardware when unavailable:**
Run without `HQH539_USE_XSIM=true`:
```python
r = requests.post("http://localhost:5391/api/set_mode", json={"mode": "hardware"})
assert r.status_code == 400
print("Test D PASS: hardware rejected when unavailable")
```

---

## Deliverable Checklist

- [ ] `app.py` modified in-place
- [ ] `XSIM_AVAILABLE` gate: `xsim_bridge` imported only when env var is true
- [ ] `_use_xsim_runtime` state + `_hardware_mode_active()` helper present
- [ ] `compute_hash_xsim` helper present
- [ ] `/api/hash` has XSim branch (STD-only) and Python fallback
- [ ] `/api/set_mode` and `/api/get_mode` present and working
- [ ] `/api/encrypt` and `/api/decrypt` UNCHANGED
- [ ] Test A PASS (software mode, no env var)
- [ ] Test B PASS (hardware mode, digest cross-check passes)
- [ ] Grok reports actual hardware-mode wall_ms from Test B response

---

## Notes

- The `HQH539_USE_XSIM` env var controls availability (is XSim configured on this machine?).
  The `/api/set_mode` toggle controls whether it's actually used for requests.
  Both must be true for hardware mode to activate.
- Non-STD mode requests always use Python, even in hardware mode. This is intentional and
  documented in the response — the `hardware: False` field in the Python-path response tells
  the UI not to show a hardware badge.
- `XSimError` propagates as HTTP 500. There is NO silent fallback to Python when XSim fails
  in hardware mode. This is per §5 of the orchestrator — a failed hardware computation
  must surface, not silently return a software result.
- The wall_ms in the JSON response reflects the total bridge call time (~4000 ms).
  sim_us (92.25) reflects RTL simulation time only. Both are meaningful for the UI.
- Do not modify BENCHMARK_DATA — that block is read-only data for /api/benchmarks.

---

*Orchestrator: Claude | Builder: Grok | 539 Labs LLC*
