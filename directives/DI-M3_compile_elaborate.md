# DI-M3: Compile and Elaborate tb_hqh539_demo Snapshot

539 Labs LLC | HQH-539 Demo Engine Integration
**Status: ACTIVE — Awaiting Grok implementation**
Created: June 10, 2026

---

## Objective

Compile `tb_hqh539_demo.sv` into the existing `xil_defaultlib` compiled library and elaborate
a new XSim snapshot `tb_hqh539_demo_behav`. Then run a single-vector sanity test to confirm
bit-identical output vs. the known DI-M1 test vectors.

DI-M3 is COMPLETE only when:
1. xvlog exits 0 with no errors
2. xelab exits 0 with no errors
3. `xsim.dir\tb_hqh539_demo_behav\` exists
4. One-vector test produces `demo_output.dat` that matches the expected digest

---

## Environment

**Working directory for all commands:**
```
E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\
```

**Vivado environment (must be sourced first):**
```cmd
call "E:\AMDDesignTools\2025.2\Vivado\settings64.bat"
```

This adds `xvlog.bat`, `xelab.bat`, and `xsim.bat` to PATH.

---

## Step 1 — Create tb_hqh539_demo_vlog.prj

Create `E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\tb_hqh539_demo_vlog.prj`
with the following content (UTF-8 no BOM):

```
# compile verilog/system verilog design source files
sv xil_defaultlib  --include "../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" \
"../../../../../rtl/hqh539_t3core.sv" \
"../../../../../rtl/div3_1024.sv" \
"../../../../../rtl/div3_1024_pipelined.sv" \
"../../../../../rtl/hqh539_t3core_top.sv" \
"../../../../../rtl/keccak_f1600.sv" \
"../../../../../rtl/hqh539_phase3.sv" \
"../../../../../rtl/hqh539_full_pipeline.sv" \
"../../../../../rtl/sha3_512_standalone.sv" \
"../../../../../rtl/tb_sha3_512_standalone.sv" \
"../../../../../rtl/tb_div3_1024.sv" \
"../../../../../rtl/tb_hqh539_pipeline.sv" \
"../../../../../rtl/tb_div3_1024_pipelined.sv" \
"../../../../../rtl/tb_hqh539_phase3.sv" \
"../../../../../rtl/tb_hqh539_full_pipeline.sv" \
"../../../../../rtl/tb_hqh539_demo.sv" \

# compile glbl module
verilog xil_defaultlib "glbl.v"

# Do not sort compile order
nosort
```

This is identical to `tb_sha3_512_standalone_vlog.prj` with one addition: `tb_hqh539_demo.sv`
appended to the sv file list.

**Write with no BOM:**
```powershell
[System.IO.File]::WriteAllText(
  "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\tb_hqh539_demo_vlog.prj",
  $content,
  (New-Object System.Text.UTF8Encoding $false)
)
```

---

## Step 2 — xvlog (compile)

From the working directory, after sourcing settings64.bat:

```cmd
xvlog --incr --relax -L uvm -prj tb_hqh539_demo_vlog.prj -log xvlog_demo.log
```

**Success criteria:**
- Exit code 0
- `xvlog_demo.log` does not contain `ERROR`
- `xil_defaultlib` compiled library updated (incremental — most files will be cache hits)

**If xvlog errors:**
- Paste the first 20 lines of `xvlog_demo.log` back to Orchestrator verbatim. Do not attempt to fix independently.

---

## Step 3 — xelab (elaborate)

From the working directory:

```cmd
xelab --incr --debug typical --relax --mt 2 -L xil_defaultlib -L uvm -L unisims_ver -L unimacro_ver -L secureip --snapshot tb_hqh539_demo_behav xil_defaultlib.tb_hqh539_demo xil_defaultlib.glbl -log elaborate_demo.log
```

Key parameters explained:
- `--snapshot tb_hqh539_demo_behav` — name of the output snapshot
- `xil_defaultlib.tb_hqh539_demo` — top-level module (library.module)
- `xil_defaultlib.glbl` — required Xilinx global module
- `--debug typical` — required for `-key` flag to work during xsim invocation

**Success criteria:**
- Exit code 0
- `elaborate_demo.log` does not contain `ERROR`
- `xsim.dir\tb_hqh539_demo_behav\` directory exists

**If xelab errors:**
- Paste the first 20 lines of `elaborate_demo.log` back to Orchestrator verbatim. Do not attempt to fix independently.

---

## Step 4 — Verify Snapshot Exists

Confirm the following directory was created:
```
E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\xsim.dir\tb_hqh539_demo_behav\
```

Run:
```powershell
Test-Path "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\xsim.dir\tb_hqh539_demo_behav"
```

Expected: `True`. If `False`, stop and report to Orchestrator.

---

## Step 5 — One-Vector Sanity Test

Run xsim with test vector 0 from `stimulus_pipeline.dat` / `expected_pipeline.dat`.

**Seed (vector 0, from stimulus_pipeline.dat):**
```
c94227733d14b7a0d35642ca3f3f422b6aec93e96c6e494850d88c4633020a79530bbf77c55dcf28ec39cf7f1f5f666127cd893ba95a359ca0812a93dcd7ee05
```

**Expected digest (vector 0, from expected_pipeline.dat):**
```
e40169d03eaf79e3cb0f2d9449fa9a4b7f6c6cb9db1143344d3662a67c3740818f0eeb338c67e9a7906232108baa43eec1fb9ca705e4965a5766435c73f196cb
```

**Command:**
```cmd
xsim.bat tb_hqh539_demo_behav -key {Behavioral:sim_1:Functional:tb_hqh539_demo} -tclbatch run_demo_sim.tcl -testplusarg SEED=c94227733d14b7a0d35642ca3f3f422b6aec93e96c6e494850d88c4633020a79530bbf77c55dcf28ec39cf7f1f5f666127cd893ba95a359ca0812a93dcd7ee05 -log sim_demo_test.log
```

**After xsim completes, read `demo_output.dat`:**
```powershell
Get-Content "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\demo_output.dat"
```

**Success criteria:**
1. xsim exit code 0
2. `demo_output.dat` exists and contains one line
3. Hex value in `demo_output.dat` equals expected digest (hex-value comparison — strip whitespace,
   leading zeros do not affect value equivalence)
4. `sim_demo_test.log` contains "DONE:" line confirming `$finish` was reached

**Verification note — timing:**
The demo testbench launches `valid_in` one cycle earlier than the full-pipeline testbench's
per-vector loop does. This does not affect the digest. Both instantiate `hqh539_full_pipeline`
identically; the extra idle cycle in the full-pipeline TB is cosmetic. If digests match, DI-M3
is complete. If they do NOT match, paste both digest values to Orchestrator — do not debug independently.

**If demo_output.dat is empty or missing:**
- Paste last 20 lines of `sim_demo_test.log` to Orchestrator verbatim.

---

## Deliverable Checklist

Grok reports COMPLETE when all of the following are true:

- [ ] `tb_hqh539_demo_vlog.prj` created, UTF-8 no BOM
- [ ] `xvlog --incr` exits 0, no errors in `xvlog_demo.log`
- [ ] `xelab` exits 0, no errors in `elaborate_demo.log`
- [ ] `xsim.dir\tb_hqh539_demo_behav\` exists (`Test-Path` returns `True`)
- [ ] One-vector test: `demo_output.dat` hex value matches expected digest
- [ ] Grok pastes `demo_output.dat` content verbatim in the result file

---

## Notes

- `--incr` on xvlog means only changed/new files are recompiled. Most source files will be
  cache hits from the DI-M1 compile. Only `tb_hqh539_demo.sv` is new.
- `--debug typical` on xelab is required. Without it, the `-key` flag in xsim is ignored
  and `-tclbatch` won't execute. This is the DI-M1 gotcha.
- Do NOT use `--debug off` even though the demo testbench has no waveform dump.
- The `-key {Behavioral:sim_1:Functional:tb_hqh539_demo}` format follows the pattern confirmed
  in DI-M1: `{Behavioral:sim_1:Functional:<top_module_name>}`.
- Do not modify `compile.bat` or `elaborate.bat` — those are Vivado-generated for the SHA3
  standalone testbench. Use the new `tb_hqh539_demo_vlog.prj` approach.
- `run_demo_sim.tcl` was confirmed created by DI-M2 with content `run -all`.

---

*Orchestrator: Claude | Builder: Grok | 539 Labs LLC*
