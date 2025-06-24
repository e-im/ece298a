`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // generate 50MHz clock (20ns period)
  initial begin
    clk = 0;
    forever #10 clk = ~clk;  // toggle every 10ns = 50MHz
  end

  // test stimulus
  initial begin
    // initialize signals
    rst_n = 0;
    ena = 1;
    ui_in = 8'b10000000;  // enable=1, default color mode
    uio_in = 8'b00000000;
    
    // hold reset for a few cycles
    #100;
    rst_n = 1;
    
    // run for enough time to see computation
    #10000;
    
    // test different colour modes
    ui_in = 8'b10001000;  // enable=1, color_mode=1
    #2000;
    
    ui_in = 8'b10010000;  // enable=1, color_mode=2
    #2000;
    
    ui_in = 8'b10011000;  // enable=1, color_mode=3
    #2000;
    
    // test disable
    ui_in = 8'b00000000;  // disable
    #1000;
    
    $display("Simulation completed");
    $finish;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Replace tt_um_example with your module name:
  tt_um_fractal user_project (
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
