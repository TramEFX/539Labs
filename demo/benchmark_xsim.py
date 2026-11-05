import sys
import os
import statistics

sys.path.insert(0, r'E:\539Labs\demo')
from xsim_bridge import hqh539_via_xsim_timed

# Fixed test seed — SHA3-512 of b"539-benchmark" as hex (128 chars).
# Any valid 128-char hex is acceptable for latency measurement.
SEED_HEX = (
    '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b'
    '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b'
)
N = 10

print(f"HQH-539 XSim per-invocation benchmark — N={N}")
print(f"Seed: {SEED_HEX[:16]}...{SEED_HEX[-8:]}")
print("-" * 60)

wall_ms_list = []

for i in range(N):
    result = hqh539_via_xsim_timed(SEED_HEX)
    wall_ms = result['wall_ms']
    wall_ms_list.append(wall_ms)
    print(f"  Run {i+1:2d}/{N}:  {wall_ms:7.1f} ms   digest={result['digest'][:16]}...")

print("-" * 60)

mn  = min(wall_ms_list)
mx  = max(wall_ms_list)
avg = statistics.mean(wall_ms_list)
sd  = statistics.stdev(wall_ms_list)

print(f"Results (ms):")
print(f"  min:    {mn:.1f}")
print(f"  max:    {mx:.1f}")
print(f"  mean:   {avg:.1f}")
print(f"  stddev: {sd:.1f}")
print()
print(f"Mean in seconds: {avg/1000:.3f} s")
print(f"Full encrypt estimate (2 x mean): {2*avg/1000:.3f} s")
print(f"Full decrypt estimate (2 x mean): {2*avg/1000:.3f} s")
print()
print("Category B — single machine (TRAM-GPC1), N=10 independent calls.")