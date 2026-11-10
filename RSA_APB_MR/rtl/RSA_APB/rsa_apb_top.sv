////////////////////////////////////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
//
// RSA_APB: 32-bit RSA coprocessor with an AMBA 3 APB slave port.
//
// Wraps rsa_core (rsa_core.v, unchanged) with
//   - rsa_apb_regs     : APB3 slave, register map, PSLVERR, irq
//   - rsa_apb_seq      : START sequencer that feeds M, e, n to rsa_core
//   - rsa_apb_rst_sync : two-flop reset synchroniser for core_rst
//   - amba_3_apb_rsa_apb_top : top level
//
// Spec: apb_integration.pdf (sections 3 to 7).
//
// Synthesis: single clock (PCLK), asynchronous-assert / synchronous-release
// reset for the core, asynchronous reset flops in the wrapper, no latches,
// no initial blocks, no delays.
//
// How this implementation relates to the datasheet (all found by reading
// rsa_core.v):
//
//  1. LOAD_GAP: rsa_core_ctrl moves LOAD_x -> WAIT_x while core_load is
//     high and only goes on to the next operand when core_load is LOW. A
//     back-to-back load (gap 0) is therefore not accepted. LOAD_GAP must be
//     >= 1 and the default is 1. A value of 0 is raised to 1.
//
//  2. core_done / core_err: rsa_core_ctrl sets core_done on the ERROR path
//     too (together with core_err), and core_err stays high until the next
//     successful operation. The wrapper therefore treats
//         core_done & ~core_err  as DONE
//         core_done &  core_err  as ERROR
//     and only looks at core_err while core_done is high.
//
//  3. SRST: the core does not clear its start_ff on core_rst, so a
//     one-cycle reset can leave a stray start pulse that launches a
//     multiplication after reset. SRST_CYCLES (default 2) holds core_rst
//     long enough for the core's INIT state to clear it. Set SRST_CYCLES = 1
//     for the exact one-cycle behaviour of the datasheet.
//
//  4. BUSY is cleared in the same clock edge that sets DONE or ERROR, so
//     software never reads BUSY = 1 together with DONE or ERROR.
//
//  5. The sequencer waits one cycle (PREP) before the first core_load and,
//     after any reset of the core, until the core is back in its LOAD_M
//     state. With LOAD_GAP = 1 the three loads take PREP + M, gap, e, gap, n
//     = 6 cycles, then T_core.
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps


////////////////////////////////////////////////////////////////////////////////
// Reset synchroniser: asynchronous assertion, synchronous release
////////////////////////////////////////////////////////////////////////////////
module rsa_apb_rst_sync (
    input  logic pclk,
    input  logic presetn,
    output logic rst_sync_n
);

    logic q1, q2;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            q1 <= 1'b0;
            q2 <= 1'b0;
        end
        else begin
            q1 <= 1'b1;
            q2 <= q1;
        end
    end

    assign rst_sync_n = q2;

endmodule


////////////////////////////////////////////////////////////////////////////////
// START sequencer
//
// IDLE -> PREP -> LD_M -> GAP_M -> LD_E -> GAP_E -> LD_N -> WAIT -> IDLE
//
// core_load is high in the LD_x states with the matching operand on
// core_din, and low in the GAP_x states (LOAD_GAP cycles each) and in WAIT.
// BUSY is high in every state except IDLE.
////////////////////////////////////////////////////////////////////////////////
module rsa_apb_seq #(
    parameter int LOAD_GAP = 1
)(
    input  logic       pclk,
    input  logic       presetn,

    input  logic       start_req,   // CTRL.START written while idle
    input  logic       srst_req,    // CTRL.SRST written
    input  logic       core_hold,   // rsa_core is in or just out of reset

    input  logic       core_done,
    input  logic       core_err,

    output logic       busy,
    output logic       core_load,
    output logic [1:0] operand_sel, // 0 = MSG, 1 = EXP, 2 = MOD
    output logic       op_done,     // one-cycle pulse: result valid
    output logic       op_err       // one-cycle pulse: n = 0
);

    // rsa_core_ctrl needs core_load low between operands
    localparam int GAP = (LOAD_GAP < 1) ? 1 : LOAD_GAP;
    localparam int GW  = (GAP > 1) ? $clog2(GAP) : 1;

    localparam logic [2:0] S_IDLE  = 3'd0,
                           S_PREP  = 3'd1,
                           S_LD_M  = 3'd2,
                           S_GAP_M = 3'd3,
                           S_LD_E  = 3'd4,
                           S_GAP_E = 3'd5,
                           S_LD_N  = 3'd6,
                           S_WAIT  = 3'd7;

    logic [2:0]    state;
    logic [GW-1:0] gap_cnt;

    wire gap_last = (gap_cnt == (GAP - 1));

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            state   <= S_IDLE;
            gap_cnt <= '0;
        end
        else if (srst_req) begin
            // CTRL.SRST aborts any operation in progress
            state   <= S_IDLE;
            gap_cnt <= '0;
        end
        else begin
            case (state)
                S_IDLE:  if (start_req)   state <= S_PREP;

                S_PREP:  if (!core_hold)  state <= S_LD_M;

                S_LD_M: begin
                    state   <= S_GAP_M;
                    gap_cnt <= '0;
                end
                S_GAP_M: begin
                    if (gap_last) state <= S_LD_E;
                    else          gap_cnt <= gap_cnt + 1'b1;
                end

                S_LD_E: begin
                    state   <= S_GAP_E;
                    gap_cnt <= '0;
                end
                S_GAP_E: begin
                    if (gap_last) state <= S_LD_N;
                    else          gap_cnt <= gap_cnt + 1'b1;
                end

                S_LD_N:  state <= S_WAIT;

                S_WAIT:  if (core_done)   state <= S_IDLE;

                default: state <= S_IDLE;
            endcase
        end
    end

    assign busy      = (state != S_IDLE);

    assign core_load = (state == S_LD_M) || (state == S_LD_E) || (state == S_LD_N);

    always_comb begin
        case (state)
            S_LD_E,
            S_GAP_E: operand_sel = 2'd1;
            S_LD_N,
            S_WAIT:  operand_sel = 2'd2;
            default: operand_sel = 2'd0;
        endcase
    end

    // core_err is only meaningful together with core_done (see note 2)
    assign op_done = (state == S_WAIT) &&  core_done && !core_err;
    assign op_err  = (state == S_WAIT) &&  core_done &&  core_err;

endmodule


////////////////////////////////////////////////////////////////////////////////
// APB3 slave: register map (Datasheet 5, 6), PSLVERR (6.7), irq (4.4)
////////////////////////////////////////////////////////////////////////////////
module rsa_apb_regs #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 12
)(
    input  logic                  pclk,
    input  logic                  presetn,

    // APB3
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [ADDR_WIDTH-1:0] paddr,
    input  logic [DATA_WIDTH-1:0] pwdata,
    output logic [DATA_WIDTH-1:0] prdata,
    output logic                  pready,
    output logic                  pslverr,
    output logic                  irq,

    // to / from the START sequencer
    input  logic                  busy,
    input  logic                  op_done,
    input  logic                  op_err,
    input  logic [DATA_WIDTH-1:0] core_dout,
    output logic                  start_req,
    output logic                  srst_req,
    output logic [DATA_WIDTH-1:0] reg_msg,
    output logic [DATA_WIDTH-1:0] reg_exp,
    output logic [DATA_WIDTH-1:0] reg_mod
);

    ////////////////////////////////////////////////
    // Register map (word index = paddr[ADDR_WIDTH-1:2]; bits [1:0] ignored)
    ////////////////////////////////////////////////
    localparam int WA = ADDR_WIDTH - 2;

    localparam logic [WA-1:0] W_CTRL   = 0,   // 0x00
                              W_STATUS = 1,   // 0x04
                              W_IER    = 2,   // 0x08
                              W_MSG    = 3,   // 0x0C
                              W_EXP    = 4,   // 0x10
                              W_MOD    = 5,   // 0x14
                              W_RESULT = 6,   // 0x18
                              W_ID     = 7;   // 0x1C

    localparam int CTRL_START = 0;
    localparam int CTRL_SRST  = 1;

    // "RS", major 2, minor 0
    localparam logic [31:0] ID_VALUE = 32'h5253_0200;

    ////////////////////////////////////////////////
    // State
    ////////////////////////////////////////////////
    logic [1:0]            ier;          // [1] ERR_IE, [0] DONE_IE
    logic [DATA_WIDTH-1:0] reg_result;
    logic                  st_done;
    logic                  st_err;

    ////////////////////////////////////////////////
    // Access decode
    ////////////////////////////////////////////////
    wire [WA-1:0] word = paddr[ADDR_WIDTH-1:2];

    wire is_ctrl   = (word == W_CTRL);
    wire is_status = (word == W_STATUS);
    wire is_ier    = (word == W_IER);
    wire is_msg    = (word == W_MSG);
    wire is_exp    = (word == W_EXP);
    wire is_mod    = (word == W_MOD);
    wire is_result = (word == W_RESULT);
    wire is_id     = (word == W_ID);

    // The transfer completes in the access phase (PREADY is always high)
    wire wr_acc = psel && penable && pwrite;

    ////////////////////////////////////////////////
    // PSLVERR (Datasheet 6.7): the transfer has no effect
    //  - write to RESULT or ID
    //  - write to CTRL with START = 1, or to MSG / EXP / MOD, while BUSY
    // SRST in the same write wins over START, so that write is accepted.
    ////////////////////////////////////////////////
    wire ro_write   = is_result || is_id;
    wire busy_write = busy && (is_msg || is_exp || is_mod ||
                               (is_ctrl && pwdata[CTRL_START] && !pwdata[CTRL_SRST]));

    assign pslverr = wr_acc && (ro_write || busy_write);

    // Write that takes effect
    wire wr_ok = wr_acc && !ro_write && !busy_write;

    assign pready = 1'b1;

    // Self-clearing CTRL bits: one-cycle requests
    assign srst_req  = wr_ok && is_ctrl && pwdata[CTRL_SRST];
    assign start_req = wr_ok && is_ctrl && pwdata[CTRL_START] && !pwdata[CTRL_SRST];

    ////////////////////////////////////////////////
    // Registers
    ////////////////////////////////////////////////
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            ier        <= 2'b00;
            reg_msg    <= '0;
            reg_exp    <= '0;
            reg_mod    <= '0;
            reg_result <= '0;
            st_done    <= 1'b0;
            st_err     <= 1'b0;
        end
        else begin

            // Read/write registers
            if (wr_ok && is_ier) ier     <= pwdata[1:0];
            if (wr_ok && is_msg) reg_msg <= pwdata;
            if (wr_ok && is_exp) reg_exp <= pwdata;
            if (wr_ok && is_mod) reg_mod <= pwdata;

            // STATUS flags
            if (srst_req) begin
                // SRST clears STATUS; MSG, EXP, MOD, RESULT, IER unchanged
                st_done <= 1'b0;
                st_err  <= 1'b0;
            end
            else begin
                // Write 1 to clear
                if (wr_ok && is_status) begin
                    if (pwdata[1]) st_done <= 1'b0;
                    if (pwdata[2]) st_err  <= 1'b0;
                end

                // A new operation clears both flags
                if (start_req) begin
                    st_done <= 1'b0;
                    st_err  <= 1'b0;
                end

                // Completion wins over a simultaneous clear
                if (op_done) begin
                    st_done    <= 1'b1;
                    reg_result <= core_dout;
                end
                if (op_err)
                    st_err <= 1'b1;     // RESULT keeps its previous value
            end
        end
    end

    ////////////////////////////////////////////////
    // Read data (reserved bits and reserved offsets read as 0)
    ////////////////////////////////////////////////
    always_comb begin
        prdata = '0;

        if (psel && !pwrite) begin
            case (word)
                W_CTRL:   prdata = '0;                                   // WO
                W_STATUS: prdata = {{(DATA_WIDTH-3){1'b0}}, st_err, st_done, busy};
                W_IER:    prdata = {{(DATA_WIDTH-2){1'b0}}, ier};
                W_MSG:    prdata = reg_msg;
                W_EXP:    prdata = reg_exp;
                W_MOD:    prdata = reg_mod;
                W_RESULT: prdata = reg_result;
                W_ID:     prdata = ID_VALUE;
                default:  prdata = '0;
            endcase
        end
    end

    ////////////////////////////////////////////////
    // Level-sensitive interrupt
    ////////////////////////////////////////////////
    assign irq = (st_done && ier[0]) || (st_err && ier[1]);

endmodule


////////////////////////////////////////////////////////////////////////////////
// Top level
////////////////////////////////////////////////////////////////////////////////
module amba_3_apb_rsa_apb_top #(
    parameter int DATA_WIDTH  = 32,
    parameter int ADDR_WIDTH  = 12,
    // Idle cycles between the three core_load cycles (must be >= 1 for this core)
    parameter int LOAD_GAP    = 1,
    // Length of the core_rst pulse generated by CTRL.SRST
    parameter int SRST_CYCLES = 2
)(
    input  logic                  pclk_i,
    input  logic                  presetn_i,
    input  logic                  psel_i,
    input  logic                  penable_i,
    input  logic                  pwrite_i,
    input  logic [ADDR_WIDTH-1:0] paddr_i,
    input  logic [DATA_WIDTH-1:0] pwdata_i,
    output logic [DATA_WIDTH-1:0] prdata_o,
    output logic                  pready_o,
    output logic                  pslverr_o,
    output logic                  irq_o
);

    ////////////////////////////////////////////////
    // Internal nets
    ////////////////////////////////////////////////
    logic                  start_req, srst_req;
    logic                  busy, op_done, op_err;
    logic [DATA_WIDTH-1:0] reg_msg, reg_exp, reg_mod;

    logic                  core_rst;
    logic                  core_load;
    logic [DATA_WIDTH-1:0] core_din;
    logic [1:0]            operand_sel;
    logic                  core_done, core_err;
    logic [DATA_WIDTH-1:0] core_dout;

    ////////////////////////////////////////////////
    // core_rst = synchronised PRESETn OR CTRL.SRST
    ////////////////////////////////////////////////
    localparam int SRST_N = (SRST_CYCLES < 1) ? 1 : SRST_CYCLES;
    localparam int SW     = (SRST_N > 1) ? $clog2(SRST_N + 1) : 1;

    logic          rst_sync_n;
    logic [SW-1:0] srst_cnt;
    logic          core_rst_d1;
    logic          core_hold;

    rsa_apb_rst_sync u_rst_sync (
        .pclk       (pclk_i),
        .presetn    (presetn_i),
        .rst_sync_n (rst_sync_n)
    );

    always_ff @(posedge pclk_i or negedge presetn_i) begin
        if (!presetn_i) begin
            srst_cnt    <= '0;
            core_rst_d1 <= 1'b1;
        end
        else begin
            if (srst_req)
                srst_cnt <= SRST_N;
            else if (srst_cnt != '0)
                srst_cnt <= srst_cnt - 1'b1;

            core_rst_d1 <= core_rst;
        end
    end

    assign core_rst  = !rst_sync_n || (srst_cnt != '0);

    // The core needs one clock after core_rst falls to leave INIT and one
    // more to reach LOAD_M: do not load before that (note 5)
    assign core_hold = core_rst || core_rst_d1;

    ////////////////////////////////////////////////
    // APB slave and registers
    ////////////////////////////////////////////////
    rsa_apb_regs #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_regs (
        .pclk       (pclk_i),
        .presetn    (presetn_i),
        .psel       (psel_i),
        .penable    (penable_i),
        .pwrite     (pwrite_i),
        .paddr      (paddr_i),
        .pwdata     (pwdata_i),
        .prdata     (prdata_o),
        .pready     (pready_o),
        .pslverr    (pslverr_o),
        .irq        (irq_o),
        .busy       (busy),
        .op_done    (op_done),
        .op_err     (op_err),
        .core_dout  (core_dout),
        .start_req  (start_req),
        .srst_req   (srst_req),
        .reg_msg    (reg_msg),
        .reg_exp    (reg_exp),
        .reg_mod    (reg_mod)
    );

    ////////////////////////////////////////////////
    // START sequencer: M, e, n onto core_din
    ////////////////////////////////////////////////
    rsa_apb_seq #(
        .LOAD_GAP   (LOAD_GAP)
    ) u_seq (
        .pclk        (pclk_i),
        .presetn     (presetn_i),
        .start_req   (start_req),
        .srst_req    (srst_req),
        .core_hold   (core_hold),
        .core_done   (core_done),
        .core_err    (core_err),
        .busy        (busy),
        .core_load   (core_load),
        .operand_sel (operand_sel),
        .op_done     (op_done),
        .op_err      (op_err)
    );

    always_comb begin
        case (operand_sel)
            2'd1:    core_din = reg_exp;
            2'd2:    core_din = reg_mod;
            default: core_din = reg_msg;
        endcase
    end

    ////////////////////////////////////////////////
    // RSA core (unchanged)
    ////////////////////////////////////////////////
    rsa_core #(
        .DATA_WIDTH (DATA_WIDTH),
        .RESET      (1'b1),
        .LOAD       (1'b1)
    ) u_rsa_core (
        .core_clk   (pclk_i),
        .core_rst   (core_rst),
        .core_load  (core_load),
        .core_din   (core_din),
        .core_done  (core_done),
        .core_err   (core_err),
        .core_dout  (core_dout),
        .core_clk_o ()
    );

endmodule
