// hqh539_phase3.sv
// STD-mode SHA3-512 (two keccak_f1600) ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â FINAL revision

module hqh539_phase3 (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          valid_in,
    input  wire [255:0]  state_in,
    output reg  [511:0]  digest,
    output reg           valid_out
);

    reg [1599:0] K;
    typedef enum logic [2:0] { IDLE, LOAD_BLOCK0, RUN_PERM1, LOAD_BLOCK1, RUN_PERM2, SQUEEZE, DONE } state_t;
    state_t state;

    wire          keccak_start;
    wire          keccak_done;
    wire [1599:0] keccak_state_out;

    keccak_f1600 keccak_inst (
        .clk(clk), .rst_n(rst_n),
        .start(keccak_start),
        .state_in(K),
        .state_out(keccak_state_out),
        .done(keccak_done)
    );

    localparam [8*13-1:0] DOMAIN = ":HQH-539-RESO";
    localparam [8*27-1:0] SALT   = "539-LABS-2026-RESONANT-SALT";

    // Module-level arrays (all synthesis issues resolved)
    logic [7:0] block0_bytes [0:71];
    logic [7:0] block1_bytes [0:71];
    logic [63:0] lane;

    reg valid_in_d;
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) valid_in_d <= 1'b0; else valid_in_d <= valid_in;
    wire valid_in_pulse = valid_in & ~valid_in_d;

    reg keccak_start_reg;
    assign keccak_start = keccak_start_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            K <= 1600'd0;
            digest <= 512'd0;
            valid_out <= 1'b0;
            keccak_start_reg <= 1'b0;
        end else begin
            valid_out <= 1'b0;
            keccak_start_reg <= 1'b0;

            case (state)
                IDLE: begin
                    if (valid_in_pulse) begin
                        for (int i = 0; i < 32; i++)
                            block0_bytes[i] = state_in[255 - 8*i -: 8];
                        for (int i = 0; i < 27; i++)
                            block0_bytes[32 + i] = SALT[8*(26-i) +: 8];
                        for (int i = 0; i < 13; i++)
                            block0_bytes[59 + i] = DOMAIN[8*(12-i) +: 8];

                        for (int i = 0; i < 9; i++) begin
                            lane = { block0_bytes[8*i+7], block0_bytes[8*i+6], block0_bytes[8*i+5], block0_bytes[8*i+4],
                                     block0_bytes[8*i+3], block0_bytes[8*i+2], block0_bytes[8*i+1], block0_bytes[8*i+0] };
                            K[64*i +: 64] <= lane;
                        end
                        for (int j = 9; j < 25; j++)
                            K[64*j +: 64] <= 64'd0;
                        state <= LOAD_BLOCK0;
                    end
                end

                LOAD_BLOCK0: begin
                    keccak_start_reg <= 1'b1;
                    state <= RUN_PERM1;
                end

                RUN_PERM1: begin
                    if (keccak_done) begin
                        K <= keccak_state_out;
                        state <= LOAD_BLOCK1;
                    end
                end

                LOAD_BLOCK1: begin
                    block1_bytes[0] = 8'h4E; block1_bytes[1] = 8'h41; block1_bytes[2] = 8'h4E;
                    block1_bytes[3] = 8'h54; block1_bytes[4] = 8'h3A; block1_bytes[5] = 8'h06;
                    for (int i = 6; i < 71; i++) block1_bytes[i] = 8'h00;
                    block1_bytes[71] = 8'h80;

                    for (int i = 0; i < 9; i++) begin
                        lane = { block1_bytes[8*i+7], block1_bytes[8*i+6], block1_bytes[8*i+5], block1_bytes[8*i+4],
                                 block1_bytes[8*i+3], block1_bytes[8*i+2], block1_bytes[8*i+1], block1_bytes[8*i+0] };
                        K[64*i +: 64] <= K[64*i +: 64] ^ lane;
                    end
                    keccak_start_reg <= 1'b1;
                    state <= RUN_PERM2;
                end

                RUN_PERM2: begin
                    if (keccak_done) begin
                        K <= keccak_state_out;
                        state <= SQUEEZE;
                    end
                end

                SQUEEZE: begin
                    for (int i = 0; i < 8; i++) begin
                        lane = K[64*i +: 64];
                        digest[512 - 64*i - 1 -: 64] <= { lane[7:0],  lane[15:8], lane[23:16], lane[31:24],
                                                           lane[39:32], lane[47:40], lane[55:48], lane[63:56] };
                    end
                    valid_out <= 1'b1;
                    state <= DONE;
                end

                DONE: state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end

endmodule