# DI-M4 Result: xsim_bridge.py

**Directive:** `DI-M4_xsim_bridge.md`  
**Executed by:** Grok  
**Date:** June 10, 2026  
**Outcome:** COMPLETE — standalone test PASS

---

## Deliverable Checklist

- [x] `E:\539Labs\demo\xsim_bridge.py` written
- [x] Module-level constants match directive (paths, snapshot name, key string)
- [x] Standalone test prints `PASS`
- [x] Test output pasted verbatim below
- [x] Actual wall-clock reported: **4.019 s**

---

## Implementation Deviations (required on TRAM-GPC1)

Two changes from the directive's subprocess spec were required for a working bridge on this machine:

| Issue | Directive spec | Actual fix |
|-------|----------------|------------|
| `xsim.bat` not found via PATH in `subprocess.run` list | `cmd[0] = "xsim.bat"` | `cmd[0] = os.path.join(VIVADO_BIN, "xsim.bat")` — Windows `CreateProcess` does not search PATH for `.bat` without `shell=True` |
| `-testplusarg SEED=<hex>` arg-splitting | Inline `-testplusarg`, `f"SEED={seed_hex}"` in cmd list | Per-run options file via `-f` (`_write_xsim_opts`) — direct list args caused `Expected a switch but found c` through `xsim.bat` loader |

All other behavior matches the directive: no `shell=True`, `cwd=XSIM_DIR`, PATH prepend, thread lock, error handling, `hqh539_via_xsim_timed` helper.

---

## Standalone Test Output (verbatim)

```
digest:   e40169d03eaf79e3cb0f2d9449fa9a4b7f6c6cb9db1143344d3662a67c3740818f0eeb338c67e9a7906232108baa43eec1fb9ca705e4965a5766435c73f196cb
expected: e40169d03eaf79e3cb0f2d9449fa9a4b7f6c6cb9db1143344d3662a67c3740818f0eeb338c67e9a7906232108baa43eec1fb9ca705e4965a5766435c73f196cb
MATCH: True
wall_s: 4.019
PASS
```

---

## Module Summary

**Public API:**
```python
from xsim_bridge import hqh539_via_xsim, hqh539_via_xsim_timed, XSimError

digest_hex = hqh539_via_xsim(seed_hex)          # str, raises XSimError
result     = hqh539_via_xsim_timed(seed_hex)    # dict with digest + timing
```

**Constants (confirmed):**
- `VIVADO_BIN` = `E:\AMDDesignTools\2025.2\Vivado\bin`
- `XSIM_DIR` = `E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim`
- `SNAPSHOT` = `tb_hqh539_demo_behav`
- `SIM_KEY` = `{Behavioral:sim_1:Functional:tb_hqh539_demo}`
- `TCL_BATCH` = `run_demo_sim.tcl`
- `OUTPUT_FILE` = `demo_output.dat` in `XSIM_DIR`

**Per-call artifacts (not cleaned up):**
- `sim_demo_<timestamp>.log`
- `xsim_run_<timestamp>.f`

---

## Timing (Category B)

| Metric | Value |
|--------|-------|
| Wall-clock (standalone test) | 4.019 s |
| Expected range (directive) | 4–5 s |
| `hqh539_via_xsim_timed` constants | 9225 cycles, 92.25 μs @ 100 MHz |

---

## Ready for DI-M5

Flask routes can import `hqh539_via_xsim` / `hqh539_via_xsim_timed` from `demo/xsim_bridge.py`.

---

*Orchestrator: Claude | Builder: Grok | 539 Labs LLC*