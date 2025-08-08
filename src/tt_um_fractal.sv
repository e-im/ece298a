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

    // iteration cap
    localparam MAX_ITERATIONS = 6'd16;

    // tile replication. compute one pixel per tile and
    // replicate across an h×v block. expose a few stride presets via uio_in[3:2]
    // 00: 64×16, 01: 32×8 (default), 10: 32×16, 11: 32×8 (alias)
    logic [1:0] stride_sel;
    assign stride_sel = uio_in[3:2];

    logic [3:0] h_stride_shift, v_stride_shift;
    always_comb begin
        unique case (stride_sel)
            2'b00: begin h_stride_shift = 4'd6; v_stride_shift = 4'd4; end // 64×16
            2'b01: begin h_stride_shift = 4'd5; v_stride_shift = 4'd3; end // 32×8
            2'b10: begin h_stride_shift = 4'd5; v_stride_shift = 4'd4; end // 32×16
            default: begin h_stride_shift = 4'd5; v_stride_shift = 4'd3; end // 32×8
        endcase
    end

    localparam int MAX_TILES_X = 640 / 32; // worst case (smallest allowed stride)

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
    wire [1:0] colour_mode = uio_in[1:0];
    
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
    logic signed [8:0] centre_x, centre_y;
    logic [7:0] zoom_level_8bit;
    logic [5:0] iteration_count;
    logic computation_done;
    logic start_computation;
    
    // colour output signals
    logic [1:0] red, green, blue;
    logic [1:0] red_reg, green_reg, blue_reg;

    // tile storage for one macroblock row (max 40 entries of 2-bit rgb)
    logic [1:0] tile_red_line   [0:MAX_TILES_X-1];
    logic [1:0] tile_green_line [0:MAX_TILES_X-1];
    logic [1:0] tile_blue_line  [0:MAX_TILES_X-1];

    // derive tile boundaries and indices from current vga counters
    logic [9:0] h_mask, v_mask;
    always_comb begin
        h_mask = ((10'(1) << h_stride_shift) - 1);
        v_mask = ((10'(1) << v_stride_shift) - 1);
    end
    wire is_first_col  = ((pixel_x & h_mask) == 10'd0);
    wire is_first_line = ((pixel_y & v_mask) == 10'd0);
    wire [5:0] tile_x_index = pixel_x >> h_stride_shift; // up to 39
    
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
    param_controller #(
        .COORD_WIDTH(9)
    ) params (
        .clk(clk),
        .rst_n(rst_n),
        .v_begin(frame_start),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .centre_x(centre_x),
        .centre_y(centre_y),
        .zoom_level(zoom_level_8bit)
    );
    
    // start a computation only at the top-left of a tile on the first line of
    // a macroblock row. engine runs on 50 mhz for extra headroom.
    assign start_computation = vga_active && enable && is_first_col && is_first_line;

    // remember which tile we launched for; latency is < tile time with chosen
    // strides, so we can store directly on result without fifo.
    logic [5:0] launched_tile_x;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            launched_tile_x <= '0;
        end else if (start_computation) begin
            launched_tile_x <= tile_x_index;
        end
    end
    
    // mandelbrot computation engine
    mandelbrot_engine #(
        .COORD_WIDTH(9),
        .FRAC_BITS(6)
    ) mandel (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_valid(start_computation),
        .center_x(centre_x),
        .center_y(centre_y),
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
        .colour_mode(colour_mode),
        .in_set(iteration_count >= MAX_ITERATIONS),
        .red(red),
        .green(green),
        .blue(blue)
    );

    // store tile colour when computation for that tile completes
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i = 0; i < MAX_TILES_X; i = i + 1) begin
                tile_red_line[i]   <= 2'b00;
                tile_green_line[i] <= 2'b00;
                tile_blue_line[i]  <= 2'b00;
            end
        end else if (computation_done) begin
            tile_red_line[launched_tile_x]   <= red;
            tile_green_line[launched_tile_x] <= green;
            tile_blue_line[launched_tile_x]  <= blue;
        end
    end
    
    // register rgb outputs for stable vga (25 mhz). read tile colour for
    // current x tile; hold across all lines in the macroblock.
    always_ff @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            red_reg <= 2'b00;
            green_reg <= 2'b00;
            blue_reg <= 2'b00;
        end else if (vga_active && enable) begin
            red_reg   <= tile_red_line[tile_x_index];
            green_reg <= tile_green_line[tile_x_index];
            blue_reg  <= tile_blue_line[tile_x_index];
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
