// =============================================================================
// hqh539_t3core.sv
// HQH-539 â€” T3 Core â€” Phase 2 Isolation Module
// Version 1.0 | 539 Labs LLC | June 4, 2026
//
// PURPOSE:
//   Implements Phase 2 of HQH-539 in isolation:
//     state_out = T3^539(seed_in)
//
//   Phase 1 (SHA3-512 seeding) and Phase 3 (SHA3-512 finalization) are
//   intentionally excluded. This module is the novel contribution â€” T3
//   iteration is what distinguishes HQH-539 from a pure SHA3 construction.
//
// WHY ISOLATED:
//   Validates the T3 core independently of SHA3 wrapper before committing
//   to a Phase 3 implementation strategy. Testbench vectors (expected_t3core.dat)
//   are Python-derived T3^539 raw integer outputs, confirmed self-consistent.
//
// PIPELINE TIMING:
//   Latency: 8,624 cycles per vector (539 steps x 16 cycles/step)
// 17 cycles/step â€” 1-cycle feedback register; 91.63 Î¼s/hash @ 100 MHz.
//   Handshake: valid_in asserted for exactly 1 cycle to start a new hash.
//              valid_out pulses for exactly 1 cycle when state_out is ready.
//              valid_in must not be reasserted while running=1.
//   Timeout expectation for testbench: 10,000 cycles
//
// Module now uses div3_1024_pipelined (synthesizable, pipelined)
//
// Author: 539 Labs LLC
// Ground model: SÂ²-11DMÂ²ET-X Minimal Unification Core v1.5
// T4121 Variant
// =============================================================================

`timescale 1ns / 1ps

module hqh539_t3core #(
    parameter STATE_W  = 1024,   // Internal state width
    parameter DIGEST_W = 512,    // Input seed width (Phase 1 output)
    parameter STEPS    = 539     // Exact T3 iteration count â€” DO NOT CHANGE
) (
    input  wire                clk,
    input  wire                reset_n,      // Active-low synchronous reset

    // Input handshake
    input  wire                valid_in,     // Assert for one cycle to load seed_in
    input  wire [DIGEST_W-1:0] seed_in,      // 512-bit seed: int(SHA3-512(msg||salt))

    // Output handshake
    output logic               valid_out,    // Pulses for one cycle when state_out ready
    output logic [STATE_W-1:0] state_out     // T3^539(seed) â€” raw integer, no finalization
);

    // â”€â”€ Internal state registers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    logic [9:0]          step_counter;       // 10 bits: covers 0..539 (needs 10 bits for 539)
    logic                running;

    // Pipelined div3 related declarations (moved before u_div3 and any assigns that use them)
    logic div3_valid;
    logic [STATE_W-1:0] div3_quotient;
    logic [1:0] div3_remainder;
    logic [STATE_W-1:0] div3_q_comb;
    logic [1:0]         div3_r_comb;
    logic               div3_last_cycle;
    logic [STATE_W-1:0] q_comb_r;
    logic [1:0]         r_comb_r;
    logic               last_cycle_r;
    logic [STATE_W-1:0] t4121_comb;
    wire div3_start_comb;
    wire [STATE_W-1:0] div3_n_in_comb;

    // Pipelined div3 instance (u_div3)
    div3_1024_pipelined #(
        .DIVIDEND_WIDTH(STATE_W),
        .STAGES_PER_CYCLE(64)
    ) u_div3 (
        .clk(clk),
        .rst_n(reset_n),
        .start(div3_start_comb),
        .n_in(div3_n_in_comb),
        .busy(),
        .valid(div3_valid),
        .quotient(div3_quotient),
        .remainder(div3_remainder),
        .q_comb(div3_q_comb),
        .r_comb(div3_r_comb),
        .last_cycle(div3_last_cycle)
    );

    // T4121 result (combinational) â€” now uses registered q/r for 1-cycle feedback
    always_comb begin
        case (r_comb_r)
            2'd0: t4121_comb = q_comb_r;                    // r == 0: contraction
            2'd1: t4121_comb = (q_comb_r << 2) | 1;         // r == 1: 4q + 1 (T4121)
            2'd2: t4121_comb = (q_comb_r << 1) | 1;         // r == 2: 2q + 1
            default: t4121_comb = '0;
        endcase
    end

    // Combinational signals for div3 (decls moved up)
    assign div3_start_comb =
        (!running && valid_in) ||
        (running && last_cycle_r && (step_counter + 1 < STEPS));

    assign div3_n_in_comb =
        (!running && valid_in) ? {{(STATE_W-DIGEST_W){1'b0}}, seed_in} :
                                  t4121_comb;

    // â”€â”€ Main sequential logic â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    //
    // State machine rebuilt around the 16-cycle handshake of div3_1024_pipelined.
    // Latency: 8,624 cycles per vector (539 steps x 16 cycles/step)
    //
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            step_counter  <= 10'd0;
            state_out     <= {STATE_W{1'b0}};
            valid_out     <= 1'b0;
            running       <= 1'b0;
            q_comb_r      <= {STATE_W{1'b0}};
            r_comb_r      <= 2'b0;
            last_cycle_r  <= 1'b0;

        end else begin
            valid_out <= 1'b0;  // default

            // Capture registered versions of div3 comb outputs on last_cycle for 1-cycle feedback delay
            last_cycle_r <= div3_last_cycle;
            if (div3_last_cycle) begin
                q_comb_r <= div3_q_comb;
                r_comb_r <= div3_r_comb;
            end

            if (!running && valid_in) begin
                // LOAD
                running      <= 1'b1;
                step_counter <= 10'd0;

            end else if (running && last_cycle_r) begin
                if (step_counter + 1 < STEPS) begin
                    step_counter <= step_counter + 10'd1;
                end else begin
                    // final step
                    step_counter <= 10'd0;
                    running      <= 1'b0;
                    state_out    <= t4121_comb;
                    valid_out    <= 1'b1;
                end
            end
            // else: IDLE or mid-cycle; do nothing special (valid_out default 0)
        end
    end

    // â”€â”€ Assertions (simulation-time checks) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // pragma translate_off
    `ifndef SYNTHESIS
    // Check: valid_in must not be asserted during a running computation
    property no_valid_in_while_running;
        @(posedge clk) disable iff (!reset_n)
        running |-> !valid_in;
    endproperty
    assert property (no_valid_in_while_running)
        else $warning("[HQH539_T3CORE] valid_in asserted while running=1; ignored per spec.");

    // Check: step_counter never exceeds STEPS+1
    property step_counter_bounded;
        @(posedge clk) disable iff (!reset_n)
        step_counter <= STEPS + 1;
    endproperty
    assert property (step_counter_bounded)
        else $error("[HQH539_T3CORE] step_counter overflow: %0d", step_counter);
    `endif
    // pragma translate_on

endmodule