import os
import subprocess
import threading
import time

# Paths — absolute, confirmed on TRAM-GPC1
VIVADO_BIN = r"E:\AMDDesignTools\2025.2\Vivado\bin"
XSIM_DIR = r"E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim"
SNAPSHOT = "tb_hqh539_demo_behav"
SIM_KEY = r"{Behavioral:sim_1:Functional:tb_hqh539_demo}"
TCL_BATCH = "run_demo_sim.tcl"
OUTPUT_FILE = os.path.join(XSIM_DIR, "demo_output.dat")

_lock = threading.Lock()


class XSimError(Exception):
    """Raised when XSim invocation fails or produces invalid output."""
    pass


def _write_xsim_opts(seed_hex: str, log_name: str) -> str:
    """Write per-run XSim options file (avoids Windows .bat arg-splitting on -testplusarg)."""
    opts_path = os.path.join(XSIM_DIR, f"xsim_run_{int(time.time() * 1000)}.f")
    content = (
        f"-key {SIM_KEY}\n"
        f"-tclbatch {TCL_BATCH}\n"
        f"-testplusarg SEED={seed_hex}\n"
        f"-log {log_name}\n"
    )
    with open(opts_path, "w", encoding="utf-8") as f:
        f.write(content)
    return opts_path


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
    opts_path = _write_xsim_opts(seed_hex, log_name)

    # Build environment: prepend Vivado bin to PATH
    env = os.environ.copy()
    env["PATH"] = VIVADO_BIN + os.pathsep + env.get("PATH", "")

    cmd = [
        os.path.join(VIVADO_BIN, "xsim.bat"),
        SNAPSHOT,
        "-f",
        opts_path,
    ]

    with _lock:
        t0 = time.perf_counter()

        try:
            result = subprocess.run(
                cmd,
                cwd=XSIM_DIR,
                env=env,
                capture_output=True,
                text=True,
                timeout=200,
            )
        except subprocess.TimeoutExpired:
            raise XSimError("xsim did not complete within 200 s — process timed out.")

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
        "digest": digest,
        "wall_ms": round(wall_ms, 1),
        "sim_cycles": 9225,
        "sim_us": 92.25,
    }