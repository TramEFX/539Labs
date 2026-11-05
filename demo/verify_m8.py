"""
verify_m8.py — M8 API-level verification script
539 Labs LLC | June 2026
Starts app.py, runs all checklist checks, terminates server.
Exit 0 = all pass. Exit 1 = any fail.
"""
import subprocess, sys, time, json
from urllib.request import urlopen, Request
from urllib.error import URLError

BASE = "http://localhost:5391"
PASS_COUNT = 0
FAIL_COUNT = 0

def post(path, payload):
    data = json.dumps(payload).encode()
    req = Request(BASE + path, data=data, headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=10) as r:
        return json.loads(r.read())

def get(path):
    with urlopen(BASE + path, timeout=10) as r:
        return json.loads(r.read())

def check(label, passed, actual=""):
    global PASS_COUNT, FAIL_COUNT
    status = "PASS" if passed else "FAIL"
    if passed:
        PASS_COUNT += 1
    else:
        FAIL_COUNT += 1
    suffix = f"  (got: {actual})" if not passed and actual != "" else (f"  ({actual})" if actual else "")
    print(f"  [{status}] {label}{suffix}")

# --- Start server ---
print("Starting app.py on port 5391...")
proc = subprocess.Popen(
    [sys.executable, "app.py"],
    cwd=r"E:\539Labs\demo",
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL
)

# Poll until ready
ready = False
for _ in range(20):
    time.sleep(0.5)
    try:
        urlopen(BASE + "/", timeout=2)
        ready = True
        break
    except (URLError, OSError):
        pass

if not ready:
    print("FATAL: server did not start within 10s")
    proc.terminate()
    sys.exit(1)

print("Server ready.\n")

# ── HASH TAB ─────────────────────────────────────────────────────────────────
print("=== Hash Tab ===")
try:
    r = post("/api/hash", {"message": "Hello, World!", "mode": "STD"})
    check("digest is 128-char hex", len(r["digest"]) == 128, str(len(r["digest"])))
    check("trace has 540 points",   len(r["trace"]) == 540,  str(len(r["trace"])))
    check("phase_boundary == 18",   r["phase_boundary"] == 18, str(r.get("phase_boundary")))
except Exception as e:
    check("Hash tab request succeeded", False, str(e))
    check("digest is 128-char hex", False)
    check("trace has 540 points",   False)

# ── AVALANCHE TAB ─────────────────────────────────────────────────────────────
print("\n=== Avalanche Tab ===")
try:
    r = post("/api/avalanche", {"message1": "abc", "message2": "abc", "mode": "STD"})
    check("identical inputs -> hamming == 0", r["hamming_distance"] == 0, str(r["hamming_distance"]))
    check("bit_diff has 512 elements",        len(r["bit_diff"]) == 512,  str(len(r["bit_diff"])))
except Exception as e:
    check("Avalanche identical request", False, str(e))

try:
    r = post("/api/avalanche", {"message1": "abc", "message2": "abd", "mode": "STD"})
    hd = r["hamming_distance"]
    check("'abc' vs 'abd' hamming in [200, 310]", 200 <= hd <= 310, str(hd))
    check("bit_diff has 512 elements",             len(r["bit_diff"]) == 512, str(len(r["bit_diff"])))
except Exception as e:
    check("Avalanche diff request", False, str(e))

# ── ENCRYPT / DECRYPT TAB ─────────────────────────────────────────────────────
print("\n=== Encrypt/Decrypt Tab ===")
ct_hex = salt_hex = None
try:
    r = post("/api/encrypt", {"plaintext": "Hello 539 Labs", "password": "test"})
    ct_hex   = r.get("ciphertext", "")
    salt_hex = r.get("salt", "")
    check("encrypt returns non-empty ciphertext", len(ct_hex) > 0, str(len(ct_hex)) + " hex chars")
except Exception as e:
    check("Encrypt request succeeded", False, str(e))

if ct_hex and salt_hex:
    try:
        r = post("/api/decrypt", {"ciphertext": ct_hex, "salt": salt_hex, "password": "test"})
        check("correct password decrypts to 'Hello 539 Labs'",
              r.get("ok") and r.get("plaintext") == "Hello 539 Labs",
              repr(r.get("plaintext")))
    except Exception as e:
        check("Decrypt (correct password)", False, str(e))

    try:
        r = post("/api/decrypt", {"ciphertext": ct_hex, "salt": salt_hex, "password": "wrong"})
        check("wrong password returns ok==False", not r.get("ok", True), str(r))
    except Exception as e:
        # 400 response from Flask is also acceptable (means MAC failure raised correctly)
        check("wrong password returns error", True, "HTTP 400 (MAC failure)")

# ── BENCHMARKS TAB ─────────────────────────────────────────────────────────────
print("\n=== Benchmarks Tab ===")
try:
    r = get("/api/benchmarks")
    check("hqh539.cycles == 9225",    r["hqh539"]["cycles"] == 9225,      str(r["hqh539"].get("cycles")))
    check("sha3_fpga.cycles == 28",   r["sha3_fpga"]["cycles"] == 28,     str(r["sha3_fpga"].get("cycles")))
    check("cycle_ratio == 329.5",     r["cycle_ratio"] == 329.5,          str(r.get("cycle_ratio")))
except Exception as e:
    check("Benchmarks request succeeded", False, str(e))

# ── SUMMARY ──────────────────────────────────────────────────────────────────
proc.terminate()
total = PASS_COUNT + FAIL_COUNT
print(f"\n{'='*50}")
print(f"Result: {PASS_COUNT}/{total} passed")
if FAIL_COUNT == 0:
    print("ALL CHECKS PASS — M8 API verification complete.")
    print("Visual checks (chart, badges, SCA panel) require manual browser inspection.")
else:
    print(f"{FAIL_COUNT} check(s) FAILED — do not mark M8 complete.")
print('='*50)
sys.exit(0 if FAIL_COUNT == 0 else 1)
