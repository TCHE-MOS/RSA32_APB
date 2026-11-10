`timescale 1ns / 1ns

module rsa_core_tb;

  // ---------------------------------------------------------------------------
  // PARAMETERS
  // ---------------------------------------------------------------------------
  parameter CLK_PERIOD = 20;
  parameter RESET      = 1'b1;
  parameter LOAD       = 1'b1;

  // ---------------------------------------------------------------------------
  // SIGNAL DECLARATIONS
  // 4-bit version of the RSA core testbench.
  // ---------------------------------------------------------------------------
  reg         core_clk;
  reg         core_rst;
  reg         core_load;
  reg  [3:0]  core_din;

  reg  [3:0]  message;
  reg  [3:0]  encryption_key;
  reg  [3:0]  modulus;

  wire        core_done;
  wire        core_err;
  wire [3:0]  core_dout;

  integer test_num;
  integer passed_count;
  integer failed_count;

  // ---------------------------------------------------------------------------
  // DUV INSTANTIATION
  // ---------------------------------------------------------------------------
  rsa_core #(
      .DATA_WIDTH(4),
      .RESET     (RESET),
      .LOAD      (LOAD)
  ) duv (
      .core_clk  (core_clk),
      .core_rst  (core_rst),
      .core_load (core_load),
      .core_din  (core_din),
      .core_done (core_done),
      .core_err  (core_err),
      .core_dout (core_dout)
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
      forever
          #(CLK_PERIOD/2) core_clk = ~core_clk;
  end

  // ---------------------------------------------------------------------------
  // RESET GENERATION
  // ---------------------------------------------------------------------------
  initial begin
      core_rst = ~RESET;
      #(5*CLK_PERIOD);
      core_rst = RESET;
      #(2*CLK_PERIOD);
      core_rst = ~RESET;
  end

  // ---------------------------------------------------------------------------
  // LOAD ONE 4-BIT VALUE INTO THE RSA CORE
  // ---------------------------------------------------------------------------
  task load_value;
      input [3:0] value;
      begin
          core_load = LOAD;
          core_din  = value;

          #CLK_PERIOD;

          core_load = ~LOAD;
          core_din  = 4'd0;

          #(1*CLK_PERIOD);
      end
  endtask

  // ---------------------------------------------------------------------------
  // RUN ONE RSA TEST
  //
  // Input order:
  //   1. message
  //   2. encryption key
  //   3. modulus
  //
  // All values are hardcoded in decimal and are 4 bits wide.
  // The source 8-bit values were converted by discarding bits [7:4]
  // and keeping bits [3:0].
  // ---------------------------------------------------------------------------
  task run_test;
      input [3:0] test_message;
      input [3:0] test_key;
      input [3:0] test_modulus;
      input [3:0] expected;

      integer timeout_count;

      begin
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
              timeout_count = timeout_count + 1;
          end

          test_num = test_num + 1;

          if (core_done !== 1'b1) begin
              failed_count = failed_count + 1;
              $display(
                  "Test %2d: %2d ^ %2d mod(%2d) = TIMEOUT  Expected=%2d  [FAILED]",
                  test_num, message, encryption_key, modulus, expected
              );
          end
          else if (core_dout === expected) begin
              passed_count = passed_count + 1;
              $display(
                  "Test %2d: %2d ^ %2d mod(%2d) = %2d       Expected=%2d  [PASSED]",
                  test_num, message, encryption_key, modulus,
                  core_dout, expected
              );
          end
          else begin
              failed_count = failed_count + 1;
              $display(
                  "Test %2d: %2d ^ %2d mod(%2d) = %2d       Expected=%2d  [FAILED]",
                  test_num, message, encryption_key, modulus,
                  core_dout, expected
              );
          end

          // Wait until DONE is deasserted before the next test.
          if (core_done === 1'b1)
              wait (core_done == 1'b0);

          #(10*CLK_PERIOD);
      end
  endtask

  // ---------------------------------------------------------------------------
  // HARDCODED STIMULUS AND CONSOLE OUTPUT
  // ---------------------------------------------------------------------------
  initial begin
      core_load      = ~LOAD;
      core_din       = 4'd0;
      message        = 4'd0;
      encryption_key = 4'd0;
      modulus        = 4'd0;

      test_num      = 0;
      passed_count  = 0;
      failed_count  = 0;

      $display("-------------------------------------------------------------------------------");
      $display("RSA Core - 4-bit Hardcoded Testbench");
      $display("-------------------------------------------------------------------------------");
      $display("          M ^  e mod( n) =  C       Expected");
      $display("-------------------------------------------------------------------------------");

      // Wait until the reset sequence has completed.
      #(8*CLK_PERIOD);

      // -----------------------------------------------------------------------
      // Test vectors derived from stimulus.txt and checker.txt.
      //
      // The original files contain 8-bit binary values.
      // For this 4-bit testbench, bits [7:4] were discarded and bits [3:0]
      // were retained. The resulting values are written below in decimal.
      // -----------------------------------------------------------------------
      run_test(4'd0 , 4'd0 , 4'd0 , 4'd15);  // Test 01
      run_test(4'd0 , 4'd0 , 4'd1 , 4'd0 );  // Test 02
      run_test(4'd0 , 4'd0 , 4'd2 , 4'd1 );  // Test 03
      run_test(4'd0 , 4'd0 , 4'd15, 4'd1 );  // Test 04
      run_test(4'd0 , 4'd1 , 4'd0 , 4'd15);  // Test 05
      run_test(4'd0 , 4'd2 , 4'd0 , 4'd15);  // Test 06
      run_test(4'd0 , 4'd15, 4'd0 , 4'd15);  // Test 07
      run_test(4'd1 , 4'd0 , 4'd0 , 4'd15);  // Test 08
      run_test(4'd2 , 4'd0 , 4'd0 , 4'd15);  // Test 09
      run_test(4'd15, 4'd0 , 4'd0 , 4'd15);  // Test 10
      run_test(4'd1 , 4'd1 , 4'd1 , 4'd0 );  // Test 11
      run_test(4'd1 , 4'd1 , 4'd2 , 4'd1 );  // Test 12
      run_test(4'd1 , 4'd1 , 4'd15, 4'd1 );  // Test 13
      run_test(4'd1 , 4'd2 , 4'd1 , 4'd0 );  // Test 14
      run_test(4'd1 , 4'd15, 4'd1 , 4'd0 );  // Test 15
      run_test(4'd2 , 4'd1 , 4'd1 , 4'd0 );  // Test 16
      run_test(4'd15, 4'd1 , 4'd1 , 4'd0 );  // Test 17
      run_test(4'd2 , 4'd2 , 4'd2 , 4'd0 );  // Test 18
      run_test(4'd2 , 4'd2 , 4'd3 , 4'd1 );  // Test 19
      run_test(4'd2 , 4'd2 , 4'd15, 4'd4 );  // Test 20
      run_test(4'd2 , 4'd3 , 4'd2 , 4'd0 );  // Test 21
      run_test(4'd2 , 4'd15, 4'd2 , 4'd0 );  // Test 22
      run_test(4'd3 , 4'd2 , 4'd2 , 4'd1 );  // Test 23
      run_test(4'd15, 4'd2 , 4'd2 , 4'd1 );  // Test 24
      run_test(4'd4 , 4'd10, 4'd9 , 4'd4 );  // Test 25
      run_test(4'd11, 4'd1 , 4'd7 , 4'd4 );  // Test 26
      run_test(4'd9 , 4'd4 , 4'd7 , 4'd2 );  // Test 27
      run_test(4'd9 , 4'd9 , 4'd3 , 4'd0 );  // Test 28
      run_test(4'd8 , 4'd10, 4'd1 , 4'd0 );  // Test 29
      run_test(4'd2 , 4'd5 , 4'd3 , 4'd2 );  // Test 30
      run_test(4'd9 , 4'd5 , 4'd3 , 4'd0 );  // Test 31
      run_test(4'd8 , 4'd5 , 4'd3 , 4'd2 );  // Test 32
      run_test(4'd14, 4'd5 , 4'd3 , 4'd2 );  // Test 33
      run_test(4'd2 , 4'd5 , 4'd3 , 4'd2 );  // Test 34
      run_test(4'd12, 4'd5 , 4'd3 , 4'd0 );  // Test 35
      run_test(4'd1 , 4'd5 , 4'd3 , 4'd1 );  // Test 36
      run_test(4'd7 , 4'd5 , 4'd3 , 4'd1 );  // Test 37
      run_test(4'd0 , 4'd5 , 4'd3 , 4'd0 );  // Test 38
      run_test(4'd11, 4'd5 , 4'd3 , 4'd2 );  // Test 39
      run_test(4'd15, 4'd15, 4'd15, 4'd0 );  // Test 40

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
