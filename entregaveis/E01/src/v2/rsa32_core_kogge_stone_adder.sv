// ============================================================
// Module: kogge_stone_adder
// Description: Parametric unsigned Kogge-Stone parallel-prefix
//              adder. Fully combinational; no pipeline stages.
//              Supports DATA_WIDTH >= 1, including non-powers
//              of two (e.g., 6, 33, and 64 bits).
// ============================================================
module kogge_stone_adder #(
    parameter int unsigned DATA_WIDTH = 64
) (
    input  logic [DATA_WIDTH-1:0] a_i,
    input  logic [DATA_WIDTH-1:0] b_i,
    input  logic                  cin_i,
    output logic [DATA_WIDTH-1:0] sum_o,
    output logic                  cout_o
);

    localparam int unsigned LEVELS = $clog2(DATA_WIDTH);

    // Index 0 contains bitwise propagate/generate signals.
    // Index k+1 contains the result of prefix stage k.
    logic [DATA_WIDTH-1:0] p_stage [0:LEVELS];
    logic [DATA_WIDTH-1:0] g_stage [0:LEVELS];
    logic [DATA_WIDTH:0]   carry;

    // --------------------------------------------------------
    // Pre-processing: P = A XOR B, G = A AND B
    // --------------------------------------------------------
    assign p_stage[0] = a_i ^ b_i;
    assign g_stage[0] = a_i & b_i;

    // --------------------------------------------------------
    // Prefix tree: combine over distances 1, 2, 4, 8, ...
    // --------------------------------------------------------
    generate
        for (genvar stage = 0; stage < LEVELS; stage = stage + 1)
            begin : gen_prefix_stage
                localparam int unsigned DISTANCE = (1 << stage);

                for (genvar bit_idx = 0; bit_idx < DATA_WIDTH; bit_idx = bit_idx + 1)
                    begin : gen_prefix_bit
                        if (bit_idx >= DISTANCE)
                            begin : gen_merge
                                assign g_stage[stage+1][bit_idx] =
                                    g_stage[stage][bit_idx] |
                                    (p_stage[stage][bit_idx] &
                                     g_stage[stage][bit_idx-DISTANCE]);

                                assign p_stage[stage+1][bit_idx] =
                                    p_stage[stage][bit_idx] &
                                    p_stage[stage][bit_idx-DISTANCE];
                            end
                        else
                            begin : gen_passthrough
                                assign g_stage[stage+1][bit_idx] =
                                    g_stage[stage][bit_idx];

                                assign p_stage[stage+1][bit_idx] =
                                    p_stage[stage][bit_idx];
                            end
                    end
            end
    endgenerate

    // --------------------------------------------------------
    // Post-processing: C[i+1] = G[i:0] | P[i:0] * Cin
    //                  S[i]   = p[i] XOR C[i]
    // --------------------------------------------------------
    assign carry[0] = cin_i;

    generate
        for (genvar bit_idx = 0; bit_idx < DATA_WIDTH; bit_idx = bit_idx + 1)
            begin : gen_sum
                assign carry[bit_idx+1] =
                    g_stage[LEVELS][bit_idx] |
                    (p_stage[LEVELS][bit_idx] & cin_i);

                assign sum_o[bit_idx] = p_stage[0][bit_idx] ^ carry[bit_idx];
            end
    endgenerate

    assign cout_o = carry[DATA_WIDTH];

endmodule
