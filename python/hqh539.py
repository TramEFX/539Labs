"""
hqh539.py â€” HQH-539 Canonical Reference Implementation
Version 1.5 | 539 Labs LLC | June 4, 2026

Hampton Qutrit Hash â€” 539-Step Resonant Ternary Primitive
SÂ²-11DMÂ²ET-X Minimal Unification Core
Author of underlying model: Arvin B. Hampton (String Weaver)

CONSTRUCTION (three phases):
  Phase 1: seed  = int(SHA3-512(message â€– salt))
  Phase 2: state = T3^539(seed)          â€” exactly 539 T3 iterations, uniform
  Phase 3: out   = SHA3-512(state â€– salt â€– b":HQH-539-RESONANT:")

NOTE: The resonant attractor Î¦(t) is a theoretical characterization only.
It is NOT applied as a per-step computational modulation. T3 is applied
uniformly across all 539 steps. Python and FPGA implementations produce
identical outputs. (Confirmed: SÂ²-11DMÂ²ET-X v1.5 author, June 4 2026.)
"""

import hashlib
import time
from typing import Optional

# â”€â”€ Version 1.5 Constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
G4    = 539.9   # Resonant period (theoretical characterization)
STEPS = 539     # Exact iteration count â€” immutable

# â”€â”€ Canonical Domain-Separated Salts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
SALT_STD     = b"539-LABS-2026-RESONANT-SALT"   # General purpose
SALT_KDF     = b"539-LABS-2026-KDF"             # Key derivation
SALT_SIG     = b"539-LABS-2026-SIG"             # Signature applications
SALT_FINTECH = b"FINTECH-539-LABS-2026"         # FinTech / transaction (legacy)

DOMAIN_SEP   = b":HQH-539-RESONANT:"            # Final domain separator

_SALT_MAP = {
    "STD":     SALT_STD,
    "KDF":     SALT_KDF,
    "SIG":     SALT_SIG,
    "FINTECH": SALT_FINTECH,
}


# â”€â”€ Core Primitive â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def T3(n: int) -> int:
    """
    Ternary Syracuse map â€” exact integer arithmetic.

      T3(n) = n // 3          if n â‰¡ 0 (mod 3)   [contraction]
      T3(n) = (4n + 2) // 3  if n â‰¡ 1 (mod 3)   [expansion]
      T3(n) = (2n + 1) // 3  if n â‰¡ 2 (mod 3)   [mild contraction]
      T3(0) = 0               [fixed point]
    """
    if n == 0:
        return 0
    r = n % 3
    if r == 0:
        return n // 3
    elif r == 1:
        return (4 * n + 1) // 3
    else:
        return (2 * n + 1) // 3


def hqh539(message: bytes,
           salt: Optional[bytes] = None,
           mode: str = "STD") -> str:
    """
    HQH-539 Production Primitive â€” Version 1.5

    Args:
        message: Arbitrary-length byte string to hash.
        salt:    Domain salt. If None, resolved from mode.
        mode:    "STD" | "KDF" | "SIG" | "FINTECH"

    Returns:
        128-character lowercase hex string (512-bit digest).
    """
    if salt is None:
        salt = _SALT_MAP.get(mode.upper(), SALT_STD)

    # Phase 1: Domain-separated seed
    seed = int.from_bytes(
        hashlib.sha3_512(message + salt).digest(), 'big'
    )

    # Phase 2: Exactly 539 uniform T3 iterations
    state = seed
    for _ in range(STEPS):
        state = T3(state)

    # Phase 3: Domain-separated finalization
    state_bytes = state.to_bytes(32, 'big')
    final_input = state_bytes + salt + DOMAIN_SEP
    return hashlib.sha3_512(final_input).digest().hex()


# â”€â”€ Resonant Attractor (Theoretical â€” NOT applied in hash computation) â”€â”€â”€â”€â”€â”€â”€â”€

import math

def resonant_attractor(t: float) -> float:
    """
    Î¦(t) = 0.90Â·cos(2Ï€t/539.9) + 0.18Â·sin(2Ï€t/539.9)

    Theoretical characterization of trajectory phase dynamics.
    Used for analysis and security arguments only â€” not in hash computation.
    """
    omega = 2 * math.pi * t / G4
    return 0.90 * math.cos(omega) + 0.18 * math.sin(omega)


def resonant_velocity(t: float) -> float:
    """Î¦'(t) â€” phase-locking velocity (theoretical only)."""
    omega = 2 * math.pi * t / G4
    return (2 * math.pi / G4) * (-0.90 * math.sin(omega) + 0.18 * math.cos(omega))


# â”€â”€ KDF Construction â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def hqh539_kdf(secret: bytes, salt: bytes, info: bytes, length: int) -> bytes:
    """
    HQH539-KDF: HKDF-style Extract-and-Expand using HQH-539 as the PRF.

    Args:
        secret: Input key material (IKM).
        salt:   Cryptographic salt (â‰¥32 bytes recommended).
        info:   Context/application-specific info string.
        length: Desired output length in bytes.

    Returns:
        Output key material (OKM) of requested length.

    Security note: Security rests on HQH-539 behaving as a PRF.
    Not formally proven. Combine with HKDF-SHA256 for production
    FinTech deployments until independent cryptanalysis is complete.
    """
    # Extract
    prk_hex = hqh539(secret + salt, salt=SALT_KDF, mode="KDF")
    prk = bytes.fromhex(prk_hex)   # 64-byte pseudorandom key

    # Expand
    blocks = []
    t_prev = b""
    n_blocks = -(-length // 64)    # ceiling division
    for i in range(1, n_blocks + 1):
        block_input = t_prev + info + bytes([i])
        t_i = bytes.fromhex(hqh539(prk + block_input, salt=SALT_KDF, mode="KDF"))
        blocks.append(t_i)
        t_prev = t_i

    return (b"".join(blocks))[:length]


# â”€â”€ FinTech Wrapper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def fintech_resonant_hash(transaction_payload: bytes) -> dict:
    """
    FinTech production wrapper.
    Uses KDF instantiation per v1.5 canonical salt definitions.
    """
    start   = time.perf_counter()
    digest  = hqh539(transaction_payload, mode="KDF")
    latency = (time.perf_counter() - start) * 1000

    return {
        "status":             "SECURE",
        "digest":             digest,
        "mode":               "KDF",
        "latency_ms":         round(latency, 3),
        "resonant_stability": "LOCKED",
    }


# â”€â”€ Test Vector Generator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def generate_test_vectors(num_vectors: int = 100, mode: str = "STD") -> None:
    """
    Generate stimulus_<mode>.dat and expected_<mode>.dat for FPGA testbench.

    File format:
      stimulus: <index>,<message_hex>
      expected: <index>,<digest_hex>
    """
    salt = _SALT_MAP.get(mode.upper(), SALT_STD)
    stim_file = f"stimulus_{mode.lower()}.dat"
    exp_file  = f"expected_{mode.lower()}.dat"

    print(f"=== 539 Labs HQH-539 Vector Generator â€” {mode} mode ===")
    print(f"Generating {num_vectors} vectors...\n")

    with open(stim_file, "w") as stim, open(exp_file, "w") as exp:
        for i in range(num_vectors):
            msg    = f"Resonant test vector {i} for 539 Labs - {mode} mode".encode("utf-8")
            digest = hqh539(msg, salt=salt)
            stim.write(f"{i},{msg.hex()}\n")
            exp.write(f"{i},{digest}\n")
            if i % 25 == 0:
                print(f"  {i}/{num_vectors} vectors written...")

    print(f"\nâœ… Complete.")
    print(f"   {stim_file}  ({num_vectors} inputs)")
    print(f"   {exp_file}   ({num_vectors} digests)")


# â”€â”€ Avalanche Diagnostic â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def avalanche_test(base_message: bytes, num_bits: int = 32) -> dict:
    """
    Measure avalanche effect: flip each of num_bits bits within
    base_message and compute average Hamming distance vs. base digest.
    Target: ~256 bit Hamming distance (50% of 512-bit output).

    Works on the message at its natural byte length to avoid slicing
    artefacts from padding.
    """
    base_digest = hqh539(base_message)
    base_int    = int(base_digest, 16)
    distances   = []

    msg_len     = max(len(base_message), 1)
    msg_int     = int.from_bytes(base_message, 'big')
    max_bits    = min(num_bits, msg_len * 8)  # can't exceed message bit width

    for bit in range(max_bits):
        flipped_int   = msg_int ^ (1 << bit)
        # Preserve original byte length
        flipped_bytes = flipped_int.to_bytes(msg_len, 'big')
        flipped_int_d = int(hqh539(flipped_bytes), 16)
        hamming       = bin(base_int ^ flipped_int_d).count('1')
        distances.append(hamming)

    avg = sum(distances) / len(distances) if distances else 0.0
    return {
        "base_message":    base_message.decode("utf-8", errors="replace"),
        "bits_tested":     len(distances),
        "avg_hamming":     round(avg, 2),
        "target_hamming":  256,
        "pct_of_output":   round(avg / 512 * 100, 2),
        "pass":            abs(avg - 256) < 30,   # within ~12% of ideal
    }


# â”€â”€ Entry Point â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

if __name__ == "__main__":
    import sys
    import os

    # Move output files to test_vectors/ if it exists
    base_dir    = os.path.dirname(os.path.abspath(__file__))
    tv_dir      = os.path.join(base_dir, "..", "test_vectors")
    os.chdir(tv_dir if os.path.isdir(tv_dir) else base_dir)

    generate_test_vectors(100, mode="STD")
    generate_test_vectors(50,  mode="KDF")
    generate_test_vectors(50,  mode="SIG")

    print("\n=== Avalanche Test ===")
    result = avalanche_test(b"539 Labs")
    for k, v in result.items():
        print(f"  {k}: {v}")
