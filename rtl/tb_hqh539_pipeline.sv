// =============================================================================
// tb_hqh539_pipeline.sv
// HQH-539 T3 Core Testbench â€” Phase 2 Behavioral Simulation
// Version 1.0 | 539 Labs LLC | June 4, 2026
//
// SCOPE:
//   Tests hqh539_t3core.sv (Phase 2 only) against 100 Python-derived
//   reference vectors. Phase 3 (SHA3-512 finalization) is NOT tested here.
//   This is intentional â€” validate the novel T3 contribution independently.
//
// VECTOR FILES (relative to Vivado simulation working dir):
//   stimulus_t3core.dat  â€” 512-bit seeds (SHA3-512 of test messages)
//   expected_t3core.dat  â€” 1024-bit T3^539(seed) reference states
//
//   Default path: ../../test_vectors/ (Vivado project layout assumption)
//   Override with:  +TV_PATH=<absolute/path/to/test_vectors/>
//
// FILE FORMAT:
//   <index_decimal>,<value_hex>
//   Stimulus: 128 hex chars (512-bit seed, zero-padded)
//   Expected: 256 hex chars (1024-bit T3 state, zero-padded)
//
// PASS CRITERIA:
//   state_out[1023:0] must exactly match expected T3^539(seed) at the
//   cycle valid_out is asserted. All 100 vectors must pass.
//
// TIMING:
//   Latency:   ~9,163 cycles per vector (539 steps x 17 cycles/step)
//   Timeout:   10,000 cycles
//   Total sim: ~916,300 clock cycles for 100 vectors (~9.16 ms simulated)
//
// KNOWN LIMITATION:
//   DUT uses behavioral division (n%3, n/3) on 1024-bit state.
//   Simulation is valid; synthesis will require div3_1024 replacement.
//   See hqh539_t3core.sv Â§SYNTHESIZABILITY WARNING.
//
// USAGE (Vivado):
//   1. Create Vivado project, add hqh539_t3core.sv and this file
//   2. Set this file as simulation top
//   3. Run behavioral simulation
//   4. Check Tcl console for [PASS]/[FAIL] report
//   Optional: +TV_PATH=/absolute/path/to/test_vectors/
//
// Author: 539 Labs LLC
// =============================================================================

`timescale 1ns / 1ps

module tb_hqh539_pipeline;

    // â”€â”€ Simulation parameters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    localparam CLK_PERIOD    = 10;    // 100 MHz clock (10 ns period)
    localparam CLK_HALF      = CLK_PERIOD / 2;
    localparam NUM_VECTORS   = 100;   // Vectors to run (0..99)
    localparam TIMEOUT_CYCS  = 10000; // 9,163 cycles expected + margin

    // â”€â”€ DUT port declarations â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    localparam STATE_W  = 1024;
    localparam DIGEST_W = 512;
    localparam STEPS    = 539;

    logic                  clk;
    logic                  reset_n;
    logic                  valid_in;
    logic [DIGEST_W-1:0]   seed_in;
    logic                  valid_out;
    logic [STATE_W-1:0]    state_out;

    // â”€â”€ DUT instantiation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    hqh539_t3core #(
        .STATE_W  (STATE_W),
        .DIGEST_W (DIGEST_W),
        .STEPS    (STEPS)
    ) dut (
        .clk      (clk),
        .reset_n  (reset_n),
        .valid_in (valid_in),
        .seed_in  (seed_in),
        .valid_out(valid_out),
        .state_out(state_out)
    );

    // â”€â”€ Clock generation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    initial clk = 1'b0;
    always #CLK_HALF clk = ~clk;

    // â”€â”€ Test variables â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    integer        stim_fd, exp_fd;
    integer        stim_idx, exp_idx;
    integer        scan_ret;
    logic [DIGEST_W-1:0] stimulus_seed;
    logic [STATE_W-1:0]  expected_state;
    integer        pass_count;
    integer        fail_count;
    integer        timeout_count;
    integer        v;
    string         tv_path;

    // â”€â”€ Helper task: apply reset â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    task apply_reset();
        reset_n  <= 1'b0;
        valid_in <= 1'b0;
        seed_in  <= {DIGEST_W{1'b0}};
        repeat (4) @(posedge clk);
        #1;
        reset_n  <= 1'b1;
        @(posedge clk);
        #1;
        $display("[TB] Reset released at t=%0t", $time);
    endtask

    // â”€â”€ Helper task: drive one vector, wait for valid_out, compare â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    task run_vector(
        input  integer          vec_num,
        input  [DIGEST_W-1:0]   seed,
        input  [STATE_W-1:0]    expected,
        output logic            pass
    );
        integer  cyc;
        logic    timed_out;

        pass      = 1'b0;
        timed_out = 1'b0;

        // Drive valid_in for exactly one clock cycle
        @(posedge clk); #1;
        valid_in <= 1'b1;
        seed_in  <= seed;

        @(posedge clk); #1;
        valid_in <= 1'b0;
        seed_in  <= {DIGEST_W{1'b0}};

        // Poll for valid_out with timeout
        cyc = 0;
        while (cyc < TIMEOUT_CYCS) begin
            @(posedge clk); #1;
            cyc = cyc + 1;
            if (valid_out) begin
                break;
            end
        end

        if (cyc >= TIMEOUT_CYCS) begin
            $display("[TIMEOUT] Vec %0d: valid_out never asserted in %0d cycles",
                     vec_num, TIMEOUT_CYCS);
            timeout_count++;
            pass = 1'b0;
        end else if (state_out !== expected) begin
            $display("[FAIL]    Vec %0d (valid_out after %0d cycles)", vec_num, cyc);
            $display("          expected = %0h", expected);
            $display("          got      = %0h", state_out);
            fail_count++;
            pass = 1'b0;
        end else begin
            $display("[PASS]    Vec %0d  (valid_out after %0d cycles)", vec_num, cyc);
            pass_count++;
            pass = 1'b1;
        end
    endtask

    // â”€â”€ Main test driver â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    initial begin : tb_main

        // â”€â”€ Banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        $display("============================================================");
        $display("  HQH-539 T3 Core Testbench");
        $display("  539 Labs LLC | Phase 2 Behavioral Simulation");
        $display("  Scope: T3^%0d only â€” no SHA3 finalization", STEPS);
        $display("  Vectors: %0d | Clock: %0d MHz", NUM_VECTORS, 1000/CLK_PERIOD);
        $display("============================================================");

        // â”€â”€ Resolve test vector path â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (!$value$plusargs("TV_PATH=%s", tv_path))
            tv_path = "../../test_vectors/";
        $display("[TB] Vector path: %s", tv_path);

        // â”€â”€ Open files â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        stim_fd = $fopen({tv_path, "stimulus_t3core.dat"}, "r");
        exp_fd  = $fopen({tv_path, "expected_t3core.dat"},  "r");

        if (stim_fd == 0) begin
            $display("[FATAL] Cannot open stimulus_t3core.dat at %s", tv_path);
            $display("        Run python/gen_t3core_vectors.py to regenerate.");
            $finish;
        end
        if (exp_fd == 0) begin
            $display("[FATAL] Cannot open expected_t3core.dat at %s", tv_path);
            $display("        Run python/gen_t3core_vectors.py to regenerate.");
            $finish;
        end

        // â”€â”€ Initialize counters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        pass_count    = 0;
        fail_count    = 0;
        timeout_count = 0;

        // â”€â”€ Reset DUT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        apply_reset();
        $display("[TB] DUT reset complete. Beginning vector loop...\n");

        // â”€â”€ Vector loop â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        for (v = 0; v < NUM_VECTORS; v++) begin

            // Read stimulus: "<idx>,<128_hex_chars>"
            scan_ret = $fscanf(stim_fd, "%d,%h\n", stim_idx, stimulus_seed);
            if (scan_ret != 2) begin
                $display("[ERROR] Failed to parse stimulus at vector %0d (ret=%0d)",
                         v, scan_ret);
                $finish;
            end
            if (stim_idx != v) begin
                $display("[ERROR] Stimulus index mismatch: expected %0d got %0d",
                         v, stim_idx);
                $finish;
            end

            // Read expected: "<idx>,<256_hex_chars>"
            scan_ret = $fscanf(exp_fd, "%d,%h\n", exp_idx, expected_state);
            if (scan_ret != 2) begin
                $display("[ERROR] Failed to parse expected at vector %0d (ret=%0d)",
                         v, scan_ret);
                $finish;
            end
            if (exp_idx != v) begin
                $display("[ERROR] Expected index mismatch: expected %0d got %0d",
                         v, exp_idx);
                $finish;
            end

            // Drive and check
            begin
                logic pass_flag;
                run_vector(v, stimulus_seed, expected_state, pass_flag);
            end
        end

        // â”€â”€ Close files â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        $fclose(stim_fd);
        $fclose(exp_fd);

        // â”€â”€ Summary report â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        $display("");
        $display("============================================================");
        $display("  HQH-539 T3 Core â€” Simulation Summary");
        $display("  Total vectors : %0d", NUM_VECTORS);
        $display("  PASS          : %0d", pass_count);
        $display("  FAIL          : %0d", fail_count);
        $display("  TIMEOUT       : %0d", timeout_count);
        $display("------------------------------------------------------------");
        if (fail_count == 0 && timeout_count == 0) begin
            $display("  STATUS: âœ… ALL VECTORS PASSED");
            $display("  T3 core matches Python reference implementation.");
            $display("  Ready for: div3_1024 synthesis module development.");
        end else begin
            $display("  STATUS: âŒ FAILURES DETECTED");
            $display("  Failures indicate a T3 mapping discrepancy.");
            $display("  Cross-check hqh539_t3core.sv t3_step() against");
            $display("  hqh539.py T3() â€” ensure exact integer arithmetic.");
        end
        $display("============================================================");

        $finish;

    end : tb_main

    // â”€â”€ Simulation timeout watchdog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    initial begin
        // Hard upper bound: NUM_VECTORS * (TIMEOUT_CYCS + 2) + 100 overhead
        #(NUM_VECTORS * (TIMEOUT_CYCS + 2) * CLK_PERIOD + 1000);
        $display("[WATCHDOG] Simulation exceeded hard time limit â€” aborting.");
        $finish;
    end

    // â”€â”€ Optional VCD waveform dump â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Uncomment for waveform capture (warning: large file for 100 vectors)
    // initial begin
    //     $dumpfile("hqh539_t3core.vcd");
    //     $dumpvars(0, tb_hqh539_pipeline);
    // end

endmodule
