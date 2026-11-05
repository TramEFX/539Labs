# Verify T4121 branch correctness — Phase 1 Python layer gate for HQH-539 T3 Syracuse
def t4121_step(n):
    r = n % 3
    q = n // 3
    if r == 0: return q
    if r == 1: return (q << 2) | 1   # 4q + 1
    return (q << 1) | 1              # 2q + 1

# Fixed-point check
assert t4121_step(0) == 0,  "Fixed point 0 broken"
assert t4121_step(1) == 1,  "Fixed point 1 broken"   # T4121 specific
assert t4121_step(2) == 1,  "n=2 should map to 1"
print("All fixed-point assertions PASSED.")

# Boundary test: run 539 steps on several seeds >= 10^18
import random
random.seed(0x539)
print("Running 20 boundary seeds (10^18 to 10^20) for 539 steps each...")
for i in range(20):
    n = random.randint(10**18, 10**20)
    state = n
    for step in range(539):
        state = t4121_step(state)
    print(f"seed={n} → state after 539 steps: {state.bit_length()} bits")
print("Boundary tests complete. Python layer gate ready for review.")
