// =============================================================================
// hqh539_t3core_top.sv
// HQH-539 - T3 Core - Narrow 64-bit Valid/Ready Streaming Wrapper
// M4 Step 3 | 539 Labs LLC | June 2026
//
// [CAT-B] hqh539_t3core_top.sv - narrow I/O wrapper
//
// PURPOSE:
//   Wraps hqh539_t3core with a simple 64-bit data-beat interface (AXI4-Stream
//   subset style) using 8 beats for the 512-bit seed (input) and 16 beats for the 1024-bit result (output).
//   This provides a narrow I/O suitable for FPGA pin or DMA streaming while the internal
//   core still performs the 16-cycle-per-T3-step pipelined iteration.
//
// INTERFACE:
//   64-bit beats, valid/ready handshake + last flag.
//   Input:  8 beats assemble 512-bit seed (wired directly to core seed_in)
//   Output: 16 beats deliver the 1024-bit core state_out (MSB-first)
//
// INTERNAL:
//   seed_reg[511:0]    - shift-assembles 8 input beats MSB-first
//   beat_in_cnt[3:0]   - counts 0..7; on 7th beat (with s_valid), pulse valid_in
//   FSM: S_IDLE -> S_LOAD (8 beats) -> S_COMPUTE (wait core valid_out) -> S_OUTPUT (16 beats) -> S_IDLE
//   result_reg[1023:0] - latches core.state_out on valid_out; shifted out MSB-first
//   beat_out_cnt[3:0]  - output beat counter; m_last when ==15
//
// CONSTRAINTS SATISFIED:
//   - Instantiates hqh539_t3core with exact port names read from hqh539_t3core.sv
//   - All core ports connected explicitly (no .*)
//   - s_ready deasserted in S_COMPUTE and S_OUTPUT
//   - No-BOM UTF-8 written via mandated [System.IO.File]::WriteAllText + UTF8Encoding(False)
//   - seed_reg is now exactly 512-bit (matches DIGEST_W); wired whole to seed_in
//
// Author: 539 Labs LLC (generated per M4 directive)
// =============================================================================

`timescale 1ns / 1ps

module hqh539_t3core_top (
    input  wire        clk,
    input  wire        rst_n,

    // Input bus (8 x 64-bit beats assemble 512-bit seed)
    input  wire [63:0] s_data,
    input  wire        s_valid,
    output wire        s_ready,
    input  wire        s_last,

    // Output bus (16 x 64-bit beats deliver 1024-bit result)
    output wire [63:0] m_data,
    output wire        m_valid,
    input  wire        m_ready,
    output wire        m_last
);

    // Internal architecture (per M4 Step 3 directive)
    logic [511:0]  seed_reg;      // shift-assembles 8 input beats MSB-first
    logic [3:0]    beat_in_cnt;   // counts 0..7; on 7 with s_valid asserted, pulse valid_in to core

    logic [1023:0] result_reg;    // latches core output on valid_out, shifted out MSB-first over 16 beats
    logic [3:0]    beat_out_cnt;  // counts output beats; m_last asserted when count == 15

    // FSM states: S_IDLE -> S_LOAD (8 beats) -> S_COMPUTE (wait for core valid_out) -> S_OUTPUT (16 beats) -> S_IDLE
    localparam [2:0] S_IDLE    = 3'd0,
                     S_LOAD    = 3'd1,
                     S_COMPUTE = 3'd2,
                     S_OUTPUT  = 3'd3;
    logic [2:0] state;

    // Core connection signals (explicit)
    logic          core_valid_in;
    logic          core_valid_out;
    logic [1023:0] core_state_out;

    // Core instantiation: exact port names from hqh539_t3core.sv read, all explicit (no .*)
    hqh539_t3core #(
        .STATE_W (1024),
        .DIGEST_W(512),
        .STEPS   (539)
    ) u_hqh539_t3core (
        .clk       (clk),
        .reset_n   (rst_n),             // wrapper rst_n drives core reset_n
        .valid_in  (core_valid_in),
        .seed_in   (seed_reg),          // 512-bit seed_reg wired directly (whole register, no slice)
        .valid_out (core_valid_out),
        .state_out (core_state_out)
    );

    // s_ready deasserted during S_COMPUTE and S_OUTPUT states (per spec)
    assign s_ready = (state == S_IDLE) || (state == S_LOAD);

    // Output bus (combo) - unchanged
    assign m_valid = (state == S_OUTPUT);
    assign m_data  = result_reg[1023:960];
    assign m_last  = (state == S_OUTPUT) && (beat_out_cnt == 4'd15);

    // Main FSM + shift registers + handshakes
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            seed_reg      <= '0;
            beat_in_cnt   <= 4'd0;
            result_reg    <= '0;
            beat_out_cnt  <= 4'd0;
            core_valid_in <= 1'b0;
        end else begin
            core_valid_in <= 1'b0;   // default low; assert for exactly one cycle on final input beat

            // Input side (corrected): 8 beats, 512-bit seed_reg, MSB-first
            //   shift: {seed_reg[447:0], s_data} places earliest (MSB) beat at [511:448] after 8 beats
            if ((state == S_IDLE || state == S_LOAD) && s_valid && s_ready) begin
                seed_reg <= {seed_reg[447:0], s_data};
                if (beat_in_cnt == 4'd7) begin
                    // 8th (final) beat - pulse core valid_in this cycle; seed_reg is exactly DIGEST_W
                    core_valid_in <= 1'b1;
                    beat_in_cnt   <= 4'd0;
                    state         <= S_COMPUTE;
                end else begin
                    beat_in_cnt <= beat_in_cnt + 4'd1;
                    state       <= S_LOAD;
                end
            end

            // Compute side: on core completion, latch full 1024-bit result and start output phase
            if (state == S_COMPUTE && core_valid_out) begin
                result_reg   <= core_state_out;
                beat_out_cnt <= 4'd0;
                state        <= S_OUTPUT;
            end

            // Output side: stream 16 beats MSB-first while downstream accepts (m_ready)
            //   shift: {result_reg[959:0], 64'd0} moves next 64-bit word into [1023:960]
            if (state == S_OUTPUT && m_valid && m_ready) begin
                result_reg <= {result_reg[959:0], 64'd0};
                if (beat_out_cnt == 4'd15) begin
                    beat_out_cnt <= 4'd0;
                    state        <= S_IDLE;
                end else begin
                    beat_out_cnt <= beat_out_cnt + 4'd1;
                end
            end
        end
    end

    // Note: s_last is provided on the bus (upstream must assert on beat 7 / final input beat).
    //       We drive transitions from beat_in_cnt per the directive (s_last is for protocol compliance).
    //       m_last is generated from beat_out_cnt.

endmodule
