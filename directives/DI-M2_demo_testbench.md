# DI-M2: Create Single-Shot Demo Testbench

539 Labs LLC | HQH-539 Demo Engine Integration
**Status: ACTIVE — Awaiting Grok implementation**
Created: June 10, 2026

---

## Objective

Write `E:\539Labs\rtl\tb_hqh539_demo.sv` — a single-shot testbench that:
1. Accepts a 512-bit seed via `+SEED=<128-hex-chars>` plusarg
2. Runs one full pass through `hqh539_full_pipeline`
3. Writes the 512-bit digest (128 hex chars) to `demo_output.dat` in the working directory
4. Calls `$finish` cleanly

This is the RTL half of the XSim bridge (`xsim_bridge.py`, DI-M4). The Python bridge will:
- Compute Phase 1 (SHA3-512 seed) in Python
- Pass `seed_hex` to XSim via `+SEED=`
- Read `demo_output.dat` for the digest

---

## File to Create

**Path:** `E:\539Labs\rtl\tb_hqh539_demo.sv`

**Encoding:** UTF-8 without BOM
Use:
```powershell
[System.IO.File]::WriteAllText("E:\539Labs\rtl\tb_hqh539_demo.sv", $content,
  (New-Object System.Text.UTF8Encoding $false))
```

---

## Full Specification

### Module Header

```
// tb_hqh539_demo.sv
// Single-shot demo testbench — hqh539_full_pipeline
// DI-M2 | 539 Labs LLC | June 2026
//
// Accepts: +SEED=<128-hex-char Phase 1 output>
// Writes:  demo_output.dat — 128 hex chars (digest) + newline, in xsim working directory
// TCL:     run_demo_sim.tcl must contain: run -all
```

### Timescale

```systemverilog
`timescale 1ns / 1ps
```

### Module Declaration

```systemverilog
module tb_hqh539_demo;
```

### Signal Declarations

```systemverilog
    reg         clk      = 0;
    reg         rst_n    = 0;
    reg         valid_in = 0;
    reg [511:0] seed_in  = 0;

    wire        busy;
    wire [511:0] digest;
    wire        valid_out;
```

### Clock

```systemverilog
    always #5 clk = ~clk;   // 100 MHz
```

### DUT Instantiation

```systemverilog
    hqh539_full_pipeline dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .seed_in  (seed_in),
        .busy     (busy),
        .digest   (digest),
        .valid_out(valid_out)
    );
```

### Local Variables

```systemverilog
    logic [511:0] seed_val;
    integer       out_fd;
    integer       timeout_cnt;
    localparam int TIMEOUT_CYC = 12000;   // >> 9,225 cycle pipeline latency
```

### Initial Block

```systemverilog
    initial begin
        // --- 1. Read seed from plusarg ---
        if (!$value$plusargs("SEED=%h", seed_val)) begin
            $display("ERROR: +SEED=<128-hex-char> plusarg required");
            $finish;
        end

        // --- 2. Reset ---
        rst_n = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // --- 3. Launch one pipeline pass ---
        seed_in  <= seed_val;
        valid_in <= 1'b1;
        @(posedge clk);
        valid_in <= 1'b0;

        // --- 4. Wait for valid_out or timeout ---
        timeout_cnt = 0;
        while (!valid_out && timeout_cnt < TIMEOUT_CYC) begin
            @(posedge clk);
            timeout_cnt++;
        end

        if (timeout_cnt >= TIMEOUT_CYC) begin
            $display("ERROR: timeout waiting for valid_out after %0d cycles", TIMEOUT_CYC);
            $finish;
        end

        // --- 5. Write digest to demo_output.dat ---
        out_fd = $fopen("demo_output.dat", "w");
        if (out_fd == 0) begin
            $display("ERROR: cannot open demo_output.dat for writing");
            $finish;
        end
        $fdisplay(out_fd, "%h", digest);   // 128 lowercase hex chars + newline
        $fclose(out_fd);

        $display("DONE: %128h", digest);
        $finish;
    end

endmodule
```

---

## Output File Format

`demo_output.dat` must contain exactly:
```
<128 lowercase hex chars>\n
```

Example (not a real vector):
```
a3f2...c9d1\n
```

The Python bridge reads this with `.strip()` and validates `len == 128`. Do not add any prefix, index, or extra newlines.

---

## Correctness Requirement

On the same `+SEED=` value, `tb_hqh539_demo.sv` must produce the **same digest** as `tb_hqh539_full_pipeline.sv` produces for that seed in its 100-vector run. Both instantiate `hqh539_full_pipeline` identically. If the digests differ, something is wrong with the reset or timing sequence — compare against the conventions in §10 of `DI_orchestrator.md`.

---

## TCL Driver

`run_demo_sim.tcl` (already exists at `E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\run_demo_sim.tcl`) must contain only:

```tcl
run -all
```

If it doesn't exist yet, Grok creates it with that single line (UTF-8 no BOM).

---

## XSim Invocation (for DI-M3 reference — not Grok's job yet)

After DI-M3 compiles the snapshot, the bridge will invoke:
```
xsim.bat tb_hqh539_demo_behav \
  -key {Behavioral:sim_1:Functional:tb_hqh539_demo} \
  -tclbatch run_demo_sim.tcl \
  -testplusarg SEED=<128-hex-chars> \
  -log sim_demo.log
```

Working directory: `E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\`
(`demo_output.dat` will be written there)

---

## Vivado Path Requirement

XSim requires the Vivado environment. Source the settings script first:
```
call "E:\AMDDesignTools\2025.2\Vivado\settings64.bat"
```
Then `xsim.bat`, `xvlog.bat`, and `xelab.bat` are in PATH. The bridge handles this at runtime — not Grok's concern for DI-M2.

---

## Deliverable Checklist

Grok delivers when:

- [ ] `E:\539Labs\rtl\tb_hqh539_demo.sv` exists, UTF-8 no BOM
- [ ] `run_demo_sim.tcl` in xsim working directory contains `run -all` (create if missing)
- [ ] Module compiles cleanly (checked in DI-M3 — but Grok should report any obvious syntax issues now)
- [ ] Grok confirms the file is written and pastes the first 10 lines back verbatim

---

## Notes

- **Do not add `$dumpfile`/`$dumpvars`** — this is a batch-mode testbench, no waveforms.
- **Do not add verification logic** comparing against expected — single-shot only.
- The `%h` format in `$value$plusargs` reads the full 128-hex-char seed into `logic [511:0]` in XSim. This is confirmed behavior.
- Do not use PowerShell `Out-File` for the `.sv` or `.tcl` files — UTF-8 BOM breaks xvlog.

---

*Orchestrator: Claude | Builder: Grok*
*539 Labs LLC*
