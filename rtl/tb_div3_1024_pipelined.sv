// =============================================================================
// tb_div3_1024_pipelined.sv
// HQH-539 | M4 Testbench | 539 Labs LLC
// Verifies div3_1024_pipelined.sv -- four tests per spec section 9
// Not for synthesis.
// Author: Orchestrator (Claude) | 2026-06-06
// =============================================================================
`timescale 1ns/1ps

module tb_div3_1024_pipelined;

    parameter int STAGES_PER_CYCLE = 64;

    localparam int DIVIDEND_WIDTH = 1024;
    localparam int CYCLES         = DIVIDEND_WIDTH / STAGES_PER_CYCLE;

    // DUT signals
    logic                      clk, rst_n, start;
    logic [DIVIDEND_WIDTH-1:0] n_in;
    logic                      busy, valid;
    logic [DIVIDEND_WIDTH-1:0] quotient;
    logic [1:0]                remainder;
    // New combinational outputs -- declared to satisfy .* port connection
    logic [DIVIDEND_WIDTH-1:0] q_comb;
    logic [1:0]                r_comb;
    logic                      last_cycle;

    div3_1024_pipelined #(
        .DIVIDEND_WIDTH   (DIVIDEND_WIDTH),
        .STAGES_PER_CYCLE (STAGES_PER_CYCLE)
    ) dut (.*);

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Module-level file and parsing variables
    integer stim_f, exp_f;
    integer pass_cnt;
    integer fail_cnt;
    string  line;
    int     dummy;
    string  hex_n;
    string  hex_q;
    int     rint;

    // Hex string (256 chars) to 1024-bit vector
    function automatic logic [DIVIDEND_WIDTH-1:0] hexstr_to_vec(input string s);
        logic [DIVIDEND_WIDTH-1:0] v = '0;
        for (int k = 0; k < 256; k++) begin
            byte c = s[k];
            logic [3:0] nib;
            if      (c >= "0" && c <= "9") nib = c - "0";
            else if (c >= "a" && c <= "f") nib = c - "a" + 10;
            else if (c >= "A" && c <= "F") nib = c - "A" + 10;
            else                           nib = 0;
            v = {v[DIVIDEND_WIDTH-5:0], nib};
        end
        return v;
    endfunction

    // Issue one vector, wait for valid, compare
    task automatic run_vector(
        input  [DIVIDEND_WIDTH-1:0] n_stimulus,
        input  [1:0]                exp_rem,
        input  [DIVIDEND_WIDTH-1:0] exp_quot,
        output logic                pass
    );
        @(negedge clk);
        n_in  = n_stimulus;
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        @(posedge valid);
        @(negedge clk);
        pass = (quotient == exp_quot) && (remainder == exp_rem);
        if (quotient * 3 + remainder != n_stimulus)
            pass = 1'b0;
    endtask

    initial begin : tb_main
        // All local variables declared at top -- Xsim requires declarations
        // before any procedural statements within a begin...end block.
        string tv_path;
        logic [DIVIDEND_WIDTH-1:0] n_stim;
        logic [DIVIDEND_WIDTH-1:0] exp_quot;
        logic [1:0]                exp_rem;
        logic                      p;
        logic [DIVIDEND_WIDTH-1:0] nA, nB;
        logic [1:0]                exp_rA, exp_rB;
        logic [DIVIDEND_WIDTH-1:0] exp_qA, exp_qB;

        if (!$value$plusargs("TV_PATH=%s", tv_path))
            tv_path = "../../test_vectors/";
        $display("Using TV_PATH = %s", tv_path);

        stim_f = $fopen({tv_path, "stimulus_div3.dat"}, "r");
        exp_f  = $fopen({tv_path, "expected_div3.dat"}, "r");

        if (stim_f == 0 || exp_f == 0) begin
            $display("ERROR: Cannot open vector files at %s", tv_path);
            $finish;
        end

        rst_n = 0; start = 0; n_in = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        pass_cnt = 0;
        fail_cnt = 0;

        // TEST 1: Drop-in replacement (STAGES_PER_CYCLE=512, CYCLES=2)
        if (STAGES_PER_CYCLE == 512) begin
            $display("=== TEST 1: Drop-in replacement (STAGES_PER_CYCLE=512) ===");
            for (int v = 0; v < 1000; v++) begin
                void'($fgets(line, stim_f));
                void'($sscanf(line, "%d,%s", dummy, hex_n));
                n_stim = hexstr_to_vec(hex_n);

                void'($fgets(line, exp_f));
                void'($sscanf(line, "%d,%d,%s", dummy, rint, hex_q));
                exp_rem  = rint[1:0];
                exp_quot = hexstr_to_vec(hex_q);

                run_vector(n_stim, exp_rem, exp_quot, p);
                if (p) pass_cnt++; else fail_cnt++;
            end
            $display("TEST1: %0d/1000 PASS", pass_cnt);

        // TESTS 2-4: Pipelined (STAGES_PER_CYCLE=64)
        end else if (STAGES_PER_CYCLE == 64) begin

            // TEST 2: Pipelined functional
            $display("=== TEST 2: Pipelined functional (STAGES_PER_CYCLE=64) ===");
            for (int v = 0; v < 1000; v++) begin
                void'($fgets(line, stim_f));
                void'($sscanf(line, "%d,%s", dummy, hex_n));
                n_stim = hexstr_to_vec(hex_n);

                void'($fgets(line, exp_f));
                void'($sscanf(line, "%d,%d,%s", dummy, rint, hex_q));
                exp_rem  = rint[1:0];
                exp_quot = hexstr_to_vec(hex_q);

                run_vector(n_stim, exp_rem, exp_quot, p);
                if (p) pass_cnt++; else fail_cnt++;
            end
            $display("TEST2: %0d/1000 PASS", pass_cnt);

            // TEST 3: Sequential 50-vector run
            $fclose(stim_f); $fclose(exp_f);
            stim_f = $fopen({tv_path, "stimulus_div3.dat"}, "r");
            exp_f  = $fopen({tv_path, "expected_div3.dat"}, "r");
            pass_cnt = 0; fail_cnt = 0;

            $display("=== TEST 3: Sequential 50-vector run (STAGES_PER_CYCLE=64) ===");
            for (int v = 0; v < 50; v++) begin
                void'($fgets(line, stim_f));
                void'($sscanf(line, "%d,%s", dummy, hex_n));
                n_stim = hexstr_to_vec(hex_n);

                void'($fgets(line, exp_f));
                void'($sscanf(line, "%d,%d,%s", dummy, rint, hex_q));
                exp_rem  = rint[1:0];
                exp_quot = hexstr_to_vec(hex_q);

                run_vector(n_stim, exp_rem, exp_quot, p);
                if (p) pass_cnt++; else fail_cnt++;
            end
            $display("TEST3: %0d/50 PASS", pass_cnt);

            // TEST 4: Reset mid-computation
            $fclose(stim_f); $fclose(exp_f);
            stim_f = $fopen({tv_path, "stimulus_div3.dat"}, "r");
            exp_f  = $fopen({tv_path, "expected_div3.dat"}, "r");

            $display("=== TEST 4: Reset mid-computation (STAGES_PER_CYCLE=64) ===");

            // Vector A (will be interrupted by reset)
            void'($fgets(line, stim_f));
            void'($sscanf(line, "%d,%s", dummy, hex_n));
            nA = hexstr_to_vec(hex_n);
            void'($fgets(line, exp_f));
            void'($sscanf(line, "%d,%d,%s", dummy, rint, hex_q));
            exp_rA = rint[1:0];
            exp_qA = hexstr_to_vec(hex_q);

            @(negedge clk); n_in = nA; start = 1'b1;
            @(negedge clk); start = 1'b0;
            repeat(5) @(posedge clk);
            rst_n = 0;
            repeat(2) @(posedge clk);
            rst_n = 1;
            @(posedge clk);

            // Vector B (post-reset correctness check)
            void'($fgets(line, stim_f));
            void'($sscanf(line, "%d,%s", dummy, hex_n));
            nB = hexstr_to_vec(hex_n);
            void'($fgets(line, exp_f));
            void'($sscanf(line, "%d,%d,%s", dummy, rint, hex_q));
            exp_rB = rint[1:0];
            exp_qB = hexstr_to_vec(hex_q);

            @(negedge clk); n_in = nB; start = 1'b1;
            @(negedge clk); start = 1'b0;
            @(posedge valid);
            @(negedge clk);

            p = (quotient == exp_qB) && (remainder == exp_rB)
                && (quotient * 3 + remainder == nB);
            if (p)
                $display("TEST4: PASS");
            else
                $display("TEST4: FAIL");
        end

        $fclose(stim_f);
        $fclose(exp_f);
        $display("=== ALL TESTS COMPLETE ===");
        $finish;
    end

    // 5 ms watchdog
    initial begin
        #5_000_000ns;
        $display("WATCHDOG TIMEOUT");
        $finish;
    end

endmodule
