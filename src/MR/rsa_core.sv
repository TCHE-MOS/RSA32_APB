`timescale 1ns / 1ps

// ============================================================
// Module: rsa_core_mult
// ============================================================
module rsa_core_mult #(
    parameter int DATA_WIDTH = 4,
    parameter bit RESET      = 1'b1,
    parameter bit START      = 1'b1
) (
    input  logic                    mult_clk,
    input  logic                    mult_rst,
    input  logic                    mult_start,
    input  logic [DATA_WIDTH-1:0]   mult_a,
    input  logic [DATA_WIDTH-1:0]   mult_b,
    output logic                    mult_done,
    output logic [2*DATA_WIDTH-1:0] mult_c
);

    typedef enum logic [2:0] {
        INIT      = 3'd0,
        ANALYZE   = 3'd1,
        SHIFT_ADD = 3'd2,
        SHIFT     = 3'd3,
        DONE      = 3'd4
    } state_e;

    state_e state_reg, state_ns;

    logic [$clog2(DATA_WIDTH+1)-1:0] a_cnt;
    logic [DATA_WIDTH-1:0]           a_reg, b_reg;
    logic [2*DATA_WIDTH-1:0]         p_reg, c_reg;
    logic                            done_ff;

    // Output assignments
    assign mult_done = done_ff;
    assign mult_c    = c_reg;

    // Next-State Logic
    always_comb begin
        if (mult_rst == RESET) begin
            state_ns = INIT;
        end else begin
            unique case (state_reg)
                INIT: begin
                    state_ns = (mult_start == START) ? ANALYZE : INIT;
                end
                
                ANALYZE: begin
                    state_ns = (b_reg[DATA_WIDTH-1]) ? SHIFT_ADD : SHIFT;
                end
                
                SHIFT_ADD: begin
                    if (a_cnt != (DATA_WIDTH - 1))
                        state_ns = (b_reg[DATA_WIDTH-1]) ? SHIFT_ADD : SHIFT;
                    else
                        state_ns = DONE;
                end
                
                SHIFT: begin
                    if (a_cnt != (DATA_WIDTH - 1))
                        state_ns = (b_reg[DATA_WIDTH-1]) ? SHIFT_ADD : SHIFT;
                    else
                        state_ns = DONE;
                end
                
                DONE: begin
                    state_ns = INIT;
                end

                default: begin
                    state_ns = INIT;
                end
            endcase
        end
    end

    // Sequential State & Data Register Updates
    always_ff @(posedge mult_clk) begin
        unique case (state_reg)
            INIT: begin
                p_reg   <= '0;
                a_cnt   <= '0;
                done_ff <= 1'b0;
                a_reg   <= mult_a;
                b_reg   <= mult_b;
            end
            ANALYZE: begin
                b_reg <= {b_reg[DATA_WIDTH-2:0], 1'b0};
            end
            SHIFT_ADD: begin
                p_reg <= a_reg + {p_reg[2*DATA_WIDTH-2:0], 1'b0};
                a_cnt <= a_cnt + 1'b1;
                b_reg <= {b_reg[DATA_WIDTH-2:0], 1'b0};
            end
            SHIFT: begin
                p_reg <= {p_reg[2*DATA_WIDTH-2:0], 1'b0};
                a_cnt <= a_cnt + 1'b1;
                b_reg <= {b_reg[DATA_WIDTH-2:0], 1'b0};
            end
            DONE: begin
                done_ff <= 1'b1;
                c_reg   <= p_reg;
            end
            default: ;
        endcase

        state_reg <= state_ns;
    end

endmodule


// ============================================================
// Module: rsa_core_mod
// ============================================================
module rsa_core_mod #(
    parameter int DATA_WIDTH = 4,
    parameter bit RESET      = 1'b1,
    parameter bit START      = 1'b1
)(
    input  logic                    mod_clk,
    input  logic                    mod_rst,
    input  logic                    mod_start,
    input  logic [2*DATA_WIDTH-1:0] mod_a,
    input  logic [DATA_WIDTH-1:0]   mod_b,
    output logic                    mod_done,
    output logic                    mod_err,
    output logic [DATA_WIDTH-1:0]   mod_c
);

    typedef enum logic [2:0] {
        INIT     = 3'b000,
        CHECK    = 3'b001,
        PREPARE  = 3'b010,
        COMPARE  = 3'b011,
        SUBTRACT = 3'b100,
        SHIFT    = 3'b101,
        DONE     = 3'b110,
        ERROR    = 3'b111
    } state_e;

    state_e state_reg, state_ns;

    logic [DATA_WIDTH:0]     a_cnt;
    logic [2*DATA_WIDTH-1:0] t_reg, n_reg;
    logic [DATA_WIDTH-1:0]   r_reg;
    logic                    mod_done_ff, mod_err_ff;

    assign mod_done = mod_done_ff;
    assign mod_err  = mod_err_ff;
    assign mod_c    = r_reg;

    // Next-State Logic
    always_comb begin
        if (mod_rst == RESET) begin
            state_ns = INIT;
        end else begin
            unique case (state_reg)
                INIT: begin
                    state_ns = (mod_start == START) ? CHECK : INIT;
                end
                CHECK: begin
                    state_ns = (n_reg[DATA_WIDTH-1:0] == '0) ? ERROR : PREPARE;
                end
                PREPARE: begin
                    state_ns = (!n_reg[2*DATA_WIDTH-2]) ? PREPARE : COMPARE;
                end
                COMPARE: begin
                    state_ns = (t_reg >= n_reg) ? SUBTRACT : SHIFT;
                end
                SUBTRACT: begin
                    state_ns = (a_cnt != '0) ? COMPARE : DONE;
                end
                SHIFT: begin
                    state_ns = (a_cnt != '0) ? COMPARE : DONE;
                end
                DONE: begin
                    state_ns = INIT;
                end
                ERROR: begin
                    state_ns = INIT;
                end
                default: begin
                    state_ns = INIT;
                end
            endcase
        end
    end

    // Sequential Registers
    always_ff @(posedge mod_clk) begin
        unique case (state_reg)
            INIT: begin
                mod_done_ff                      <= 1'b0;
                t_reg                            <= mod_a;
                n_reg[DATA_WIDTH-1:0]            <= mod_b;
                n_reg[2*DATA_WIDTH-1:DATA_WIDTH] <= '0;
                a_cnt                            <= '0;
            end
            CHECK: begin
                // No register operations required
            end
            PREPARE: begin
                a_cnt <= a_cnt + 1'b1;
                n_reg <= {n_reg[2*DATA_WIDTH-2:0], 1'b0};
            end
            COMPARE: begin
                // No register operations required
            end
            SUBTRACT: begin
                t_reg <= t_reg - n_reg;
                n_reg <= {1'b0, n_reg[2*DATA_WIDTH-1:1]};
                a_cnt <= a_cnt - 1'b1;
            end
            SHIFT: begin
                n_reg <= {1'b0, n_reg[2*DATA_WIDTH-1:1]};
                a_cnt <= a_cnt - 1'b1;
            end
            DONE: begin
                r_reg       <= t_reg[DATA_WIDTH-1:0];
                mod_done_ff <= 1'b1;
                mod_err_ff  <= 1'b0;
            end
            ERROR: begin
                mod_err_ff  <= 1'b1;
                mod_done_ff <= 1'b1;
                r_reg       <= '1; // Set all bits to 1
            end
            default: ;
        endcase

        state_reg <= state_ns;
    end

endmodule


// ============================================================
// Module: rsa_core_ctrl
// ============================================================
module rsa_core_ctrl #(
    parameter int DATA_WIDTH = 4,
    parameter bit RESET      = 1'b1,
    parameter bit LOAD       = 1'b1
)(
    input  logic                  ctrl_clk,
    input  logic                  ctrl_rst,
    input  logic                  ctrl_load,
    input  logic [DATA_WIDTH-1:0] ctrl_din,
    input  logic                  ctrl_loadx,
    input  logic [DATA_WIDTH-1:0] ctrl_dinx,
    output logic                  ctrl_done,
    output logic                  ctrl_err,
    output logic [DATA_WIDTH-1:0] ctrl_c,
    output logic                  ctrl_start,
    output logic [DATA_WIDTH-1:0] ctrl_n,
    output logic [DATA_WIDTH-1:0] ctrl_m,
    output logic [DATA_WIDTH-1:0] ctrl_doutx
);

    localparam logic [DATA_WIDTH-1:0] ONE = 1'b1;

    typedef enum logic [3:0] {
        INIT    = 4'd0,
        LOAD_M  = 4'd1,
        WAIT_M  = 4'd2,
        LOAD_E  = 4'd3,
        WAIT_E  = 4'd4,
        LOAD_N  = 4'd5,
        WAIT_N  = 4'd6,
        ERROR   = 4'd7,
        CASE0   = 4'd8,
        ANALYZE = 4'd9,
        DONE    = 4'd10,
        CASE1   = 4'd11,
        CASE2   = 4'd12,
        START   = 4'd13
    } state_e;

    state_e state_reg, state_ns;

    logic [DATA_WIDTH-1:0] n_reg, e_reg, m_reg, x_reg, c_reg;
    logic                  err_ff, start_ff, done_ff;

    assign ctrl_c     = c_reg;
    assign ctrl_n     = n_reg;
    assign ctrl_m     = m_reg;
    assign ctrl_doutx = x_reg;

    assign ctrl_done  = done_ff;
    assign ctrl_start = start_ff;
    assign ctrl_err   = err_ff;

    // Next-State Logic
    always_comb begin
        if (ctrl_rst == RESET) begin
            state_ns = INIT;
        end else begin
            unique case (state_reg)
                INIT:   state_ns = LOAD_M;
                LOAD_M: state_ns = (ctrl_load == LOAD) ? WAIT_M : LOAD_M;
                WAIT_M: state_ns = (ctrl_load == LOAD) ? WAIT_M : LOAD_E;
                LOAD_E: state_ns = (ctrl_load == LOAD) ? WAIT_E : LOAD_E;
                WAIT_E: state_ns = (ctrl_load == LOAD) ? WAIT_E : LOAD_N;
                LOAD_N: state_ns = (ctrl_load == LOAD) ? WAIT_N : LOAD_N;
                
                WAIT_N: begin
                    if (ctrl_load == LOAD)
                        state_ns = WAIT_N;
                    else if (n_reg == '0)
                        state_ns = ERROR;
                    else if (e_reg == '0)
                        state_ns = CASE0;
                    else if (e_reg == 1'b1)
                        state_ns = CASE1;
                    else
                        state_ns = CASE2;
                end
                
                ERROR:  state_ns = LOAD_M;
                CASE0:  state_ns = ANALYZE;
                
                ANALYZE: begin
                    if (!ctrl_loadx)
                        state_ns = ANALYZE;
                    else if (e_reg == '0)
                        state_ns = DONE;
                    else
                        state_ns = START;
                end
                
                DONE:   state_ns = LOAD_M;
                CASE1:  state_ns = ANALYZE;
                CASE2:  state_ns = ANALYZE;
                START:  state_ns = ANALYZE;
                default: state_ns = INIT;
            endcase
        end
    end

    // Sequential Registers
    always_ff @(posedge ctrl_clk) begin
        unique case (state_reg)
            INIT: begin
                err_ff   <= 1'b0;
                start_ff <= 1'b0;
                done_ff  <= 1'b0;
            end
            LOAD_M: begin
                m_reg   <= ctrl_din;
                x_reg   <= ctrl_din;
                done_ff <= 1'b0;
            end
            WAIT_M: ;
            LOAD_E: e_reg <= ctrl_din;
            WAIT_E: ;
            LOAD_N: n_reg <= ctrl_din;
            ERROR: begin
                done_ff <= 1'b1;
                err_ff  <= 1'b1;
                c_reg   <= '1; // Set all bits to 1
            end
            CASE0: begin
                start_ff <= 1'b1;
                m_reg    <= ONE;
                x_reg    <= ONE;
            end
            ANALYZE: begin
                x_reg    <= ctrl_dinx;
                start_ff <= 1'b0;
            end
            DONE: begin
                c_reg   <= x_reg;
                done_ff <= 1'b1;
                err_ff  <= 1'b0;
            end
            CASE1: begin
                x_reg    <= ONE;
                start_ff <= 1'b1;
                e_reg    <= e_reg - 1'b1;
            end
            CASE2: begin
                start_ff <= 1'b1;
                e_reg    <= e_reg - 2'd2;
            end
            START: begin
                start_ff <= 1'b1;
                e_reg    <= e_reg - 1'b1;
            end
            default: ;
        endcase

        state_reg <= state_ns;
    end

endmodule


// ============================================================
// Module: rsa_core (TOP)
// ============================================================
module rsa_core #(
    parameter int DATA_WIDTH = 4,
    parameter bit RESET      = 1'b1,
    parameter bit LOAD       = 1'b1
) (
    input  logic                  core_clk,
    input  logic                  core_rst,
    input  logic                  core_load,
    input  logic [DATA_WIDTH-1:0] core_din,
    output logic                  core_done,
    output logic                  core_err,
    output logic [DATA_WIDTH-1:0] core_dout,
    output logic                  core_clk_o
);

    assign core_clk_o = core_clk;

    // Internal interconnect logic
    logic                  ctrl_start_sig;
    logic [DATA_WIDTH-1:0] ctrl_m_sig;
    logic [DATA_WIDTH-1:0] ctrl_n_sig;
    logic [DATA_WIDTH-1:0] ctrl_doutx_sig;

    logic                  mult_done_sig;
    logic [2*DATA_WIDTH-1:0] mult_c_sig;

    logic                  mod_done_sig;
    logic [DATA_WIDTH-1:0] mod_c_sig;

    // Multiplier Block
    rsa_core_mult #(
        .DATA_WIDTH(DATA_WIDTH),
        .RESET     (RESET),
        .START     (1'b1)
    ) rsa_core_mult_blk (
        .mult_clk  (core_clk),
        .mult_rst  (core_rst),
        .mult_start(ctrl_start_sig),
        .mult_a    (ctrl_m_sig),
        .mult_b    (ctrl_doutx_sig),
        .mult_done (mult_done_sig),
        .mult_c    (mult_c_sig)
    );

    // Modulo Block
    rsa_core_mod #(
        .DATA_WIDTH(DATA_WIDTH),
        .RESET     (RESET),
        .START     (1'b1)
    ) rsa_core_mod_blk (
        .mod_clk  (core_clk),
        .mod_rst  (core_rst),
        .mod_start(mult_done_sig),
        .mod_a    (mult_c_sig),
        .mod_b    (ctrl_n_sig),
        .mod_done (mod_done_sig),
        .mod_err  (/* unused */),
        .mod_c    (mod_c_sig)
    );

    // Controller Block
    rsa_core_ctrl #(
        .DATA_WIDTH(DATA_WIDTH),
        .RESET     (RESET),
        .LOAD      (LOAD)
    ) rsa_core_ctrl_blk (
        .ctrl_clk  (core_clk),
        .ctrl_rst  (core_rst),
        .ctrl_load (core_load),
        .ctrl_din  (core_din),
        .ctrl_loadx(mod_done_sig),
        .ctrl_dinx (mod_c_sig),
        .ctrl_done (core_done),
        .ctrl_err  (core_err),
        .ctrl_c    (core_dout),
        .ctrl_start(ctrl_start_sig),
        .ctrl_n    (ctrl_n_sig),
        .ctrl_m    (ctrl_m_sig),
        .ctrl_doutx(ctrl_doutx_sig)
    );

endmodule
