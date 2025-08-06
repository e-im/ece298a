/*
 * Copyright (c) 2024 ECE298A Team
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// mandelbrot fractal generator for TinyTapeout
module tt_um_fractal (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs  
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire       ena,      // always 1 when design is powered
    /* verilator lint_on UNUSEDSIGNAL */
    input  wire       clk,      // clock (50MHz)
    input  wire       rst_n     // reset_n - low to reset
);

    localparam MAX_ITERATIONS = 6'd63;

    // control signals from UI pins
    wire zoom_in     = ui_in[0];
    wire zoom_out    = ui_in[1]; 
    wire pan_left    = ui_in[2];
    wire pan_right   = ui_in[3];
    wire pan_up      = ui_in[4];
    wire pan_down    = ui_in[5];
    wire reset_view  = ui_in[6];
    wire enable      = ui_in[7];
    
    // colour mode from bidirectional pins
    wire [1:0] color_mode = uio_in[1:0];
    
    // generate 25MHz pixel clock
    logic clk_div;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) clk_div <= 1'b0;
        else clk_div <= ~clk_div;
    end
    wire clk_25mhz = clk_div;
    
    // VGA timing signals
    logic vga_hsync, vga_vsync, vga_active;
    logic [9:0] pixel_x, pixel_y;
    logic frame_start;
    
    // mandelbrot computation signals
    logic signed [10:0] center_x, center_y;
    logic [7:0] zoom_level_8bit;
    logic [5:0] iteration_count;
    logic computation_done;
    logic start_computation;
    
    // colour output signals
    logic [1:0] red, green, blue;
    logic [1:0] red_reg, green_reg, blue_reg;
    
    // VGA timing generator (640x480 @ 60Hz)
    vga vga_timing (
        .clk(clk_25mhz),
        .rst_n(rst_n),
        .clk_en(1'b1),
        .active(vga_active),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .hpos(pixel_x),
        .vpos(pixel_y),
        .v_begin(frame_start)
    );
    
    // parameter controller for zoom/pan
    param_controller params (
        .clk(clk),
        .rst_n(rst_n),
        .v_begin(frame_start),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .centre_x(center_x),
        .centre_y(center_y),
        .zoom_level(zoom_level_8bit)
    );
    
    // start computation when new pixel is active
    assign start_computation = vga_active && enable;
    
    // mandelbrot computation engine
    mandelbrot_engine mandel (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_valid(start_computation),
        .center_x(center_x),
        .center_y(center_y),
        .zoom_level(zoom_level_8bit),
        .max_iter_limit(MAX_ITERATIONS),
        .enable(enable),
        .iteration_count(iteration_count),
        .result_valid(computation_done),
        .busy() // Not used
    );
    
    // colour mapping
    mandelbrot_colour_mapper colors (
        .clk(clk),
        .rst_n(rst_n),
        .iteration_count(iteration_count),
        .colour_mode(color_mode),
        .in_set(iteration_count >= MAX_ITERATIONS),
        .red(red),
        .green(green),
        .blue(blue)
    );
    
    // register RGB outputs for stable VGA (synchronized to 25MHz)
    always_ff @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            red_reg <= 2'b00;
            green_reg <= 2'b00;
            blue_reg <= 2'b00;
        end else if (vga_active && enable) begin
            red_reg <= red;
            green_reg <= green;
            blue_reg <= blue;
        end else if (!vga_active) begin
            // black during blanking
            red_reg <= 2'b00;
            green_reg <= 2'b00;
            blue_reg <= 2'b00;
        end
    end
    
    // VGA output assignment (TinyTapeout standard VGA pinout)
    assign uo_out[7] = vga_hsync;
    assign uo_out[6] = blue_reg[0];   // vga_b0
    assign uo_out[5] = green_reg[0];  // vga_g0  
    assign uo_out[4] = red_reg[0];    // vga_r0
    assign uo_out[3] = vga_vsync;
    assign uo_out[2] = blue_reg[1];   // vga_b1
    assign uo_out[1] = green_reg[1];  // vga_g1
    assign uo_out[0] = red_reg[1];    // vga_r1
    
    // bidirectional pins - input only for colour mode
    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;

endmodule
