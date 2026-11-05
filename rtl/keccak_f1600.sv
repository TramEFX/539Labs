// keccak_f1600.sv
// Keccak-f[1600] 24-round permutation Ã¢â‚¬â€ always_comb/always_ff split
// Fixes XSIM simulation hazard from blocking assignments in always_ff

module keccak_f1600 (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          start,
    input  wire [1599:0] state_in,
    output reg  [1599:0] state_out,
    output reg           done
);

    localparam logic [5:0] RHO[0:4][0:4] = '{
        '{ 6'd0,  6'd36,  6'd3,  6'd41, 6'd18 },
        '{ 6'd1,  6'd44, 6'd10,  6'd45,  6'd2 },
        '{6'd62,   6'd6, 6'd43,  6'd15, 6'd61 },
        '{6'd28,  6'd55, 6'd25,  6'd21, 6'd56 },
        '{6'd27,  6'd20, 6'd39,   6'd8, 6'd14 }
    };

    localparam logic [63:0] RC[0:23] = '{
        64'h0000000000000001, 64'h0000000000008082,
        64'h800000000000808A, 64'h8000000080008000,
        64'h000000000000808B, 64'h0000000080000001,
        64'h8000000080008081, 64'h8000000000008009,
        64'h000000000000008A, 64'h0000000000000088,
        64'h0000000080008009, 64'h000000008000000A,
        64'h000000008000808B, 64'h800000000000008B,
        64'h8000000000008089, 64'h8000000000008003,
        64'h8000000000008002, 64'h8000000000000080,
        64'h000000000000800A, 64'h800000008000000A,
        64'h8000000080008081, 64'h8000000000008080,
        64'h0000000080000001, 64'h8000000080008008
    };

    function automatic [63:0] rot64(input [63:0] v, input [5:0] n);
        rot64 = (v << n) | (v >> (64 - n));
    endfunction

    // State registers
    reg  [63:0] A      [0:4][0:4];
    reg  [4:0]  round_cnt;
    reg         running;

    // Combinational round outputs
    logic [63:0] C      [0:4];
    logic [63:0] D      [0:4];
    logic [63:0] B      [0:4][0:4];
    logic [63:0] next_A [0:4][0:4];

    // One full Keccak round Ã¢â‚¬â€ purely combinational from A and round_cnt
    always_comb begin
        // ÃŽÂ¸
        for (int x = 0; x < 5; x++)
            C[x] = A[x][0] ^ A[x][1] ^ A[x][2] ^ A[x][3] ^ A[x][4];
        for (int x = 0; x < 5; x++)
            D[x] = C[(x+4)%5] ^ rot64(C[(x+1)%5], 1);
        for (int x = 0; x < 5; x++) for (int y = 0; y < 5; y++)
            next_A[x][y] = A[x][y] ^ D[x];
        // ÃÂ + Ãâ‚¬
        for (int x = 0; x < 5; x++) for (int y = 0; y < 5; y++)
            B[y][(2*x + 3*y) % 5] = rot64(next_A[x][y], RHO[x][y]);
        // Ãâ€¡
        for (int x = 0; x < 5; x++) for (int y = 0; y < 5; y++)
            next_A[x][y] = B[x][y] ^ ((~B[(x+1)%5][y]) & B[(x+2)%5][y]);
        // ÃŽÂ¹
        next_A[0][0] = next_A[0][0] ^ RC[round_cnt];
    end

    // State registration only
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running   <= 1'b0;
            done      <= 1'b0;
            round_cnt <= 5'd0;
            state_out <= 1600'd0;
            for (int x = 0; x < 5; x++)
                for (int y = 0; y < 5; y++)
                    A[x][y] <= 64'd0;
        end else begin
            done <= 1'b0;

            if (start && !running) begin
                for (int x = 0; x < 5; x++)
                    for (int y = 0; y < 5; y++)
                        A[x][y] <= state_in[64*(5*y + x) +: 64];
                round_cnt <= 5'd0;
                running   <= 1'b1;
            end else if (running) begin
                for (int x = 0; x < 5; x++)
                    for (int y = 0; y < 5; y++)
                        A[x][y] <= next_A[x][y];
                if (round_cnt == 5'd23) begin
                    running <= 1'b0;
                    for (int x = 0; x < 5; x++)
                        for (int y = 0; y < 5; y++)
                            state_out[64*(5*y + x) +: 64] <= next_A[x][y];
                    done <= 1'b1;
                end else begin
                    round_cnt <= round_cnt + 1'b1;
                end
            end
        end
    end

endmodule