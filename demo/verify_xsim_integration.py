"""
verify_xsim_integration.py — DI-M8 XSim hardware verification
539 Labs LLC | Authored by Orchestrator (Claude)

Assumes Flask is ALREADY RUNNING on port 5391 with HQH539_USE_XSIM=true.
Start it first:
    $env:HQH539_USE_XSIM="true"; python E:\\539Labs\\demo\\app.py

Run:
    python verify_xsim_integration.py

Exit 0 = all PASS. Exit 1 = any FAIL.
"""
import sys
import json
import os
from urllib.request import urlopen, Request
from urllib.error import URLError

# Tee all output to a log file — independent of shell redirect
_LOG = open(r"E:\539Labs\demo\verify_m8_run.log", "w", buffering=1, encoding="utf-8")
_orig_stdout = sys.stdout
class _Tee:
    def write(self, s):
        _orig_stdout.write(s); _orig_stdout.flush()
        _LOG.write(s); _LOG.flush()
    def flush(self):
        _orig_stdout.flush(); _LOG.flush()
sys.stdout = _Tee()

sys.path.insert(0, r'E:\539Labs')
from python.hqh539 import hqh539

BASE = "http://localhost:5391"
PASS_COUNT = 0
FAIL_COUNT = 0

# ---------------------------------------------------------------------------
# 10 test vectors — diverse messages covering edge-case lengths and charsets
# ---------------------------------------------------------------------------
VECTORS = [
    "Hello, World!",
    "539 Labs",
    "The quick brown fox jumps over the lazy dog",
    "a",
    "HQH-539 Demo Engine",
    "XSim hardware integration test",
    "Truman Fuller",
    "S2-11DM2ET-X Minimal Unification Core v1.5",
    "abc",
    "539-LABS-2026",
]


def post(path, payload, timeout=20):
    data = json.dumps(payload).encode()
    req = Request(BASE + path, data=data,
                  headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def get(path):
    with urlopen(BASE + path, timeout=10) as r:
        return json.loads(r.read())


def check(label, passed, actual=""):
    global PASS_COUNT, FAIL_COUNT
    if passed:
        PASS_COUNT += 1
    else:
        FAIL_COUNT += 1
    status = "PASS" if passed else "FAIL"
    suffix = f"  (got: {actual})" if not passed and actual != "" else \
             (f"  ({actual})" if actual else "")
    print(f"  [{status}] {label}{suffix}")


# ---------------------------------------------------------------------------
# Pre-flight: confirm server is reachable and hardware mode is available
# ---------------------------------------------------------------------------
print("HQH-539 XSim Integration Verification — DI-M8")
print("=" * 60)

try:
    urlopen(BASE + "/", timeout=3)
except (URLError, OSError) as e:
    print(f"FATAL: Flask not reachable at {BASE}. Start with HQH539_USE_XSIM=true first.")
    print(f"       ({e})")
    sys.exit(1)

try:
    mode_state = get("/api/get_mode")
    xsim_available = mode_state.get("available", False)
except Exception as e:
    print(f"FATAL: /api/get_mode failed: {e}")
    sys.exit(1)

if not xsim_available:
    print("FATAL: xsim_available=False. Flask was not started with HQH539_USE_XSIM=true.")
    print("       Restart Flask: $env:HQH539_USE_XSIM=\"true\"; python app.py")
    sys.exit(1)

# Enable hardware mode
try:
    post("/api/set_mode", {"mode": "hardware"})
    state = get("/api/get_mode")
    assert state.get("mode") == "hardware"
    print("Hardware mode: ON")
except Exception as e:
    print(f"FATAL: Could not enable hardware mode: {e}")
    sys.exit(1)

print()

# ---------------------------------------------------------------------------
# Core DI-M8 check: 10 vectors via XSim, bit-identical to Python hqh539()
# ---------------------------------------------------------------------------
print("=== XSim Hardware Hash Verification (N=10) ===")

for i, message in enumerate(VECTORS):
    label_short = repr(message) if len(message) <= 20 else repr(message[:17] + "...")
    try:
        r = post("/api/hash", {"message": message, "mode": "STD"}, timeout=180)

        digest_hw   = r.get("digest", "")
        digest_py   = hqh539(message.encode("utf-8"), mode="STD")
        is_hw       = r.get("hardware", False)
        wall_ms     = r.get("wall_ms", 0)

        match = (digest_hw.lower() == digest_py.lower())
        check(f"Vector {i+1:2d} {label_short}: hardware==True",
              is_hw, str(is_hw))
        check(f"Vector {i+1:2d} {label_short}: digest bit-identical",
              match, f"hw={digest_hw[:12]}… py={digest_py[:12]}…" if not match else "")
        if is_hw:
            print(f"           wall_ms={wall_ms:.0f}  digest={digest_hw[:16]}…")

    except Exception as e:
        check(f"Vector {i+1:2d} {label_short}: request succeeded", False, str(e))
        check(f"Vector {i+1:2d} {label_short}: digest bit-identical", False)

print()

# ---------------------------------------------------------------------------
# Encrypt / Decrypt round-trips (Python path — always)
# ---------------------------------------------------------------------------
print("=== Encrypt/Decrypt Round-Trip (Python path) ===")
ct_hex = salt_hex = None
try:
    r = post("/api/encrypt", {"plaintext": "Hello 539 Labs", "password": "test"})
    ct_hex   = r.get("ciphertext", "")
    salt_hex = r.get("salt", "")
    check("Encrypt returns non-empty ciphertext", len(ct_hex) > 0)
except Exception as e:
    check("Encrypt request succeeded", False, str(e))

if ct_hex and salt_hex:
    try:
        r = post("/api/decrypt",
                 {"ciphertext": ct_hex, "salt": salt_hex, "password": "test"})
        check("Correct password decrypts to 'Hello 539 Labs'",
              r.get("ok") and r.get("plaintext") == "Hello 539 Labs",
              repr(r.get("plaintext")))
    except Exception as e:
        check("Decrypt (correct password)", False, str(e))

    try:
        r = post("/api/decrypt",
                 {"ciphertext": ct_hex, "salt": salt_hex, "password": "wrong"})
        check("Wrong password returns ok==False", not r.get("ok", True))
    except URLError:
        check("Wrong password returns error (HTTP 4xx)", True, "HTTP error")

print()

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
total = PASS_COUNT + FAIL_COUNT
print("=" * 60)
print(f"Result: {PASS_COUNT}/{total} passed")
if FAIL_COUNT == 0:
    print("ALL CHECKS PASS — DI-M8 XSim integration verification complete.")
else:
    print(f"{FAIL_COUNT} check(s) FAILED — do not mark DI-M8 complete.")
print("=" * 60)
sys.exit(0 if FAIL_COUNT == 0 else 1)
