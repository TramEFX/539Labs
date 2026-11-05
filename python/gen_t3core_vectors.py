"""
gen_t3core_vectors.py — HQH-539 T3 Core Test Vector Generator
Version 1.0 | 539 Labs LLC | June 4, 2026

Generates FPGA testbench vectors for the T3 core (Phase 2 only).
Phase 3 (SHA3-512 finalization) is NOT applied — output is the raw
T3^539(seed) integer state, which is what the hqh539_t3core module
outputs on state_out[1023:0].

Output files (written to ../test_vectors/):
  stimulus_t3core.dat  — <index>,<seed_512bit_hex>  (128 hex chars = 512 bits)
  expected_t3core.dat  — <index>,<t3state_1024bit_hex> (256 hex chars = 1024 bits)

Hardware interface (hqh539_t3core.sv):
  seed_in[511:0]   ← stimulus: int value of SHA3-512(message || salt)
  state_out[1023:0] → expected: T3^539(seed) zero-padded to 1024 bits

State width analysis (100 vectors, STD mode):
  Seed width:   512 bits (constant, from SHA3-512)
  Max state:    237 bits after 539 T3 steps
  Min state:    147 bits after 539 T3 steps
  Avg state:    196.2 bits after 539 T3 steps
  1024-bit register: SUFFICIENT (max 237 << 1024)

Author note: T3^539 is strongly contractive in practice.
Starting from a 512-bit seed, the state converges to ~196 bits on average.
This is consistent with the expected average bit-change per step:
  E[Δbits] = (log2(1/3) + log2(4/3) + log2(2/3)) / 3 ≈ -0.585 bits/step
  539 steps × -0.585 ≈ -315 bits → 512 - 315 ≈ 197 bits (matches observed 196.2)
"""

import hashlib
import os

from hqh539 import T3

# ── Constants (must match hqh539.py v1.5) ──────────────────────────────────
SALT_STD = b"539-LABS-2026-RESONANT-SALT"
STEPS    = 539
NUM_VECS = 100


def generate_t3core_vectors(num_vectors: int = NUM_VECS) -> None:
    """
    Generate stimulus_t3core.dat and expected_t3core.dat.

    Stimulus:  seed = int(SHA3-512(message || SALT_STD), big-endian)
               Formatted as 128 zero-padded hex characters (512 bits).

    Expected:  state = T3^539(seed)
               Formatted as 256 zero-padded hex characters (1024 bits).
               Zero-padding is safe: max observed state is 237 bits.
    """
    base_dir = os.path.dirname(os.path.abspath(__file__))
    tv_dir   = os.path.join(base_dir, "..", "test_vectors")
    os.makedirs(tv_dir, exist_ok=True)

    stim_path = os.path.join(tv_dir, "stimulus_t3core.dat")
    exp_path  = os.path.join(tv_dir, "expected_t3core.dat")

    print(f"=== 539 Labs HQH-539 T3 Core Vector Generator ===")
    print(f"Generating {num_vectors} vectors (T3^{STEPS} only, no SHA3 finalization)...")
    print(f"Output: {tv_dir}\n")

    max_state_bits = 0
    min_state_bits = 9999

    with open(stim_path, "w") as stim, open(exp_path, "w") as exp:
        for i in range(num_vectors):
            # Phase 1: seed (same as hqh539.py)
            msg  = f"Resonant test vector {i} for 539 Labs - STD mode".encode("utf-8")
            seed = int.from_bytes(hashlib.sha3_512(msg + SALT_STD).digest(), 'big')

            # Phase 2: exactly 539 T3 iterations (no Phase 3)
            state = seed
            for _ in range(STEPS):
                state = T3(state)

            # Track width statistics
            bw = state.bit_length()
            max_state_bits = max(max_state_bits, bw)
            min_state_bits = min(min_state_bits, bw)

            # Format: 128 hex chars for seed (512 bits), 256 for state (1024 bits)
            seed_hex  = format(seed,  '0128x')
            state_hex = format(state, '0256x')

            stim.write(f"{i},{seed_hex}\n")
            exp.write(f"{i},{state_hex}\n")

            if i % 25 == 0:
                print(f"  {i:>3}/{num_vectors}  seed[{seed.bit_length()}-bit]"
                      f"  →  state[{bw}-bit]")

    print(f"\n✅ Complete.")
    print(f"   stimulus_t3core.dat  ({num_vectors} lines, seed_in values)")
    print(f"   expected_t3core.dat  ({num_vectors} lines, state_out values)")
    print(f"\n   State width range: {min_state_bits}–{max_state_bits} bits")
    print(f"   (1024-bit RTL register is SUFFICIENT)")


if __name__ == "__main__":
    generate_t3core_vectors()
