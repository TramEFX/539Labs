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