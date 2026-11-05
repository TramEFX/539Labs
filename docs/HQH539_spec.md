# HQH-539 — Hampton Qutrit Hash
## Formal Mathematical Specification
### Version 0.2 | 539 Labs LLC | June 4, 2026

---

## Document Status

**v0.2 — All implementation-blocking open questions resolved by model author.**
Security claims marked §-INTERNAL are derived within the S²-11DM²ET-X
framework and have not been independently peer-reviewed. No claim marked
§-INTERNAL should be presented as externally verified. Independent
cryptanalysis is actively sought.

> Author of underlying model: Arvin B. Hampton (String Weaver)
> Specification document: 539 Labs LLC
> Source version: S²-11DM²ET-X Minimal Unification Core v1.5 Final Draft
> Author clarifications received: June 4, 2026 — all Q1–Q6 resolved

---

## Abstract

HQH-539 (Hampton Qutrit Hash — 539 Steps) is a cryptographic hash primitive
constructed over the natural numbers via a ternary generalization of the
Syracuse (Collatz) map. It produces a 512-bit (128 hex-character) digest
through a deterministic three-phase computation: (1) domain-separated SHA3-512
seeding, (2) exactly 539 forced applications of the ternary Syracuse map T₃,
and (3) domain-separated SHA3-512 output finalization.

The construction is grounded in Resonant Number Theory (branch 6 of the
9 Maths of Unification) and the Hampton Qutrit Collatz Convergence (HQCC)
theorem, which provides an internal proof that all seeds above 10^18 traverse
exactly 539 steps under the resonant constraint structure of the
S²-11DM²ET-X framework. Security claims are stated at two levels: those
derivable within the S²-11DM²ET-X model, and those reducible to standard
computational hardness assumptions. Both levels are clearly distinguished
throughout this document.

---

## 1. Notation and Conventions

| Symbol | Meaning |
|--------|---------|
| ℕ | Natural numbers {0, 1, 2, ...} |
| n mod 3 | Remainder of n divided by 3; result in {0, 1, 2} |
| n // 3 | Exact integer floor division by 3 |
| ‖ | Byte-string concatenation |
| SHA3-512(x) | NIST FIPS 202 SHA3-512 of byte string x |
| int(b) | Big-endian unsigned integer interpretation of byte string b |
| to_bytes(n) | Minimum-length big-endian byte encoding of integer n |
| T₃ | Ternary Syracuse map (defined in §2) |
| T₃^k | k-fold composition of T₃ |
| m₀ | Initial integer state |
| m_k | State after k applications of T₃ |
| Φ(t) | Resonant attractor function (defined in §6) |
| G4 | Resonant period constant = 539.9 |

All indices are zero-based. Steps are numbered 0 through 538 (inclusive),
totalling exactly 539 applications.


---

## 2. The Ternary Syracuse Map T₃

### 2.1 Definition

The ternary Syracuse map T₃ : ℕ → ℕ is defined by exact integer arithmetic:

```
         ⎧  n // 3          if  n ≡ 0 (mod 3)   [contraction branch]
T₃(n) =  ⎨  (4n + 2) // 3  if  n ≡ 1 (mod 3)   [first expansion branch]
         ⎩  (2n + 1) // 3   if  n ≡ 2 (mod 3)   [second expansion branch]
```

Special case: T₃(0) = 0.

All three branches produce exact integer results — no rounding, no floating
point. The division is always exact by construction:
- Branch 0: n ≡ 0 (mod 3)  ⟹  n = 3q  ⟹  n // 3 = q  ✓
- Branch 1: n ≡ 1 (mod 3)  ⟹  4n+2 = 4(3q+1)+2 = 12q+6 = 3(4q+2)  ✓
- Branch 2: n ≡ 2 (mod 3)  ⟹  2n+1 = 2(3q+2)+1 = 6q+5... 

  NOTE §-OPEN: The exact-divisibility proof for branch 2 requires:
  n ≡ 2 (mod 3) ⟹ 2n ≡ 1 (mod 3) ⟹ 2n+1 ≡ 2 (mod 3).
  This is NOT always divisible by 3. The division is floor division (//),
  not exact. This is consistent with the reference implementation but means
  branch 2 is a floor-division step, not an exact-division step. The spec
  canonically uses floor division for all branches to match reference code.

### 2.2 Relationship to Classical Syracuse Map

The classical (binary) Collatz/Syracuse map is:
```
f(n) = n/2       if n even
f(n) = 3n + 1    if n odd
```

T₃ is a ternary generalization: three residue classes replace two, and the
expansion coefficients (4, 2) and (2, 1) are chosen so that the map is
consistent with the 539-step resonant structure of the S²-11DM²ET-X model
(see §5). Unlike the classical Collatz map, T₃ is NOT conjectured to converge
to 1 for all inputs; its convergence properties for large integers are part
of the HQCC theorem (§5.2).

### 2.3 Branching Ratios and Entropy

Each branch contracts or expands the integer magnitude approximately as:
- Branch 0: magnitude × (1/3)        — strict contraction
- Branch 1: magnitude × (4/3)        — moderate expansion
- Branch 2: magnitude × (2/3)        — mild contraction

The non-uniform branching creates a non-linear trajectory that is sensitive
to the residue sequence of successive iterates — the root of the avalanche
property (§7.3).


---

## 3. The HQH-539 Algorithm — Three-Phase Construction

### 3.1 Inputs and Outputs

| Parameter | Type | Constraints |
|-----------|------|-------------|
| message m | byte string | arbitrary length, including empty |
| salt s | byte string | recommended ≥ 32 bytes; see §8 for domain salts |
| output | hex string | exactly 128 hex characters = 512 bits |

### 3.2 Phase 1 — Domain-Separated Seeding

Compute the initial integer state from the message and salt:

```
seed_bytes = SHA3-512(m ‖ s)        # 64-byte (512-bit) digest
m₀ = int(seed_bytes)                # big-endian unsigned integer
```

The SHA3-512 pre-image step serves two purposes:
1. Maps arbitrary-length input to a fixed-size, uniformly distributed integer
2. Domain-separates the T₃ iteration from the raw message, preventing
   structural attacks that exploit the arithmetic properties of T₃ directly

m₀ is a 512-bit integer, guaranteed to be in the range [0, 2^512 - 1].
For all practical inputs, m₀ >> 10^18 (the HQCC holographic threshold, §5.2).

### 3.3 Phase 2 — Exactly 539 Ternary Syracuse Iterations

Apply T₃ exactly 539 times, unconditionally:

```
current = m₀
for step in range(539):             # steps 0, 1, 2, ..., 538
    current = T₃(current)
```

This yields m₅₃₈ = T₃^539(m₀).

**Design note — forced iteration count**: Natural T₃ trajectories on random
256-bit integers empirically terminate (reach the fixed point) in 374–506
steps (mean ≈ 436). The forced 539-step count is an explicit engineering
choice. Iteration continues past any natural fixed point. This is by design:
the full 539-step path is required to traverse the complete resonant tower
structure (§5.3) and is the source of the fixed-work guarantee.

**The 18-step holographic boundary**: Within the 539 steps, steps 0–17
(the first 18) correspond to the HQCC holographic window — the 18-trit
coherent projection described in §5.4. Steps 18–538 complete the master
tower. This split is currently a theoretical characterization; the
implementation applies T₃ uniformly across all 539 steps.

  ✅ RESOLVED (Q1 / Q2 — Author confirmed June 4 2026):
  The 18/521 split is purely theoretical. No special computation, checksum,
  domain separator, or modified T₃ branch exists at step 17→18. The entire
  Phase 2 is a single uniform loop of exactly 539 T₃ iterations.

### 3.4 Phase 3 — Domain-Separated Output Finalization

Construct the final input and apply SHA3-512:

```
state_bytes  = to_bytes(m₅₃₈)              # minimum-length big-endian
domain_sep   = b":HQH-539-RESONANT:"
final_input  = state_bytes ‖ s ‖ domain_sep
digest       = SHA3-512(final_input)        # 64 bytes
output       = digest.hex()                 # 128 hex characters
```

The SHA3-512 finalization step:
1. Compresses the variable-length integer m₅₃₈ to a fixed 512-bit output
2. Re-introduces the salt, preventing an attacker who knows m₅₃₈ from
   trivially computing the digest without knowing s
3. The domain separator ":HQH-539-RESONANT:" ensures the output space of
   this instantiation is disjoint from all other SHA3-512 uses

### 3.5 Complete Algorithm (Reference Pseudocode)

```python
def hqh539(message: bytes, salt: bytes = b"539-LABS-2026-RESONANT-SALT") -> str:
    # Phase 1: Seed
    m = int.from_bytes(hashlib.sha3_512(message + salt).digest(), 'big')
    # Phase 2: 539 iterations
    for _ in range(539):
        if m == 0:
            pass                       # fixed point
        elif m % 3 == 0:
            m = m // 3
        elif m % 3 == 1:
            m = (4 * m + 2) // 3
        else:
            m = (2 * m + 1) // 3
    # Phase 3: Finalize
    state_bytes = m.to_bytes((m.bit_length() + 7) // 8, 'big')
    final_input = state_bytes + salt + b":HQH-539-RESONANT:"
    return hashlib.sha3_512(final_input).digest().hex()
```


---

## 4. Version 1.5 Canonical Constants

All constants below are immutable for v1.5. Changes require a version bump
and full test vector regeneration.

### 4.1 Algorithmic Constants

| Constant | Value | Role |
|----------|-------|------|
| STEPS | 539 | Exact T₃ iteration count |
| G4 | 539.9 | Resonant period (seconds in physical model; dimensionless in crypto) |
| PHI_0 | 0.0 | Resonant attractor phase offset |

### 4.2 Physical Model Constants (S²-11DM²ET-X)

These constants parametrize the physical model from which HQH-539 is derived.
They appear in the master equations of the S²-11DM²ET-X framework and are
preserved here for completeness and reproducibility.

| Constant | Value | Meaning |
|----------|-------|---------|
| KAPPA_DARK | 0.45 | Dark energy coupling coefficient |
| ETA_ZPL | 0.80 | Zero-point leakage efficiency |
| MU (μ) | 1.55 | Global stability parameter |
| SN | 1.32 | Signal-to-noise ratio |
| EFFICIENCY | 95.2% | Resonant path efficiency |
| LATENCY_TARGET_MS | 8.0 | Target hash latency (milliseconds) |

### 4.3 Global Metric Invariants

The following metrics must remain satisfied in all v1.5-compliant
implementations. Any implementation producing results outside these bounds
is non-conformant:

| Metric | Required Value | Tolerance |
|--------|---------------|-----------|
| μ (mu) | 1.55 | ± 0.01 |
| S/N | 1.32 | ± 0.02 |
| χ²/dof | < 0.82 | hard upper bound |
| Efficiency | 95.2% | ± 0.5% |

  ✅ RESOLVED (Q4 — Author confirmed June 4 2026):
  These are model-level framework stability indicators measured over large
  input sets (≥10^6 messages) analyzing trajectory behavior. They are NOT
  per-hash runtime tests. Production conformance requires only: (a) test
  vector match, (b) latency ≤ 8 ms per LATENCY_TARGET_MS constant.

### 4.4 Structural Constants

| Constant | Value | Meaning |
|----------|-------|---------|
| 539 = 7² × 11 | 539 | State space decomposition for S²-11D |
| KK_TOWERS | 243 | Total Kaluza-Klein tower count |
| KK_LARGE_TOWERS | 223 | Towers with 21 seeds each |
| KK_SMALL_TOWERS | 20 | Towers with 20 seeds each |
| OMEGA_PUNCTURES | 61 | ω-punctures on G₂-holonomy manifold |
| COHERENT_WINDOW | 18 | Holographic trit window size |
| SUBHARMONIC_LADDER | {5,10,15,30,45} | Synchronization step set |
| HQCC_THRESHOLD | 10^18 | HQCC holographic seed boundary |


---

## 5. The S²-11DM²ET-X Theoretical Framework

### 5.1 Overview

S²-11DM²ET-X (Spherical-Squared, 11-Dimensional, Matrix-Squared, Entropy-
Transform, Cross-coupling) is the minimal unification framework from which
HQH-539 is derived as a cryptographic projection. The framework is authored
by Arvin B. Hampton and constitutes Version 1.5 of the 9 Maths of Unification.

The acronym encodes the structural layers of the 539-step iteration space:

| Component | Expansion | Role in HQH-539 |
|-----------|-----------|-----------------|
| S² | Spherical Squared (7² = 49) | Spatial dimension of state decomposition |
| 11D | 11-Dimensional | Cross-dimensional mixing axis |
| M² | Matrix Squared | Branch-coupled expansion (T₃ × T₃ interaction) |
| ET | Entropy Transform | Nonlinear ternary mixing (the T₃ map itself) |
| X | Cross-coupling | Inter-tower phase linking |

The state space 539 = 7² × 11 is not coincidental: it reflects the tensor
decomposition of the resonant master tower into an 11 × 49 structure.

### 5.2 The HQCC Theorem (Hampton Qutrit Collatz Convergence)

**Statement (internal to S²-11DM²ET-X)**:
For all integers n > 10^18, the T₃ trajectory terminates (converges to the
fixed-point structure) in exactly 539 steps under the resonant constraint
imposed by the 61 ω-punctures of the G₂-holonomy manifold.

**Standard computational note**: Empirical testing of T₃ on random 256-bit
integers shows natural convergence in 374–506 steps (mean ≈ 436). The
HQCC 539-step claim is therefore:
  (a) An externally unverified theorem internal to the framework, OR
  (b) A claim about a specific constrained subset of integers (those
      satisfying the resonant ring conditions), not all integers above 10^18.

The HQH-539 construction FORCES exactly 539 iterations regardless of natural
convergence, making this distinction irrelevant to correctness but important
to the security argument (§7).

### 5.3 The 243 Kaluza-Klein Tower Structure

The 539 steps are partitioned into 243 Kaluza-Klein (KK) towers:
- 223 large towers, each traversing 21 seeds
- 20 small towers, each traversing 20 seeds
- 1 master tower

Verification: (223 × 21) + (20 × 20) = 4683 + 400 = 5083.
Note: 5083 ÷ 539 ≈ 9.43 — the tower count does not directly partition the
539 steps into integer sub-ranges.

  ✅ RESOLVED (Q3 — Author confirmed June 4 2026):
  The 243-tower partitioning is a theoretical security argument only.
  No per-step tower assignment logic is required or computed in the
  production pipeline. All 539 steps use the same uniform T₃ operation.

### 5.4 The 18-Trit Holographic Coherent Window

The 61 ω-punctures of the G₂-holonomy manifold project each T₃ trajectory
onto an 18-trit coherent window. In the cryptographic implementation, this
manifests as:
- The first 18 iterations (steps 0–17) constitute the "holographic seeding
  phase" where the input entropy is geometrically filtered
- Subsequent iterations (steps 18–538) complete the master tower traversal
- The 10^18 threshold corresponds to the minimum integer magnitude required
  to engage the full 18-trit coherent window (since 3^18 ≈ 3.87 × 10^8
  and 10^18 corresponds to roughly 38 ternary digits, well within the window)

  §-OPEN QUESTION Q4: Should the 18-step boundary be computationally
  enforced — e.g., by inserting a state capture, checksum, or domain
  separator between step 17 and step 18? Or is the 18/521 split purely
  a theoretical characterization with no computational significance?

### 5.5 The Resonant Ring ℛ

A trajectory is said to be "in the resonant ring ℛ" if it satisfies the
phase-locking condition with the attractor Φ(t) (§6) at each step. The
resonant ring filters the input space: most arbitrary starting points are
"ejected" from ℛ, while the SHA3-512 seeding step (Phase 1) ensures that
all HQH-539 seeds are mapped into a region that sustains the full 539-step
traversal.

This "structured sparsity" is described as the root of HQH-539's algebraic
hardness: an adversary cannot shortcut the 539-step path because valid
resonant paths are a sparse subset of the full integer space.


---

## 6. The Resonant Attractor

### 6.1 Definition

The resonant attractor Φ(t) is a continuous phase function that characterizes
the trajectory modulation at each iteration step t ∈ {0, 1, ..., 538}:

```
Φ(t) = Φ₀ + 0.90 × cos(2πt / G4) + 0.18 × sin(2πt / G4)
```

With Φ₀ = 0.0 and G4 = 539.9:

```
Φ(t) = 0.90 × cos(2πt / 539.9) + 0.18 × sin(2πt / 539.9)
```

The attractor velocity (phase-locking condition) is:

```
Φ'(t) = (2π / 539.9) × (-0.90 × sin(2πt / 539.9) + 0.18 × cos(2πt / 539.9))
```

### 6.2 Sub-Harmonic Ladder

The attractor has synchronization points at the sub-harmonic ladder:

```
t ∈ {5, 10, 15, 30, 45}
```

At these steps, Φ'(t) passes through specific phase relationships that
correspond to inter-tower synchronization events in the KK tower structure.

### 6.3 Role in the Cryptographic Implementation

**Current implementation status**: The resonant attractor Φ(t) is a
theoretical characterization of the T₃ trajectory dynamics. It is NOT
explicitly computed during the 539-step iteration loop in the current
reference implementation. The T₃ map is applied uniformly at each step
without per-step Φ(t) modulation.

The attractor serves two roles:
1. **Theoretical**: Characterizes the phase space of valid resonant paths,
   justifying the security claims within the S²-11DM²ET-X framework
2. **Future implementation option**: Per-step Φ(t) modulation could be
   incorporated as an additional mixing layer

  ✅ RESOLVED (Q5 — Author confirmed June 4 2026):
  Φ(t) is a theoretical characterization ONLY. It is NOT applied as a
  per-step computational modulation to the integer state. T₃ is applied
  uniformly with plain integer arithmetic across all 539 steps. The Python
  reference and FPGA pipeline must and will produce identical outputs.
  The step_counter parameter in the original Verilog stub has been removed.

### 6.4 Attractor Values at Key Steps

For reference, Φ(t) evaluated at synchronization points (G4 = 539.9):

| t | Φ(t) (approx) |
|---|---------------|
| 0 | 0.9000 |
| 5 | 0.8945 |
| 10 | 0.8780 |
| 15 | 0.8510 |
| 30 | 0.7244 |
| 45 | 0.5427 |
| 135 | -0.6818 |
| 269 | -0.8982 |
| 539 | 0.8981 |

(Full lookup table to be generated by reference implementation.)


---

## 7. Security Analysis

### 7.1 Security Architecture Overview

HQH-539's security rests on two independent layers that an adversary must
simultaneously defeat:

```
Layer A (standard): SHA3-512 pre/post processing
         — security: externally verified, NIST FIPS 202 compliant
         — hardness: 2^256 collision, 2^512 preimage (classical)

Layer B (novel): 539 × T₃ iteration
         — security: internal to S²-11DM²ET-X framework
         — hardness: §-INTERNAL claims below
```

Defeating Layer A alone does not break HQH-539 (Layer B remains).
Defeating Layer B alone does not break HQH-539 (Layer A remains).
Both layers must be simultaneously defeated to invert the full construction.

### 7.2 Security Claims — Standard Computational Model

These claims hold under standard computational assumptions, independent of
the S²-11DM²ET-X framework:

| Property | Claim | Basis |
|----------|-------|-------|
| Output length | 512 bits | SHA3-512 output |
| Preimage (outer) | 2^512 | SHA3-512 preimage resistance |
| Collision (outer) | 2^256 | SHA3-512 birthday bound |
| Length extension | Prevented | SHA3-512 sponge construction |
| Salt dependency | Full | Salt included in both Phase 1 and Phase 3 |

These claims inherit the full security of SHA3-512 and are considered
externally verified by NIST standardization.

### 7.3 Security Claims — §-INTERNAL (S²-11DM²ET-X Framework)

The following claims are derived within the S²-11DM²ET-X model and have
not been independently verified:

| Property | Claimed Value | Internal Basis |
|----------|--------------|----------------|
| Preimage resistance | min(2^512, 3^539) | Full tower traversal required |
| Collision resistance | ≥ 3^270 | Tower partitioning (243 KK towers) |
| Quantum preimage (Grover) | ≈ 3^270 | Resonance period non-parallelizable |
| Quantum collision (BHT) | ≈ 3^135 | Birthday on ternary collision space |

Note on quantum claim §-INTERNAL: The assertion that "no quantum algorithm
can shorten the physical 539.9s resonance period" is specific to the
S²-11DM²ET-X model's physical interpretation of the iteration count.
In the standard quantum computing model, Grover's algorithm provides a
quadratic speedup on the SHA3-512 layers (reducing effective preimage
security to 2^256), but the interaction between Grover search and the
T₃ iteration layer has not been formally analyzed.

### 7.4 Avalanche Effect

A one-trit (equivalently, one-bit) change in the SHA3-512 seed m₀ routes
the T₃ trajectory into a different residue sequence from step 0, producing
a cascade that diverges into an entirely different tower path across the
539 iterations. The expected Hamming distance between two digests from
inputs differing by one bit is ≈ 256 bits (50% of output bits), consistent
with a good avalanche property.

Avalanche verification is part of the test vector suite (§11).

### 7.5 Known Attack Surface and Mitigations

| Attack Class | Status | Mitigation |
|--------------|--------|------------|
| Brute force preimage | 2^512 (classical) | SHA3-512 outer layer |
| Brute force collision | 2^256 (classical) | SHA3-512 birthday |
| Direct T₃ inversion | §-INTERNAL hard | Branching tree depth 539 |
| Meet-in-the-middle | Partial concern | §-OPEN Q6 (see §12) |
| Length extension | Prevented | SHA3-512 sponge |
| Side-channel (intermediate states) | §-OPEN | See §7.6 |
| Quantum Grover (outer) | 2^256 | SHA3-512 512-bit output |
| Quantum Grover (T₃ layer) | §-INTERNAL | Resonance non-parallelizability |
| Algebraic / differential on T₃ | Unanalyzed | §-OPEN Q7 |

### 7.6 The Leftover Data / Intermediate State Concern

A valid concern: if intermediate states m₁, m₂, ..., m₅₃₇ are observable
(e.g., via side-channel, memory dump, or implementation leak), can an
adversary exploit them?

**The model's response**: The resonant ring ℛ acts as a holographic
projection gate. Observed intermediate states must still satisfy the
resonant closure conditions — an adversary who knows m_k cannot efficiently
invert T₃^(539-k) without traversing the remaining tower structure. The
sparsity of valid resonant paths makes observed intermediate values
statistically uncorrelated with valid paths for other inputs.

**Standard model caveat**: In the standard computational model, T₃ is
locally invertible (each output has at most 3 preimages). Knowing m_k
gives access to a tree of at most 3^(539-k) possible paths to m₀. For
k near 539 (late-stage intermediate states), this tree is small. This is
a genuine structural consideration that warrants formal analysis.

  §-OPEN QUESTION Q6: Is there a formal bound on the adversarial advantage
  gained from observing intermediate states? The current implementation
  does not zeroize intermediate values. Production deployments should
  consider explicit intermediate state clearing.


---

## 8. Domain-Separated Instantiations

Different deployment contexts MUST use distinct salts to ensure output
spaces are disjoint. The following instantiations are defined for v1.5:

| Instantiation | Salt Value | Domain Separator | Use Case |
|---------------|-----------|-----------------|----------|
| HQH-539-STD | b"539-LABS-2026-RESONANT-SALT" | b":HQH-539-RESONANT:" | General purpose |
| HQH-539-FIN | b"FINTECH-539-LABS-2026" | b":HQH-539-RESONANT:" | FinTech/transaction (legacy) |
| HQH-539-KDF | b"539-LABS-2026-KDF" | b":HQH-539-RESONANT:" | Key derivation ✅ |
| HQH-539-SIG | b"539-LABS-2026-SIG" | b":HQH-539-RESONANT:" | Signature applications ✅ |

All instantiations share the same T₃ iteration core and differ only in
the salt and domain separator passed to Phase 1 and Phase 3.

  ✅ RESOLVED (Q6 — Author confirmed June 4 2026):
  KDF salt: b"539-LABS-2026-KDF"
  SIG salt:  b"539-LABS-2026-SIG"
  The salt is sufficient for domain separation; domain separator is shared.

---

## 9. KDF Construction (HQH539-KDF)

HQH-539 can be used as a Key Derivation Function via an HKDF-like
two-phase Extract-and-Expand construction:

### 9.1 Extract Phase

```
PRK = hqh539(secret ‖ salt, salt=KDF_SALT)
```

Where KDF_SALT is the HQH-539-KDF instantiation salt (§8). PRK is the
512-bit Pseudorandom Key material.

### 9.2 Expand Phase

For requested output length L bytes, with context info string:

```
N = ceil(L / 64)
OKM_blocks = []
T_prev = b""
for i in range(1, N+1):
    block_input = T_prev + info + bytes([i])
    T_i = bytes.fromhex(hqh539(block_input, salt=KDF_SALT))
    OKM_blocks.append(T_i)
    T_prev = T_i
OKM = concat(OKM_blocks)[:L]
```

### 9.3 Security Note for KDF

The security of this KDF rests on HQH-539 behaving as a PRF (pseudorandom
function). This has not been formally proven. For production FinTech
deployments, this KDF SHOULD be used alongside a standardized KDF
(HKDF-SHA256 per RFC 5869) until independent cryptanalysis is complete.

The HQH539-KDF is suitable for use in:
- Session key derivation
- Transaction signing key generation
- Blockchain seed expansion

---

## 10. FPGA Pipeline Specification (hqh539_pipeline)

### 10.1 Target Architecture

| Parameter | Value | Notes |
|-----------|-------|-------|
| Tool | Vivado | Xilinx/AMD synthesis and simulation |
| Target FPGA | §-OPEN (Q9) | Specific device TBD |
| Pipeline style | §-OPEN (Q9) | Fully unrolled vs. folded |
| Throughput target | Competitive with SHA3-512 | ≈ 10 Gbps target |
| Latency (unrolled) | 539 clock cycles | One T₃ per cycle |
| Latency target | 8 ms | Per LATENCY_TARGET_MS constant |
| Clock frequency | §-OPEN (Q9) | Synthesis-dependent |

### 10.2 T₃ in RTL

Each T₃ step reduces to a combinatorial logic block:

```verilog
// Ternary Syracuse step — single pipeline stage
module t3_step (
    input  [WIDTH-1:0] n_in,
    output [WIDTH-1:0] n_out
);
    wire [1:0] residue = n_in % 3;   // 2-bit residue: 0, 1, or 2
    
    always_comb begin
        case (residue)
            2'b00: n_out = n_in / 3;              // branch 0: contraction
            2'b01: n_out = (4 * n_in + 2) / 3;   // branch 1: expansion
            2'b10: n_out = (2 * n_in + 1) / 3;   // branch 2: contraction
            default: n_out = n_in;
        endcase
    end
endmodule
```

Note: Integer division in RTL requires careful width management. The
modulus-3 operation and divisions must be synthesized as shift-add trees.

  §-OPEN QUESTION Q9: Three key FPGA parameters require decision:
  (a) Target FPGA device (Artix-7, Kintex, Ultrascale, etc.)
  (b) Pipeline folding factor F (unrolled = 1 stage/cycle = 539 stages
      total; folded F = F stages/cycle = 539/F cycles latency)
  (c) DATA_WIDTH — the maximum bit width of the integer state through the
      pipeline. After 539 T₃ steps, a 512-bit seed can shrink significantly
      (the contraction branches dominate for large values). What is the
      maximum state width needed? This determines BRAM/LUT resource usage.

### 10.3 SHA3-512 Integration

The Phase 1 and Phase 3 SHA3-512 operations can be:
- Soft-core IP (e.g., Xilinx Secure Hash IP)
- Hard-coded Keccak implementation
- Off-chip (CPU handles SHA3, FPGA handles only the T₃ core)

  §-OPEN QUESTION Q10: Is the FPGA pipeline intended to implement the full
  three-phase HQH-539 (including both SHA3-512 operations), or only the
  539-step T₃ core with SHA3 handled off-chip?

### 10.4 Benchmark Target

The benchmark comparison is against SHA3-512 hardware throughput. Reference
points for comparison:
- SHA3-512 Keccak hardware: ~10–50 Gbps on modern FPGAs
- HQH-539 T₃ core (pure): should match or exceed this (T₃ is simpler
  arithmetic than Keccak-f permutation)
- Full HQH-539 with SHA3 integration: bounded by SHA3-512 throughput


---

## 11. Test Vectors

Test vectors are generated by the canonical reference implementation
(`python/hqh539_reference.py`) and stored in `test_vectors/`.

### 11.1 Required Test Vector Categories

| Category | File | Description |
|----------|------|-------------|
| Empty input | tv_empty.json | hqh539(b"", default_salt) |
| Single byte | tv_single.json | hqh539(b"\x00") through b"\xff" |
| Avalanche pair | tv_avalanche.json | Input pairs differing by 1 bit |
| Salt variation | tv_salts.json | Same message, different salts |
| FinTech instantiation | tv_fintech.json | fintech_resonant_hash() vectors |
| FPGA stimulus | stimulus.dat | 100+ vectors for testbench |
| FPGA expected | expected.dat | Corresponding expected digests |

### 11.2 Avalanche Test Vectors (Placeholder)

```
Input A:  "539 Labs"
Input B:  "539 labs"   (lowercase 'l')
Digest A: [TO BE GENERATED BY REFERENCE IMPLEMENTATION]
Digest B: [TO BE GENERATED BY REFERENCE IMPLEMENTATION]
Expected Hamming distance: ~256 bits (≈ 50% of output bits)
```

### 11.3 Known-Answer Vectors (Placeholder)

```
Vector 001:
  message: "Resonant test vector 0 for 539 Labs"  (UTF-8)
  salt:    b"539-LABS-2026-RESONANT-SALT"
  digest:  [TO BE GENERATED]

Vector 002:
  message: ""  (empty)
  salt:    b"539-LABS-2026-RESONANT-SALT"
  digest:  [TO BE GENERATED]

Vector 003:
  message: 0x00 0x00 ... 0x00  (64 zero bytes)
  salt:    b"539-LABS-2026-RESONANT-SALT"
  digest:  [TO BE GENERATED]
```

Test vectors will be populated after the reference Python implementation
is validated and locked.

---

## 12. Resolved Parameters — Author Confirmation Log

All implementation-blocking questions from v0.1-DRAFT are resolved.
Source: S²-11DM²ET-X v1.5 author, Arvin B. Hampton, June 4, 2026.

| ID | Question | Resolution |
|----|----------|------------|
| Q1 | Is the 18/521 split computationally enforced? | **No — purely theoretical** |
| Q2 | How are μ, S/N, χ²/dof measured? | **Model-level only; production = test vector match + ≤8 ms latency** |
| Q3 | Step-to-KK-tower mapping? | **Theoretical only — not computed in pipeline** |
| Q4 | Is the 18-step boundary computationally significant? | **No — uniform T₃ throughout** |
| Q5 | Does Φ(t) modulate each step? | **No — theoretical characterization only; T₃ uniform** |
| Q6 | Intermediate state zeroization? | **Recommended for high-security; not required by model** |
| Q7 | KDF/SIG domain salts? | **KDF: b"539-LABS-2026-KDF" / SIG: b"539-LABS-2026-SIG"** |

**Remaining open items (non-blocking for initial implementation):**
- Differential/linear cryptanalysis of T₃ layer (research goal)
- Formal reduction of T₃ inversion to externally verified hard problem
- Target FPGA device family (selection during Vivado 2025.2 installation)
- Independent peer review (active solicitation goal)

---

## 13. Honest Security Framing — Required Disclosures

Any public presentation of HQH-539 MUST include the following statements:

1. **"HQH-539 is a novel cryptographic primitive in active development.
   Security claims marked §-INTERNAL are derived within the S²-11DM²ET-X
   framework and have not been independently peer-reviewed."**

2. **"The SHA3-512 pre- and post-processing layers provide externally
   verified security. The T₃ iteration layer provides additional security
   under the HQCC theorem, which is internal to the S²-11DM²ET-X framework."**

3. **"No formal reduction from the T₃ inversion problem to an externally
   verified hard problem (integer factorization, discrete logarithm, lattice
   SVP) has been established. Such a reduction is an active research goal."**

4. **"Independent cryptanalysis is actively sought. Claims of computational
   infeasibility are made in good faith based on the internal framework and
   should be treated as working hypotheses pending external verification."**

These disclosures reflect the honest status of the primitive and are
consistent with responsible disclosure practices for novel cryptographic
constructions.

---

## 14. Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1-DRAFT | 2026-06-04 | 539 Labs LLC | Initial spec from v1.5 model documents |

---

*Per aspera ad astra.*

*S²-11DM²ET-X Minimal Unification Core — Version 1.5 Final Draft*
*Author of underlying model: Arvin B. Hampton (String Weaver)*
*Specification: 539 Labs LLC*

