`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb_vga ();

  // wire up the inputs and outputs
  reg clk;
  reg rst_n;
  reg clk_en;
  wire active;
  wire hsync;
  wire vsync;
  wire v_begin;
  wire [9:0] hpos;
  wire [9:0] vpos;

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb_vga);
    #1;
  end


`ifdef VGA_MODE_LARGE
    parameter int H_ACTIVE      = 640;
    parameter int H_FRONT_PORCH = 16;
    parameter int H_SYNC        = 96;
    parameter int H_BACK_PORCH  = 48;

    parameter int V_ACTIVE      = 480;
    parameter int V_FRONT_PORCH = 10;
    parameter int V_SYNC        = 2;
    parameter int V_BACK_PORCH  = 33;
`else
    parameter int H_ACTIVE      = 8;
    parameter int H_FRONT_PORCH = 2;
    parameter int H_SYNC        = 4;
    parameter int H_BACK_PORCH  = 2;

    parameter int V_ACTIVE      = 6;
    parameter int V_FRONT_PORCH = 1;
    parameter int V_SYNC        = 2;
    parameter int V_BACK_PORCH  = 1;
`endif

    // vga module instantiation
    vga #(
        .H_ACTIVE(H_ACTIVE),
        .H_FRONT_PORCH(H_FRONT_PORCH),
        .H_SYNC(H_SYNC),
        .H_BACK_PORCH(H_BACK_PORCH),
        .V_ACTIVE(V_ACTIVE),
        .V_FRONT_PORCH(V_FRONT_PORCH),
        .V_SYNC(V_SYNC),
        .V_BACK_PORCH(V_BACK_PORCH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .clk_en(clk_en),
        .active(active),
        .hsync(hsync),
        .vsync(vsync),
        .v_begin(v_begin),
        .hpos(hpos),
        .vpos(vpos)
    );

endmodule
