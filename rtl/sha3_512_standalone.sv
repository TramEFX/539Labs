// sha3_512_standalone.sv
// SHA3-512 of a fixed 64-byte (512-bit) message — single Keccak-f[1600] permutation
// SHA3-512 rate = 576 bits = 72 bytes (9 x 64-bit lanes)
// Block: msg[63:0] + 0x06 + 0x00..0x00 + 0x80 (72 bytes total)
// M7 benchmark reference — 539 Labs LLC

module sha3_512_standalone (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          valid_in,       // hold high for one cycle to submit msg
    input  wire [511:0]  msg_in,         // big-endian: byte0 at [511:504], byte63 at [7:0]
    output reg  [511:0]  digest_out,     // big-endian SHA3-512 digest
    output reg           valid_out       // pulses one cycle when digest_out is ready
);

    reg [1599:0] K;

    typedef enum logic [2:0] {
        IDLE, LOAD, RUN_PERM, SQUEEZE, DONE_ST
    } state_t;
    state_t state;

    wire          keccak_done;
    wire [1599:0] keccak_state_out;
    reg           keccak_start_reg;

    keccak_f1600 keccak_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (keccak_start_reg),
        .state_in (K),
        .state_out(keccak_state_out),
        .done     (keccak_done)
    );

    // Rising-edge detect on valid_in
    reg valid_in_d;
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) valid_in_d <= 1'b0; else valid_in_d <= valid_in;
    wire valid_in_pulse = valid_in & ~valid_in_d;

    logic [7:0]  block_bytes [0:71];
    logic [63:0] lane;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= IDLE;
            K                <= 1600'd0;
            digest_out       <= 512'd0;
            valid_out        <= 1'b0;
            keccak_start_reg <= 1'b0;
        end else begin
            valid_out        <= 1'b0;
            keccak_start_reg <= 1'b0;

            case (state)
                IDLE: begin
                    if (valid_in_pulse) begin
                        // msg_in big-endian: byte 0 at [511:504]
                        for (int i = 0; i < 64; i++)
                            block_bytes[i] = msg_in[511 - 8*i -: 8];
                        block_bytes[64] = 8'h06;           // SHA3 domain sep
                        for (int i = 65; i < 71; i++)
                            block_bytes[i] = 8'h00;
                        block_bytes[71] = 8'h80;           // multi-rate padding

                        // Load 9 lanes into K (state starts all-zero, so no XOR needed)
                        for (int i = 0; i < 9; i++) begin
                            lane = { block_bytes[8*i+7], block_bytes[8*i+6],
                                     block_bytes[8*i+5], block_bytes[8*i+4],
                                     block_bytes[8*i+3], block_bytes[8*i+2],
                                     block_bytes[8*i+1], block_bytes[8*i+0] };
                            K[64*i +: 64] <= lane;
                        end
                        for (int j = 9; j < 25; j++)
                            K[64*j +: 64] <= 64'd0;
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    keccak_start_reg <= 1'b1;
                    state <= RUN_PERM;
                end

                RUN_PERM: begin
                    if (keccak_done) begin
                        K     <= keccak_state_out;
                        state <= SQUEEZE;
                    end
                end

                SQUEEZE: begin
                    // Squeeze 8 lanes → 512-bit digest, byte-reverse per lane (little→big endian)
                    // Corrected: read from K (matches hqh539_phase3 pattern)
                    for (int i = 0; i < 8; i++) begin
                        lane = K[64*i +: 64];
                        digest_out[511 - 64*i -: 64] <= {
                            lane[7:0],  lane[15:8],  lane[23:16], lane[31:24],
                            lane[39:32], lane[47:40], lane[55:48], lane[63:56]
                        };
                    end
                    valid_out <= 1'b1;
                    state <= DONE_ST;
                end

                DONE_ST: state <= IDLE;

                default: state <= IDLE;
            endcase
        end
    end

endmodule