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