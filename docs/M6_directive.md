# M6 Directive — Full HQH-539 Pipeline Integration
**539 Labs LLC | Orchestrator: Claude | Builder: Grok**
**Date: June 7, 2026 | M5 COMPLETE (20/20) — Proceeding to M6**

---

## Objective

Connect Phase 2 (`hqh539_t3core`) and Phase 3 (`hqh539_phase3`) into a single
end-to-end pipeline module. Verify with 100 full-stack test vectors.

Pipeline: `seed_in[511:0]` → T4121^539 → SHA3-512 → `digest[511:0]`

---

## Interface Facts (from M4/M5 RTL — do not infer, use these exactly)

**hqh539_t3core ports:**
```
clk, reset_n (active-low), valid_in (1-cycle pulse), seed_in[511:0]
valid_out (1-cycle pulse), state_out[1023:0]
```
Latency: 9,163 cycles (539 steps × 17 cycles/step)

**hqh539_phase3 ports:**
```
clk, rst_n (active-low), valid_in (level — edge-detected internally),
state_in[255:0], digest[511:0], valid_out (1-cycle pulse)
```
Latency: ~54 cycles. Edge-detects valid_in, so a 1-cycle pulse works correctly.

**State connection:** `t3core.state_out[255:0]` → `phase3.state_in[255:0]`
The T3 state integer is stored in bits [195:0] of the 1024-bit register
(bits [1023:256] unused, bits [255:196] zero). Truncating to [255:0] is
equivalent to Python's `state.to_bytes(32, 'big')`. Verified correct.

**Reset:** Both submodules use active-low reset. Map both to pipeline's `rst_n`.
(t3core's port is named `reset_n`, phase3's is `rst_n` — same signal, different names.)

---

## Step 1 — Generate Pipeline Test Vectors

Write and run `E:\539Labs\python\gen_pipeline_vectors.py`.

This script generates end-to-end vectors where the stimulus is the **Phase 1 output**
(the seed fed into the RTL), not the raw message. This is what the RTL testbench will consume.

```python
"""
gen_pipeline_vectors.py
Generates end-to-end HQH-539 pipeline test vectors (STD mode, 100 vectors).
Stimulus: Phase 1 output (seed = int(SHA3-512(msg || SALT_STD), 'big'))
Expected: Full HQH-539 digest (Phase 3 output)
"""
import hashlib
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hqh539 import hqh539, SALT_STD

N = 100
base_dir = os.path.dirname(os.path.abspath(__file__))
tv_dir   = os.path.join(base_dir, "..", "test_vectors")

stim_path = os.path.join(tv_dir, "stimulus_pipeline.dat")
exp_path  = os.path.join(tv_dir, "expected_pipeline.dat")

with open(stim_path, "w") as sf, open(exp_path, "w") as ef:
    for i in range(N):
        msg    = f"Resonant test vector {i} for 539 Labs - STD mode".encode("utf-8")
        # Phase 1: seed = int(SHA3-512(msg || SALT_STD), big-endian)
        seed   = int.from_bytes(hashlib.sha3_512(msg + SALT_STD).digest(), 'big')
        digest = hqh539(msg, mode="STD")
        sf.write(f"{i},{seed:0128x}\n")   # 512-bit seed as 128-char hex
        ef.write(f"{i},{digest}\n")
        if i % 25 == 0: print(f"  {i}/{N}")

print(f"Done. {stim_path}, {exp_path}")
```

Run from PowerShell (no BOM issues — no RTL files involved):
```powershell
cd E:\539Labs\python
python gen_pipeline_vectors.py
```
Verify output: both files exist, each has 100 lines.

---

## Step 2 — Write hqh539_full_pipeline.sv

Write to `E:\539Labs\rtl\hqh539_full_pipeline.sv` using no-BOM encoding.

```systemverilog
// hqh539_full_pipeline.sv
// HQH-539 Full Pipeline — Phase 2 (T4121^539) + Phase 3 (SHA3-512)
// M6 | 539 Labs LLC | June 2026
// S²-11DM²ET-X Minimal Unification Core v1.5 — T4121 Variant
//
// Interface:
//   seed_in  [511:0] — Phase 1 output: int(SHA3-512(msg||salt), big-endian)
//   valid_in         — 1-cycle pulse to start; do not assert while busy=1
//   digest   [511:0] — Final HQH-539 SHA3-512 digest
//   valid_out        — 1-cycle pulse when digest is ready
//   busy             — high from valid_in acceptance until valid_out
//
// Latency: ~9,218 cycles @ 100 MHz (9163 Phase 2 + ~55 Phase 3)

`timescale 1ns / 1ps

module hqh539_full_pipeline (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          valid_in,
    input  wire [511:0]  seed_in,
    output wire          busy,
    output wire [511:0]  digest,
    output wire          valid_out
);

    wire         t3_valid_out;
    wire [1023:0] t3_state_out;

    // busy: high from valid_in acceptance through valid_out
    reg running_r;
    assign busy = running_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)           running_r <= 1'b0;
        else if (valid_in)    running_r <= 1'b1;
        else if (valid_out)   running_r <= 1'b0;
    end

    // Phase 2: T4121^539
    hqh539_t3core u_t3core (
        .clk      (clk),
        .reset_n  (rst_n),           // both active-low; t3core port named reset_n
        .valid_in (valid_in),
        .seed_in  (seed_in),
        .valid_out(t3_valid_out),
        .state_out(t3_state_out)
    );

    // Phase 3: SHA3-512 finalization
    // state_in[255:0] = lower 256 bits of t3 state = state.to_bytes(32,'big')
    hqh539_phase3 u_phase3 (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (t3_valid_out),    // 1-cycle pulse feeds edge detector
        .state_in (t3_state_out[255:0]),
        .digest   (digest),
        .valid_out(valid_out)
    );

endmodule
```

Write using no-BOM encoding:
```powershell
$sv = @'
<paste full module text above>
'@
[System.IO.File]::WriteAllText("E:\539Labs\rtl\hqh539_full_pipeline.sv", $sv,
    (New-Object System.Text.UTF8Encoding $false))
```

---

## Step 3 — Write tb_hqh539_full_pipeline.sv

Write to `E:\539Labs\rtl\tb_hqh539_full_pipeline.sv` (no BOM).

```systemverilog
// tb_hqh539_full_pipeline.sv
// Testbench for hqh539_full_pipeline — 100 end-to-end STD vectors
// M6 | 539 Labs LLC
// Vector format:
//   stimulus_pipeline.dat: index,seed_hex   (512-bit seed as 128 hex chars)
//   expected_pipeline.dat: index,digest_hex (512-bit digest as 128 hex chars)
// Plusarg: +TV_PATH=E:/539Labs/test_vectors/  (trailing slash required)

`timescale 1ns / 1ps

module tb_hqh539_full_pipeline;

    localparam int N_VECTORS   = 100;
    localparam int TIMEOUT_CYC = 10000;  // >> 9218 cycle pipeline latency

    reg         clk     = 0;
    reg         rst_n   = 0;
    reg         valid_in = 0;
    reg [511:0] seed_in  = 0;

    wire        busy;
    wire [511:0] digest;
    wire        valid_out;

    always #5 clk = ~clk;   // 100 MHz

    hqh539_full_pipeline dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .seed_in  (seed_in),
        .busy     (busy),
        .digest   (digest),
        .valid_out(valid_out)
    );

    // File handles
    integer stim_fd, exp_fd;
    string  tv_path;
    integer idx_s, idx_e;
    reg [511:0] seed_vec  [0:N_VECTORS-1];
    reg [511:0] exp_vec   [0:N_VECTORS-1];

    // Load vectors
    initial begin
        if (!$value$plusargs("TV_PATH=%s", tv_path)) tv_path = "E:/539Labs/test_vectors/";
        stim_fd = $fopen({tv_path, "stimulus_pipeline.dat"}, "r");
        exp_fd  = $fopen({tv_path, "expected_pipeline.dat"}, "r");
        if (stim_fd == 0) begin $display("ERROR: cannot open stimulus_pipeline.dat"); $finish; end
        if (exp_fd  == 0) begin $display("ERROR: cannot open expected_pipeline.dat"); $finish; end

        for (int i = 0; i < N_VECTORS; i++) begin
            void'($fscanf(stim_fd, "%d,%128h\n", idx_s, seed_vec[i]));
            void'($fscanf(exp_fd,  "%d,%128h\n", idx_e, exp_vec[i]));
        end
        $fclose(stim_fd);
        $fclose(exp_fd);
    end

    // Main test
    integer pass_count;
    integer timeout_cnt;

    initial begin
        pass_count = 0;
        rst_n      = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        for (int v = 0; v < N_VECTORS; v++) begin
            // Assert valid_in for exactly 1 cycle
            @(posedge clk);
            seed_in  <= seed_vec[v];
            valid_in <= 1'b1;
            @(posedge clk);
            valid_in <= 1'b0;

            // Wait for valid_out or timeout
            timeout_cnt = 0;
            while (!valid_out && timeout_cnt < TIMEOUT_CYC) begin
                @(posedge clk);
                timeout_cnt++;
            end

            if (timeout_cnt >= TIMEOUT_CYC) begin
                $display("FAIL [%0d]: TIMEOUT after %0d cycles", v, TIMEOUT_CYC);
            end else if (digest !== exp_vec[v]) begin
                $display("FAIL [%0d]: digest mismatch", v);
                $display("  Got: %128h", digest);
                $display("  Exp: %128h", exp_vec[v]);
            end else begin
                $display("PASS [%0d]", v);
                pass_count++;
            end

            // Wait for busy to clear before next vector
            while (busy) @(posedge clk);
            repeat(2) @(posedge clk);
        end

        $display("\n=== M6 Result: %0d/%0d PASS ===", pass_count, N_VECTORS);
        $finish;
    end

endmodule
```

---

## Step 4 — Vivado Integration

Open `E:\539Labs\vivado\hqh539_t3core.xpr` in Vivado 2025.2.

In the Vivado TCL console:

```tcl
# Add new RTL files
add_files -norecurse {E:/539Labs/rtl/hqh539_full_pipeline.sv}
add_files -fileset sim_1 -norecurse {E:/539Labs/rtl/tb_hqh539_full_pipeline.sv}

# Set file types
set_property file_type SystemVerilog [get_files hqh539_full_pipeline.sv]
set_property file_type SystemVerilog [get_files tb_hqh539_full_pipeline.sv]

# Mark testbench as simulation-only
set_property used_in_synthesis false [get_files tb_hqh539_full_pipeline.sv]
set_property used_in_implementation false [get_files tb_hqh539_full_pipeline.sv]

# Set simulation top
set_property top tb_hqh539_full_pipeline [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Set TV_PATH plusarg (trailing slash required)
set_property -name {xsim.simulate.xsim.more_options} \
    -value {-testplusarg TV_PATH=E:/539Labs/test_vectors/} \
    -objects [get_filesets sim_1]

# Launch simulation
launch_simulation
run -all
```

---

## M6 Success Criteria

- `stimulus_pipeline.dat` / `expected_pipeline.dat` — 100 lines each
- `hqh539_full_pipeline.sv` — synthesizes without errors or critical warnings
- `tb_hqh539_full_pipeline.sv` — simulation completes `100/100 PASS`
- No $display statements left in any RTL file after passing

## What to Report Back

Paste the final `=== M6 Result: N/100 PASS ===` line.
If any FAIL, paste the first failing vector's Got/Exp lines.

---

## Diagnostic Entry Point (if any FAIL)

**If 0/100 FAIL with hash-like wrong outputs:**
The state connection may be byte-swapped. Add to tb:
```sv
$display("RTL state[255:0]: %064h", dut.u_t3core.state_out[255:0]);
```
after t3core valid_out, before phase3 runs. Compare to Python:
```python
from hqh539 import T3, SALT_STD
import hashlib
msg = b"Resonant test vector 0 for 539 Labs - STD mode"
seed = int.from_bytes(hashlib.sha3_512(msg + SALT_STD).digest(), 'big')
state = seed
for _ in range(539): state = T3(state)
print(f"state.to_bytes(32,'big'): {state.to_bytes(32,'big').hex()}")
print(f"state[255:0] as big-endian: {state & ((1<<256)-1):064x}")
```
Both should match. If RTL differs, the T3 core itself has an issue (regression from M4 — stop and report).

**If timeout (no valid_out):**
Check `busy` signal — if it never goes low, t3core may not be receiving valid_in correctly.
Add: `$display("valid_in asserted, busy=%b", busy);` after the valid_in pulse.

---

*539 Labs LLC | Orchestrator: Claude | Builder: Grok | M6 Directive*
*Per aspera ad astra.*
