# M8 Directive — Demonstration Engine
**539 Labs LLC | HQH-539 | June 8, 2026**
**Status: M7 COMPLETE → M8 IN PROGRESS**

---

## Objective

Build a single-page Python Flask web application that demonstrates HQH-539
to an informed audience. All computation uses `hqh539.py` as the sole
canonical reference — no local reimplementation of T3 or any hash logic.

**Four demonstration panels:**
1. **Hash** — Compute digest + visualize 539-step state trajectory
2. **Avalanche** — Compare two inputs, show bit-difference heatmap
3. **Encrypt/Decrypt** — HQH539-KDF + ChaCha20-Poly1305 AEAD
4. **Benchmarks** — M7 measured results + SCA status table

---

## File Layout

Create the following structure. All paths are absolute.

```
E:\539Labs\
└── demo\
    ├── app.py
    ├── requirements.txt
    └── templates\
        └── index.html
```

Use `[System.IO.File]::WriteAllText(path, content, (New-Object System.Text.UTF8Encoding $false))`
for ALL files. No UTF-8 BOM.

---

## Step 1 — requirements.txt

```
flask>=3.0
cryptography>=42.0
```

Install: `pip install flask cryptography`

---

## Step 2 — app.py

Write `E:\539Labs\demo\app.py` exactly as specified below.

### app.py — Imports and constants

```python
import sys, os, hashlib, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'python'))
from hqh539 import T3, STEPS, DOMAIN_SEP, hqh539_kdf, _SALT_MAP

from flask import Flask, request, jsonify, render_template
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305

app = Flask(__name__)

# M7 benchmark data — all values simulation-confirmed or measured
BENCHMARK_DATA = {
    "hqh539": {
        "label": "HQH-539 Full Pipeline",
        "cycles": 9225,
        "latency_us": 92.25,
        "throughput_hs": 10840,
        "sim_result": "100/100 PASS"
    },
    "sha3_fpga": {
        "label": "SHA3-512 Standalone FPGA",
        "cycles": 28,
        "latency_us": 0.28,
        "throughput_hs": 3571429,
        "fmax_mhz_synth": 370.5,
        "sim_result": "10/10 PASS"
    },
    "sha3_cpu": {
        "label": "SHA3-512 CPU (Python hashlib)",
        "latency_us": 0.948,
        "throughput_hs": 1055000
    },
    "cycle_ratio": 329.5,
    "note": "329.5x ratio (9225/28) is cycle-count only — clock-independent."
}
```

### app.py — Helper functions

```python
def compute_trace(message_bytes, salt_bytes):
    """Run Phase 1 + Phase 2 + Phase 3. Return step trace and final digest."""
    seed = int.from_bytes(
        hashlib.sha3_512(message_bytes + salt_bytes).digest(), 'big'
    )
    trace = [seed.bit_length()]
    state = seed
    for _ in range(STEPS):
        state = T3(state)
        trace.append(state.bit_length())
    state_bytes = state.to_bytes(32, 'big')
    digest = hashlib.sha3_512(state_bytes + salt_bytes + DOMAIN_SEP).digest().hex()
    return trace, digest    # trace: list of 540 ints (bit_length at step 0..539)


def bit_diff_array(hex1, hex2):
    """Return 512-element list: 1=bit differs, 0=same. MSB first."""
    xor = int(hex1, 16) ^ int(hex2, 16)
    return [(xor >> (511 - i)) & 1 for i in range(512)]


def resolve_salt(mode):
    return _SALT_MAP.get(mode.upper(), _SALT_MAP['STD'])
```

### app.py — Routes

```python
@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/hash', methods=['POST'])
def api_hash():
    data = request.get_json()
    msg = data['message'].encode('utf-8')
    salt = resolve_salt(data.get('mode', 'STD'))
    trace, digest = compute_trace(msg, salt)
    return jsonify({
        'digest': digest,
        'trace': trace,           # 540 values: step 0 = seed, step 539 = final
        'phase_boundary': 18      # holographic entry / master tower split
    })


@app.route('/api/avalanche', methods=['POST'])
def api_avalanche():
    data = request.get_json()
    salt = resolve_salt(data.get('mode', 'STD'))
    _, d1 = compute_trace(data['message1'].encode('utf-8'), salt)
    _, d2 = compute_trace(data['message2'].encode('utf-8'), salt)
    diff = bit_diff_array(d1, d2)
    hamming = sum(diff)
    return jsonify({
        'digest1': d1, 'digest2': d2,
        'bit_diff': diff,
        'hamming_distance': hamming,
        'pct': round(hamming / 512 * 100, 1)
    })


@app.route('/api/encrypt', methods=['POST'])
def api_encrypt():
    data = request.get_json()
    pt = data['plaintext'].encode('utf-8')
    pw = data['password'].encode('utf-8')
    salt = os.urandom(32)
    km = hqh539_kdf(secret=pw, salt=salt, info=b'HQH539-DEMO-ENC-v1', length=44)
    key, nonce = km[:32], km[32:]          # 32-byte key, 12-byte nonce
    ct = ChaCha20Poly1305(key).encrypt(nonce, pt, None)   # ct includes 16-byte tag
    return jsonify({
        'salt': salt.hex(),
        'ciphertext': ct.hex(),
        'kdf_key': key.hex(),
        'nonce': nonce.hex()
    })


@app.route('/api/decrypt', methods=['POST'])
def api_decrypt():
    data = request.get_json()
    try:
        ct  = bytes.fromhex(data['ciphertext'])
        salt = bytes.fromhex(data['salt'])
        pw  = data['password'].encode('utf-8')
        km  = hqh539_kdf(secret=pw, salt=salt, info=b'HQH539-DEMO-ENC-v1', length=44)
        key, nonce = km[:32], km[32:]
        pt = ChaCha20Poly1305(key).decrypt(nonce, ct, None)
        return jsonify({'plaintext': pt.decode('utf-8'), 'ok': True})
    except Exception as e:
        return jsonify({'error': str(e), 'ok': False}), 400


@app.route('/api/benchmarks')
def api_benchmarks():
    return jsonify(BENCHMARK_DATA)


if __name__ == '__main__':
    app.run(debug=True, port=5391)
```

---

## Step 3 — templates/index.html

Single HTML file. No external static files. Use CDN links below.

**Required CDN scripts (cdnjs.cloudflare.com):**
```html
<link rel="stylesheet"
  href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.3/css/bootstrap.min.css">
<script
  src="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.3/js/bootstrap.bundle.min.js"></script>
<script
  src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.3/chart.umd.min.js"></script>
```

Use Bootstrap's dark theme: `<html lang="en" data-bs-theme="dark">`.

**Page title:** `HQH-539 Demonstration Engine | 539 Labs`

---

### Tab 1 — Hash

**Controls:**
- `<textarea>` for message (placeholder: `"Enter any message..."`, rows=3)
- `<select>` for mode: options STD (default), KDF, SIG
- Button: "Compute Hash"

**On click:** POST `/api/hash` with `{message, mode}`.

**Output:**
- Digest display: full 128-char hex in `<code>` block, monospace
- **Step trajectory chart** (Chart.js line chart):
  - X-axis: step index 0–539, label "Step"
  - Y-axis (left): bit_length, label "State Bit Width"
  - Dataset 1: `trace` array, color `rgba(0, 200, 150, 0.9)`, label "State Bit Width"
  - No point markers (pointRadius: 0), smooth tension: 0.2
  - **Phase boundary vertical line at x=18**: implement as a custom Chart.js plugin
    registered before chart creation:

```javascript
const phaseBoundaryPlugin = {
  id: 'phaseBoundary',
  afterDraw(chart) {
    const {ctx, chartArea, scales} = chart;
    const x = scales.x.getPixelForValue(18);
    ctx.save();
    ctx.strokeStyle = 'rgba(255, 200, 0, 0.9)';
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]);
    ctx.beginPath();
    ctx.moveTo(x, chartArea.top);
    ctx.lineTo(x, chartArea.bottom);
    ctx.stroke();
    // Label
    ctx.fillStyle = 'rgba(255, 200, 0, 0.9)';
    ctx.font = '11px monospace';
    ctx.fillText('← Entry | Master Tower →', x + 5, chartArea.top + 15);
    ctx.restore();
  }
};
Chart.register(phaseBoundaryPlugin);
```

  - Show below the chart: two small badges — "Steps 0–17: Holographic Entry Phase"
    and "Steps 18–538: Master Tower Traversal" with tooltip text from §8 of master doc.

---

### Tab 2 — Avalanche

**Controls:**
- Input 1: "Original Message" (text input)
- Input 2: "Modified Message" (text input, pre-fill with same value as input 1)
  - When input 1 changes, auto-copy to input 2 (user then edits one char)
- Mode selector (same as Hash tab)
- Button: "Compare"

**On click:** POST `/api/avalanche` with `{message1, message2, mode}`.

**Output:**
- Two digest blocks side by side (col-6 / col-6)
- Hamming distance: large number display + percentage of 512 bits
  - Color: green if 220–290 (near-ideal), yellow otherwise
- **Bit difference grid**: render `bit_diff` array (512 elements) as a 32×16 grid of
  small squares. Use `<canvas>` element, draw with 2D context.
  - Cell size: 12×12 px with 1px gap
  - Color: `#ff4444` for diff=1, `#333333` for diff=0
  - Canvas total: 32 cols × 13 = 416px wide, 16 rows × 13 = 208px tall
  - Label above: "512-bit Difference Map (red = flipped bit)"

---

### Tab 3 — Encrypt / Decrypt

**Encrypt section:**
- Plaintext textarea (rows=4)
- Password input (type=text for demo clarity)
- Button: "Encrypt with HQH539-KDF + ChaCha20-Poly1305"
- Output box: shows `salt`, `ciphertext` hex values for copy-paste into Decrypt section
- Expandable "Key material" section showing `kdf_key` and `nonce` (collapsed by default)
- Security note below (pre-written, see below)

**Decrypt section** (below a `<hr>`):
- Ciphertext input (textarea)
- Salt input
- Password input
- Button: "Decrypt"
- Output: plaintext or error message

**Security note (copy verbatim):**
```
Encryption construction: HQH539-KDF (HKDF-style, §hqh539_kdf) →
ChaCha20-Poly1305 (AEAD). 44-byte key material derived per encryption;
32 bytes → ChaCha20 key, 12 bytes → nonce. Authenticated: wrong password
or tampered ciphertext returns a MAC failure error.
Security rests on HQH-539 behaving as a PRF (Category B — proprietary
framework claim, S²-11DM²ET-X v1.5, not independently verified).
ChaCha20-Poly1305 security is Category A (RFC 8439).
```

---

### Tab 4 — Benchmarks

On tab activation, GET `/api/benchmarks` (or fetch on page load and cache).

**Render two sections:**

**Section A — Throughput Comparison Table:**
| Metric | HQH-539 Full Pipeline | SHA3-512 FPGA | SHA3-512 CPU |
|---|---|---|---|
| Cycles / hash | 9,225 | 28 | — |
| Latency @ 100 MHz | 92.25 μs | 0.280 μs | 0.948 μs |
| Throughput | ~10,840 H/s | ~3,571,429 H/s | ~1,055,000 H/s |
| Simulation | 100/100 PASS | 10/10 PASS | measured |

Below table: note — "Cycle-count ratio: **329.5×** (SHA3-512 standalone is 329.5× faster
than HQH-539 at 100 MHz). Lower throughput is by design: the 539-iteration T4121
computation is the security primitive."

SHA3-512 FPGA Fmax estimate (synthesis, pre-route): ~370.5 MHz.

**Section B — SCA Status Panel:**
Render as a card with these rows:

| Property | Value | Category |
|---|---|---|
| Latency variance | Zero (confirmed M1, 100/100 PASS) | A |
| Control flow | Constant-time — no data-dependent branches in T4121 RTL | A |
| Power/EM leakage | Unmitigated — hardware countermeasures pending | Risk |
| TVLA validation | Planned — ChipWhisperer CW305 | Pending |
| DOM masking | Planned (Domain-Oriented Masking on intermediate states) | Pending |

Category A badge = green. Risk badge = yellow. Pending badge = gray.

Footer note: "Category A = externally verifiable. Category B = proprietary framework
claim (S²-11DM²ET-X v1.5) — not independently verified, pending external cryptanalysis."

---

## Step 4 — Run Instructions

```powershell
# From E:\539Labs\demo\
pip install flask cryptography
python app.py
```

Navigate to: `http://localhost:5391`

App runs in Flask debug mode. No production server needed for M8.

---

## Step 5 — Verification Checklist

Before reporting M8 complete, confirm all of the following:

### Hash Tab
- [ ] Computing digest for "Hello, World!" returns a 128-char hex string
- [ ] Step chart renders 540 data points (step 0 = seed bit_length, step 539 = final)
- [ ] Yellow dashed vertical line appears at step 18 with label
- [ ] Phase badges ("Holographic Entry / Master Tower") are visible

### Avalanche Tab
- [ ] Input 1 "abc" vs Input 2 "abc" → Hamming distance = 0, all squares black
- [ ] Input 1 "abc" vs Input 2 "abd" → Hamming distance ≈ 240–280 (near 256)
  - If Hamming is not in 200–310 range, report the actual value — do not adjust
- [ ] 512-element bit grid renders correctly (32 cols × 16 rows)

### Encrypt/Decrypt Tab
- [ ] Encrypt "Hello 539 Labs" with password "test" → produces non-empty ciphertext hex
- [ ] Copy salt + ciphertext into decrypt form with same password → recovers "Hello 539 Labs"
- [ ] Wrong password returns error (MAC failure, not a crash)

### Benchmarks Tab
- [ ] Table matches M7 report values exactly (9225 cycles, 28 cycles, 329.5× ratio)
- [ ] SCA panel renders with correct badge colors (A=green, Risk=yellow)

---

## Architecture Notes

- All hash computation routes through `hqh539.py` — no local T3/T4121 definitions
- `compute_trace()` in app.py calls `T3()` from hqh539 module for every step
- Phase boundary at step 18 is a S²-11DM²ET-X v1.5 structural constant (§8 of master doc)
  - Steps 0–17: holographic window entry (G₂-manifold projection)
  - Steps 18–538: master tower traversal under phase-locking
- Benchmark numbers are locked from M7 — do not recalculate or estimate
- Security claims: label Category A vs B per §7 of master doc
  - Do not upgrade Category B claims to Category A in UI text

---

## File Inventory (post-M8)

```
E:\539Labs\demo\
├── app.py
├── requirements.txt
└── templates\
    └── index.html
```

No changes to `rtl/`, `python/`, `test_vectors/`, or `vivado/` directories.
No new test vectors required.
No Vivado runs required.

---

*539 Labs LLC | Orchestrator: Claude | Builder: Grok*
*S²-11DM²ET-X Minimal Unification Core v1.5 | T4121 Adopted*
