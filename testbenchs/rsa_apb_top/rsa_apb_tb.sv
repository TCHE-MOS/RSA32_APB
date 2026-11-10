// Directed self-checking test of amba_3_apb_rsa_apb_top + rsa_core.
// Plain SystemVerilog (no UVM) so it runs on Verilator / any simulator.
`timescale 1ns/1ps

`ifndef SRST_CYC
 `define SRST_CYC 2
`endif

module tb #(
    // Periodo do PCLK; ajustavel por -defparam tb.CLOCK_PERIOD_NS=<ns>.
    parameter realtime CLOCK_PERIOD_NS = 10.0
);

    logic        pclk = 1'b0;
    logic        presetn = 1'b0;
    logic        psel = 1'b0, penable = 1'b0, pwrite = 1'b0;
    logic [11:0] paddr = '0;
    logic [31:0] pwdata = '0;
    logic [31:0] prdata;
    logic        pready, pslverr, irq;

    // A netlist sintetizada (POST_SYNTHESIS) nao tem parametros.
    amba_3_apb_rsa_apb_top
`ifndef POST_SYNTHESIS
        #(.DATA_WIDTH(32), .ADDR_WIDTH(12),
          .LOAD_GAP(1), .SRST_CYCLES(`SRST_CYC))
`endif
        dut (
        .pclk_i(pclk), .presetn_i(presetn), .psel_i(psel), .penable_i(penable),
        .pwrite_i(pwrite), .paddr_i(paddr), .pwdata_i(pwdata),
        .prdata_o(prdata), .pready_o(pready), .pslverr_o(pslverr), .irq_o(irq));

    always #(CLOCK_PERIOD_NS / 2) pclk = ~pclk;

    localparam [11:0] CTRL=12'h000, STATUS=12'h004, IER=12'h008, MSG=12'h00C,
                      EXP=12'h010, MOD=12'h014, RESULT=12'h018, ID=12'h01C;

    int errors = 0;
    int checks = 0;
    bit bus_open = 1'b0;

    ////////////////////////////////////////////////
    // APB transfer: setup, access, optional hold of PSEL (back-to-back)
    ////////////////////////////////////////////////
    task automatic apb(input bit wr, input [11:0] a, input [31:0] wd,
                       output [31:0] rdv, output bit err, input bit hold = 1'b0);
        if (!bus_open) @(posedge pclk);
        psel <= 1'b1; penable <= 1'b0; pwrite <= wr; paddr <= a;
        if (wr) pwdata <= wd;
        @(posedge pclk);
        penable <= 1'b1;
        @(posedge pclk);
        rdv = prdata;
        err = pslverr;
        if (hold) bus_open = 1'b1;
        else begin psel <= 1'b0; penable <= 1'b0; bus_open = 1'b0; end
    endtask

    task automatic wr(input [11:0] a, input [31:0] d, output bit err, input bit hold = 1'b0);
        logic [31:0] dummy;
        apb(1'b1, a, d, dummy, err, hold);
    endtask

    task automatic rd(input [11:0] a, output [31:0] v, output bit err, input bit hold = 1'b0);
        apb(1'b0, a, 32'h0, v, err, hold);
    endtask

    task automatic check(input string what, input [31:0] got, input [31:0] exp);
        checks++;
        if (got !== exp) begin
            errors++;
            $display("[%0t] FAIL %s: got 0x%08h expected 0x%08h", $time, what, got, exp);
        end
    endtask

    // irq is a registered level: look at it half a cycle after the write edge
    task automatic check_irq(input string what, input bit exp);
        @(negedge pclk);
        check(what, {31'b0, irq}, {31'b0, exp});
    endtask

    task automatic check_err(input string what, input bit got, input bit exp);
        checks++;
        if (got !== exp) begin
            errors++;
            $display("[%0t] FAIL %s: PSLVERR=%0b expected %0b", $time, what, got, exp);
        end
    endtask

    function automatic [31:0] modexp(input [31:0] m, input [31:0] e, input [31:0] n);
        logic [63:0] r, b;
        logic [31:0] x;
        if (n == 0 || n == 1) return 32'h0;
        r = 64'd1; b = m % n; x = e;
        while (x != 0) begin
            if (x[0]) r = (r * b) % n;
            b = (b * b) % n;
            x = x >> 1;
        end
        return r[31:0];
    endfunction

    task automatic do_reset(input int cycles = 10);
        @(negedge pclk);
        presetn = 1'b0;
        repeat (cycles) @(negedge pclk);
        presetn = 1'b1;
    endtask

    // Poll STATUS until BUSY = 0 and DONE or ERROR set
    task automatic wait_done(output [31:0] st, input int max_polls = 40000);
        bit e;
        for (int i = 0; i < max_polls; i++) begin
            rd(STATUS, st, e);
            if (!st[0] && (st[1] || st[2])) return;
        end
        errors++;
        $display("[%0t] FAIL wait_done: timeout, STATUS=0x%08h", $time, st);
    endtask

    task automatic load_ops(input [31:0] m, input [31:0] e, input [31:0] n);
        bit er;
        wr(MSG, m, er); check_err("write MSG", er, 1'b0);
        wr(EXP, e, er); check_err("write EXP", er, 1'b0);
        wr(MOD, n, er); check_err("write MOD", er, 1'b0);
    endtask

    // Full operation with checking. Leaves STATUS flags set.
    task automatic run_op(input [31:0] m, input [31:0] e, input [31:0] n);
        bit er; logic [31:0] st, res;
        load_ops(m, e, n);
        wr(CTRL, 32'h1, er); check_err("write START", er, 1'b0);
        wait_done(st);
        if (n == 0) begin
            check("STATUS after n=0", st, 32'h4);
        end
        else begin
            check("STATUS after op", st, 32'h2);
            rd(RESULT, res, er); check_err("read RESULT", er, 1'b0);
            check($sformatf("RESULT M=%0h e=%0h n=%0h", m, e, n), res, modexp(m, e, n));
        end
    endtask

    ////////////////////////////////////////////////
    // Tests
    ////////////////////////////////////////////////
    logic [31:0] v, st, prev;
    bit er;

    initial begin
        repeat (3) @(posedge pclk);

        // ---- test_reset (plan 1)
        do_reset(10);
        rd(MSG, v, er); check("MSG after reset", v, 0);
        wr(MSG, 32'hFFFF_FFFF, er); check_err("wr MSG", er, 0);
        rd(MSG, v, er); check("MSG readback", v, 32'hFFFF_FFFF);
        do_reset(10);
        rd(MSG, v, er); check("MSG after 2nd reset", v, 0);
        for (int a = 0; a < 8; a++) begin
            rd(a*4, v, er); check($sformatf("reset value @%0h", a*4), v, (a == 7) ? 32'h5253_0200 : 32'h0);
            check_err("read no error", er, 0);
        end

        // ---- test_id (plan 3)
        rd(ID, v, er); check("ID", v, 32'h5253_0200);
        wr(ID, 32'hFFFF_FFFF, er); check_err("write ID", er, 1);
        rd(ID, v, er); check("ID unchanged", v, 32'h5253_0200);

        // ---- read-only RESULT, CTRL reads 0, reserved bits
        wr(RESULT, 32'h1234, er); check_err("write RESULT", er, 1);
        rd(RESULT, v, er); check("RESULT unchanged", v, 0);
        wr(IER, 32'hFFFF_FFFF, er); rd(IER, v, er); check("IER reserved bits", v, 32'h3);
        wr(IER, 0, er);
        wr(CTRL, 32'hFFFF_FFFC, er); check_err("CTRL reserved write", er, 0);
        rd(CTRL, v, er); check("CTRL reads 0", v, 0);

        // ---- test_rsa_operation (plan 4): known vector 7^5 mod 33 = 10
        run_op(32'd7, 32'd5, 32'd33);
        rd(RESULT, v, er); check("known vector", v, 32'd10);
        wr(STATUS, 32'h2, er); rd(STATUS, v, er); check("STATUS after W1C", v, 0);

        // ---- edge exponents and moduli, random operands
        run_op(32'd4, 32'd2, 32'd1);          // n = 1 -> 0
        wr(STATUS, 32'h6, er);
        run_op(32'd9, 32'd0, 32'd13);         // e = 0 -> 1
        wr(STATUS, 32'h6, er);
        run_op(32'd9, 32'd1, 32'd13);         // e = 1
        wr(STATUS, 32'h6, er);
        run_op(32'd9, 32'd2, 32'd13);         // e = 2
        wr(STATUS, 32'h6, er);
        run_op(32'hFFFF_FFFF, 32'd3, 32'hFFFF_FFFB);   // large operands
        wr(STATUS, 32'h6, er);
        for (int i = 0; i < 40; i++) begin
            run_op($urandom, $urandom_range(0, 12), ($urandom % 32'hFFFF_FFF0) + 32'd2);
            wr(STATUS, 32'h6, er);
        end

        // ---- error path: n = 0 keeps RESULT, sets ERROR only
        rd(RESULT, prev, er);
        run_op(32'd5, 32'd3, 32'd0);
        rd(RESULT, v, er); check("RESULT kept on error", v, prev);
        wr(STATUS, 32'h4, er); rd(STATUS, v, er); check("ERROR cleared", v, 0);
        // and a good operation right after the error
        run_op(32'd3, 32'd4, 32'd7);
        wr(STATUS, 32'h6, er);

        // ---- IRQ (level, enables, W1C)
        wr(IER, 32'h1, er);
        check("irq low before op", irq, 0);
        run_op(32'd6, 32'd3, 32'd11);
        check("irq on DONE with DONE_IE", irq, 1);
        wr(STATUS, 32'h2, er); check_irq("irq low after W1C", 0);
        wr(IER, 32'h2, er);
        run_op(32'd6, 32'd3, 32'd11);
        check("no irq on DONE with only ERR_IE", irq, 0);
        wr(STATUS, 32'h2, er);
        run_op(32'd6, 32'd3, 32'd0);
        check("irq on ERROR with ERR_IE", irq, 1);
        wr(IER, 32'h0, er); check_irq("irq masked by IER", 0);
        wr(STATUS, 32'h4, er);

        // ---- PSLVERR while BUSY: operands and START rejected, no effect
        load_ops(32'd2, 32'd10, 32'd1000);
        wr(CTRL, 32'h1, er); check_err("START", er, 0);
        wr(MSG, 32'hDEAD_BEEF, er); check_err("MSG while BUSY", er, 1);
        wr(EXP, 32'hDEAD_BEEF, er); check_err("EXP while BUSY", er, 1);
        wr(MOD, 32'hDEAD_BEEF, er); check_err("MOD while BUSY", er, 1);
        wr(CTRL, 32'h1, er);        check_err("START while BUSY", er, 1);
        rd(STATUS, v, er);          check("BUSY set", v & 32'h1, 32'h1);
        wait_done(st);
        check("STATUS", st, 32'h2);
        rd(MSG, v, er); check("MSG unchanged", v, 2);
        rd(RESULT, v, er); check("RESULT 2^10 mod 1000", v, 32'd24);
        wr(STATUS, 32'h2, er);

        // ---- test_soft_reset (plan 2)
        load_ops(32'd3, 32'h7FFF_FFFF, 32'd1000003);
        wr(CTRL, 32'h1, er);
        rd(STATUS, v, er); check("BUSY before SRST", v, 32'h1);
        wr(CTRL, 32'h2, er); check_err("SRST", er, 0);
        rd(STATUS, v, er); check("STATUS after SRST", v, 0);
        rd(MSG, v, er); check("MSG kept by SRST", v, 3);
        rd(EXP, v, er); check("EXP kept by SRST", v, 32'h7FFF_FFFF);
        rd(MOD, v, er); check("MOD kept by SRST", v, 32'd1000003);
        // operation right after SRST works
        run_op(32'd5, 32'd3, 32'd13);
        wr(STATUS, 32'h6, er);

        // ---- SRST and START in the same write: SRST wins, nothing starts
        load_ops(32'd5, 32'd3, 32'd13);
        wr(CTRL, 32'h3, er); check_err("SRST+START", er, 0);
        repeat (50) @(posedge pclk);
        rd(STATUS, v, er); check("no op after SRST+START", v, 0);

        // ---- SRST at many points of a long operation, then a new operation
        //      straight away (and back-to-back transfers)
        for (int d = 0; d < 300; d += 1) begin
            load_ops(32'd3, 32'h7FFF_FFFF, 32'd1000003);
            wr(CTRL, 32'h1, er);
            repeat (d) @(posedge pclk);
            wr(CTRL, 32'h2, er, 1'b1);          // SRST, PSEL held
            wr(MSG, 32'd8, er, 1'b1);           // back-to-back: operands ...
            wr(EXP, 32'd3, er, 1'b1);
            wr(MOD, 32'd21, er, 1'b1);
            wr(CTRL, 32'h1, er);                // ... and START right behind SRST
            check_err("START after SRST", er, 0);
            wait_done(st);
            check($sformatf("STATUS after SRST at +%0d", d), st, 32'h2);
            rd(RESULT, v, er);
            check($sformatf("RESULT after SRST at +%0d", d), v, modexp(8, 3, 21));
            wr(STATUS, 32'h6, er);
        end

        // ---- reset in the middle of an operation (PRESETn)
        load_ops(32'd3, 32'h7FFF_FFFF, 32'd1000003);
        wr(CTRL, 32'h1, er);
        repeat (40) @(posedge pclk);
        do_reset(10);
        rd(STATUS, v, er); check("STATUS after PRESETn", v, 0);
        rd(MSG, v, er); check("MSG after PRESETn", v, 0);
        run_op(32'd11, 32'd7, 32'd77);

        if (errors == 0) $display("PASS: %0d checks", checks);
        else             $display("FAIL: %0d errors in %0d checks", errors, checks);
        $finish;
    end

    // Global watchdog (100 ms)
    initial begin
        #100_000_000;
        $display("FAIL: watchdog");
        $finish;
    end

endmodule
