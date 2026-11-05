// tb_hqh539_demo.sv
// Single-shot demo testbench - hqh539_full_pipeline
// DI-M2 | 539 Labs LLC | June 2026
//
// Accepts: +SEED=<128-hex-char Phase 1 output>
// Writes:  demo_output.dat - 128 hex chars (digest) + newline, in xsim working directory
// TCL:     run_demo_sim.tcl must contain: run -all

`timescale 1ns / 1ps

module tb_hqh539_demo;

    reg         clk      = 0;
    reg         rst_n    = 0;
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

    logic [511:0] seed_val;
    integer       out_fd;
    integer       timeout_cnt;
    localparam int TIMEOUT_CYC = 12000;   // >> 9,225 cycle pipeline latency

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