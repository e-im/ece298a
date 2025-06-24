/*
 * Copyright (c) 2024 ECE298A Team
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_fractal (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output logic [7:0] uo_out,  // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output logic [7:0] uio_out, // IOs: Output path
    output logic [7:0] uio_oe,  // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // input pin mapping
    // extract control signals from ui_in
    logic zoom_toggle, pan_h, pan_v;
    logic [1:0] colour_mode;
    logic max_iter_sel, reset_view, module_enable;
    
    assign zoom_toggle = ui_in[0];          // active during VSYNC for zoom in/out
    assign pan_h = ui_in[1];                // horizontal pan toggle (active during VSYNC)
    assign pan_v = ui_in[2];                // vertical pan toggle (active during VSYNC) 
    assign colour_mode = ui_in[4:3];         // 4 colour schemes
    assign max_iter_sel = ui_in[5];         // higher detail vs speed
    assign reset_view = ui_in[6];           // reset to default view (center + wide zoom)
    assign module_enable = ui_in[7];        // master enable signal
    
    // extract parameter data from uio_in (bidirectional pins)
    logic [7:0] param_data;
    assign param_data = uio_in[7:0];        // signed pan speed, zoom direction
    
    
    
    logic [5:0] engine_iterations;
    logic engine_result_valid, engine_busy;
    
    // mandelbrot computation engine
    mandelbrot_engine #(
        .COORD_WIDTH(16),
        .FRAC_BITS(12),
        .MAX_ITER(63),
        .SCREEN_CENTER_X(320),
        .SCREEN_CENTER_Y(240)
    ) mandelbrot (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_x(vga_pixel_x),
        .pixel_y(vga_pixel_y),
        .pixel_valid(vga_active),
        .center_x(center_x),
        .center_y(center_y),
        .zoom_level(zoom_level),
        .enable(module_enable),
        .iteration_count(engine_iterations),
        .result_valid(engine_result_valid),
        .busy(engine_busy)
    );

    // colour mapping
    logic in_set;
    logic [1:0] red, green, blue;
    
    assign in_set = (engine_iterations >= max_iterations); // in set if max iterations reached
    
    mandelbrot_colour_mapper colour_mapper (
        .iteration_count(engine_iterations),
        .colour_mode(colour_mode),
        .in_set(in_set),
        .red(red),
        .green(green),
        .blue(blue)
    );
   
    
    // bidirectional pins - all inputs for parameter data
    assign uio_out = 8'h00;  // Not driving outputs
    assign uio_oe = 8'h00;   // All inputs
    
    // unused signals
    wire _unused = &{ena, 1'b0};

endmodule 