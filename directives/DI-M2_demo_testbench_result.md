# DI-M2 Result: Single-Shot Demo Testbench

**Directive:** `DI-M2_demo_testbench.md`  
**Executed by:** Grok  
**Date:** June 10, 2026  
**Outcome:** COMPLETE — files written per specification

---

## Deliverable Checklist

- [x] `E:\539Labs\rtl\tb_hqh539_demo.sv` exists, UTF-8 no BOM (verified: first bytes `47,47,32` = `//`, not `EF,BB,BF`)
- [x] `run_demo_sim.tcl` in xsim working directory contains `run -all`
- [x] Syntax review (pre-DI-M3): no obvious issues — see notes below
- [x] First 10 lines pasted verbatim below

---

## Files Created / Updated

| File | Action |
|------|--------|
| `E:\539Labs\rtl\tb_hqh539_demo.sv` | Created (2306 bytes) |
| `E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\run_demo_sim.tcl` | Created (`run -all`) |
| `E:\539Labs\vivado\run_demo_sim.tcl` | Pre-existing (`run -all`) — unchanged |

---

## First 10 Lines — tb_hqh539_demo.sv (verbatim)

```
// tb_hqh539_demo.sv
// Single-shot demo testbench - hqh539_full_pipeline
// DI-M2 | 539 Labs LLC | June 2026
//
// Accepts: +SEED=<128-hex-char Phase 1 output>
// Writes:  demo_output.dat - 128 hex chars (digest) + newline, in xsim working directory
// TCL:     run_demo_sim.tcl must contain: run -all

`timescale 1ns / 1ps
```

---

## Syntax / Convention Review (pre-DI-M3)

**No blocking syntax issues identified.**

| Item | Status |
|------|--------|
| `timescale 1ns / 1ps` | Matches `tb_hqh539_full_pipeline.sv` |
| DUT ports / instantiation | Identical to full-pipeline testbench |
| Clock (`always #5`) | 100 MHz — matches |
| Reset sequence (`repeat(4)`, `rst_n` release) | Matches full-pipeline testbench |
| `valid_in` 1-cycle pulse pattern | Matches inner loop of full-pipeline testbench |
| `TIMEOUT_CYC = 12000` | > 10000 used in full-pipeline TB; >> 9225 latency |
| No `$dumpfile`/`$dumpvars` | Confirmed absent |
| No expected-value comparison | Confirmed absent |
| Output format `$fdisplay(out_fd, "%h", digest)` | Single line, 128 hex + newline |

**Timing note for DI-M3 verification:**  
`tb_hqh539_full_pipeline.sv` inserts an extra `@(posedge clk)` before each vector launch (line 73) in addition to the post-reset wait (line 69). The demo testbench launches immediately after the single post-reset `@(posedge clk)` (directive spec). Digest equivalence on a shared `+SEED=` must be confirmed in DI-M3; if mismatch, align demo launch timing to full-pipeline convention.

---

## Module Summary

- **Input:** `+SEED=<128-hex-chars>` via `$value$plusargs("SEED=%h", seed_val)`
- **Output:** `demo_output.dat` in xsim CWD — one line of 128 lowercase hex chars + newline
- **Completion:** `$display("DONE: %128h", digest)` then `$finish`
- **Error paths:** missing plusarg, timeout (`TIMEOUT_CYC`), file open failure

---

## Planned XSim Invocation (DI-M3 reference — not executed)

```
xsim.bat tb_hqh539_demo_behav \
  -key {Behavioral:sim_1:Functional:tb_hqh539_demo} \
  -tclbatch run_demo_sim.tcl \
  -testplusarg SEED=<128-hex-chars> \
  -log sim_demo.log
```

Working directory: `E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\`

---

## Ready for DI-M3

Grok scope complete. Next step: Orchestrator directs DI-M3 (xvlog + xelab → `tb_hqh539_demo_behav` snapshot, compile verification).

---

*Orchestrator: Claude | Builder: Grok | 539 Labs LLC*