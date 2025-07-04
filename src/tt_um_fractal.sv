/*
 * Copyright (c) 2024 ECE298A Team
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_fractal (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    logic clk_25mhz;
    logic clk_div;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) clk_div <= 1'b0;
        else clk_div <= ~clk_div;
    end
    assign clk_25mhz = clk_div;

    logic vga_active; // active high when visible
    logic vga_hsync, vga_vsync; // sync pulses
    logic v_begin; //new frame
    logic [9:0] pixel_x, pixel_y;

    logic signed [15:0] centre_x, centre_y;
    logic [7:0] zoom_level;
    logic [5:0] max_iter_limit;

    logic [5:0] iteration_count;
    logic result_valid;
    logic engine_busy;

    logic [1:0] red, green, blue;
    reg [1:0] current_colour_mode; // latched colour mode


    logic vga_advance;
    assign vga_advance = result_valid || !vga_active; // computation finished, or in blanking period

    vga vga_timing (
        .clk(clk_25mhz),
        .rst_n(rst_n),
        .clk_en(vga_advance),
        .active(vga_active),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .hpos(pixel_x),
        .vpos(pixel_y),
        .v_begin(v_begin)
    );

    param_controller #(
        .COORD_WIDTH(16),
        .ZOOM_WIDTH(8),
        .ITER_WIDTH(6)
    ) param_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .v_begin(v_begin),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .centre_x(centre_x),
        .centre_y(centre_y),
        .zoom_level(zoom_level),
        .max_iter_limit(max_iter_limit)
    );

    mandelbrot_engine #(
        .COORD_WIDTH(16),
        .FRAC_BITS(12),
        .SCREEN_CENTER_X(320),
        .SCREEN_CENTER_Y(240)
    ) mandelbrot_core (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_valid(vga_active),
        .center_x(centre_x),
        .center_y(centre_y),
        .zoom_level(zoom_level),
        .max_iter_limit(max_iter_limit),
        .enable(ui_in[7]),
        .iteration_count(iteration_count),
        .result_valid(result_valid),
        .busy(engine_busy)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_colour_mode <= 2'b00;
        end else if (v_begin) begin
            current_colour_mode <= ui_in[4:3];
        end
    end

    wire in_set = (iteration_count >= max_iter_limit);
    mandelbrot_colour_mapper colour_mapper (
        .iteration_count(iteration_count),
        .colour_mode(current_colour_mode),
        .in_set(in_set),
        .red(red),
        .green(green),
        .blue(blue)
    );

    assign uo_out[7] = vga_hsync;
    assign uo_out[6] = vga_active ? blue[0] : 1'b0; // vga_b0
    assign uo_out[5] = vga_active ? green[0] : 1'b0; // vga_g0
    assign uo_out[4] = vga_active ? red[0] : 1'b0; // vga_r0
    assign uo_out[3] = vga_vsync;
    assign uo_out[2] = vga_active ? blue[1] : 1'b0; // vga_b1
    assign uo_out[1] = vga_active ? green[1] : 1'b0; // vga_g1
    assign uo_out[0] = vga_active ? red[1] : 1'b0; // vga_r1

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
endmodule
