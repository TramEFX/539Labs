"""
gen_pipeline_vectors.py
Generates end-to-end HQH-539 pipeline test vectors (STD mode, 100 vectors).
Stimulus: Phase 1 output (seed = int(SHA3-512(msg || SALT_STD), 'big'))
Expected: Full HQH-539 digest (Phase 3 output)
"""
import hashlib
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hqh539 import hqh539, SALT_STD

N = 100
base_dir = os.path.dirname(os.path.abspath(__file__))
tv_dir   = os.path.join(base_dir, "..", "test_vectors")

stim_path = os.path.join(tv_dir, "stimulus_pipeline.dat")
exp_path  = os.path.join(tv_dir, "expected_pipeline.dat")

with open(stim_path, "w") as sf, open(exp_path, "w") as ef:
    for i in range(N):
        msg    = f"Resonant test vector {i} for 539 Labs - STD mode".encode("utf-8")
        # Phase 1: seed = int(SHA3-512(msg || SALT_STD), big-endian)
        seed   = int.from_bytes(hashlib.sha3_512(msg + SALT_STD).digest(), 'big')
        digest = hqh539(msg, mode="STD")
        sf.write(f"{i},{seed:0128x}\n")   # 512-bit seed as 128-char hex
        ef.write(f"{i},{digest}\n")
        if i % 25 == 0: print(f"  {i}/{N}")

print(f"Done. {stim_path}, {exp_path}")
