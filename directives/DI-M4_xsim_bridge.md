# DI-M4: Build xsim_bridge.py

539 Labs LLC | HQH-539 Demo Engine Integration
**Status: ACTIVE — Awaiting Grok implementation**
Created: June 10, 2026

---

## Objective

Write `E:\539Labs\demo\xsim_bridge.py` — the Python module that Flask routes will call to
invoke XSim for a single hash computation.

Public interface:
```python
from xsim_bridge import hqh539_via_xsim, XSimError

digest_hex = hqh539_via_xsim(seed_hex)   # raises XSimError on failure
```

---

## File to Create

**Path:** `E:\539Labs\demo\xsim_bridge.py`
**Encoding:** UTF-8 (standard Python file — no BOM concern)

---

## Full Specification

### Constants (top of module, after imports)

```python
import os
import subprocess
import threading
import time

# Paths — absolute, confirmed on TRAM-GPC1
VIVADO_BIN  = r"E:\AMDDesignTools\2025.2\Vivado\bin"
XSIM_DIR    = r"E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim"
SNAPSHOT    = "tb_hqh539_demo_behav"
SIM_KEY     = r"{Behavioral:sim_1:Functional:tb_hqh539_demo}"
TCL_BATCH   = "run_demo_sim.tcl"
OUTPUT_FILE = os.path.join(XSIM_DIR, "demo_output.dat")

_lock = threading.Lock()
```

### Exception Class

```python
class XSimError(Exception):
    """Raised when XSim invocation fails or produces invalid output."""
    pass
```

### Entry Point

```python
def hqh539_via_xsim(seed_hex: str) -> str:
    """
    Compute HQH-539 Phases 2+3 via XSim hardware simulation.

    Args:
        seed_hex: Phase 1 output — 512-bit seed as hex string.
                  Variable length accepted; zero-padded to 128 chars internally.
                  Leading '0x' prefix stripped if present.

    Returns:
        128-character lowercase hex digest string.

    Raises:
        XSimError: on non-zero xsim exit, missing output file, or malformed digest.

    Note:
        Thread-safe via module-level lock. Concurrent calls are serialized.
        Per-call wall-clock: ~4.2 s on TRAM-GPC1 (Category B, includes XSim startup).
    """
    # Normalize seed to 128 lowercase hex chars
    seed_hex = seed_hex.strip().lower()
    if seed_hex.startswith("0x"):
        seed_hex = seed_hex[2:]
    seed_hex = seed_hex.zfill(128)

    if len(seed_hex) != 128:
        raise XSimError(f"seed_hex must be ≤128 hex chars after normalization, got {len(seed_hex)}")

    log_name = f"sim_demo_{int(time.time() * 1000)}.log"

    # Build environment: prepend Vivado bin to PATH
    env = os.environ.copy()
    env["PATH"] = VIVADO_BIN + os.pathsep + env.get("PATH", "")

    cmd = [
        "xsim.bat",
        SNAPSHOT,
        "-key",        SIM_KEY,
        "-tclbatch",   TCL_BATCH,
        "-testplusarg", f"SEED={seed_hex}",
        "-log",        log_name,
    ]

    with _lock:
        t0 = time.perf_counter()

        result = subprocess.run(
            cmd,
            cwd=XSIM_DIR,
            env=env,
            capture_output=True,
            text=True,
        )

        wall_s = time.perf_counter() - t0

        if result.returncode != 0:
            raise XSimError(
                f"xsim exited {result.returncode} after {wall_s:.2f}s. "
                f"Check {log_name} in {XSIM_DIR}.\n"
                f"stderr: {result.stderr[:500]}"
            )

        if not os.path.exists(OUTPUT_FILE):
            raise XSimError(
                f"demo_output.dat not found after xsim run ({wall_s:.2f}s). "
                f"Check {log_name} in {XSIM_DIR}."
            )

        with open(OUTPUT_FILE, "r") as f:
            raw = f.read().strip()

        digest = raw.lstrip("0x").lower().zfill(128)

        if len(digest) != 128 or not all(c in "0123456789abcdef" for c in digest):
            raise XSimError(
                f"Malformed digest in demo_output.dat: {raw!r}"
            )

    return digest
```

### Optional Timing Helper (add below entry point)

```python
def hqh539_via_xsim_timed(seed_hex: str) -> dict:
    """
    Same as hqh539_via_xsim but returns timing metadata alongside the digest.
    Used by Flask routes to annotate JSON responses.

    Returns:
        {
            "digest":       <128-char hex string>,
            "wall_ms":      <float, wall-clock milliseconds>,
            "sim_cycles":   9225,
            "sim_us":       92.25,
        }
    """
    t0 = time.perf_counter()
    digest = hqh539_via_xsim(seed_hex)
    wall_ms = (time.perf_counter() - t0) * 1000

    return {
        "digest":     digest,
        "wall_ms":    round(wall_ms, 1),
        "sim_cycles": 9225,
        "sim_us":     92.25,
    }
```

---

## Subprocess Invocation Notes

**Do NOT use `shell=True`.** Pass `cmd` as a list — Python's subprocess resolves `.bat`
extension correctly on Windows without shell=True.

**`-testplusarg` quoting:** When using a list (not shell=True), Python handles argument
boundaries. `f"SEED={seed_hex}"` is passed as a single argument to xsim.bat with no
additional quoting needed. (Grok's DI-M3 note about quoting applied to manual cmd.exe
invocation only, not Python subprocess list.)

**`capture_output=True`:** Captures stdout/stderr to `result.stdout` / `result.stderr`
so they don't pollute Flask's console. XSim `$display` output goes to the `-log` file,
not stdout, so nothing meaningful is lost.

**Working directory (`cwd=XSIM_DIR`):** Required because:
- `demo_output.dat` is written to cwd
- `xsim.ini` must be present in cwd (§7 gotcha in orchestrator)
- `run_demo_sim.tcl` is resolved relative to cwd
- Snapshot path resolution depends on cwd

---

## Error Handling Matrix

| Condition | Behavior |
|-----------|----------|
| xsim returncode != 0 | `XSimError` with returncode + log filename |
| `demo_output.dat` absent after run | `XSimError` with log filename |
| Digest not 128 hex chars | `XSimError` with raw content |
| seed_hex > 128 chars after normalization | `XSimError` before subprocess call |
| Threading: concurrent call | Blocked by `_lock`; serialized (not rejected) |

Flask routes catch `XSimError` and return HTTP 500 (per §5 of orchestrator — no silent fallback).

---

## Standalone Test (Grok runs this after writing the file)

From `E:\539Labs\demo\` (or any directory with access to the module):

```python
# quick_test.py — run once to verify bridge, then delete
import sys
sys.path.insert(0, r"E:\539Labs\demo")
from xsim_bridge import hqh539_via_xsim, XSimError

SEED     = "c94227733d14b7a0d35642ca3f3f422b6aec93e96c6e494850d88c4633020a79530bbf77c55dcf28ec39cf7f1f5f666127cd893ba95a359ca0812a93dcd7ee05"
EXPECTED = "e40169d03eaf79e3cb0f2d9449fa9a4b7f6c6cb9db1143344d3662a67c3740818f0eeb338c67e9a7906232108baa43eec1fb9ca705e4965a5766435c73f196cb"

try:
    digest = hqh539_via_xsim(SEED)
    match = (int(digest, 16) == int(EXPECTED, 16))
    print(f"digest:   {digest}")
    print(f"expected: {EXPECTED}")
    print(f"MATCH: {match}")
    assert match, "DIGEST MISMATCH"
    print("PASS")
except XSimError as e:
    print(f"XSimError: {e}")
```

**Success criteria:**
- Prints `PASS`
- Digest hex value equals expected (int comparison, leading zeros irrelevant)
- No exception raised

**Expected wall-clock:** ~4–5 s (Category B). Report actual time in result.

---

## Deliverable Checklist

- [ ] `E:\539Labs\demo\xsim_bridge.py` written
- [ ] Module-level constants match values above exactly (paths, snapshot name, key string)
- [ ] Standalone test prints `PASS`
- [ ] Grok pastes test output verbatim in result file
- [ ] Grok reports actual wall-clock from test run

---

## Notes

- The `_lock` is per-process. Multiple Flask workers (if any) would NOT share this lock.
  For the demo (single-threaded Flask dev server), this is sufficient.
- Log files (`sim_demo_<timestamp>.log`) accumulate in `XSIM_DIR`. The bridge does not
  clean them up. This is acceptable for demo use; add cleanup to DI-M7 if needed.
- `hqh539_via_xsim` returns only the digest string, not timing metadata. Flask routes
  that need timing should call `hqh539_via_xsim_timed` instead.
- The 9225 cycles and 92.25 μs values in `hqh539_via_xsim_timed` are constants from
  confirmed DI-M1/DI-M3 measurements — not re-measured per call.

---

*Orchestrator: Claude | Builder: Grok | 539 Labs LLC*
