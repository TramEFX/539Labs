# M7 Post-Benchmark Vivado Restore Directive

**To:** Grok  
**From:** Orchestrator  
**Date:** June 8, 2026  
**Status:** M7 COMPLETE — restoring project to M6 state

---

## Task: Restore Vivado Synthesis and Simulation Tops

M7 synthesis was run with `sha3_512_standalone` as the synthesis top.
Restore the project to the M6 production state before closing.

### Run in Vivado TCL Console

```tcl
# Restore synthesis top
set_property top hqh539_full_pipeline [get_filesets sources_1]
set_property top_lib xil_defaultlib [get_filesets sources_1]
update_compile_order -fileset sources_1

# Restore simulation top
set_property top tb_hqh539_full_pipeline [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.xsim.more_options} \
             -value "-testplusarg TV_PATH=E:/539Labs/test_vectors/" \
             -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "Restore complete."
puts "Synthesis top: [get_property top [get_filesets sources_1]]"
puts "Simulation top: [get_property top [get_filesets sim_1]]"
```

### Expected Output
```
Restore complete.
Synthesis top: hqh539_full_pipeline
Simulation top: tb_hqh539_full_pipeline
```

### Verify (optional — run sim to confirm M6 still passes)
```tcl
launch_simulation
run -all
```
Expected: `=== HQH-539 Pipeline Sim: 100/100 PASS ===`

---

Report: paste the two "puts" lines confirming tops are correct.
