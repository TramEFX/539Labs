import sys, os, hashlib, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'python'))
from hqh539 import T3, STEPS, DOMAIN_SEP, hqh539_kdf, _SALT_MAP

from flask import Flask, request, jsonify, render_template
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305

# XSim bridge — imported conditionally; XSimError only available if XSIM_AVAILABLE
XSIM_AVAILABLE = os.getenv("HQH539_USE_XSIM", "false").strip().lower() == "true"
if XSIM_AVAILABLE:
    import xsim_bridge
    from xsim_bridge import XSimError

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

# Runtime hardware/software toggle — changed via /api/set_mode without restarting Flask
# Only effective when XSIM_AVAILABLE is True
_use_xsim_runtime = False

def _hardware_mode_active():
    """True iff XSim is available AND the runtime toggle is on."""
    return XSIM_AVAILABLE and _use_xsim_runtime

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

def bit_diff_array(hex1, hex2):
    """Return 512-element list: 1=bit differs, 0=same. MSB first."""
    xor = int(hex1, 16) ^ int(hex2, 16)
    return [(xor >> (511 - i)) & 1 for i in range(512)]

def resolve_salt(mode):
    return _SALT_MAP.get(mode.upper(), _SALT_MAP['STD'])

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/hash', methods=['POST'])
def api_hash():
    data = request.get_json()
    msg  = data['message'].encode('utf-8')
    mode = data.get('mode', 'STD')
    salt = resolve_salt(mode)

    # Use XSim when: hardware mode active AND mode is STD (only mode RTL supports)
    if _hardware_mode_active() and mode.upper() == 'STD':
        try:
            digest, timing = compute_hash_xsim(msg, salt)
            return jsonify({
                'digest':         digest,
                'trace':          None,        # not available in hardware mode
                'phase_boundary': 18,
                'hardware':       True,
                'sim_cycles':     timing['sim_cycles'],
                'sim_us':         timing['sim_us'],
                'wall_ms':        timing['wall_ms'],
            })
        except XSimError as e:
            return jsonify({'error': str(e)}), 500

    # Python path (default)
    trace, digest = compute_trace(msg, salt)
    return jsonify({
        'digest':         digest,
        'trace':          trace,
        'phase_boundary': 18,
        'hardware':       False,
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

@app.route('/api/set_mode', methods=['POST'])
def api_set_mode():
    """Switch between software and hardware simulation mode at runtime."""
    global _use_xsim_runtime
    data      = request.get_json()
    requested = data.get('mode', 'software')   # 'software' | 'hardware'
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

@app.route('/api/benchmarks')
def api_benchmarks():
    return jsonify(BENCHMARK_DATA)

if __name__ == '__main__':
    _xsim_env = os.getenv("HQH539_USE_XSIM", "false").strip().lower() == "true"
    app.run(debug=True, port=5391, use_reloader=not _xsim_env)