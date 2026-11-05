# DI-M5 Result: Flask Routes Modified

**Directive:** `DI-M5_flask_routes.md`  
**Executed by:** Grok  
**Date:** June 10, 2026  
**Outcome:** COMPLETE — all verification tests PASS

---

## Deliverable Checklist

- [x] `app.py` modified in-place
- [x] `XSIM_AVAILABLE` gate: `xsim_bridge` imported only when env var is true
- [x] `_use_xsim_runtime` state + `_hardware_mode_active()` helper present
- [x] `compute_hash_xsim` helper present
- [x] `/api/hash` has XSim branch (STD-only) and Python fallback
- [x] `/api/set_mode` and `/api/get_mode` present and working
- [x] `/api/encrypt` and `/api/decrypt` UNCHANGED
- [x] Test A PASS (software mode, no env var)
- [x] Test B PASS (hardware mode, digest cross-check passes)
- [x] Hardware-mode `wall_ms` from Test B: **3983.1 ms**

---

## Changes Applied to `app.py`

1. Conditional `xsim_bridge` / `XSimError` import gated on `HQH539_USE_XSIM`
2. Runtime toggle: `_use_xsim_runtime`, `_hardware_mode_active()`
3. `compute_hash_xsim()` — Phase 1 Python, Phases 2+3 via `hqh539_via_xsim_timed`
4. `/api/hash` — hardware branch (STD only) with timing metadata; Python fallback with `hardware: false`
5. `/api/set_mode` (POST) and `/api/get_mode` (GET) added before `/api/benchmarks`
6. `/api/encrypt` and `/api/decrypt` — no changes

### Additional fix (required on TRAM-GPC1)

```python
if __name__ == '__main__':
    _xsim_env = os.getenv("HQH539_USE_XSIM", "false").strip().lower() == "true"
    app.run(debug=True, port=5391, use_reloader=not _xsim_env)
```

Werkzeug debug reloader spawns a child process that re-imports `app.py` without `HQH539_USE_XSIM`, leaving `XSIM_AVAILABLE=False` in the serving process. Disabling reloader when XSim is enabled fixes `$env:HQH539_USE_XSIM="true"; python app.py`.

Also added `.strip()` to env-var parsing (cmd `set VAR=true` can leave trailing space).

---

## Verification Test Output (verbatim)

### Test A — Software mode (no `HQH539_USE_XSIM`)

```
Test A PASS: 6876ccc576a48785 ...
get_mode: {'available': False, 'mode': 'software'}
Test D PASS: hardware rejected when unavailable
```

### Test C — get_mode (software server)

```
get_mode: {'available': False, 'mode': 'software'}
```

### Test B — Hardware mode (`$env:HQH539_USE_XSIM="true"; python app.py`)

```
{'available': True, 'mode': 'software'}
Test B PASS: 6876ccc576a48785... wall=6.0s sim_us=92.25 wall_ms=3983.1
Test B digest cross-check PASS
```

**Hardware response fields (from `/api/hash`):**
- `hardware`: `true`
- `trace`: `null`
- `sim_cycles`: `9225`
- `sim_us`: `92.25`
- `wall_ms`: `3983.1`
- `digest`: matches Python-mode digest for `message="hello"`, `mode="STD"`

### Test D — Hardware rejected when unavailable

Confirmed via Test A run (status 400, `available: false`).

---

## API Summary

| Endpoint | Change |
|----------|--------|
| `POST /api/hash` | XSim when `_hardware_mode_active()` AND `mode==STD`; else Python |
| `POST /api/set_mode` | `{"mode":"software"\|"hardware"}` — runtime toggle |
| `GET /api/get_mode` | `{"mode":..., "available":...}` |
| `POST /api/encrypt` | Unchanged (Python-only) |
| `POST /api/decrypt` | Unchanged (Python-only) |

**Activation requires both:**
1. `HQH539_USE_XSIM=true` at Flask startup (availability)
2. `POST /api/set_mode {"mode":"hardware"}` (runtime toggle)

---

## Ready for DI-M6

UI can poll `/api/get_mode`, call `/api/set_mode`, and display `hardware`, `wall_ms`, `sim_us`, `sim_cycles` from `/api/hash` responses.

---

*Orchestrator: Claude | Builder: Grok | 539 Labs LLC*