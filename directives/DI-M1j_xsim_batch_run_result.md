# DI-M1j Result: XSim Batch Run — Approach A SUCCESS

**Directive:** `DI-M1j_xsim_batch_run.md`  
**Executed by:** Grok  
**Date:** June 10, 2026  
**Outcome:** Approach A succeeded. Approach B not run (not required).

---

## Summary

| Field | Value |
|-------|-------|
| Working approach | **A** — SHA3 pattern (`-key` + `-tclbatch run_pipeline_all.tcl`) |
| TotalSeconds (wall-clock, 100 vectors) | **132.1523782** |
| Testbench result | **100/100 PASS** |
| Simulated time | 9,225,045 ns (per `$finish`) |
| XSim elapsed (internal) | 00:02:09 run / 00:02:10 total |
| Approach B | Skipped — A met success criteria |

---

## Approach A — Command Used

```cmd
call "E:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim"
xsim.bat tb_hqh539_full_pipeline_behav -key {Behavioral:sim_1:Functional:tb_hqh539_full_pipeline} -tclbatch run_pipeline_all.tcl -log sim_pipeline_A.log
```

---

## 1. TotalSeconds

```
132.1523782
```

---

## 2. sim_stdout_A.txt — First 30 Lines

```
****** xsim v2025.2 (64-bit)
  **** SW Build 6299465 on Fri Nov 14 19:35:11 GMT 2025
  **** IP Build 6300035 on Fri Nov 14 10:48:45 MST 2025
  **** SharedData Build 6298862 on Thu Nov 13 04:50:51 MST 2025
  **** Start of session at: Wed Jun 10 01:37:48 2026
    ** Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
    ** Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.

source xsim.dir/tb_hqh539_full_pipeline_behav/xsim_script.tcl
# xsim {tb_hqh539_full_pipeline_behav} -autoloadwcfg -tclbatch {run_pipeline_all.tcl} -key {Behavioral:sim_1:Functional:tb_hqh539_full_pipeline}
Time resolution is 1 ps
source run_pipeline_all.tcl
## run -all
PASS [0]
PASS [1]
PASS [2]
PASS [3]
PASS [4]
PASS [5]
PASS [6]
PASS [7]
PASS [8]
PASS [9]
PASS [10]
PASS [11]
PASS [12]
PASS [13]
PASS [14]
PASS [15]
PASS [16]
PASS [17]
PASS [18]
PASS [19]
PASS [20]
PASS [21]
PASS [22]
PASS [23]
PASS [24]
PASS [25]
PASS [26]
PASS [27]
PASS [28]
PASS [29]
```

## 2b. sim_stdout_A.txt — Last 30 Lines

```
PASS [70]
PASS [71]
PASS [72]
PASS [73]
PASS [74]
PASS [75]
PASS [76]
PASS [77]
PASS [78]
PASS [79]
PASS [80]
PASS [81]
PASS [82]
PASS [83]
PASS [84]
PASS [85]
PASS [86]
PASS [87]
PASS [88]
PASS [89]
PASS [90]
PASS [91]
PASS [92]
PASS [93]
PASS [94]
PASS [95]
PASS [96]
PASS [97]
PASS [98]
PASS [99]

=== M6 Result: 100/100 PASS ===
$finish called at time : 9225045 ns : File "E:/539Labs/rtl/tb_hqh539_full_pipeline.sv" Line 103
run: Time (s): cpu = 00:00:00 ; elapsed = 00:02:09 . Memory (MB): peak = 225.883 ; gain = 0.000
xsim: Time (s): cpu = 00:00:00 ; elapsed = 00:02:10 . Memory (MB): peak = 225.883 ; gain = 31.871
xsim% INFO: xsimkernel Simulation Memory Usage: 12292 KB (Peak: 12292 KB), Simulation CPU Usage: 128859 ms
INFO: [Common 17-206] Exiting xsim at Wed Jun 10 01:39:59 2026...
```

---

## 3. xsim.log Contents

**Note:** `xsim.log` was not written by Approach A (`-log sim_pipeline_A.log` was used). Contents below are from a prior session (June 10 00:31:45) that exited without running simulation.

```
#-----------------------------------------------------------
# xsim v2025.2 (64-bit)
# SW Build 6299465 on Fri Nov 14 19:35:11 GMT 2025
# IP Build 6300035 on Fri Nov 14 10:48:45 MST 2025
# SharedData Build 6298862 on Thu Nov 13 04:50:51 MST 2025
# Start of session at: Wed Jun 10 00:31:45 2026
# Process ID         : 26376
# Current directory  : E:/539Labs/vivado/hqh539_t3core.sim/sim_1/behav/xsim
# Command line       : xsim.exe -mode tcl -source {xsim.dir/tb_hqh539_full_pipeline_behav/xsim_script.tcl}
# Log file           : E:/539Labs/vivado/hqh539_t3core.sim/sim_1/behav/xsim/xsim.log
# Journal file       : E:/539Labs/vivado/hqh539_t3core.sim/sim_1/behav/xsim\xsim.jou
# Running On         : TRAM-GPC1
# Platform           : Windows Server 2016 or Windows 10
# Operating System   : 26200
# Processor Detail   : AMD Ryzen 7 5700X3D 8-Core Processor           
# CPU Frequency      : 3000 MHz
# CPU Physical cores : 8
# CPU Logical cores  : 16
# Host memory        : 68621 MB
# Swap memory        : 10200 MB
# Total Virtual      : 78822 MB
# Available Virtual  : 39400 MB
#-----------------------------------------------------------
source xsim.dir/tb_hqh539_full_pipeline_behav/xsim_script.tcl
# xsim {tb_hqh539_full_pipeline_behav} -autoloadwcfg
Time resolution is 1 ps
xsim% INFO: [Common 17-206] Exiting xsim at Wed Jun 10 00:31:47 2026...
```

### sim_pipeline_A.log (actual Approach A run log)

```
#-----------------------------------------------------------
# xsim v2025.2 (64-bit)
# SW Build 6299465 on Fri Nov 14 19:35:11 GMT 2025
# IP Build 6300035 on Fri Nov 14 10:48:45 MST 2025
# SharedData Build 6298862 on Thu Nov 13 04:50:51 MST 2025
# Start of session at: Wed Jun 10 01:37:48 2026
# Process ID         : 32688
# Current directory  : E:/539Labs/vivado/hqh539_t3core.sim/sim_1/behav/xsim
# Command line       : xsim.exe -log sim_pipeline_A.log -mode tcl -source {xsim.dir/tb_hqh539_full_pipeline_behav/xsim_script.tcl}
# Log file           : E:/539Labs/vivado/hqh539_t3core.sim/sim_1/behav/xsim/sim_pipeline_A.log
# Journal file       : E:/539Labs/vivado/hqh539_t3core.sim/sim_1/behav/xsim\xsim.jou
# Running On         : TRAM-GPC1
# Platform           : Windows Server 2016 or Windows 10
# Operating System   : 26200
# Processor Detail   : AMD Ryzen 7 5700X3D 8-Core Processor           
# CPU Frequency      : 3000 MHz
# CPU Physical cores : 8
# CPU Logical cores  : 16
# Host memory        : 68621 MB
# Swap memory        : 10200 MB
# Total Virtual      : 78822 MB
# Available Virtual  : 39141 MB
#-----------------------------------------------------------
source xsim.dir/tb_hqh539_full_pipeline_behav/xsim_script.tcl
# xsim {tb_hqh539_full_pipeline_behav} -autoloadwcfg -tclbatch {run_pipeline_all.tcl} -key {Behavioral:sim_1:Functional:tb_hqh539_full_pipeline}
Time resolution is 1 ps
source run_pipeline_all.tcl
## run -all
PASS [0]
PASS [1]
PASS [2]
PASS [3]
PASS [4]
PASS [5]
PASS [6]
PASS [7]
PASS [8]
PASS [9]
PASS [10]
PASS [11]
PASS [12]
PASS [13]
PASS [14]
PASS [15]
PASS [16]
PASS [17]
PASS [18]
PASS [19]
PASS [20]
PASS [21]
PASS [22]
PASS [23]
PASS [24]
PASS [25]
PASS [26]
PASS [27]
PASS [28]
PASS [29]
PASS [30]
PASS [31]
PASS [32]
PASS [33]
PASS [34]
PASS [35]
PASS [36]
PASS [37]
PASS [38]
PASS [39]
PASS [40]
PASS [41]
PASS [42]
PASS [43]
PASS [44]
PASS [45]
PASS [46]
PASS [47]
PASS [48]
PASS [49]
PASS [50]
PASS [51]
PASS [52]
PASS [53]
PASS [54]
PASS [55]
PASS [56]
PASS [57]
PASS [58]
PASS [59]
PASS [60]
PASS [61]
PASS [62]
PASS [63]
PASS [64]
PASS [65]
PASS [66]
PASS [67]
PASS [68]
PASS [69]
PASS [70]
PASS [71]
PASS [72]
PASS [73]
PASS [74]
PASS [75]
PASS [76]
PASS [77]
PASS [78]
PASS [79]
PASS [80]
PASS [81]
PASS [82]
PASS [83]
PASS [84]
PASS [85]
PASS [86]
PASS [87]
PASS [88]
PASS [89]
PASS [90]
PASS [91]
PASS [92]
PASS [93]
PASS [94]
PASS [95]
PASS [96]
PASS [97]
PASS [98]
PASS [99]

=== M6 Result: 100/100 PASS ===
$finish called at time : 9225045 ns : File "E:/539Labs/rtl/tb_hqh539_full_pipeline.sv" Line 103
run: Time (s): cpu = 00:00:00 ; elapsed = 00:02:09 . Memory (MB): peak = 225.883 ; gain = 0.000
xsim: Time (s): cpu = 00:00:00 ; elapsed = 00:02:10 . Memory (MB): peak = 225.883 ; gain = 31.871
xsim% INFO: xsimkernel Simulation Memory Usage: 12292 KB (Peak: 12292 KB), Simulation CPU Usage: 128859 ms
INFO: [Common 17-206] Exiting xsim at Wed Jun 10 01:39:59 2026...
```

---

## 4. xsim.jou Contents (post Approach A)

```
#-----------------------------------------------------------
# xsim v2025.2 (64-bit)
# SW Build 6299465 on Fri Nov 14 19:35:11 GMT 2025
# IP Build 6300035 on Fri Nov 14 10:48:45 MST 2025
# SharedData Build 6298862 on Thu Nov 13 04:50:51 MST 2025
# Start of session at: Wed Jun 10 01:37:48 2026
# Process ID         : 32688
# Current directory  : E:/539Labs/vivado/hqh539_t3core.sim/sim_1/behav/xsim
# Command line       : xsim.exe -log sim_pipeline_A.log -mode tcl -source {xsim.dir/tb_hqh539_full_pipeline_behav/xsim_script.tcl}
# Log file           : E:/539Labs/vivado/hqh539_t3core.sim/sim_1/behav/xsim/sim_pipeline_A.log
# Journal file       : E:/539Labs/vivado/hqh539_t3core.sim/sim_1/behav/xsim\xsim.jou
# Running On         : TRAM-GPC1
# Platform           : Windows Server 2016 or Windows 10
# Operating System   : 26200
# Processor Detail   : AMD Ryzen 7 5700X3D 8-Core Processor           
# CPU Frequency      : 3000 MHz
# CPU Physical cores : 8
# CPU Logical cores  : 16
# Host memory        : 68621 MB
# Swap memory        : 10200 MB
# Total Virtual      : 78822 MB
# Available Virtual  : 39141 MB
#-----------------------------------------------------------
source xsim.dir/tb_hqh539_full_pipeline_behav/xsim_script.tcl
source run_pipeline_all.tcl
```

---

## Approach B

Not executed. Approach A met all success criteria (TotalSeconds > 5, 100 PASS lines, M6 Result 100/100 PASS).

---

## Key Finding for DI-M1 Integration

The working invocation pattern is:

```
xsim.bat <snapshot> -key {Behavioral:sim_1:Functional:<top_module>} -tclbatch <driver.tcl> -log <logfile>
```

Passing only `xsim.bat <snapshot>` silently ignores `-tclbatch`, `-R`, and `--runall` (root cause confirmed by directive).

**Per-vector wall-clock estimate:** 132.15 s / 100 vectors ≈ **1.32 s/vector** (Category B — single measurement, this machine).