`default_nettype none
`timescale 1ns / 1ps

module tb_engine ();
  parameter COORD_WIDTH = 11;
  parameter FRAC_BITS = 8;

  reg clk;
  reg rst_n;
  reg enable;
  reg [9:0] pixel_x;
  reg [9:0] pixel_y;
  reg pixel_valid;
  reg signed [15:0] center_x;
  reg signed [15:0] center_y;
  reg [7:0] zoom_level;
  reg [5:0] max_iter_limit;
  
  wire [5:0] iteration_count;
  wire result_valid;
  wire busy;

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb_engine);
  end


  `ifdef GL_TEST
    mandelbrot_engine dut (
  `else
    mandelbrot_engine #(
      .COORD_WIDTH(COORD_WIDTH),
      .FRAC_BITS(FRAC_BITS)
    ) dut (
  `endif
      .clk(clk),
      .rst_n(rst_n),
      .pixel_x(pixel_x),
      .pixel_y(pixel_y),
      .pixel_valid(pixel_valid),
      .center_x(center_x),
      .center_y(center_y),
      .zoom_level(zoom_level),
      .max_iter_limit(max_iter_limit),
      .enable(enable),
      .iteration_count(iteration_count),
      .result_valid(result_valid),
      .busy(busy)
    );


endmodule
