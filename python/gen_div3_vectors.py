import random
import os

def div3_ref(n):
    """Python reference: exact integer division by 3."""
    return n // 3, n % 3

N_BITS = 1024
HEX_COLS = N_BITS // 4  # 256 hex characters per value

TV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test_vectors")
os.makedirs(TV_PATH, exist_ok=True)

vectors = []

# --- Explicit edge cases (architecturally significant) ---
edge_cases = [
    0,                    # T3 fixed point: T3(0)=0. Known attractor. MUST pass.
    1,                    # Smallest non-zero; r=1 branch
    2,                    # r=2 branch
    3,                    # r=0 branch, simplest
    4,                    # r=1 branch
    5,                    # r=2 branch
    6,                    # r=0 branch
    10**18,               # HQCC theorem lower bound (seeds >= 10^18)
    10**18 + 1,
    10**18 + 2,
    2**511,               # Mid-range, typical seed magnitude
    2**511 + 1,
    2**511 + 2,
    2**1024 - 1,          # Maximum 1024-bit value
    2**1024 - 2,
    2**1024 - 3,
]

for n in edge_cases:
    n = n % (2**N_BITS)   # Clamp to N_BITS
    q, r = div3_ref(n)
    vectors.append((n, q, r))

# --- Random vectors to reach 1000 total ---
random.seed(0x539)        # HQH-539 project seed
while len(vectors) < 1000:
    n = random.getrandbits(N_BITS)
    q, r = div3_ref(n)
    vectors.append((n, q, r))

# --- Write files ---
stim_path = os.path.join(TV_PATH, "stimulus_div3.dat")
exp_path  = os.path.join(TV_PATH, "expected_div3.dat")

with open(stim_path, "w") as f:
    for i, (n, q, r) in enumerate(vectors):
        f.write(f"{i:04d},{n:0{HEX_COLS}x}\n")

with open(exp_path, "w") as f:
    for i, (n, q, r) in enumerate(vectors):
        f.write(f"{i:04d},{r},{q:0{HEX_COLS}x}\n")

print(f"Generated {len(vectors)} vectors ({len(edge_cases)} edge + {len(vectors)-len(edge_cases)} random).")
print(f"stimulus_div3.dat -> {stim_path}")
print(f"expected_div3.dat -> {exp_path}")
print()
print("Edge case spot-check:")
for label, n in [("n=0", 0), ("n=1", 1), ("n=2", 2), ("n=3", 3)]:
    q, r = div3_ref(n)
    print(f" {label}: q={q}, r={r}")

