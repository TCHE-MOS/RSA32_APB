`timescale 1ns / 1ns

module rsa_core_tb;

  // ---------------------------------------------------------------------------
  // PARAMETERS
  // ---------------------------------------------------------------------------
  localparam time CLK_PERIOD = 20ns;
  localparam bit  RESET      = 1'b1;
  localparam bit  LOAD       = 1'b1;

  // ---------------------------------------------------------------------------
  // SIGNAL DECLARATIONS
  // 32-bit version of the RSA core testbench.
  // ---------------------------------------------------------------------------
  logic       core_clk;
  logic       core_rst;
  logic       core_load;
  logic [31:0] core_din;

  logic [31:0] message;
  logic [31:0] encryption_key;
  logic [31:0] modulus;

  logic       core_done;
  logic       core_err;
  logic [31:0] core_dout;

  int         test_num;
  int         passed_count;
  int         failed_count;

  // ---------------------------------------------------------------------------
  // DUV INSTANTIATION
  // ---------------------------------------------------------------------------
  rsa_core #(
      .DATA_WIDTH(32),
      .RESET     (RESET),
      .LOAD      (LOAD)
  ) duv (
      .core_clk (core_clk),
      .core_rst (core_rst),
      .core_load(core_load),
      .core_din (core_din),
      .core_done(core_done),
      .core_err (core_err),
      .core_dout(core_dout)
  );

  // ---------------------------------------------------------------------------
  // SIMULATION DATA
  // ---------------------------------------------------------------------------
  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, rsa_core_tb);
  end

  // ---------------------------------------------------------------------------
  // CLOCK GENERATION
  // ---------------------------------------------------------------------------
  initial begin
    core_clk = 1'b0;
    forever #(CLK_PERIOD / 2) core_clk = ~core_clk;
  end

  // ---------------------------------------------------------------------------
  // RESET GENERATION
  // ---------------------------------------------------------------------------
  initial begin
    core_rst = ~RESET;
    #(5 * CLK_PERIOD);
    core_rst = RESET;
    #(2 * CLK_PERIOD);
    core_rst = ~RESET;
  end

  // ---------------------------------------------------------------------------
  // LOAD ONE 32-BIT VALUE INTO THE RSA CORE
  // ---------------------------------------------------------------------------
  task automatic load_value(input logic [31:0] value);
    core_load = LOAD;
    core_din  = value;

    #CLK_PERIOD;

    core_load = ~LOAD;
    core_din  = 32'd0;

    #(1 * CLK_PERIOD);
  endtask

  // ---------------------------------------------------------------------------
  // RUN ONE RSA TEST
  // ---------------------------------------------------------------------------

  function automatic logic [31:0] rsa_reference(
      input logic [31:0] m,
      input logic [31:0] e,
      input logic [31:0] n
  );
      logic [63:0] base;
      logic [63:0] result;
      logic [31:0] exponent;

      if (n == 0)
          return 32'hFFFFFFFF;

      result   = 1;
      base     = m % n;
      exponent = e;

      while (exponent != 0) begin
          if (exponent[0])
              result = (result * base) % n;

          base = (base * base) % n;
          exponent = exponent >> 1;
      end

      return result[31:0];
  endfunction


  task automatic run_test(
      input logic [31:0] test_message,
      input logic [31:0] test_key,
      input logic [31:0] test_modulus
    );  

    logic [31:0] expected;
    int timeout_count;

    expected = rsa_reference(
    test_message,
    test_key,
    test_modulus
    );

    message        = test_message;
    encryption_key = test_key;
    modulus        = test_modulus;

    

    // Ensure the previous operation has completed.
    wait (core_done == 1'b0);

    // Apply the three input words.
    load_value(message);
    load_value(encryption_key);
    load_value(modulus);

    // Wait for the RSA core to complete.
    timeout_count = 0;
    while ((core_done !== 1'b1) && (timeout_count < 25000)) begin
      @(posedge core_clk);
      timeout_count++;
    end

    test_num++;

    if (core_done !== 1'b1) begin
      failed_count++;
      $display(
          "Test %2d: %2d ^ %2d mod(%2d) = TIMEOUT  Expected=%2d  [FAILED]",
          test_num, message, encryption_key, modulus, expected
      );
    end else if (core_dout === expected) begin
      passed_count++;
      $display(
          "Test %2d: %2d ^ %2d mod(%2d) = %2d       Expected=%2d  [PASSED]",
          test_num, message, encryption_key, modulus, core_dout, expected
      );
    end else begin
      failed_count++;
      $display(
          "Test %2d: %2d ^ %2d mod(%2d) = %2d       Expected=%2d  [FAILED]",
          test_num, message, encryption_key, modulus, core_dout, expected
      );
    end

    // Wait until DONE is deasserted before the next test.
    if (core_done === 1'b1) begin
      wait (core_done == 1'b0);
    end

    #(10 * CLK_PERIOD + CLK_PERIOD/2);
  endtask


  // ---------------------------------------------------------------------------
  // HARDCODED STIMULUS AND CONSOLE OUTPUT
  // ---------------------------------------------------------------------------
  initial begin
    core_load      = ~LOAD;
    core_din       = 32'd0;
    message        = 32'd0;
    encryption_key = 32'd0;
    modulus        = 32'd0;

    test_num       = 0;
    passed_count   = 0;
    failed_count   = 0;

    $display("-------------------------------------------------------------------------------");
    $display("RSA Core - 32-bit Hardcoded Testbench");
    $display("-------------------------------------------------------------------------------");
    $display("          M ^  e mod( n) =  C       Expected");
    $display("-------------------------------------------------------------------------------");

    // Wait until the reset sequence has completed.
    #(8 * CLK_PERIOD);

    // Test vectors
    run_test(32'd4,       32'd2,       32'd11);
    run_test(32'd2,       32'd3,       32'd5);
    run_test(32'd3,       32'd2,       32'd7);
    run_test(32'd5,       32'd3,       32'd13);
    run_test(32'd7,       32'd2,       32'd11);
    run_test(32'd10,      32'd2,       32'd13);
    run_test(32'd6,       32'd3,       32'd17);
    run_test(32'd8,       32'd2,       32'd15);
    run_test(32'd9,       32'd3,       32'd17);
    run_test(32'd12,      32'd2,       32'd19);

    run_test(32'd2,       32'd5,       32'd13);
    run_test(32'd3,       32'd4,       32'd11);
    run_test(32'd4,       32'd5,       32'd17);
    run_test(32'd5,       32'd4,       32'd23);
    run_test(32'd7,       32'd3,       32'd19);
    run_test(32'd11,      32'd3,       32'd23);
    run_test(32'd13,      32'd2,       32'd29);
    run_test(32'd14,      32'd3,       32'd31);
    run_test(32'd15,      32'd4,       32'd37);
    run_test(32'd16,      32'd3,       32'd41);

    run_test(32'd0,       32'd5,       32'd17);
    run_test(32'd1,       32'd100,     32'd17);
    run_test(32'd5,       32'd0,       32'd13);
    run_test(32'd13,      32'd2,       32'd13);
    run_test(32'd14,      32'd2,       32'd13);
    run_test(32'd25,      32'd3,       32'd13);
    run_test(32'd100,     32'd2,       32'd17);
    run_test(32'd50,      32'd3,       32'd23);
    run_test(32'd99,      32'd2,       32'd31);
    run_test(32'd123,     32'd3,       32'd17);

    run_test(32'd1234,    32'd5,       32'd97);
    run_test(32'd5678,    32'd3,       32'd101);
    run_test(32'd12345,   32'd2,       32'd257);
    run_test(32'd9999,    32'd3,       32'd251);
    run_test(32'd54321,   32'd4,       32'd997);
    run_test(32'd65535,   32'd3,       32'd65521);

    run_test(32'd255,     32'd17,      32'd257);
    run_test(32'd1024,    32'd10,      32'd1009);
    run_test(32'd65536,   32'd2,       32'd65537);
    run_test(32'd123456,  32'd3,       32'd10007);


    $display("-------------------------------------------------------------------------------");
    $display("Tests executed : %0d", test_num);
    $display("Passed         : %0d", passed_count);
    $display("Failed         : %0d", failed_count);
    $display("-------------------------------------------------------------------------------");
    $display("End of Simulation");

    #CLK_PERIOD;
    $finish;
  end

endmodule
