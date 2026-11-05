# HQH-539 vs SHA3-512 Throughput Benchmark
**539 Labs LLC | M7 | June 2026 | S²-11DM²ET-X v1.5**

---

## 1. Overview

This report documents the M7 throughput benchmark comparing HQH-539 (full 3-phase pipeline)
against SHA3-512 standalone on the same FPGA target. All cycle counts are
simulation-confirmed. Synthesis Fmax values are pre-route estimates. No values are
projected or prejudged.

**FPGA Target:** xc7a200tfbg676-2 (Artix-7 200T)  
**Operating Clock:** 100 MHz  
**Simulator:** Vivado XSIM 2025.2  
**Simulation Date:** June 2026  

---

## 2. Primary Result: Cycle-Count Throughput Ratio

| Metric                    | HQH-539 Full Pipeline       | SHA3-512 Standalone FPGA    |
|---------------------------|-----------------------------|-----------------------------|
| Cycles per hash           | **9,225**                   | **28**                      |
| Latency @ 100 MHz         | 92.25 μs/hash               | 0.280 μs/hash               |
| Throughput @ 100 MHz      | ~10,840 H/s                 | ~3,571,429 H/s (3.57 MH/s) |
| Simulation result         | 100/100 PASS (M6)           | 10/10 PASS (M7)             |

**Throughput ratio (SHA3-512 standalone / HQH-539): 9,225 / 28 = 329.5×**

SHA3-512 standalone processes 329.5 hashes in the time HQH-539 processes one. This ratio is
the direct consequence of the T4121^539 computation embedded in Phase 2: 539 iterations of the
ternary Syracuse map applied to a 1024-bit state, pipelined across a 64-stage div3 chain.

---

## 3. HQH-539 Pipeline Timing (Confirmed M6)

HQH-539 is a 3-phase sequential pipeline:

| Phase | Operation                         | Cycles   | Notes                          |
|-------|-----------------------------------|----------|--------------------------------|
| 1     | SHA3-512 (off-chip, CPU)          | n/a      | Software; not clocked on FPGA  |
| 2     | T4121^539 (ternary Syracuse)      | ~9,169   | 539 iterations × 17 cyc avg   |
| 3     | SHA3-512 (on-FPGA, Keccak-f[1600])| 28       | Single block, 25-cycle perm    |
|       | **Total (Phases 2+3)**            | **9,225**| Simulation-confirmed           |

**Simulation evidence:** `tb_hqh539_full_pipeline` XSIM run, M6 — 100/100 PASS at 100 MHz.  
**M4 post-route Fmax:** ~101.6 MHz (WNS +0.162 ns at 100 MHz target; critical path: div3_1024_pipelined).

> **S²-11DM²ET-X claim [not independently verified]:** Under the S²-11DM²ET-X Minimal
> Unification Core v1.5 framework, the T4121^539 iteration count establishes a 539-step
> lower bound on adversarial preimage work in the ternary domain. This bound is a
> framework-level assertion and has not been verified by independent cryptanalysis.

---

## 4. SHA3-512 Standalone Timing (Confirmed M7)

| Metric                        | Value                         | Source                     |
|-------------------------------|-------------------------------|----------------------------|
| Cycles per hash               | 28                            | XSIM simulation (M7)       |
| Latency @ 100 MHz             | 0.280 μs                      | 28 × 10 ns                 |
| Throughput @ 100 MHz          | 3,571,429 H/s (3.57 MH/s)    | 1 / 0.280 μs               |
| WNS (synthesis, 100 MHz)      | +7.301 ns                     | Vivado synthesis M7        |
| Estimated Fmax (synthesis)    | ~370.5 MHz                    | 1000 / (10.000 − 7.301) ns |
| Slice LUTs                    | 5,500 (4.09% of 134,600)      | Vivado synthesis M7        |
| Slice Registers (FFs)         | 5,331 (1.98% of 269,200)      | Vivado synthesis M7        |
| BRAMs / DSPs                  | 0 / 0                         | Pure LUT/FF implementation |

**Cycle count breakdown (28 total):**
- Cycle 0: `valid_in` pulse asserted; IDLE → LOAD_BLOCK (state machine latches msg, builds 72-byte block)
- Cycle 1: LOAD_BLOCK → RUN_PERM; `keccak_start` driven high for one cycle; keccak_f1600 begins
- Cycles 2–26: Keccak-f[1600] permutation (25 cycles: 1 load + 24 rounds)
- Cycle 27: `keccak_done` registered output sampled; `K` updated → SQUEEZE
- Cycle 28: SQUEEZE: byte-reverse 8 lanes, `valid_out` asserted, `digest_out` valid

**Note on Fmax:** The synthesis-level estimate of ~370.5 MHz is pre-route. Post-route Fmax
will be lower due to routing delays. The value is included for comparative reference only.

---

## 5. CPU Baseline (Python hashlib SHA3-512)

Included as context for the FPGA comparison; not the primary benchmark metric.

| Metric             | Value                    | Platform                    |
|--------------------|--------------------------|-----------------------------|
| Throughput         | 1,054,719 H/s (1.055 MH/s)| Python 3.x hashlib, CPU    |
| Latency per hash   | 0.9481 μs                | Measured (100,000 iter avg) |
| Input size         | 64 bytes                 | Single-block, no padding    |
| Benchmark script   | `benchmarks/cpu_benchmark_sha3.py` | M7 Task F        |

**FPGA vs CPU (at same 100 MHz operating clock):**

| System                        | Throughput         | vs CPU Python       |
|-------------------------------|--------------------|---------------------|
| SHA3-512 FPGA standalone      | 3.571 MH/s         | **3.39× faster**    |
| HQH-539 FPGA full pipeline    | 0.01084 MH/s       | 97.3× slower        |
| SHA3-512 CPU (Python hashlib) | 1.055 MH/s         | baseline            |

HQH-539's lower throughput vs CPU is by design: the 539-iteration T4121 computation is the
security primitive, intentionally costly. Throughput is not an optimization target for HQH-539.

---

## 6. Resource Comparison (Synthesis)

| Module                  | Slice LUTs        | Slice FFs         | BRAMs | DSPs |
|-------------------------|-------------------|-------------------|-------|------|
| sha3_512_standalone     | 5,500 (4.09%)     | 5,331 (1.98%)     | 0     | 0    |
| hqh539_t3core_top (M4)  | 3,184 (2.37%)     | 4,573 (1.70%)     | 0     | 0    |

Note: `hqh539_t3core_top` is Phase 2 only (T4121^539 core + wrapper); full pipeline synthesis
was not run in M6. `sha3_512_standalone` is Phase 3 only. Both fit comfortably on the
xc7a200tfbg676-2 with substantial headroom.

---

## 7. Methodology Notes

- All FPGA cycle counts are measured from XSIM waveform timing, not estimated.
- "Latency" = cycles from `valid_in` assertion to `valid_out` assertion at 100 MHz.
- Synthesis WNS values are from Vivado post-synthesis timing reports (not post-route).
- Fmax estimates derived as: `Fmax = 1000 / (Tperiod − WNS)` ns.
- CPU benchmark uses Python `hashlib.sha3_512`, 100,000 iterations, wall-clock time.
- The primary benchmark metric is the **cycle-count ratio (329.5×)** — clock-independent
  and directly comparable at any frequency.

---

## 8. M7 Deliverables

| File                              | Status   | Description                              |
|-----------------------------------|----------|------------------------------------------|
| `rtl/sha3_512_standalone.sv`      | ✓ DONE   | Standalone SHA3-512 module               |
| `rtl/tb_sha3_512_standalone.sv`   | ✓ DONE   | Testbench, 10/10 PASS                    |
| `test_vectors/stimulus_sha3.dat`  | ✓ DONE   | 10 stimulus vectors (clean hex)          |
| `test_vectors/expected_sha3.dat`  | ✓ DONE   | 10 expected digests                      |
| `benchmarks/M7_sha3_timing_synth.txt`      | ✓ DONE   | Vivado timing report (WNS +7.301 ns) |
| `benchmarks/M7_sha3_utilization_synth.txt` | ✓ DONE   | Vivado utilization (5,500 LUTs)      |
| `benchmarks/M7_cpu_benchmark.txt`          | ✓ DONE   | Python CPU baseline (1.055 MH/s)     |
| `benchmarks/M7_benchmark_report.md`        | ✓ DONE   | This report                          |

---

## 9. M7 Summary

- **Cycle-count ratio: 329.5×** (SHA3-512 standalone vs HQH-539 full pipeline)
- SHA3-512 standalone: 28 cycles, 0.28 μs/hash @ 100 MHz, timing met (WNS +7.301 ns)
- HQH-539 full pipeline: 9,225 cycles, 92.25 μs/hash @ 100 MHz, 100/100 PASS (M6)
- SHA3-512 FPGA is 3.39× faster than CPU Python baseline at 100 MHz
- HQH-539 throughput is intentionally limited by the 539-iteration T4121 security primitive
- All Artix-7 resource usage is well within device capacity; no BRAMs or DSPs used

**Milestone M7: COMPLETE**
