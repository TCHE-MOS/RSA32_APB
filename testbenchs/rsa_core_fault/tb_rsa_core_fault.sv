`timescale 1ns/1ps
// ============================================================================
// tb_rsa_core_fault
// ----------------------------------------------------------------------------
// Bancada dirigida ao núcleo RSA (src/rsa32/v1 ou v2), sem APB, sem UVM e
// sem SVA. Investiga as falhas do README_falhas_uvm.md na fronteira core_*
// definida na seção 3.2 do datasheet e dentro do próprio núcleo.
//
// Instâncias:
//   dut     rsa_core completo, dirigido pelos pinos core_*.
//   u_mult  rsa_core_mult isolado (teste unitário do multiplicador).
//   u_mod   rsa_core_mod  isolado (teste unitário do redutor modular).
//
// Observação passiva dentro de dut:
//   - scoreboard de cada transação interna mult (a*b) e mod (a % b);
//   - caminho de estados de rsa_core_ctrl em operações selecionadas.
//
// Plusargs: +SEED=<n> (1)  +N_RANDOM=<n> (12)  +RAND_EXP_MAX=<n> (48)
// Define:   -D RSA_V1  ajusta as referências de linha do diagnóstico
// ============================================================================

package rsa_cf_pkg;

    localparam int ID_TB_REF     = 0;
    localparam int ID_RESULT     = 1;
    localparam int ID_RES_BIGM   = 2;
    localparam int ID_DONE_W     = 3;
    localparam int ID_NO_ERR     = 4;
    localparam int ID_ERR_ON     = 5;
    localparam int ID_ERR_EXCL   = 6;
    localparam int ID_ERR_W      = 7;
    localparam int ID_RECOV      = 8;
    localparam int ID_RST_ERR    = 9;
    localparam int ID_RST_ABORT  = 10;
    localparam int ID_LOAD_GAP   = 11;
    localparam int ID_SUB_MULT   = 12;
    localparam int ID_SUB_MOD    = 13;
    localparam int ID_U_MULT     = 14;
    localparam int ID_U_MOD      = 15;
    localparam int N_IDS         = 16;

    function automatic string id_name(input int id);
        case (id)
            ID_TB_REF:    return "TB_REF";
            ID_RESULT:    return "RESULT";
            ID_RES_BIGM:  return "RES_BIGM";
            ID_DONE_W:    return "DONE_W";
            ID_NO_ERR:    return "NO_ERR";
            ID_ERR_ON:    return "ERR_ON";
            ID_ERR_EXCL:  return "ERR_EXCL";
            ID_ERR_W:     return "ERR_W";
            ID_RECOV:     return "RECOV";
            ID_RST_ERR:   return "RST_ERR";
            ID_RST_ABORT: return "RST_ABORT";
            ID_LOAD_GAP:  return "LOAD_GAP";
            ID_SUB_MULT:  return "SUB_MULT";
            ID_SUB_MOD:   return "SUB_MOD";
            ID_U_MULT:    return "U_MULT";
            ID_U_MOD:     return "U_MOD";
            default:      return "?";
        endcase
    endfunction

    function automatic string id_desc(input int id);
        case (id)
            ID_TB_REF:    return "Modelos de referencia concordam";
            ID_RESULT:    return "core_dout = M^e mod n (M e n gerais)";
            ID_RES_BIGM:  return "core_dout correto com M >> n";
            ID_DONE_W:    return "core_done dura 1 ciclo";
            ID_NO_ERR:    return "Operacao valida nao gera core_error";
            ID_ERR_ON:    return "n=0 gera core_error";
            ID_ERR_EXCL:  return "n=0: core_error sem core_done";
            ID_ERR_W:     return "core_error dura 1 ciclo";
            ID_RECOV:     return "Op. apos erro comeca com core_error=0";
            ID_RST_ERR:   return "core_rst limpa core_error";
            ID_RST_ABORT: return "core_rst aborta operacao em curso";
            ID_LOAD_GAP:  return "Cargas aceitas com qualquer intervalo";
            ID_SUB_MULT:  return "Interno: mult_c = a*b";
            ID_SUB_MOD:   return "Interno: mod_c = a mod b";
            ID_U_MULT:    return "Unitario rsa_core_mult";
            ID_U_MOD:     return "Unitario rsa_core_mod";
            default:      return "?";
        endcase
    endfunction

    function automatic string id_spec(input int id);
        case (id)
            ID_RESULT, ID_RES_BIGM:            return "4.1";
            ID_DONE_W, ID_ERR_W, ID_RECOV:     return "3.2";
            ID_NO_ERR, ID_ERR_ON, ID_ERR_EXCL: return "3.2/4.1";
            ID_RST_ERR, ID_RST_ABORT:          return "3.2/4.5";
            ID_LOAD_GAP:                       return "3.2/4.3";
            ID_SUB_MULT, ID_SUB_MOD,
            ID_U_MULT, ID_U_MOD:               return "interno";
            default:                           return "-";
        endcase
    endfunction

    // Modelo 1: square-and-multiply, produtos de 64 bits.
    function automatic logic [31:0] modexp_sqm(input logic [31:0] m, e, n);
        logic [63:0] acc, base;
        logic [31:0] k;
        acc = 64'd1 % n; base = {32'b0, m} % n; k = e;
        while (k != 0) begin
            if (k[0]) acc = (acc * base) % n;
            base = (base * base) % n;
            k = k >> 1;
        end
        return acc[31:0];
    endfunction

    // Modelo 2: multiplicação repetida (independente; e pequeno).
    function automatic logic [31:0] modexp_naive(input logic [31:0] m, e, n);
        logic [63:0] acc, base;
        acc = 64'd1 % n; base = {32'b0, m} % n;
        for (int unsigned i = 0; i < e; i++) acc = (acc * base) % n;
        return acc[31:0];
    endfunction

    function automatic void fixed_vec(input int i, output logic [31:0] m, e, n, output string label);
        case (i)
            0: begin m = 32'd65;        e = 32'd17; n = 32'd3233;      label = "65^17 mod 3233";             end
            1: begin m = 32'h0F1C_3861; e = 32'd9;  n = 32'hC7C6_4DFB; label = "preparacao do caso UVM 10";  end
            2: begin m = 32'h181D_60BF; e = 32'd0;  n = 32'hC206_5569; label = "EXP=0 (README)";             end
            3: begin m = 32'h1234_5678; e = 32'd1;  n = 32'd65521;     label = "EXP=1, M>n";                 end
            4: begin m = 32'hFFFF_FFFF; e = 32'd3;  n = 32'hFFFF_FFFB; label = "M>n, n alto";                end
            5: begin m = 32'd123;       e = 32'd7;  n = 32'd1;         label = "n=1";                        end
            6: begin m = 32'hFEDC_BA98; e = 32'd17; n = 32'h8000_000B; label = "MSB de n em 1";              end
            7: begin m = 32'd2;         e = 32'd31; n = 32'hFFFF_FFFF; label = "2^31 mod (2^32-1)";          end
            8: begin m = 32'd0;         e = 32'd5;  n = 32'd97;        label = "M=0";                        end
            default: begin m = 0; e = 0; n = 1; label = "?"; end
        endcase
    endfunction
    localparam int N_FIXED = 9;

    // M muito maior que n: o primeiro produto interno é M*M (x_reg inicia com M).
    function automatic void bigm_vec(input int i, output logic [31:0] m, e, n, output string label);
        case (i)
            0: begin m = 32'hFFFF_FFFF; e = 32'd2; n = 32'd7;          label = "M=2^32-1, e=2, n=7";        end
            1: begin m = 32'hFFFF_FFFF; e = 32'd2; n = 32'd3;          label = "M=2^32-1, e=2, n=3";        end
            2: begin m = 32'hFFFF_FFFF; e = 32'd2; n = 32'd65521;      label = "M=2^32-1, e=2, n=65521";    end
            3: begin m = 32'h8000_0000; e = 32'd2; n = 32'd5;          label = "M=2^31, e=2, n=5";          end
            4: begin m = 32'hDEAD_BEEF; e = 32'd5; n = 32'd255;        label = "M=0xDEADBEEF, e=5, n=255";  end
            5: begin m = 32'hFFFF_FFFF; e = 32'd2; n = 32'h7FFF_FFFF;  label = "M=2^32-1, e=2, n=2^31-1";   end
            6: begin m = 32'h0000_FFFF; e = 32'd2; n = 32'd7;          label = "M=2^16-1, e=2, n=7";        end
            default: begin m = 0; e = 0; n = 1; label = "?"; end
        endcase
    endfunction
    localparam int N_BIGM = 7;

    localparam logic [31:0] MZ_MSG      = 32'h1C2F_4FF3;
    localparam logic [31:0] MZ_EXP      = 32'h0000_000A;
    localparam logic [31:0] PREP_RESULT = 32'h7B10_05AC;

    function automatic string ctrl_state_name(input logic [3:0] s);
        case (s)
            4'd0: return "INIT";    4'd1: return "LOAD_M";  4'd2: return "WAIT_M";
            4'd3: return "LOAD_E";  4'd4: return "WAIT_E";  4'd5: return "LOAD_N";
            4'd6: return "WAIT_N";  4'd7: return "ERROR";   4'd8: return "CASE0";
            4'd9: return "ANALYZE"; 4'd10: return "DONE";   4'd11: return "CASE1";
            4'd12: return "CASE2";  4'd13: return "START";
            default: return "X";
        endcase
    endfunction

endpackage : rsa_cf_pkg


module tb_rsa_core_fault;
    import rsa_cf_pkg::*;

    parameter realtime CLOCK_PERIOD_NS = 10.0;
    localparam int OP_TIMEOUT    = 200000;
    localparam int SHORT_TIMEOUT = 20000;
    localparam int OBSERVE       = 24;

    logic clk = 1'b0;
    always #(CLOCK_PERIOD_NS / 2) clk = ~clk;
    int cyc = 0;
    always @(posedge clk) cyc++;

    int pass_cnt [N_IDS];
    int fail_cnt [N_IDS];
    string fail_log = "";
    int seed = 1;
    int n_random = 12;
    int rand_exp_max = 48;

    // ------------------------------------------------------------------
    // DUT: rsa_core completo
    // ------------------------------------------------------------------
    logic        rst = 1'b1, load = 1'b0;
    logic [31:0] din = '0;
    wire         done, err;
    wire  [31:0] dout;
    bit          op_active = 1'b0;

    rsa_core #(.DATA_WIDTH(32), .RESET(1'b1), .LOAD(1'b1)) dut (
        .core_clk(clk), .core_rst(rst), .core_load(load), .core_din(din),
        .core_done(done), .core_err(err), .core_dout(dout)
    );

    // ------------------------------------------------------------------
    // Unitários: rsa_core_mult e rsa_core_mod isolados
    // ------------------------------------------------------------------
    logic        um_rst = 1'b1, um_start = 1'b0;
    logic [31:0] um_a = '0, um_b = '0;
    wire         um_done;
    wire  [63:0] um_c;
    rsa_core_mult #(.DATA_WIDTH(32), .RESET(1'b1), .START(1'b1)) u_mult (
        .mult_clk(clk), .mult_rst(um_rst), .mult_start(um_start),
        .mult_a(um_a), .mult_b(um_b), .mult_done(um_done), .mult_c(um_c)
    );

    logic        ud_rst = 1'b1, ud_start = 1'b0;
    logic [63:0] ud_a = '0;
    logic [31:0] ud_b = '0;
    wire         ud_done, ud_err;
    wire  [31:0] ud_c;
    rsa_core_mod #(.DATA_WIDTH(32), .RESET(1'b1), .START(1'b1)) u_mod (
        .mod_clk(clk), .mod_rst(ud_rst), .mod_start(ud_start),
        .mod_a(ud_a), .mod_b(ud_b), .mod_done(ud_done), .mod_err(ud_err), .mod_c(ud_c)
    );

    // ------------------------------------------------------------------
    // Monitor da interface core_* (amostra na subida, antes dos NBAs)
    // ------------------------------------------------------------------
    int n_done_rise, n_err_rise, n_both, n_dout_err;
    int max_done_w, max_err_w, cur_done_w, cur_err_w;
    bit done_q = 1'b0, err_q = 1'b0;
    logic [31:0] dout_q = '0;

    always @(posedge clk) begin
        if (rst !== 1'b0) begin
            if (cur_done_w > max_done_w) max_done_w = cur_done_w;
            if (cur_err_w  > max_err_w)  max_err_w  = cur_err_w;
            cur_done_w = 0; cur_err_w = 0; done_q = 1'b0; err_q = 1'b0;
        end else begin
            if (done === 1'b1) begin
                if (!done_q) n_done_rise++;
                cur_done_w++;
            end else begin
                if (cur_done_w > max_done_w) max_done_w = cur_done_w;
                cur_done_w = 0;
            end
            if (err === 1'b1) begin
                if (!err_q) n_err_rise++;
                cur_err_w++;
            end else begin
                if (cur_err_w > max_err_w) max_err_w = cur_err_w;
                cur_err_w = 0;
            end
            if (done === 1'b1 && err === 1'b1) n_both++;
            if (err === 1'b1 && dout !== dout_q) n_dout_err++;
            done_q = (done === 1'b1);
            err_q  = (err === 1'b1);
        end
        dout_q = dout;
    end

    function automatic int done_width();
        return (cur_done_w > max_done_w) ? cur_done_w : max_done_w;
    endfunction
    function automatic int err_width();
        return (cur_err_w > max_err_w) ? cur_err_w : max_err_w;
    endfunction
    task automatic mon_clear();
        n_done_rise = 0; n_err_rise = 0; n_both = 0; n_dout_err = 0;
        max_done_w = 0; max_err_w = 0; cur_done_w = 0; cur_err_w = 0;
    endtask
    task automatic mon_show(input string tag);
        $display("        [MON] %s: done subidas=%0d largura=%0d | err subidas=%0d largura=%0d%s | done&err=%0d ciclo(s) | dout mudou com err=%0d | mult_start=%0d",
                 tag, n_done_rise, done_width(), n_err_rise, err_width(),
                 (cur_err_w > 0) ? " (ainda alto)" : "", n_both, n_dout_err, n_mult_start);
    endtask

    // ------------------------------------------------------------------
    // Scoreboards internos: cada transação mult e mod dentro do dut
    // ------------------------------------------------------------------
    wire        i_mult_start = dut.rsa_core_mult_blk.mult_start;
    wire [31:0] i_mult_a     = dut.rsa_core_mult_blk.mult_a;
    wire [31:0] i_mult_b     = dut.rsa_core_mult_blk.mult_b;
    wire        i_mult_done  = dut.rsa_core_mult_blk.mult_done;
    wire [63:0] i_mult_c     = dut.rsa_core_mult_blk.mult_c;
    wire        i_mod_start  = dut.rsa_core_mod_blk.mod_start;
    wire [63:0] i_mod_a      = dut.rsa_core_mod_blk.mod_a;
    wire [31:0] i_mod_b      = dut.rsa_core_mod_blk.mod_b;
    wire        i_mod_done   = dut.rsa_core_mod_blk.mod_done;
    wire        i_mod_err    = dut.rsa_core_mod_blk.mod_err;
    wire [31:0] i_mod_c      = dut.rsa_core_mod_blk.mod_c;
    wire [3:0]  i_ctrl_state = dut.rsa_core_ctrl_blk.state_reg;

    logic [31:0] sb_mult_a, sb_mult_b;
    logic [63:0] sb_mod_a;
    logic [31:0] sb_mod_b;
    int  n_mult_start = 0;
    int  sub_reported = 0;
    bit  sub_bad_first_seen = 1'b0;

    always @(posedge clk) begin
        if (rst === 1'b0) begin
            if (i_mult_start === 1'b1) begin
                sb_mult_a = i_mult_a; sb_mult_b = i_mult_b; n_mult_start++;
            end
            if (i_mult_done === 1'b1) begin
                if (i_mult_c === {32'b0, sb_mult_a} * {32'b0, sb_mult_b}) pass_cnt[ID_SUB_MULT]++;
                else sub_fail(ID_SUB_MULT, $sformatf("mult %08h*%08h = %016h, esperado %016h",
                              sb_mult_a, sb_mult_b, i_mult_c, {32'b0, sb_mult_a} * {32'b0, sb_mult_b}));
            end
            if (i_mod_start === 1'b1) begin
                sb_mod_a = i_mod_a; sb_mod_b = i_mod_b;
            end
            if (i_mod_done === 1'b1 && i_mod_err !== 1'b1 && sb_mod_b != 0) begin
                if (i_mod_c === 32'(sb_mod_a % {32'b0, sb_mod_b})) pass_cnt[ID_SUB_MOD]++;
                else sub_fail(ID_SUB_MOD, $sformatf("mod %016h %% %08h = %08h, esperado %08h",
                              sb_mod_a, sb_mod_b, i_mod_c, 32'(sb_mod_a % {32'b0, sb_mod_b})));
            end
        end
    end

    // Falha interna: conta sempre; imprime só as primeiras para não inundar o log.
    task automatic sub_fail(input int id, input string what);
        fail_cnt[id]++;
        if (sub_reported < 6) begin
            sub_reported++;
            fail_log = {fail_log, "  ", $sformatf("[%s] t=%0t %s", id_name(id), $realtime, what), "\n"};
            $display("  [%-9s] FAIL  t=%0t %s", id_name(id), $realtime, what);
        end
    endtask

    // ------------------------------------------------------------------
    // Rastreio do caminho de estados de rsa_core_ctrl
    // ------------------------------------------------------------------
    bit    trace_on = 1'b0;
    string trace_path = "";
    logic [3:0] trace_prev = 4'hF;
    int    trace_iter = 0;
    // O laço ANALYZE/START é resumido por contagem. Os flags são anotados ao
    // sair de ERROR/DONE, quando já refletem as atribuições daquele estado.
    always @(posedge clk) begin
        if (trace_on && i_ctrl_state !== trace_prev) begin
            if (trace_prev === 4'd7 || trace_prev === 4'd10)
                trace_path = {trace_path, $sformatf("[done_ff=%b err_ff=%b]",
                              dut.rsa_core_ctrl_blk.done_ff, dut.rsa_core_ctrl_blk.err_ff)};
            if (i_ctrl_state === 4'd13) trace_iter++;
            if (i_ctrl_state !== 4'd9 && i_ctrl_state !== 4'd13) begin
                if (trace_iter > 0) begin
                    trace_path = {trace_path, $sformatf(" > (ANALYZE/START x%0d)", trace_iter)};
                    trace_iter = 0;
                end
                trace_path = {trace_path, (trace_path == "") ? "" : " > ", ctrl_state_name(i_ctrl_state)};
            end
        end
        trace_prev = i_ctrl_state;
    end
    task automatic trace_start();
        trace_path = ""; trace_prev = 4'hF; trace_iter = 0; trace_on = 1'b1;
    endtask
    task automatic trace_stop(input string tag);
        trace_on = 1'b0;
        $display("        [FSM] %s: %s", tag, trace_path);
    endtask

    // ------------------------------------------------------------------
    // Verificação
    // ------------------------------------------------------------------
    task automatic chk(input int id, input bit ok, input string what);
        if (ok) pass_cnt[id]++;
        else begin
            fail_cnt[id]++;
            fail_log = {fail_log, "  ", $sformatf("[%s] t=%0t %s", id_name(id), $realtime, what), "\n"};
        end
        $display("  [%-9s] %s  %s", id_name(id), ok ? "PASS" : "FAIL", what);
    endtask

    task automatic obs(input string what);
        $display("        [OBS] %s", what);
    endtask

    // ------------------------------------------------------------------
    // Driver do núcleo
    // ------------------------------------------------------------------
    task automatic core_reset(input int cycles = 3);
        @(negedge clk);
        rst = 1'b1; load = 1'b0; din = '0;
        repeat (cycles) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);   // INIT -> LOAD_M
    endtask

    task automatic drive_operands(input logic [31:0] m, e, n, input int gap);
        logic [31:0] ops [3];
        ops[0] = m; ops[1] = e; ops[2] = n;
        for (int k = 0; k < 3; k++) begin
            @(negedge clk);
            load = 1'b1; din = ops[k];
            if (gap > 0 || k == 2) begin
                @(negedge clk);
                load = 1'b0; din = '0;
                if (gap > 1) repeat (gap - 1) @(negedge clk);
            end
        end
    endtask

    task automatic core_op(
        input  logic [31:0] m, e, n,
        input  int          gap,
        input  int          timeout,
        input  bit          wait_done_only,
        output bit          got_done,
        output bit          got_err,
        output bit          err_at_start,
        output int          latency,
        output logic [31:0] result
    );
        int t0;
        bit stop;
        mon_clear();
        n_mult_start = 0;
        op_active = 1'b1;
        err_at_start = (err === 1'b1);
        drive_operands(m, e, n, gap);
        t0 = cyc;
        got_done = 1'b0; got_err = 1'b0; stop = 1'b0;
        while (!stop && (cyc - t0) < timeout) begin
            @(posedge clk);
            if (done === 1'b1) got_done = 1'b1;
            if (err === 1'b1)  got_err  = 1'b1;
            stop = got_done || (got_err && !wait_done_only);
        end
        latency = cyc - t0;
        #1;
        result = dout;
        repeat (OBSERVE) @(posedge clk);
        op_active = 1'b0;
        #1;
    endtask

    task automatic valid_op(input int id, input string label, input logic [31:0] m, e, n, input int gap = 1);
        bit gd, ge, es;
        int lat;
        logic [31:0] r, x;
        x = modexp_sqm(m, e, n);
        core_op(m, e, n, gap, OP_TIMEOUT, 1'b0, gd, ge, es, lat, r);
        chk(id, gd && r === x,
            $sformatf("%s: M=0x%08h e=%0d n=0x%08h -> 0x%08h esperado 0x%08h (%0d ciclos%s)",
                      label, m, e, n, r, x, lat, gd ? "" : ", sem core_done"));
        if (gd) chk(ID_DONE_W, done_width() == 1, $sformatf("%s: core_done com %0d ciclo(s)", label, done_width()));
        chk(ID_NO_ERR, n_err_rise == 0, $sformatf("%s: core_error subiu %0d vez(es)", label, n_err_rise));
    endtask

    // ------------------------------------------------------------------
    // Drivers unitários
    // ------------------------------------------------------------------
    task automatic mult_unit(input logic [31:0] a, b, output bit ok_done, output logic [63:0] c);
        int t0;
        @(negedge clk);
        um_a = a; um_b = b; um_start = 1'b1;
        @(negedge clk);
        um_start = 1'b0;
        t0 = cyc; ok_done = 1'b0;
        while (!ok_done && (cyc - t0) < 500) begin
            @(posedge clk);
            if (um_done === 1'b1) ok_done = 1'b1;
        end
        #1; c = um_c;
        @(negedge clk);
    endtask

    task automatic mod_unit(input logic [63:0] a, input logic [31:0] b,
                            output bit got_done, output bit got_err, output logic [31:0] c,
                            output int both_cycles, output int err_cycles);
        int t0;
        @(negedge clk);
        ud_a = a; ud_b = b; ud_start = 1'b1;
        @(negedge clk);
        ud_start = 1'b0;
        t0 = cyc; got_done = 1'b0; got_err = 1'b0; both_cycles = 0; err_cycles = 0;
        while (!(got_done || got_err) && (cyc - t0) < 1000) begin
            @(posedge clk);
            if (ud_done === 1'b1) got_done = 1'b1;
            if (ud_err === 1'b1)  got_err  = 1'b1;
            if (ud_done === 1'b1 && ud_err === 1'b1) both_cycles++;
        end
        #1; c = ud_c;
        repeat (16) begin
            @(posedge clk);
            if (ud_err === 1'b1) err_cycles++;
        end
        @(negedge clk);
    endtask

    // ------------------------------------------------------------------
    // Cenários
    // ------------------------------------------------------------------
    task automatic t0_self_test();
        logic [31:0] m, e, n;
        int s, mism;
        $display("\n[T0] Autoverificacao dos modelos de referencia");
        chk(ID_TB_REF, modexp_sqm(65, 17, 3233) == 2790, "65^17 mod 3233 = 2790");
        chk(ID_TB_REF, modexp_sqm(4, 13, 497) == 445, "4^13 mod 497 = 445");
        chk(ID_TB_REF, modexp_sqm(32'h0F1C_3861, 9, 32'hC7C6_4DFB) == PREP_RESULT, "0x0F1C3861^9 mod 0xC7C64DFB = 0x7B1005AC (README)");
        chk(ID_TB_REF, modexp_sqm(32'h181D_60BF, 0, 32'hC206_5569) == 1, "EXP=0 -> 1 (README)");
        chk(ID_TB_REF, modexp_sqm(32'hFFFF_FFFF, 2, 7) == 2, "(2^32-1)^2 mod 7 = 2 (2^32 = 4 mod 7)");
        s = 7; mism = 0;
        for (int i = 0; i < 400; i++) begin
            m = $random(s); n = $random(s);
            if (i % 2) n = n & 32'hFF;
            if (n == 0) n = 1;
            e = $unsigned($random(s)) % 80;
            if (modexp_sqm(m, e, n) !== modexp_naive(m, e, n)) mism++;
        end
        chk(ID_TB_REF, mism == 0, $sformatf("square-and-multiply = multiplicacao repetida em 400 vetores (divergencias=%0d)", mism));
    endtask

    task automatic t1_valid();
        logic [31:0] m, e, n;
        string label;
        $display("\n[T1] Operacoes validas: vetores fixos e %0d aleatorios (seed=%0d, e<=%0d)", n_random, seed, rand_exp_max);
        core_reset();
        for (int i = 0; i < N_FIXED; i++) begin
            fixed_vec(i, m, e, n, label);
            valid_op(ID_RESULT, label, m, e, n);
        end
        for (int i = 0; i < n_random; i++) begin
            m = $random(seed);
            n = $random(seed);
            case (i % 3)
                1: n = n & 32'h0000_FFFF;
                2: n = n & 32'h0000_00FF;
                default: ;
            endcase
            if (n == 0) n = 32'd3;
            e = $unsigned($random(seed)) % (rand_exp_max + 1);
            valid_op(ID_RESULT, $sformatf("aleatorio %0d (n de %0d bits)", i, $clog2(n + 1)), m, e, n);
        end
    endtask

    task automatic t2_bigm();
        logic [31:0] m, e, n;
        string label;
        $display("\n[T2] M muito maior que n (dominio 4.1: 0 <= M, e, n <= 2^32-1)");
        for (int i = 0; i < N_BIGM; i++) begin
            bigm_vec(i, m, e, n, label);
            valid_op(ID_RES_BIGM, label, m, e, n);
        end
    endtask

    task automatic t3_mod_zero();
        bit gd, ge, es;
        int lat;
        logic [31:0] m, e, n, r, dout_before;
        string label;
        $display("\n[T3] n=0 logo apos uma operacao valida (vetor do caso UVM 10)");
        fixed_vec(1, m, e, n, label);
        valid_op(ID_RESULT, label, m, e, n);
        dout_before = dout;
        trace_start();
        core_op(MZ_MSG, MZ_EXP, 32'd0, 1, OP_TIMEOUT, 1'b0, gd, ge, es, lat, r);
        trace_stop("n=0");
        mon_show("n=0");
        chk(ID_ERR_ON, ge, $sformatf("core_error subiu %0d ciclos apos a carga de n", lat));
        chk(ID_ERR_EXCL, n_done_rise == 0,
            $sformatf("core_done subiu %0d vez(es); %0d ciclo(s) com core_done e core_error juntos", n_done_rise, n_both));
        chk(ID_ERR_W, err_width() == 1,
            $sformatf("core_error com %0d ciclo(s)%s, observado por %0d ciclos", err_width(),
                      (cur_err_w > 0) ? " e ainda alto" : "", OBSERVE));
        obs($sformatf("core_dout antes=0x%08h depois=0x%08h; mult/mod nao foram acionados (mult_start=%0d)",
                      dout_before, dout, n_mult_start));

        $display("\n[T3b] n=0 com EXP=0 e com M=0 (prioridade do teste de n)");
        core_op(32'd5, 32'd0, 32'd0, 1, OP_TIMEOUT, 1'b0, gd, ge, es, lat, r);
        chk(ID_ERR_ON, ge, "M=5, e=0, n=0 sinaliza erro");
        chk(ID_ERR_EXCL, n_done_rise == 0, $sformatf("M=5, e=0, n=0: core_done subiu %0d vez(es)", n_done_rise));
        core_op(32'd0, 32'd3, 32'd0, 1, OP_TIMEOUT, 1'b0, gd, ge, es, lat, r);
        chk(ID_ERR_ON, ge, "M=0, e=3, n=0 sinaliza erro");
        chk(ID_ERR_EXCL, n_done_rise == 0, $sformatf("M=0, e=3, n=0: core_done subiu %0d vez(es)", n_done_rise));
    endtask

    task automatic t4_persistence();
        bit gd, ge, es;
        int lat, high;
        logic [31:0] r, m, e, n;
        string label;
        $display("\n[T4] Persistencia de core_error e operacao seguinte, sem core_rst");
        high = 0;
        repeat (200) begin
            @(posedge clk);
            if (err === 1'b1) high++;
        end
        obs($sformatf("core_error alto em %0d de 200 ciclos ociosos apos o erro", high));
        fixed_vec(0, m, e, n, label);
        trace_start();
        core_op(m, e, n, 1, OP_TIMEOUT, 1'b1, gd, ge, es, lat, r);
        trace_stop("op. apos erro");
        mon_show("op. apos erro");
        chk(ID_RECOV, !es, $sformatf("core_error no inicio da nova operacao = %0d", es));
        chk(ID_RECOV, err_width() == 0,
            $sformatf("core_error alto por %0d ciclos durante a nova operacao", err_width()));
        chk(ID_RESULT, gd && r === modexp_sqm(m, e, n),
            $sformatf("resultado apos erro 0x%08h esperado 0x%08h", r, modexp_sqm(m, e, n)));
        obs($sformatf("core_error depois do DONE = %b (o estado DONE e o unico, alem de INIT, que zera err_ff)", err));
    endtask

    task automatic t5_reset();
        bit gd, ge, es;
        int lat, k, t0, extra_done;
        logic [31:0] r, m, e, n;
        string label;
        $display("\n[T5] core_rst");
        core_reset();
        core_op(MZ_MSG, MZ_EXP, 32'd0, 1, OP_TIMEOUT, 1'b0, gd, ge, es, lat, r);
        // core_rst de um ciclo, como o reset sincronizador/SRST gera (4.5).
        @(negedge clk); rst = 1'b1;
        @(negedge clk); rst = 1'b0;
        k = 0;
        while (err === 1'b1 && k < 20) begin @(negedge clk); k++; end
        chk(ID_RST_ERR, err === 1'b0 && k <= 1,
            $sformatf("core_error caiu %0d ciclo(s) apos soltar core_rst de 1 ciclo", k));
        if (k == 1)
            obs("err_ff so e zerado no estado INIT, um ciclo depois do pulso de core_rst; o pulso de reset sozinho nao o limpa");
        @(negedge clk);

        // Reset no meio de uma operação longa.
        fixed_vec(7, m, e, n, label);
        mon_clear();
        drive_operands(m, e, n, 1);
        repeat (500) @(negedge clk);
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        t0 = cyc; extra_done = 0;
        while ((cyc - t0) < 6000) begin
            @(posedge clk);
            if (done === 1'b1) extra_done++;
        end
        chk(ID_RST_ABORT, extra_done == 0,
            $sformatf("core_done apos reset no meio de %s: %0d (esperado 0)", label, extra_done));
        @(negedge clk);
        fixed_vec(1, m, e, n, label);
        valid_op(ID_RST_ABORT, "operacao apos o aborto", m, e, n);
    endtask

    task automatic t6_load_gap();
        bit gd, ge, es;
        int lat;
        int gaps [4];
        logic [31:0] r, m, e, n, x;
        string label;
        gaps[0] = 0; gaps[1] = 1; gaps[2] = 2; gaps[3] = 7;
        $display("\n[T6] Intervalo entre cargas de M, e, n (datasheet 4.3: cargas consecutivas aceitas)");
        fixed_vec(0, m, e, n, label);
        x = modexp_sqm(m, e, n);
        for (int g = 0; g < 4; g++) begin
            core_reset();
            core_op(m, e, n, gaps[g], SHORT_TIMEOUT, 1'b0, gd, ge, es, lat, r);
            chk(ID_LOAD_GAP, gd && r === x,
                $sformatf("intervalo de %0d ciclo(s): core_done=%0d em %0d ciclos, resultado 0x%08h esperado 0x%08h",
                          gaps[g], gd, lat, r, x));
            if (!gd)
                obs($sformatf("parado em rsa_core_ctrl.%s; WAIT_M/WAIT_E so avancam com core_load=0",
                              ctrl_state_name(i_ctrl_state)));
        end
        core_reset();
    endtask

    task automatic t7_units();
        bit okd, gd, ge;
        int both, errc, bad;
        logic [63:0] c, a, x;
        logic [31:0] b, r;
        $display("\n[T7] Unitarios dos sub-blocos");
        @(negedge clk); um_rst = 1'b1; ud_rst = 1'b1;
        repeat (3) @(negedge clk);
        um_rst = 1'b0; ud_rst = 1'b0;
        repeat (2) @(negedge clk);
        obs($sformatf("rsa_core_mod.mod_err logo apos o reset = %b (mod_err_ff nao e inicializado em INIT)", ud_err));

        bad = 0;
        for (int i = 0; i < 60; i++) begin
            a = $random(seed); b = $random(seed);
            if (i == 0) begin a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF; end
            if (i == 1) begin a = 0; b = 32'hFFFF_FFFF; end
            mult_unit(a[31:0], b, okd, c);
            x = {32'b0, a[31:0]} * {32'b0, b};
            if (!(okd && c === x)) begin
                bad++;
                if (bad <= 3) $display("        mult %08h*%08h = %016h esperado %016h", a[31:0], b, c, x);
            end
        end
        chk(ID_U_MULT, bad == 0, $sformatf("60 produtos de 32x32 bits (divergencias=%0d)", bad));

        bad = 0;
        for (int i = 0; i < 80; i++) begin
            a = {$random(seed), $random(seed)};
            b = $random(seed);
            case (i % 4)
                1: b = b & 32'h0000_FFFF;
                2: b = b & 32'h0000_00FF;
                3: a = a & 64'h0000_0000_FFFF_FFFF;
                default: ;
            endcase
            if (b == 0) b = 3;
            mod_unit(a, b, gd, ge, r, both, errc);
            if (!(gd && !ge && r === 32'(a % {32'b0, b}))) begin
                bad++;
                if (bad <= 4) $display("        mod %016h %% %08h = %08h esperado %08h", a, b, r, 32'(a % {32'b0, b}));
            end
        end
        chk(ID_U_MOD, bad == 0, $sformatf("80 restos de 64 bits por 32 bits, incluindo divisores pequenos (divergencias=%0d)", bad));

        mod_unit(64'h1234, 32'd0, gd, ge, r, both, errc);
        obs($sformatf("rsa_core_mod com b=0: mod_done=%0d mod_err=%0d, %0d ciclo(s) juntos, mod_c=0x%08h, mod_err alto em %0d dos 16 ciclos seguintes",
                      gd, ge, both, r, errc));
        obs("o mesmo padrao do estado ERROR do controle; no rsa_core esse caminho e inalcancavel (n=0 e barrado em WAIT_N) e mod_err fica desconectado");
    endtask

    // ------------------------------------------------------------------
    // Relatório
    // ------------------------------------------------------------------
    function automatic string fmt_res(input int p, input int f);
        if (p + f == 0) return "--";
        if (f > 0) return $sformatf("FAIL %0d/%0d", f, p + f);
        return $sformatf("ok %0d", p);
    endfunction

    task automatic report();
        int total;
        string sep;
        sep = "+-----------+------------------------------------------+---------+-------------+";
        total = 0;
        for (int id = 0; id < N_IDS; id++) total += fail_cnt[id];
        $display("\n\n%s", sep);
        $display("| %-9s | %-40s | %-7s | %-11s |", "ID", "Propriedade do rsa_core", "Datash.", "Resultado");
        $display("%s", sep);
        for (int id = 0; id < N_IDS; id++)
            $display("| %-9s | %-40s | %-7s | %-11s |", id_name(id), id_desc(id), id_spec(id),
                     fmt_res(pass_cnt[id], fail_cnt[id]));
        $display("%s", sep);
        if (total != 0) begin
            $display("\nDivergencias:");
            $write("%s", fail_log);
            $display("\nLocalizacao no RTL:");
`ifdef RSA_V1
            $display("  ERR_EXCL      src/rsa32/v1/rsa_core_32.sv:392-396  ERROR: done_ff<=1 e err_ff<=1 no mesmo flanco; c_reg<=FFFFFFFF.");
            $display("  ERR_W, RECOV  err_ff so e zerado em INIT (:375) e DONE (:409); ERROR segue para LOAD_M com err_ff=1.");
            $display("  RST_ERR       core_rst leva a INIT, que zera err_ff no flanco seguinte (:374-377).");
            $display("  LOAD_GAP      WAIT_M/WAIT_E/WAIT_N (:325-) so avancam com core_load=0.");
`else
            $display("  ERR_EXCL      src/rsa32/v2/rsa32_core_ctrl.sv:168-173  ERROR: done_ff<=1 e err_ff<=1 no mesmo flanco; c_reg<=FFFFFFFF.");
            $display("  ERR_W, RECOV  err_ff so e zerado em INIT (:145) e DONE (:192); ERROR (:112) segue para LOAD_M com err_ff=1.");
            $display("  RST_ERR       core_rst leva a INIT, que zera err_ff no flanco seguinte (:143-147).");
            $display("  LOAD_GAP      WAIT_M/WAIT_E/WAIT_N (:91-110) so avancam com core_load=0.");
`endif
        end
        $display("\nTotal: %0d falha(s) | t=%0t", total, $realtime);
        if (total != 0) $fatal(1, "TEST FAIL: %0d divergencia(s) no rsa_core", total);
        $display("TEST PASS");
    endtask

    initial begin
        $timeformat(-9, 0, " ns", 0);
        for (int id = 0; id < N_IDS; id++) begin pass_cnt[id] = 0; fail_cnt[id] = 0; end
        void'($value$plusargs("SEED=%d", seed));
        void'($value$plusargs("N_RANDOM=%d", n_random));
        void'($value$plusargs("RAND_EXP_MAX=%d", rand_exp_max));
        $display("\n=== tb_rsa_core_fault: rsa_core isolado (sem APB/UVM/SVA) ===");
        t0_self_test();
        t1_valid();
        t2_bigm();
        t3_mod_zero();
        t4_persistence();
        t5_reset();
        t6_load_gap();
        t7_units();
        report();
        $finish;
    end
endmodule : tb_rsa_core_fault
