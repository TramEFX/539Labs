//==============================================================================
// div3_1024_pipelined.sv
// HQH-539 | M4 Deliverable | 539 Labs LLC
//
// Time-partitioned 1024-bit division by 3.
// STAGES_PER_CYCLE serial algorithm stages per clock cycle.
// CYCLES = DIVIDEND_WIDTH / STAGES_PER_CYCLE clock cycles to completion.
// Inter-cycle state: 2-bit running remainder (rem_r) only.
//
// Architecture: temporal partitioning (NOT spatial/data-slice partitioning).
// See M4_div3_1024_pipelined_spec.md for full design rationale.
//
// Map-agnostic: implements div3 only. Replaces div3_1024.sv (M2 baseline).
// T4121 mux belongs in hqh539_t3core.sv â€” not here.
//
// Author: Grok (Builder) | Spec: Claude (Orchestrator)
// Date: 2026-06-06
//==============================================================================

module div3_1024_pipelined #(
    parameter  int DIVIDEND_WIDTH   = 1024,
    parameter  int STAGES_PER_CYCLE = 64
) (
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic                       start,
    input  logic [DIVIDEND_WIDTH-1:0]  n_in,
    output logic                       busy,
    output logic                       valid,
    output logic [DIVIDEND_WIDTH-1:0]  quotient,
    output logic [1:0]                 remainder,
    output logic [DIVIDEND_WIDTH-1:0]  q_comb,
    output logic [1:0]                 r_comb,
    output logic                       last_cycle
);

    localparam int CYCLES   = DIVIDEND_WIDTH / STAGES_PER_CYCLE;
    localparam int CYC_BITS = (CYCLES);

    // FSM state
    localparam logic IDLE    = 1'b0;
    localparam logic RUNNING = 1'b1;
    logic state;
    
    // Registers
    logic [DIVIDEND_WIDTH-1:0]  n_shift;    // Input shift register
    logic [1:0]                 rem_r;      // Inter-cycle remainder
    logic [CYC_BITS-1:0]        cyc;        // Cycle counter
    logic [DIVIDEND_WIDTH-1:0]  quot_sr;    // Quotient shift register
    
    // Stage block wires
    wire [1:0]                  r_chain [0:STAGES_PER_CYCLE];
    wire [STAGES_PER_CYCLE-1:0] stage_q;
    wire [1:0]                  stage_rem;
    wire [DIVIDEND_WIDTH-1:0]   q_comb_wire;

    assign busy       = (state == RUNNING);
    assign r_chain[0] = rem_r;
    assign stage_rem  = r_chain[STAGES_PER_CYCLE];

    assign q_comb_wire = {quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q};
    assign q_comb      = q_comb_wire;
    assign r_comb      = stage_rem;
    assign last_cycle  = (state == RUNNING) && (cyc == CYCLES-1);

    function automatic [2:0] div3_step(input [2:0] r_b);
        case (r_b)
            3'b000: div3_step = 3'b0_00;
            3'b001: div3_step = 3'b0_01;
            3'b010: div3_step = 3'b0_10;
            3'b011: div3_step = 3'b1_00;
            3'b100: div3_step = 3'b1_01;
            3'b101: div3_step = 3'b1_10;
            default: div3_step = 3'bx_xx;
        endcase
    endfunction

    genvar i;
    generate
        for (i = 0; i < STAGES_PER_CYCLE; i++) begin : g_stage
            wire [2:0] step_out =
                div3_step({r_chain[i], n_shift[DIVIDEND_WIDTH-1-i]});
            assign stage_q[STAGES_PER_CYCLE-1-i] = step_out[2];
            assign r_chain[i+1]                  = step_out[1:0];
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state     <= IDLE;
            n_shift   <= '0;
            rem_r     <= 2'b00;
            cyc       <= '0;
            quot_sr   <= '0;
            valid     <= 1'b0;
            quotient  <= '0;
            remainder <= 2'b00;
        end else begin
            valid <= 1'b0;

            if (state == IDLE) begin
                if (start) begin
                    state     <= RUNNING;
                    n_shift   <= n_in;
                    rem_r     <= 2'b00;
                    cyc       <= '0;
                    valid     <= 1'b0;
                end
            end else begin // RUNNING
                if (cyc < CYCLES-1) begin
                    n_shift   <= {n_shift[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], {STAGES_PER_CYCLE{1'b0}}};
                    rem_r     <= stage_rem;
                    quot_sr   <= {quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q};
                    cyc       <= cyc + 1;
                    valid     <= 1'b0;
                end else begin
                    // cyc == CYCLES-1
                    quotient  <= {quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q};
                    remainder <= stage_rem;
                    valid     <= 1'b1;

                    if (start) begin
                        // immediate restart
                        state   <= RUNNING;
                        n_shift <= n_in;
                        rem_r   <= 2'b00;
                        cyc     <= '0;
                        quot_sr <= {quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q};
                    end else begin
                        state   <= IDLE;
                        cyc     <= '0;
                        rem_r   <= stage_rem;
                        quot_sr <= {quot_sr[DIVIDEND_WIDTH-STAGES_PER_CYCLE-1:0], stage_q};
                    end
                end
            end
        end
    end

endmodule