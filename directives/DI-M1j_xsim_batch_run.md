# DI-M1j: Get XSim to execute run -all and produce PASS/FAIL output

## Root cause (read before running anything)

When you call `xsim.bat <snapshot_name>`, xsim.exe internally converts the snapshot name to
`-mode tcl -source {xsim.dir/<snapshot>/xsim_script.tcl}`. That script only loads the simulation —
it has no `run -all`. Any flags you pass after the snapshot name (-tclbatch, -R, --runall) are
silently ignored because xsim.exe has already chosen TCL mode from the snapshot arg.

The SHA3 simulate.bat works differently: it uses `-key {Behavioral:sim_1:Functional:<top>}` which
switches xsim.exe to project-key mode where -tclbatch IS processed.

## Working directory for all commands

```cmd
E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\
```

## Approach A — Mirror SHA3 pattern (try this first)

Files already written:
- `run_pipeline_all.tcl` contains: `run -all`

Run from PowerShell:

```powershell
$t = Measure-Command {
  cmd /c 'call "E:\AMDDesignTools\2025.2\Vivado\settings64.bat" && cd /d "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim" && xsim.bat tb_hqh539_full_pipeline_behav -key {Behavioral:sim_1:Functional:tb_hqh539_full_pipeline} -tclbatch run_pipeline_all.tcl -log sim_pipeline_A.log > sim_stdout_A.txt 2>&1'
}
Write-Output "=== Approach A TotalSeconds: $($t.TotalSeconds) ==="
Get-Content "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\sim_stdout_A.txt"
Get-Content "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\sim_pipeline_A.log" -ErrorAction SilentlyContinue
Get-Content "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\xsim.jou"
```

**Success indicator**: TotalSeconds > 5, output contains PASS or FAIL lines from testbench $display.

If Approach A produces "Invalid key" or errors with no PASS/FAIL, proceed to Approach B.

## Approach B — Direct TCL source override

Files already written:
- `custom_run.tcl` contains:
  ```
  xsim {tb_hqh539_full_pipeline_behav} -autoloadwcfg
  run -all
  quit
  ```

Run from PowerShell:

```powershell
$t = Measure-Command {
  cmd /c 'call "E:\AMDDesignTools\2025.2\Vivado\settings64.bat" && cd /d "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim" && xsim.bat -mode tcl -source custom_run.tcl > sim_stdout_B.txt 2>&1'
}
Write-Output "=== Approach B TotalSeconds: $($t.TotalSeconds) ==="
Get-Content "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\sim_stdout_B.txt"
Get-Content "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\xsim.log"
Get-Content "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\xsim.jou"
```

Mechanism: passing `-mode tcl -source custom_run.tcl` directly means xsim.exe never sees a snapshot
name, so it does NOT auto-switch modes. rdiArgs.bat passes these flags through verbatim. Our file
controls the full sequence: load snapshot → run all → quit.

**Success indicator**: TotalSeconds > 5, PASS/FAIL lines in stdout or xsim.log.

## What to report back

For whichever approach worked (or both if both run):
1. TotalSeconds value
2. First 30 lines and last 30 lines of stdout file
3. xsim.log contents
4. xsim.jou contents

If neither approach produces PASS/FAIL, also run:
```powershell
Get-Content "E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\webtalk.log" -ErrorAction SilentlyContinue
```
