`timescale 1ns/1ps

module tb_div3_1024;

    string tv_path;

    initial begin
        if (!$value$plusargs("TV_PATH=%s", tv_path)) begin
            tv_path = "../../test_vectors/";
        end
        $display("Using TV_PATH = %s", tv_path);
    end

    // DUT
    logic [1023:0] dividend;
    logic [1023:0] quotient;
    logic [1:0]    remainder;

    div3_1024 #(.N(1024)) dut (
        .dividend (dividend),
        .quotient (quotient),
        .remainder(remainder)
    );

    integer stim_f, exp_f;
    integer pass_cnt = 0;
    integer fail_cnt = 0;
    string  line;

    // Pre-declared for $sscanf (Vivado compatibility)
    int    dummy;
    string hex_n;
    string hex_q;
    int    rint;
    logic [1023:0] exp_q;
    logic [1:0]    exp_r;

    function automatic logic [1023:0] hexstr_to_vec(input string s);
        logic [1023:0] v = '0;
        for (int k = 0; k < 256; k++) begin
            byte c = s[k];
            logic [3:0] nib;
            if      (c >= "0" && c <= "9") nib = c - "0";
            else if (c >= "a" && c <= "f") nib = c - "a" + 10;
            else if (c >= "A" && c <= "F") nib = c - "A" + 10;
            else nib = 0;
            v = {v[1019:0], nib};
        end
        return v;
    endfunction

    initial begin
        stim_f = $fopen({tv_path, "stimulus_div3.dat"}, "r");
        exp_f  = $fopen({tv_path, "expected_div3.dat"}, "r");

        if (stim_f == 0 || exp_f == 0) begin
            $display("ERROR: Cannot open vector files at %s", tv_path);
            $finish;
        end

        #10;

        for (int v = 0; v < 1000; v++) begin
            void'($fgets(line, stim_f));
            void'($sscanf(line, "%d,%s", dummy, hex_n));
            dividend = hexstr_to_vec(hex_n);

            void'($fgets(line, exp_f));
            void'($sscanf(line, "%d,%d,%h", dummy, exp_r, exp_q));
            #10;

            if (quotient === exp_q && remainder === exp_r) begin
                $display("[PASS] vector %0d", v);
                pass_cnt++;
            end else begin
                $display("[FAIL] vector %0d : got q=%h r=%0d   exp q=%h r=%0d",
                         v, quotient, remainder, exp_q, exp_r);
                fail_cnt++;
            end
        end

        $fclose(stim_f);
        $fclose(exp_f);

        $display("============================================================");
        $display("  PASS : %0d", pass_cnt);
        $display("  FAIL : %0d", fail_cnt);
        if (fail_cnt == 0)
            $display("  STATUS : ALL VECTORS PASSED");
        else
            $display("  STATUS : FAILURES DETECTED");
        $display("============================================================");

        #100;
        $finish;
    end

    initial begin
        #5_000_000ns;
        $display("WATCHDOG TIMEOUT");
        $finish;
    end

endmodule

