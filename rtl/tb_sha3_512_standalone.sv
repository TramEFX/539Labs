`timescale 1ns/1ps
module tb_sha3_512_standalone;

    parameter CLK_PERIOD   = 10;
    parameter TIMEOUT_CYCS = 100;
    parameter NUM_VECTORS  = 10;

    reg         clk, rst_n, valid_in;
    reg [511:0] msg_in;
    wire [511:0] digest_out;
    wire         valid_out;

    sha3_512_standalone dut (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .msg_in(msg_in), .digest_out(digest_out), .valid_out(valid_out)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    integer      stim_fd, exp_fd, scan_ret, v, timeout_cnt;
    integer      pass_cnt, fail_cnt;
    reg [511:0]  expected;
    reg [1023:0] tv_path_r;

    initial begin
        clk = 0; rst_n = 0; valid_in = 0; msg_in = 0;
        pass_cnt = 0; fail_cnt = 0;

        if (!$value$plusargs("TV_PATH=%s", tv_path_r)) begin
            $display("ERROR: TV_PATH plusarg required"); $finish;
        end

        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        stim_fd = $fopen({tv_path_r, "stimulus_sha3.dat"}, "r");
        exp_fd  = $fopen({tv_path_r, "expected_sha3.dat"}, "r");
        if (!stim_fd || !exp_fd) begin
            $display("ERROR: Cannot open vector files"); $finish;
        end

        for (v = 0; v < NUM_VECTORS; v++) begin
            scan_ret = $fscanf(stim_fd, "%128h\n", msg_in);
            scan_ret = $fscanf(exp_fd,  "%128h\n", expected);

            @(posedge clk); #1;
            valid_in = 1;
            @(posedge clk); #1;
            valid_in = 0;

            timeout_cnt = 0;
            while (!valid_out && timeout_cnt < TIMEOUT_CYCS) begin
                @(posedge clk); #1;
                timeout_cnt = timeout_cnt + 1;
            end

            if (timeout_cnt >= TIMEOUT_CYCS) begin
                $display("TIMEOUT  vector %0d", v); fail_cnt = fail_cnt + 1;
            end else if (digest_out === expected) begin
                $display("PASS     vector %0d", v); pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL     vector %0d", v);
                $display("  Expected: %h", expected);
                $display("  Got:      %h", digest_out);
                fail_cnt = fail_cnt + 1;
            end

            repeat(2) @(posedge clk);
        end

        $fclose(stim_fd); $fclose(exp_fd);
        $display("=== SHA3 Standalone Sim: %0d/%0d PASS ===", pass_cnt, NUM_VECTORS);
        $finish;
    end
endmodule