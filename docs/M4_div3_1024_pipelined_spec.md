# `div3_1024_pipelined.sv` — RTL Specification

**Project:** HQH-539 | **Milestone:** M4
**Company:** 539 Labs LLC
**Date:** June 6, 2026
**Author:** Orchestrator (Claude)
**Status:** DRAFT — AWAITING BUILDER IMPLEMENTATION
**Workspace target:** `E:\539Labs\docs\M4_div3_1024_pipelined_spec.md`

---

## 0. Document Purpose

This specification is the authoritative design authority for
`div3_1024_pipelined.sv`. It defines every architectural decision,
interface contract, internal structure, and verification requirement.

**Grok implements this module exactly as specified. No architectural
decisions are delegated to the Builder.** Where the spec says "must",
there is no alternative. Where the spec says "should", a deviation
requires written Orchestrator approval before the code is written.

---

## 1. Context and Motivation

### 1.1 What This Module Replaces

`div3_1024.sv` is the current synthesizable division module for HQH-539.
It implements all 1024 stages of the binary long-division algorithm as a
single purely combinational block: one 1024-bit input, one 1024-bit
quotient output, one 2-bit remainder output, no clock.

M2 synthesis results on xc7a200tfbg676-2 (Vivado 2025.2):

| Metric | Value |
|---|---|
| Slice LUTs | 4,250 (3.16%) |
| Slice Registers | 2,060 (0.77%) |
| Critical path (total) | ~127 ns |
| Critical path (logic) | 27.6 ns |
| Critical path (routing) | 99 ns |
| Fmax (synthesis estimate) | ~7.86 MHz |

The critical path is dominated by routing at 78%. Vivado cannot
restructure the 1024-stage serial dependency chain automatically.
The path spans a large region of the device, generating long nets that
the router cannot compact. This is not a logic depth problem; it is a
physical placement and routing problem caused by the sheer span of the
combinational chain.

The only fix that preserves the correctness of the algorithm is
**temporal partitioning**: break the 1024-stage chain into N sequential
clock cycles, each processing 1024/N stages, so that the combinational
logic per cycle spans a small, physically compact region.

### 1.2 What Was Explicitly Rejected

**Spatial partitioning (data slices)** — dividing the 1024-bit input
into 16 independent 64-bit slices and processing them in parallel or
sequentially — was reviewed and rejected.

**Reason:** Integer division by 3 cannot be computed from independent
bit slices. Each algorithm stage produces a new running remainder that
is the sole input to the next stage. The only value that carries
information between stages is the 2-bit running remainder. There is
no way to decompose the problem across data width without producing
incorrect results.

This is a hard architectural constraint. Three-slice, sixteen-slice, or
any other data-width partitioning scheme for this algorithm is wrong.

### 1.3 Adopted Architecture

**Time partitioning: 64 serial algorithm stages per clock cycle.**

The 1024 algorithm stages are distributed across 16 clock cycles.
Each cycle processes 64 consecutive stages of the standard MSB-first
binary long-division algorithm. The only value that crosses a clock
boundary is the 2-bit running remainder.

This reduces the routing span from "all 1024 stages simultaneously"
to "64 stages simultaneously," compacting the combinational logic into
a small physical region and slashing routing delay.

### 1.4 Expected Synthesis Improvement

The M2 critical path had 27.6 ns of logic for 1024 stages — about
0.027 ns per algorithm stage, consistent with Vivado packing ~4 div3
stages into each LUT6 level (4 stages/LUT x 0.1 ns/LUT ~= 0.4 ns per
4-stage group; 1024/4 = 256 LUT levels x 0.1 ns = 25.6 ns ~= matches).

For 64 stages per cycle: 64/4 = **16 LUT levels** of logic
depth (~2 ns). With short local routing (~3-5 ns), the target
critical path is **~7-9 ns -> Fmax ~110-140 MHz**. This exceeds the
100 MHz milestone target.

If synthesis reveals Fmax < 100 MHz, reduce `STAGES_PER_CYCLE` to 32
(32 LUT levels -> 8 LUT levels -> ~1 ns logic -> easier timing closure)
at the cost of 32 cycles per division instead of 16. The parameter is
designed to support this adjustment without RTL restructuring.

---

## 2. Interface Definition

### 2.1 Module Signature

```systemverilog
module div3_1024_pipelined #(
    parameter  int DIVIDEND_WIDTH   = 1024,
    parameter  int STAGES_PER_CYCLE = 64
) (
    input  logic                       clk,
    input  logic                       rst_n,       // Active-low synchronous reset
    input  logic                       start,       // Begin computation (one-cycle high)
    input  logic [DIVIDEND_WIDTH-1:0]  n_in,        // Dividend (sampled when start is high)
    output logic                       busy,        // High while computing
    output logic                       valid,       // One-cycle high when result is ready
    output logic [DIVIDEND_WIDTH-1:0]  quotient,    // Registered output; stable when valid
    output logic [1:0]                 remainder,   // Registered output; stable when valid
    // Combinational lookahead outputs (meaningful only when last_cycle=1)
    output logic [DIVIDEND_WIDTH-1:0]  q_comb,      // Fully assembled quotient (combinational)
    output logic [1:0]                 r_comb,      // Final remainder (combinational)
    output logic                       last_cycle   // High during the final processing cycle
);
```

### 2.2 Port Semantics

| Port | Dir | Width | Semantics |
|---|---|---|---|
| `clk` | in | 1 | System clock. All registers trigger on posedge. |
| `rst_n` | in | 1 | Synchronous active-low reset. Drives all registers to 0. Deassert at least 1 cycle before first `start`. |
| `start` | in | 1 | Assert for exactly one cycle to begin a new computation. Sampled on the rising clock edge. If asserted while `busy` is high and this is the final processing cycle (`cyc == CYCLES-1`), the module immediately restarts. If asserted while `busy` is high at any other cycle, `start` is ignored. |
| `n_in` | in | 1024 | Dividend. Must be stable during the clock cycle when `start` is sampled. Not required to be stable after that edge. |
| `busy` | out | 1 | Combinational output. High whenever the internal FSM is in the RUNNING state. |
| `valid` | out | 1 | Registered output. High for exactly one clock cycle when the final result is registered. `quotient` and `remainder` are guaranteed correct on any cycle where `valid` is high and for all subsequent cycles until the next `start`. |
| `quotient` | out | 1024 | Registered output. The integer quotient of `n_in / 3`. Updated only when `valid` pulses. |
| `remainder` | out | 2 | Registered output. The remainder of `n_in / 3`, in range {0, 1, 2}. Same update contract as `quotient`. |
| `q_comb` | out | 1024 | Combinational output. The fully assembled quotient `{quot_sr[959:0], stage_q}`. Meaningful only when `last_cycle=1`. Holds the correct final quotient between clock edges T-1 and T where T is the clock edge that will register `valid=1`. Used by `hqh539_t3core` to compute the T4121 result one cycle before `valid` fires. |
| `r_comb` | out | 2 | Combinational output. Alias for `stage_rem` — the running remainder after all 64 stages of the current processing cycle. Meaningful only when `last_cycle=1`. |
| `last_cycle` | out | 1 | Combinational output. Asserted (`1`) during the clock period immediately before `valid` fires: `(state == RUNNING) && (cyc == CYCLES-1)`. Fires for exactly one clock period per computation. Used by `hqh539_t3core` to trigger the immediate-restart path without waiting for the registered `valid`. |

### 2.3 Derived Localparams

These must appear at the top of the module body, immediately after the
parameter declarations. They are not overridable.

```systemverilog
localparam int CYCLES     = DIVIDEND_WIDTH / STAGES_PER_CYCLE;
localparam int CYC_BITS   = $clog2(CYCLES);
```

**Constraints on parameter values:**
- `DIVIDEND_WIDTH` must be a power of 2. Default: 1024.
- `STAGES_PER_CYCLE` must be a power of 2 and must divide `DIVIDEND_WIDTH` evenly. Default: 64.
- `CYCLES` must be at least 2.
- Valid configurations: `(1024, 64)` -> 16 cycles [primary target];
  `(1024, 32)` -> 32 cycles [fallback if Fmax < 100 MHz];
  `(1024, 128)` -> 8 cycles [aggressive; may not meet timing];
  `(1024, 512)` -> 2 cycles [minimum valid; Test 1 reference config].
  NOTE: STAGES_PER_CYCLE=DIVIDEND_WIDTH (CYCLES=1) is NOT supported.
  When CYCLES=1 the shift expressions n_shift[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0]
  produce an index of -1 and fail elaboration. Single-cycle use is served
  by the original div3_1024.sv, not this module.

---

## 3. Internal Architecture

### 3.1 Named Structures

The following named structures must appear in the implementation. Their
exact names are normative.

#### 3.1.1 `n_shift` — Input Shift Register

```
n_shift [DIVIDEND_WIDTH-1:0]    // 1024 FFs
```

A left-shift register loaded from `n_in` on the cycle following `start`.
On each RUNNING cycle, it shifts left by `STAGES_PER_CYCLE` (64) bits,
discarding the MSBs and filling the LSBs with zeros.

**Purpose:** Avoids variable part selects. The top `STAGES_PER_CYCLE`
bits always hold the next 64 bits to be processed without needing `cyc`
as a runtime index.

**Initialization:**
- On the clock edge that samples `start=1`: `n_shift <- n_in`
- On each subsequent RUNNING clock edge:
  `n_shift <- {n_shift[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], {STAGES_PER_CYCLE{1'b0}}}`

#### 3.1.2 `rem_r` — Inter-Cycle Remainder Register

```
rem_r [1:0]    // 2 FFs
```

The running remainder accumulated from all algorithm stages processed
in previous cycles. This is the sole information crossing a clock
boundary in the computation.

**Initialization:** Reset to `2'b00` on every `start` pulse.

**Update:** On each RUNNING clock edge, `rem_r <- stage_rem`.

#### 3.1.3 `cyc` — Cycle Counter

```
cyc [CYC_BITS-1:0]    // 4 FFs for CYCLES=16
```

Counts the current processing cycle from 0 to CYCLES-1.

**Initialization:** Reset to 0 on every `start` pulse.

**Update:** Increments by 1 each RUNNING clock edge. Wraps to 0 on
the final cycle (when transitioning back to IDLE or on immediate restart).

#### 3.1.4 `quot_sr` — Quotient Accumulation Shift Register

```
quot_sr [DIVIDEND_WIDTH-1:0]    // 1024 FFs
```

Accumulates the 1024-bit quotient MSB-first over 16 clock cycles.
Implemented as a left-shift register: on each RUNNING clock edge, it
shifts left by `STAGES_PER_CYCLE` bits and loads the new `stage_q`
bits into the LSB positions.

**Formula:** `quot_sr <- {quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q}`

After 16 cycles, `quot_sr` contains the complete assembled quotient
with MSB 64 bits at positions [1023:960] down to LSB 64 bits at [63:0].

**Initialization:** Not reset on `start` (fully overwritten by the time
`valid` fires). The reset value of 0 from `rst_n` is the only
initialization needed.

#### 3.1.5 `state` — FSM State Register

```
state    // 1 FF
// IDLE = 1'b0 / RUNNING = 1'b1
```

#### 3.1.6 `valid` — Valid Output Register

```
valid    // 1 FF
```

Registered output. Set to 1 for exactly one cycle when computation
completes. Otherwise 0.

#### 3.1.7 `quotient`, `remainder` — Registered Outputs

```
quotient  [DIVIDEND_WIDTH-1:0]    // 1024 FFs
remainder [1:0]                   // 2 FFs
```

Separate registered outputs that capture the final result when `valid`
fires. Updated only on the cycle `valid` goes high. Retain their values
until the next `valid` pulse.

**Why separate from `quot_sr`:** `quot_sr` is updated every RUNNING
cycle (assembly in progress). These separate output registers give the
consumer a stable, well-defined result to hold across the entire
16-cycle computation of the next step.

### 3.2 Combinational Stage Block

```
// Wires — not registers
wire [STAGES_PER_CYCLE-1:0]   stage_q;      // Quotient bits (MSB at [63])
wire [1:0]                    stage_rem;    // Remainder after all 64 stages
```

The stage block is a purely combinational 64-stage chain of the binary
div3 algorithm. It has no state.

**Inputs:** `rem_r[1:0]` and `n_shift[DIVIDEND_WIDTH-1:DIVIDEND_WIDTH-STAGES_PER_CYCLE]`

**Outputs:** `stage_q[STAGES_PER_CYCLE-1:0]` and `stage_rem[1:0]`

**Implementation:** See Section 4 for the per-stage algorithm and
required implementation style.

### 3.3 `busy` — Combinational Output

```systemverilog
assign busy = (state == RUNNING);
```

No register. Combinational function of state only.

---

## 4. Per-Stage Division Algorithm

### 4.1 Algorithm Statement

HQH-539 Phase 2 requires computing `q = n // 3` and `r = n mod 3` for
a 1024-bit unsigned integer `n`. The standard MSB-first binary
long-division algorithm for divisor 3 is:

```
Initialize R = 0 (2 bits)
For each bit b[i] from MSB (bit 1023) to LSB (bit 0):
    temp = 2 * R + b[i]   // temp = {R[1:0], b[i]}  (3-bit value)
    if temp >= 3:
        q[i] = 1
        R = temp - 3
    else:
        q[i] = 0
        R = temp
After 1024 bits: remainder = R, quotient = assembled q[1023:0]
```

The key property: at each step, only R (2 bits) carries forward.

### 4.2 Single-Stage Function

Each of the 64 stages per cycle implements one iteration of the loop
above. The complete truth table for one stage is:

| R_in[1:0] | b_in | temp | q_out | R_out[1:0] |
|---|---|---|---|---|
| 00 | 0 | 0 | 0 | 00 |
| 00 | 1 | 1 | 0 | 01 |
| 01 | 0 | 2 | 0 | 10 |
| 01 | 1 | 3 | 1 | 00 |
| 10 | 0 | 4 | 1 | 01 |
| 10 | 1 | 5 | 1 | 10 |
| 11 | x | -- | x | xx |  (invalid: R can never be 3)

### 4.3 Boolean Equations

Derived from the truth table:

```
q_out    = R_in[1] | (R_in[0] & b_in)
R_out[1] = (~R_in[1] & R_in[0] & ~b_in) | (R_in[1] & ~R_in[0] & b_in)
R_out[0] = (~R_in[0]) & (R_in[1] ^ b_in)
```

All six valid rows spot-checked against the truth table in section 4.2
and confirmed. The R=11 don't-care state is unreachable from a valid
initial condition and does not need to be handled.


### 4.4 Implementation Style (Required)

The stage block **must** be implemented as a `genvar`/`generate` loop
using a module-level `wire` array for `r_chain` and a module-level
`function automatic` for the per-stage logic. It must **not** be
implemented as 64 separate submodule instantiations (adds hierarchy
that prevents cross-stage LUT packing) and must **not** use an
`always_comb` for-loop with `automatic` local variables (Vivado
synthesis support for `automatic` in `always_comb` is version-specific
and untested in this project).

#### Module-level declarations (wires, placed with other wire decls):

```systemverilog
wire [1:0] r_chain [0:STAGES_PER_CYCLE];  // STAGES_PER_CYCLE+1 elements
wire [STAGES_PER_CYCLE-1:0] stage_q;
wire [1:0]                  stage_rem;
```

#### `r_chain[0]` assignment (continuous, module level):

```systemverilog
assign r_chain[0] = rem_r;
assign stage_rem  = r_chain[STAGES_PER_CYCLE];
```

#### Per-stage function (module level, before the generate block):

```systemverilog
// Map-agnostic div3 stage — direct transcription of truth table, section 4.2
// Input:  {r_in[1:0], b_in}  — Output: {q_bit, r_out[1:0]}
function automatic [2:0] div3_step(input [2:0] r_b);
    case (r_b)
        3'b000: div3_step = 3'b0_00;  // temp=0: q=0, R=0
        3'b001: div3_step = 3'b0_01;  // temp=1: q=0, R=1
        3'b010: div3_step = 3'b0_10;  // temp=2: q=0, R=2
        3'b011: div3_step = 3'b1_00;  // temp=3: q=1, R=0
        3'b100: div3_step = 3'b1_01;  // temp=4: q=1, R=1
        3'b101: div3_step = 3'b1_10;  // temp=5: q=1, R=2
        default: div3_step = 3'bx_xx; // R=3 impossible; explicit don't-care
    endcase
endfunction
```

#### Generate loop (module level):

```systemverilog
genvar i;
generate
    for (i = 0; i < STAGES_PER_CYCLE; i++) begin : g_stage
        wire [2:0] step_out =
            div3_step({r_chain[i], n_shift[DIVIDEND_WIDTH-1-i]});
        assign stage_q[STAGES_PER_CYCLE-1-i] = step_out[2];
        assign r_chain[i+1]                  = step_out[1:0];
    end
endgenerate
```

**Bit ordering:** Loop index `i=0` selects `n_shift[DIVIDEND_WIDTH-1]`
(MSB), produces `stage_q[STAGES_PER_CYCLE-1]` (bit 63). Loop index
`i=63` selects `n_shift[DIVIDEND_WIDTH-64]` (LSB of current slice),
produces `stage_q[0]`. MSB quotient bit for this cycle is always at
`stage_q[STAGES_PER_CYCLE-1]`. Confirmed correct.

**`r_chain[i+1]` driving:** Each element `r_chain[k]` for k >= 1 is
driven by exactly one generate iteration. `r_chain[0]` is driven by
the separate `assign r_chain[0] = rem_r` above. No multi-driver
conflicts.

#### Fallback (if Vivado emits a synthesis warning on `function automatic` in a `generate` block):

Replace the `wire [2:0] step_out = div3_step(...)` wire initialization
with an explicit `always_comb` inside the named generate block:

```systemverilog
for (i = 0; i < STAGES_PER_CYCLE; i++) begin : g_stage
    logic [2:0] step_out;
    always_comb begin
        case ({r_chain[i], n_shift[DIVIDEND_WIDTH-1-i]})
            3'b000: step_out = 3'b0_00;
            3'b001: step_out = 3'b0_01;
            3'b010: step_out = 3'b0_10;
            3'b011: step_out = 3'b1_00;
            3'b100: step_out = 3'b1_01;
            3'b101: step_out = 3'b1_10;
            default: step_out = 3'bx_xx;
        endcase
    end
    assign stage_q[STAGES_PER_CYCLE-1-i] = step_out[2];
    assign r_chain[i+1]                  = step_out[1:0];
end
```

This fallback is unambiguously synthesis-safe in all Vivado versions.
Use the primary form first; switch to the fallback only if a synthesis
warning appears. Report to Orchestrator before switching.

---

## 5. Sequential Behavior (FSM)

### 5.1 State Machine Overview

Two states: `IDLE` and `RUNNING`. One-bit register.

```
              start
     +-----------------------------------------+
     |                                         |
  +--+--+  start (IDLE)          +---------+  |
  | IDLE|----------------------->| RUNNING |--+
  +--+--+                        +----+----+
     ^           cyc==CYCLES-1        |  cyc<CYCLES-1
     |           (fire valid)         |  (increment cyc)
     +------------------------------------+
```

Immediate restart: if `start` is asserted on the same clock edge that
`cyc == CYCLES-1` is true, the module skips IDLE and goes directly
back to RUNNING with the new `n_in` latched. `valid` still fires for
one cycle during this transition.

### 5.2 Synchronous Reset Behavior

On any clock edge where `rst_n == 1'b0`:

```
state     <- IDLE
cyc       <- 0
n_shift   <- 0
rem_r     <- 0
quot_sr   <- 0
valid     <- 0
quotient  <- 0
remainder <- 0
```

`busy` is combinational and goes to 0 immediately when state=IDLE.

### 5.3 IDLE State Behavior

On each rising clock edge while `state == IDLE`:
- If `start == 1'b1`:
  - `state <- RUNNING`
  - `n_shift <- n_in`
  - `rem_r <- 2'b00`
  - `cyc <- 0`
  - `valid <- 1'b0` (clear any previous valid)
  - `quot_sr`: not modified (previous value; will be fully overwritten)
- If `start == 1'b0`: hold all values

### 5.4 RUNNING State Behavior (cyc < CYCLES-1)

On each rising clock edge while `state == RUNNING && cyc < CYCLES-1`:

```
n_shift  <- {n_shift[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], {STAGES_PER_CYCLE{1'b0}}}
rem_r    <- stage_rem
quot_sr  <- {quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q}
cyc      <- cyc + 1
valid    <- 1'b0
```

`start` is ignored in this state (except when `cyc == CYCLES-1`).

### 5.5 RUNNING State Behavior (cyc == CYCLES-1, Final Cycle)

On the rising clock edge while `state == RUNNING && cyc == CYCLES-1`:

Regardless of `start`:
```
quotient  <- {quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q}
remainder <- stage_rem
valid     <- 1'b1
```

If `start == 1'b0` (normal completion):
```
state   <- IDLE
cyc     <- 0
rem_r   <- stage_rem
quot_sr <- {quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q}
```

If `start == 1'b1` (immediate restart — zero dead cycles):
```
state   <- RUNNING
n_shift <- n_in
rem_r   <- 2'b00
cyc     <- 0
quot_sr <- {quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q}
```

The `quotient` and `remainder` outputs are registered with the
**completed** result. They are stable for the consumer to read while
the new computation proceeds.

---

## 6. Timing Contract

### 6.1 Latency

**Definition:** The number of rising clock edges from the edge that
samples `start = 1` to the edge that registers `valid = 1`.

**Guaranteed latency: exactly CYCLES (16) clock edges.**

```
Cycle index:  0    1    2   ...  14   15
              ^    ^    ^         ^    ^     (rising edges)
start         ^
              |RUNNING                 |IDLE (or restart)
                  <- cyc 0 ->            (processing cycle 0)
                       <- cyc 1 ->
                              ...
                                    <- cyc 14 ->
                                          <- cyc 15 ->
                                                      ^valid=1
```

At cyc=0: stage block processes n_shift[1023:960] = n_in[1023:960] with rem_r=0.
At clock edge 1: rem_r <- stage_rem_0; quot_sr <- {960'b0, stage_q_0}; cyc <- 1.
...
At cyc=15: stage block processes n_shift[63:0] with rem_r after bits 1023..64.
At clock edge 16: quotient and remainder registered; valid <- 1.

### 6.2 Timing Diagram

```
         ___     ___     ___     ___              ___     ___     ___
CLK  ___|   |___|   |___|   |___|   |___ ... ____|   |___|   |___|   |___

        T=0     T=1     T=2     T=3           T=14    T=15    T=16

start ___^^^^_____________________________________________________

n_in  ---NNNN----------------------------------------------------

busy  ________^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^____

cyc   xxxxxxxx|  0  |  1  |  2  | ... |  14  |  15  |  0/x  xxxx

valid _____________________________________________________________^^^^__
                                                              (1 cycle)
quot  ======================================================(new value)===
rem   ======================================================(new value)===
```

### 6.3 Setup/Hold Requirements

- `start` and `n_in` must satisfy standard FPGA FF setup/hold timing.
- `n_in` need not remain stable after T=0.
- `start` need not remain high after T=0.

### 6.4 Back-to-Back Operation and Throughput

**Baseline (registered valid, 18 cycles/step):** With `hqh539_t3core`
driven by the registered `valid` output, each T3 step takes 18 clock
cycles (16 computation + 1 registered-valid delay + 1 response cycle).
539 x 18 = 9,702 cycles per hash = 97.0 us at 100 MHz.

**Optimized (last_cycle + immediate restart, 16 cycles/step):**
Using the `last_cycle` output and making `div3_start` combinational
in `hqh539_t3core`, the module fires the immediate-restart path
(Section 5.5) directly at the final processing cycle edge. Both dead
cycles are eliminated. 539 x 16 = **8,624 cycles** per hash =
**86.2 us at 100 MHz**.

This is the adopted M4 throughput target. The critical timing path for
the 16-cycle design is the feedback loop:

`n_shift FF -> [64-stage chain] -> q_comb/r_comb -> T4121 mux ->
 div3.n_in -> n_shift FF`

Synthesis measured the 64-stage chain alone at ~9.1 ns (synthesis
estimate, unplaced). With dense placement in implementation, routing
compresses significantly. Actual timing must be confirmed by synthesis
and reported. If this feedback path does not close at 100 MHz, reduce
STAGES_PER_CYCLE to 32 and document the actual Fmax.

---

## 7. Quotient Bit Ordering

The quotient is assembled MSB-first across 16 cycles:

| Cycle (cyc) | Input bits processed | Quotient bits |
|---|---|---|
| 0 | n_in[1023:960] | q[1023:960] |
| 1 | n_in[959:896]  | q[959:896]  |
| 2 | n_in[895:832]  | q[895:832]  |
| ... | ... | ... |
| 14 | n_in[127:64]  | q[127:64]   |
| 15 | n_in[63:0]    | q[63:0]     |

**Verification invariant:** For any 1024-bit `n`,
`quotient * 3 + remainder == n` must hold exactly. This is the
primary correctness check for all 1000 test vectors.

---

## 8. Resource Budget and Synthesis Targets

### 8.1 Register Count

| Structure | Width (bits) | FFs |
|---|---|---|
| `n_shift` | 1024 | 1024 |
| `quot_sr` | 1024 | 1024 |
| `quotient` (output reg) | 1024 | 1024 |
| `remainder` (output reg) | 2 | 2 |
| `rem_r` | 2 | 2 |
| `cyc` | 4 | 4 |
| `state` | 1 | 1 |
| `valid` | 1 | 1 |
| **Total** | | **~3,082** |

3,082 / 269,200 = **1.14%** of device FFs. Well within budget.

If FF count is flagged as a concern: the `quotient` output register
can be eliminated by making `quotient` a direct output from `quot_sr`
with an enable gate on `valid`. Do not implement this optimization
without Orchestrator approval.

### 8.2 LUT Count

- 64 stages, each a 3-input -> 3-output function
- Vivado packs ~4 chained stages into one LUT6
- 64 / 4 = **~16 LUT levels** in critical path; ~96-128 LUTs for stage block
- Control logic: ~100-200 LUTs

Estimated total: **~250-350 Slice LUTs** (< 0.3% of 134,600).

### 8.3 Timing Targets

| Metric | Target | Minimum Acceptable |
|---|---|---|
| Fmax (synthesis) | >= 120 MHz | >= 100 MHz |
| Logic delay | < 5 ns | < 8 ns |
| Routing delay | < 5 ns | < 8 ns |
| Total critical path | < 8 ns | < 10 ns |

If Fmax is 85-100 MHz: re-run with `STAGES_PER_CYCLE = 32`.
If Fmax is below 85 MHz at `STAGES_PER_CYCLE = 64`: halt and report
to Orchestrator. Do not change architecture without review.


---

## 9. Verification Requirements

All four verification tests must pass before declaring M4 div3
verification complete. No test may be skipped.

### 9.1 Test 1 — Drop-In Replacement (Functional Correctness)

**Purpose:** Confirm the pipelined module produces bit-identical results
to the existing `div3_1024` module on all 1000 M2 test vectors.

**Configuration:** `STAGES_PER_CYCLE = 1024` (single cycle, all stages
in one clock).

**Method:**
- Write `tb_div3_1024_pipelined.sv` referencing tb_div3_1024.sv structure
- Read from `test_vectors/stimulus_div3.dat` and `test_vectors/expected_div3.dat`
- Issue one `start` per vector; wait for `valid`; compare results
- Expected file format: `idx,remainder,quotient` (remainder BEFORE quotient)
- **Pass criterion:** 1000/1000 vectors match exactly

### 9.2 Test 2 — Pipelined Functional Correctness

**Purpose:** Confirm the 16-cycle pipelined design produces correct results.

**Configuration:** `STAGES_PER_CYCLE = 64`.

**Method:** Same testbench as Test 1 but with `STAGES_PER_CYCLE = 64`.
Wait 16 cycles between issuing `start` and sampling `valid`.

**Pass criterion:** 1000/1000 vectors match exactly.

### 9.3 Test 3 — Back-to-Back Throughput

**Purpose:** Confirm correct operation with consecutive computations
and minimum dead cycles between valid of computation k and start of k+1.

**Configuration:** `STAGES_PER_CYCLE = 64`.

**Method:**
- Issue at least 50 consecutive test vectors
- Immediately after `valid` fires for vector k, assert `start` for k+1
- Verify all 50 results correct (expected values + invariant check)

**Pass criterion:** All 50 consecutive results correct.

### 9.4 Test 4 — Reset Assertion

**Purpose:** Confirm the synchronous reset clears all state cleanly.

**Configuration:** `STAGES_PER_CYCLE = 64`.

**Method:**
- Begin computing a known vector
- Assert `rst_n = 0` after 4-8 cycles (mid-computation)
- Deassert `rst_n = 1` after 2 cycles
- Assert `start` with a new known vector
- Verify result is correct and no stale results appear

**Pass criterion:** No stale results; correct output for vector issued
after reset.

---

## 10. Integration Notes for hqh539_t3core Refactor

This section is informational. The hqh539_t3core refactor is a separate
M4 deliverable with its own spec.

### 10.1 Step Input Derivation (T4121 Mux)

After `div3_1024_pipelined` completes one step:
- `quotient` = `state_k // 3` = the T4121 q value
- `remainder` = `state_k mod 3` = the T4121 branch selector

The T4121 mux (from RTL already in `hqh539_t3core.sv`):

```
r == 2'b00:  next_state = quotient                     // n // 3
r == 2'b01:  next_state = {quotient[1021:0], 2'b01}   // 4q + 1
r == 2'b10:  next_state = {quotient[1022:0], 1'b1}    // 2q + 1
```

### 10.2 Step Counter

hqh539_t3core will maintain a 10-bit step counter (0-539).

```
- On initial start: step_counter <- 0; issue start to div3_pipelined
- On each valid: step_counter <- step_counter + 1
    - If step_counter < 539: compute T4121(quotient, remainder),
      issue start with result to div3_pipelined
    - If step_counter == 539: T3^539 complete; begin Phase 3
```

### 10.3 Total Latency for 539 T3 Steps (Baseline)

- 539 x 17 cycles (16 computation + 1 inter-step) = **9,163 clock cycles**
- At 100 MHz: **91.6 us per hash**
- At 120 MHz: **76.4 us per hash**

The zero-dead-cycle path (8,624 cycles) is documented in the
hqh539_t3core refactor spec.

---

## 11. Hard Rules for Builder

These constraints are non-negotiable. Violations are architectural
errors, not style disagreements.

1. **Do NOT implement spatial partitioning.** Integer division by 3
   requires the running remainder to traverse all 1024 bits serially.
   Any design where bits [1023:960] are processed independently of
   bits [959:896] is incorrect.

2. **Do NOT add extra pipeline stages inside the 64-stage combinational
   block.** The stage block is purely combinational. Registers inside
   break the algorithm.

3. **Do NOT use three instances of div3_1024.** Three instances was an
   explicitly rejected proposal.

4. **Do NOT use `Out-File -Encoding utf8` in PowerShell.** Use
   `[System.IO.File]::WriteAllText` with
   `New-Object System.Text.UTF8Encoding $false` to avoid BOM injection.
   (Ref: M2 bug log, Notion Section 10.)

5. **Do NOT use a local T3 implementation.** This module is
   map-agnostic. No T3 or T4121 logic belongs in this file.

6. **Use `STAGES_PER_CYCLE = 64` as the default parameter value.**
   Do not hard-code 64 anywhere in the RTL.

7. **Do NOT run `impl_1` on this module alone.** Synthesis only.
   Full implementation requires `hqh539_t3core_top.sv` wrapper (M4 Step 4).

8. **S2-11DM2ET-X constants: none in this file.** This module is pure
   arithmetic. If a framework constant appears, use the required comment
   template from Notion Section 8.

---

## 12. File Header Template

The following header must appear verbatim at the top of the generated
`.sv` file:

```systemverilog
//==============================================================================
// div3_1024_pipelined.sv
// HQH-539 | M4 Deliverable | 539 Labs LLC
//
// Time-partitioned 1024-bit division by 3.
// STAGES_PER_CYCLE serial algorithm stages per clock cycle.
// CYCLES = DIVIDEND_WIDTH / STAGES_PER_CYCLE clock cycles to completion.
// Inter-cycle state: 2-bit running remainder (rem_r) only.
//
// Architecture: temporal partitioning (NOT spatial/data-slice partitioning).
// See M4_div3_1024_pipelined_spec.md for full design rationale.
//
// Map-agnostic: implements div3 only. Replaces div3_1024.sv (M2 baseline).
// T4121 mux belongs in hqh539_t3core.sv -- not here.
//
// Author: Grok (Builder) | Spec: Claude (Orchestrator)
// Date: 2026-06-06
//==============================================================================
```

---

## 13. Acceptance Checklist

Before marking this deliverable complete, the Orchestrator verifies:

- [ ] File saved as `E:\539Labs\rtl\div3_1024_pipelined.sv`
- [ ] File header matches template (Section 12)
- [ ] Module signature matches Section 2.1 exactly
- [ ] `DIVIDEND_WIDTH` and `STAGES_PER_CYCLE` are parameters (not hard-coded)
- [ ] `CYCLES` and `CYC_BITS` are localparams derived from parameters
- [ ] `n_shift` is a left-shift register (not a static register with variable part select)
- [ ] `quot_sr` is a left-shift register accumulating MSB-first
- [ ] Stage block uses `genvar`/`generate` loop with module-level
  `wire [1:0] r_chain [0:STAGES_PER_CYCLE]` and `function automatic
  div3_step` (Section 4.4) — not a submodule instantiation loop, not
  an `always_comb` for-loop with `automatic` local variables
- [ ] Stage block truth table matches Section 4.2 exactly (verify by
  inspection of the `case` statement rows)
- [ ] Three combinational outputs present: `q_comb`, `r_comb`, `last_cycle`
- [ ] `q_comb` = `{quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q}` (assign)
- [ ] `r_comb` = `stage_rem` (assign)
- [ ] `last_cycle` = `(state == RUNNING) && (cyc == CYCLES-1)` (assign)
- [ ] Immediate-restart on `cyc == CYCLES-1 && start` is implemented
- [ ] `valid` is a 1-cycle pulse (not a level)
- [ ] `busy` is a combinational output of `state == RUNNING`
- [ ] No `$display` or `$monitor` statements in the synthesizable RTL
- [ ] No UTF-8 BOM in the file
- [ ] Synthesis runs without errors at `STAGES_PER_CYCLE = 64`
- [ ] Test 1: 1000/1000 PASS (STAGES_PER_CYCLE = 1024)
- [ ] Test 2: 1000/1000 PASS (STAGES_PER_CYCLE = 64)
- [ ] Test 3: 50/50 back-to-back PASS
- [ ] Test 4: Reset assertion PASS
- [ ] Synthesis Fmax reported and filed under
  `E:\539Labs\docs\M4_div3_pipelined_timing.txt`

---

*539 Labs LLC | HQH-539 | M4*
*Orchestrator: Claude | Builder: Grok*
*S2-11DM2ET-X Minimal Unification Core v1.5 | T4121 Variant Adopted*
