import sys
sys.path.insert(0, r"E:\539Labs\python")
from hqh539 import hqh539, avalanche_test

msg = b"Resonant test vector 0 for 539 Labs - STD mode"
d = hqh539(msg)
print("Vector 0 digest (first 32 chars):", d[:32])
print("Digest length:", len(d), "chars =", len(d)//2*8, "bits")

r = avalanche_test(b"539 Labs", num_bits=64)
print("\nAvalanche test on b'539 Labs' (64 bit-flips):")
print("  avg Hamming distance:", r["avg_hamming"], "/ 512 bits")
print("  pct of output bits  :", r["pct_of_output"], "%")
print("  PASS                :", r["pass"])
