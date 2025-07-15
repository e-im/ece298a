`default_nettype none

// Add lint suppression for unused bits and signals
/* verilator lint_off UNUSEDSIGNAL */

// mandelbrot computation engine with pixel coordinate interface
// implements the escape time algorithm: z(n+1) = z(n)^2 + c
// https://en.wikipedia.org/wiki/Plotting_algorithms_for_the_Mandelbrot_set
module mandelbrot_engine #(
    parameter COORD_WIDTH = 16,  // fixed-point coordinate width
    parameter FRAC_BITS = 12,    // fractional bits (Q4.12 format)
    parameter SCREEN_CENTER_X = 320,  // screen center X (for VGA: 320)
    parameter SCREEN_CENTER_Y = 240   // screen center Y (for VGA: 240)
) (
    input  logic clk,
    input  logic rst_n,
    
    // pixel coordinate inputs
    input  logic [9:0] pixel_x,   // 0-639
    input  logic [9:0] pixel_y,   // 0-479
    input  logic pixel_valid,     // start computation for this pixel
    
    // parameter inputs (from parameter bus)
    input  logic signed [15:0] center_x,    // complex plane center X
    input  logic signed [15:0] center_y,    // complex plane center Y
    input  logic [7:0] zoom_level,          // zoom factor (0 = widest view)
    input  logic [5:0] max_iter_limit,      // for iter sel
    
    // control
    input  logic enable,
    
    // outputs
    output logic [5:0] iteration_count,    // 0-63 iterations
    output logic result_valid,             // result ready
    output logic busy                      // engine computing
);

    // coordinate mapping with zoom scaling
    logic signed [15:0] scale_factor = 16'h2000;
    // always_comb begin
    //     // Carefully tuned scale factors for smooth zooming
    //     case (zoom_level[3:0]) // Use bottom 4 bits for compatibility
    //         4'd0:  scale_factor = 16'h2000; // 0.5 (wide view)
    //         4'd1:  scale_factor = 16'h1000; // 0.25
    //         4'd2:  scale_factor = 16'h0800; // 0.125 (good starting view)
    //         4'd3:  scale_factor = 16'h0400; // 0.0625
    //         4'd4:  scale_factor = 16'h0200; // 0.03125
    //         4'd5:  scale_factor = 16'h0100; // 0.015625
    //         4'd6:  scale_factor = 16'h0080; // 0.0078125
    //         4'd7:  scale_factor = 16'h0040; // 0.00390625
    //         4'd8:  scale_factor = 16'h0020; // 0.001953125
    //         4'd9:  scale_factor = 16'h0010; // 0.0009765625
    //         4'd10: scale_factor = 16'h0008; // 0.00048828125
    //         4'd11: scale_factor = 16'h0004; // 0.000244140625
    //         4'd12: scale_factor = 16'h0002; // 0.000122070313
    //         4'd13: scale_factor = 16'h0001; // 0.000061035156
    //         4'd14: scale_factor = 16'h0001; // 0.000030517578
    //         4'd15: scale_factor = 16'h0001; // 0.000015258789
    //     endcase
    // end

    // state machine for computation pipeline
    typedef enum logic [2:0] {
        IDLE = 3'b000, 
        SETUP = 3'b001, 
        ITERATE = 3'b010, 
        ESCAPE_CHECK = 3'b011, 
        DONE_STATE = 3'b100
    } state_t;
    state_t state;
    
    // mandelbrot variables
    logic signed [15:0] c_real, c_imag;
    logic signed [15:0] z_real, z_imag;
    logic [5:0] iter_count;
    
    // map pixel coordinates to complex plane
    always_comb begin
        logic signed [31:0] temp_real, temp_imag;
        // center at screen center (320, 240) and scale
        temp_real = ($signed({1'b0, pixel_x}) - 16'd320) * scale_factor;
        temp_imag = ($signed({1'b0, pixel_y}) - 16'd240) * scale_factor;
        c_real = center_x + temp_real[29:14]; // extract Q2.14 result
        c_imag = center_y + temp_imag[29:14];
    end
    
    // mandelbrot iteration with pipeline stages
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            z_real <= 16'h0000;
            z_imag <= 16'h0000;
            iter_count <= 6'b0;
        end else if (enable) begin
            case (state)
                IDLE: begin
                    if (pixel_valid) begin
                        z_real <= 16'h0000; // start with z = 0
                        z_imag <= 16'h0000;
                        iter_count <= 6'b0;
                        state <= SETUP;
                    end
                end
                
                SETUP: begin
                    // one cycle to setup, then start iterating
                    state <= ITERATE;
                end
                
                ITERATE: begin
                    // mandelbrot iteration: z = z² + c
                    // split computation across multiple cycles for timing
                    logic signed [31:0] z_real_sq, z_imag_sq, z_cross;
                    logic signed [15:0] z_real_new, z_imag_new;
                    
                    // calculate z² components
                    z_real_sq = z_real * z_real;
                    z_imag_sq = z_imag * z_imag;
                    z_cross = z_real * z_imag;
                    
                    // new z value: z = z² + c
                    z_real_new = (z_real_sq[29:14] - z_imag_sq[29:14]) + c_real;
                    z_imag_new = (z_cross[28:13]) + c_imag; // 2 * z_real * z_imag (shift left by 1)
                    
                    z_real <= z_real_new;
                    z_imag <= z_imag_new;
                    iter_count <= iter_count + 1;
                    state <= ESCAPE_CHECK;
                end
                
                ESCAPE_CHECK: begin
                    // check escape condition: |z|² > 4
                    logic signed [31:0] z_real_sq, z_imag_sq;
                    logic [31:0] magnitude_sq;
                    
                    z_real_sq = z_real * z_real;
                    z_imag_sq = z_imag * z_imag;
                    magnitude_sq = z_real_sq[29:14] + z_imag_sq[29:14]; // |z|² in Q2.14
                    
                    if (magnitude_sq > 32'h10000 || iter_count >= max_iter_limit) begin 
                        // escaped (|z|² > 4) or max iterations reached
                        state <= DONE_STATE;
                    end else begin
                        // continue iterating
                        state <= ITERATE;
                    end
                end
                
                DONE_STATE: begin
                    if (!pixel_valid) begin
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    assign iteration_count = iter_count;
    assign result_valid = (state == DONE_STATE);
    assign busy = (state != IDLE);

endmodule

