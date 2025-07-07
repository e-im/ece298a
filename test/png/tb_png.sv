/*
 * Copyright (c) 2024 ECE298A Team
 * SPDX-License-Identifier: Apache-2.0
 *
 * Description: A minimal Verilog testbench wrapper for running cocotb tests
 * on the tt_um_fractal module. This wrapper instantiates the DUT and
 * exposes its I/O ports and necessary internal signals to the simulator's
 * top level, allowing cocotb to drive and monitor them.
 */

`default_nettype none
`timescale 1ns/1ps

module tb_png;
    reg clk;
    reg rst_n;
    reg ena;
    reg [7:0] ui_in;
    reg [7:0] uio_in;

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    wire v_begin;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire vga_active;
    wire clk_25mhz;


    tt_um_fractal dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .clk(clk),
        .rst_n(rst_n)
    );

    assign v_begin    = dut.v_begin;
    assign pixel_x    = dut.pixel_x;
    assign pixel_y    = dut.pixel_y;
    assign vga_active = dut.vga_active;
    assign clk_25mhz  = dut.clk_25mhz;


    initial begin
        $dumpfile("tb_png.vcd");
        $dumpvars(0, tb_png);
    end

endmodule
