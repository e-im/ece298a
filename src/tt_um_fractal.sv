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

    // simple unit test wrapper for Mandelbrot engine
    // input pin mapping 
    wire enable = ui_in[7];
    wire [1:0] colour_mode = ui_in[4:3];
    wire max_iter_sel = ui_in[5];
    
    // fixed test pixel coordinates - testing center of screen
    wire [9:0] pixel_x = 10'd320;  // center X
    wire [9:0] pixel_y = 10'd240;  // center Y
    wire pixel_valid = enable;     // start computation when enabled
    
    // fixed parameters for testing
    wire signed [15:0] center_x = 16'hF800;  // -0.5 in Q4.12 format
    wire signed [15:0] center_y = 16'h0000;  // 0.0 in Q4.12 format
    wire [7:0] zoom_level = 8'd0;            // Default zoom level
    
    // engine outputs
    wire [5:0] iteration_count;
    wire result_valid;
    wire busy;
    
    // instantiate Mandelbrot engine with fixed MAX_ITER
    mandelbrot_engine #(
        .COORD_WIDTH(16),
        .FRAC_BITS(12),
        .MAX_ITER(63),  // fixed to maximum for unit testing
        .SCREEN_CENTER_X(320),
        .SCREEN_CENTER_Y(240)
    ) mandelbrot_core (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_valid(pixel_valid),
        .center_x(center_x),
        .center_y(center_y),
        .zoom_level(zoom_level),
        .enable(enable),
        .iteration_count(iteration_count),
        .result_valid(result_valid),
        .busy(busy)
    );
    
    // colour mapper
    wire in_set = (iteration_count == 63);  // fixed max iterations for unit test
    wire [1:0] red, green, blue;
    
    mandelbrot_colour_mapper colour_mapper (
        .iteration_count(iteration_count),
        .colour_mode(colour_mode),
        .in_set(in_set),
        .red(red),
        .green(green),
        .blue(blue)
    );
    
    // output assignments - VGA-style pinout
    assign uo_out = {
        1'b1,           // hsync (always high for testing)
        blue[0],        // vga_b0
        green[0],       // vga_g0
        red[0],         // vga_r0
        1'b1,           // vsync (always high for testing)
        blue[1],        // vga_b1
        green[1],       // vga_g1
        red[1]          // vga_r1
    };
    
    // Bidirectional pins not used in unit test
    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;

endmodule 