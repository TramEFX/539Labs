# DI-M3 Result: Compile and Elaborate tb_hqh539_demo Snapshot

**Directive:** `DI-M3_compile_elaborate.md`  
**Executed by:** Grok  
**Date:** June 10, 2026  
**Outcome:** COMPLETE — all success criteria met

---

## Deliverable Checklist

- [x] `tb_hqh539_demo_vlog.prj` created, UTF-8 no BOM
- [x] `xvlog --incr` exits 0, no `ERROR` in `xvlog_demo.log`
- [x] `xelab` exits 0, no `ERROR` in `elaborate_demo.log`
- [x] `xsim.dir\tb_hqh539_demo_behav\` exists (`Test-Path` → **True**)
- [x] One-vector test: `demo_output.dat` hex value matches expected digest
- [x] `demo_output.dat` content pasted verbatim below

---

## Step 1 — xvlog

**Command:**
```cmd
xvlog --incr --relax -L uvm -prj tb_hqh539_demo_vlog.prj -log xvlog_demo.log
```

**Exit code:** 0

**xvlog_demo.log (full):**
```
INFO: [VRFC 10-2263] Analyzing SystemVerilog file "E:/539Labs/rtl/tb_hqh539_demo.sv" into library xil_defaultlib
INFO: [VRFC 10-311] analyzing module tb_hqh539_demo
```

No `ERROR` lines present. Only `tb_hqh539_demo.sv` recompiled (incremental cache hit on all other sources).

---

## Step 2 — xelab

**Command:**
```cmd
xelab --incr --debug typical --relax --mt 2 -L xil_defaultlib -L uvm -L unisims_ver -L unimacro_ver -L secureip --snapshot tb_hqh539_demo_behav xil_defaultlib.tb_hqh539_demo xil_defaultlib.glbl -log elaborate_demo.log
```

**Exit code:** 0

**elaborate_demo.log (full):**
```
Vivado Simulator v2025.2
Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
Running: E:/AMDDesignTools/2025.2/Vivado/bin/unwrapped/win64.o/xelab.exe --incr --debug typical --relax --mt 2 -L xil_defaultlib -L uvm -L unisims_ver -L unimacro_ver -L secureip --snapshot tb_hqh539_demo_behav xil_defaultlib.tb_hqh539_demo xil_defaultlib.glbl -log elaborate_demo.log 
Using 2 slave threads.
Starting static elaboration
Pass Through NonSizing Optimizer
Completed static elaboration
Starting simulation data flow analysis
Completed simulation data flow analysis
Time Resolution for simulation is 1ps
Compiling module xil_defaultlib.div3_1024_pipelined_default
Compiling module xil_defaultlib.hqh539_t3core
Compiling module xil_defaultlib.keccak_f1600
Compiling module xil_defaultlib.hqh539_phase3
Compiling module xil_defaultlib.hqh539_full_pipeline
Compiling module xil_defaultlib.tb_hqh539_demo
Compiling module xil_defaultlib.glbl
Built simulation snapshot tb_hqh539_demo_behav
```

No `ERROR` lines present.

---

## Step 3 — Snapshot Verification

```powershell
Test-Path "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\xsim.dir\tb_hqh539_demo_behav"
```

**Result:** `True`

---

## Step 4 — One-Vector Sanity Test

**Seed (vector 0):**
```
c94227733d14b7a0d35642ca3f3f422b6aec93e96c6e494850d88c4633020a79530bbf77c55dcf28ec39cf7f1f5f666127cd893ba95a359ca0812a93dcd7ee05
```

**Expected digest (vector 0):**
```
e40169d03eaf79e3cb0f2d9449fa9a4b7f6c6cb9db1143344d3662a67c3740818f0eeb338c67e9a7906232108baa43eec1fb9ca705e4965a5766435c73f196cb
```

**Command (as-run; `-testplusarg` quoted for cmd parsing):**
```cmd
xsim.bat tb_hqh539_demo_behav -key {Behavioral:sim_1:Functional:tb_hqh539_demo} -tclbatch run_demo_sim.tcl -testplusarg "SEED=c94227733d14b7a0d35642ca3f3f422b6aec93e96c6e494850d88c4633020a79530bbf77c55dcf28ec39cf7f1f5f666127cd893ba95a359ca0812a93dcd7ee05" -log sim_demo_test.log
```

**Note for DI-M4:** Unquoted `-testplusarg SEED=c942...` fails in cmd with `Expected a switch but found c` because the hex value is parsed as a separate argument. The Python bridge must quote the full `SEED=<hex>` string.

**xsim exit code:** 0

**Wall-clock (single vector):** ~4.2 seconds

**sim_demo_test.log — key lines:**
```
source run_demo_sim.tcl
## run -all
DONE: e40169d03eaf79e3cb0f2d9449fa9a4b7f6c6cb9db1143344d3662a67c3740818f0eeb338c67e9a7906232108baa43eec1fb9ca705e4965a5766435c73f196cb
$finish called at time : 92255 ns : File "E:/539Labs/rtl/tb_hqh539_demo.sv" Line 80
```

**Digest match:** YES — `demo_output.dat` hex value equals expected digest (bit-identical).

---

## demo_output.dat (verbatim)

```
e40169d03eaf79e3cb0f2d9449fa9a4b7f6c6cb9db1143344d3662a67c3740818f0eeb338c67e9a7906232108baa43eec1fb9ca705e4965a5766435c73f196cb
```

---

## Summary

| Criterion | Result |
|-----------|--------|
| xvlog exit 0 | PASS |
| xelab exit 0 | PASS |
| Snapshot `tb_hqh539_demo_behav` exists | PASS |
| Vector 0 digest match | PASS |
| `$finish` reached (`DONE:` in log) | PASS |

**DI-M3: COMPLETE.** Ready for DI-M4 (`xsim_bridge.py`).

---

*Orchestrator: Claude | Builder: Grok | 539 Labs LLC*