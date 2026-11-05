# M7 Directive — Benchmark vs SHA3-512 Throughput
539 Labs LLC | Orchestrator: Claude | Builder: Grok
Generated: June 8, 2026

---

## Goal

Populate `benchmarks/` (currently empty). Establish hard cycle-count and throughput numbers
for HQH-539 vs standalone SHA3-512 on the same FPGA at 100 MHz. Also capture CPU baseline.

## Context

**HQH-539 confirmed throughput (M4/M6):**
- 9,225 cycles/hash @ 100 MHz = 92.25 μs/hash = ~10,840 hashes/sec
- Latency breakdown: 9,163 cycles Phase 2 (539 × 17) + 55 cycles Phase 3 + 7 overhead

**Comparison target:**
- SHA3-512 of a 64-byte (512-bit) input
- 64 bytes < 72-byte SHA3-512 rate → fits in one block → ONE Keccak-f[1600] permutation
- Expected: ~28 cycles (1 load + 24 rounds + 2 FSM overhead + 1 squeeze)

**keccak_f1600.sv interface (confirmed from source):**
```
module keccak_f1600 (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          start,        // pulse to begin
    input  wire [1599:0] state_in,
    output reg  [1599:0] state_out,
    output reg           done           // pulses one cycle when complete
);
```
Latency: 25 cycles from `start` assertion to `done` (1 load + 24 rounds).

---


## Task A — Python Vector Generator

Write `python/gen_sha3_standalone_vectors.py`:

```python
import hashlib

IN    = "E:/539Labs/test_vectors/stimulus_pipeline.dat"
S_OUT = "E:/539Labs/test_vectors/stimulus_sha3.dat"
E_OUT = "E:/539Labs/test_vectors/expected_sha3.dat"

with open(IN) as f:
    lines = [l.strip() for l in f if l.strip()][:10]

with open(S_OUT, 'w') as sf, open(E_OUT, 'w') as ef:
    for seed_hex in lines:
        seed_bytes = bytes.fromhex(seed_hex)
        digest = hashlib.sha3_512(seed_bytes).hexdigest()
        sf.write(seed_hex + '\n')
        ef.write(digest + '\n')

print("Generated 10 SHA3-512 standalone test vectors")
print(f"  stimulus_sha3.dat: first entry = {lines[0][:16]}...")
```

Run it. Verify 10 lines written to each output file.

**Note:** `stimulus_sha3.dat` reuses the first 10 seeds from M6's pipeline stimulus.
The expected output is SHA3-512(seed_bytes) — this is a standalone SHA3-512 hash,
not the HQH-539 pipeline output.

---

## Task B — sha3_512_standalone.sv

Write `rtl/sha3_512_standalone.sv` using the EXACT content below.
Use `[System.IO.File]::WriteAllText` with no-BOM UTF-8.

```systemverilog
// sha3_512_standalone.sv
// SHA3-512 of a fixed 64-byte (512-bit) message — single Keccak-f[1600] permutation
// SHA3-512 rate = 576 bits = 72 bytes (9 x 64-bit lanes)
// Block: msg[63:0] + 0x06 + 0x00..0x00 + 0x80 (72 bytes total)
// M7 benchmark reference — 539 Labs LLC

module sha3_512_standalone (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          valid_in,       // hold high for one cycle to submit msg
    input  wire [511:0]  msg_in,         // big-endian: byte0 at [511:504], byte63 at [7:0]
    output reg  [511:0]  digest_out,     // big-endian SHA3-512 digest
    output reg           valid_out       // pulses one cycle when digest_out is ready
);

    reg [1599:0] K;

    typedef enum logic [2:0] {
        IDLE, LOAD, RUN_PERM, SQUEEZE, DONE_ST
    } state_t;
    state_t state;

    wire          keccak_done;
    wire [1599:0] keccak_state_out;
    reg           keccak_start_reg;

    keccak_f1600 keccak_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (keccak_start_reg),
        .state_in (K),
        .state_out(keccak_state_out),
        .done     (keccak_done)
    );

    // Rising-edge detect on valid_in
    reg valid_in_d;
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) valid_in_d <= 1'b0; else valid_in_d <= valid_in;
    wire valid_in_pulse = valid_in & ~valid_in_d;

    logic [7:0]  block_bytes [0:71];
    logic [63:0] lane;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= IDLE;
            K                <= 1600'd0;
            digest_out       <= 512'd0;
            valid_out        <= 1'b0;
            keccak_start_reg <= 1'b0;
        end else begin
            valid_out        <= 1'b0;
            keccak_start_reg <= 1'b0;

            case (state)
                IDLE: begin
                    if (valid_in_pulse) begin
                        // msg_in big-endian: byte 0 at [511:504]
                        for (int i = 0; i < 64; i++)
                            block_bytes[i] = msg_in[511 - 8*i -: 8];
                        block_bytes[64] = 8'h06;           // SHA3 domain sep
                        for (int i = 65; i < 71; i++)
                            block_bytes[i] = 8'h00;
                        block_bytes[71] = 8'h80;           // multi-rate padding

                        // Load 9 lanes into K (state starts all-zero, so no XOR needed)
                        for (int i = 0; i < 9; i++) begin
                            lane = { block_bytes[8*i+7], block_bytes[8*i+6],
                                     block_bytes[8*i+5], block_bytes[8*i+4],
                                     block_bytes[8*i+3], block_bytes[8*i+2],
                                     block_bytes[8*i+1], block_bytes[8*i+0] };
                            K[64*i +: 64] <= lane;
                        end
                        for (int j = 9; j < 25; j++)
                            K[64*j +: 64] <= 64'd0;
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    keccak_start_reg <= 1'b1;
                    state <= RUN_PERM;
                end

                RUN_PERM: begin
                    if (keccak_done) begin
                        K     <= keccak_state_out;
                        state <= SQUEEZE;
                    end
                end

                SQUEEZE: begin
                    // Squeeze 8 lanes → 512-bit digest, byte-reverse per lane (little→big endian)
                    for (int i = 0; i < 8; i++) begin
                        lane = keccak_state_out[64*i +: 64];
                        digest_out[511 - 64*i -: 64] <= {
                            lane[7:0],  lane[15:8],  lane[23:16], lane[31:24],
                            lane[39:32], lane[47:40], lane[55:48], lane[63:56]
                        };
                    end
                    valid_out <= 1'b1;
                    state <= DONE_ST;
                end

                DONE_ST: state <= IDLE;

                default: state <= IDLE;
            endcase
        end
    end

endmodule
```

**Critical note on SQUEEZE:** read from `keccak_state_out` directly (not `K`), because
`K <= keccak_state_out` hasn't registered yet when we transition from RUN_PERM to SQUEEZE
on the same cycle as `keccak_done`. This matches hqh539_phase3's pattern.

---

**CORRECTION to SQUEEZE state:** Read from `K`, not `keccak_state_out`. When `keccak_done`
fires on cycle C, `K <= keccak_state_out` registers on that same edge. By the time the FSM
is in SQUEEZE (cycle C+1), `K` is already updated. Use this for SQUEEZE:

```systemverilog
SQUEEZE: begin
    for (int i = 0; i < 8; i++) begin
        lane = K[64*i +: 64];
        digest_out[511 - 64*i -: 64] <= {
            lane[7:0],  lane[15:8],  lane[23:16], lane[31:24],
            lane[39:32], lane[47:40], lane[55:48], lane[63:56]
        };
    end
    valid_out <= 1'b1;
    state <= DONE_ST;
end
```

This matches hqh539_phase3's SQUEEZE pattern exactly.

---

## Task C — tb_sha3_512_standalone.sv

Write `rtl/tb_sha3_512_standalone.sv`. Model directly on `tb_hqh539_phase3.sv`.

Key differences from the Phase 3 testbench:
- DUT: `sha3_512_standalone` (ports: `clk`, `rst_n`, `valid_in`, `msg_in[511:0]`, `digest_out[511:0]`, `valid_out`)
- Stimulus file: `stimulus_sha3.dat` (10 lines, 128-char hex = 512-bit messages)
- Expected file: `expected_sha3.dat` (10 lines, 128-char hex = 512-bit digests)
- N_VECTORS = 10
- TIMEOUT_CYCS = 100 (28-cycle expected latency + margin)
- Apply `valid_in` for 1 cycle per vector, then deassert and wait for `valid_out`
- Compare `digest_out` to expected; print PASS/FAIL per vector
- Final line: `"N/10 PASS"` then `$finish`

TV_PATH plusarg: `-testplusarg TV_PATH=E:/539Labs/test_vectors/`
(testbench concatenates `TV_PATH + "stimulus_sha3.dat"` etc.)

---

## Task D — Vivado Simulation

**D1.** Add files to project (from existing Vivado TCL session or sim_setup.tcl run):

```tcl
add_files -norecurse -scan_for_includes {E:/539Labs/rtl/sha3_512_standalone.sv}
add_files -norecurse -scan_for_includes {E:/539Labs/rtl/tb_sha3_512_standalone.sv}
set_property file_type SystemVerilog [get_files {sha3_512_standalone.sv}]
set_property file_type SystemVerilog [get_files {tb_sha3_512_standalone.sv}]
set_property used_in_synthesis false [get_files {tb_sha3_512_standalone.sv}]
set_property top tb_sha3_512_standalone [get_filesets sim_1]
```

**D2.** Launch simulation:
```tcl
launch_simulation -simset sim_1 -mode behavioral \
  -testplusarg TV_PATH=E:/539Labs/test_vectors/
run -all
```

**Target:** 10/10 PASS. Report exact cycle count from `valid_in_pulse` to `valid_out` for vector 0.

---

## Task E — SHA3-512 Standalone Synthesis

This gets us LUT count and estimated Fmax for standalone SHA3-512 as a reference.

**E1.** Set synthesis top:
```tcl
set_property top sha3_512_standalone [get_filesets sources_1]
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1
```

Expected: synthesis completes with I/O warnings (no wrapper) but no errors.
LUT count should be in the ~5,000–8,000 range (keccak logic dominates).

**E2.** Report results:
```tcl
report_timing_summary -file {E:/539Labs/benchmarks/M7_sha3_timing_synth.txt}
report_utilization    -file {E:/539Labs/benchmarks/M7_sha3_utilization_synth.txt}
```

**E3.** Extract and report back:
- Slice LUTs used
- WNS (synthesis estimate — use to compute Fmax = 1000 / (10 - WNS) MHz)
- Note: synthesis-level Fmax is an estimate; post-route would require a wrapper

---


## Task F — Python CPU Benchmark

Write `python/benchmark_sha3.py`:

```python
import hashlib, time, os

N   = 100_000
msg = os.urandom(64)   # 64-byte random message, matches FPGA benchmark input size

start   = time.perf_counter()
for _   in range(N):
    hashlib.sha3_512(msg).digest()
elapsed = time.perf_counter() - start

us_per_hash   = elapsed / N * 1e6
hashes_per_sec = N / elapsed

result = (
    f"SHA3-512 CPU Benchmark\n"
    f"Platform: Python hashlib\n"
    f"Input size: 64 bytes\n"
    f"Iterations: {N:,}\n\n"
    f"Total time:    {elapsed:.3f} s\n"
    f"Throughput:    {hashes_per_sec:,.0f} hashes/sec  ({hashes_per_sec/1e6:.3f} MH/s)\n"
    f"Latency:       {us_per_hash:.4f} us/hash\n"
)
print(result)

out_path = "E:/539Labs/benchmarks/M7_cpu_benchmark.txt"
with open(out_path, 'w') as f:
    f.write(result)
print(f"Saved to {out_path}")
```

Run it. Paste the output into `benchmarks/M7_cpu_benchmark.txt` (script does this automatically).

---

## Task G — Benchmark Report

After D2, E2, and F complete, write `benchmarks/M7_benchmark_report.md`.

Fill in the bracketed values from measured data. Use the template:

```
# HQH-539 vs SHA3-512 Throughput Benchmark
539 Labs LLC | M7 | June 2026 | S2-11DM2ET-X v1.5

## Platform
Device: xc7a200tfbg676-2 (Artix-7 200T)
Clock: 100 MHz (10 ns period)
Sim tool: Vivado 2025.2 XSIM
Synthesis: Vivado 2025.2 synth_design

## FPGA Results — Simulation-Confirmed Cycle Counts

| Metric                 | HQH-539 Full Pipeline       | SHA3-512 Standalone        |
|------------------------|-----------------------------|----------------------------|
| Input                  | 512-bit seed                | 512-bit (64-byte) message  |
| Keccak-f[1600] perms   | 2 (Phase 3)                 | 1                          |
| T4121 iterations       | 539                         | 0                          |
| Cycles/hash (sim)      | 9,225 (100/100 M6 PASS)     | [from D2]                  |
| Latency @ 100 MHz      | 92.25 us/hash               | [X] us/hash                |
| Throughput @ 100 MHz   | ~10,840 hashes/sec          | [Y] hashes/sec             |
| Throughput ratio       | —                           | HQH-539 is ~[N]x slower    |
| Slice LUTs (synth)     | [from M4 utilization]       | [from E2]                  |
| Fmax (synthesis est.)  | 101.6 MHz (M4 post-route)   | [from E2 WNS]              |

## HQH-539 Cycle Breakdown
- Phase 2 (T4121^539): 9,163 cycles (539 steps x 17 cycles/step)
- Phase 3 (SHA3-512): 55 cycles (2 Keccak-f[1600] x 25 + 5 FSM overhead)
- Pipeline overhead: 7 cycles
- Total: 9,225 cycles

## CPU Baseline (software SHA3-512)
[paste M7_cpu_benchmark.txt output here]

## Interpretation
The throughput ratio quantifies the additional computational work HQH-539 performs per
digest relative to bare SHA3-512. This overhead is intentional: the 539 T4121 iterations
constitute the cryptographic work function, making brute-force preimage attacks
proportionally harder than against SHA3-512 alone.

// S2-11DM2ET-X v1.5 — Proprietary framework claim, not independently verified.
// The 539-step bound is a topological invariant of the G2-holonomy manifold (61 punctures).
// Per Arvin B. Hampton, String Weaver. Ref: 539 Labs Notion, Section 8.

All cycle counts are simulation-confirmed. Synthesis Fmax values are pre-route estimates.
No values are projected or prejudged.

## Source Files
- benchmarks/M7_sha3_timing_synth.txt
- benchmarks/M7_sha3_utilization_synth.txt
- benchmarks/M7_cpu_benchmark.txt
```

---

## Execution Order

1. Task A — generate vectors (Python, ~5 seconds)
2. Task B — write sha3_512_standalone.sv
3. Task C — write tb_sha3_512_standalone.sv
4. Task D — Vivado simulation → confirm 10/10 PASS, record cycle count
5. Task E — Vivado synthesis → record LUT + Fmax
6. Task F — Python CPU benchmark
7. Task G — write M7_benchmark_report.md with all measured values

If simulation fails (Task D): report exact FAIL output before proceeding to synthesis.
If synthesis fails on errors (not warnings): report error messages.

## Restore Vivado Sim Top After M7

After synthesis completes, restore the simulation top for future work:
```tcl
set_property top hqh539_full_pipeline [get_filesets sources_1]
set_property top tb_hqh539_full_pipeline [get_filesets sim_1]
```

---
*M7 Directive — 539 Labs LLC | Orchestrator: Claude*
