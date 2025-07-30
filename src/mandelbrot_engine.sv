`default_nettype none

/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */

// compact mandelbrot fractal engine optimized for 1x2 tinytapeout tile
// uses reduced precision arithmetic and simplified state machine for minimal area
module mandelbrot_engine #(
    parameter COORD_WIDTH = 12,   // reduced from 16-bit for area savings
    parameter FRAC_BITS = 8,      // Q4.8 format instead of Q4.12
    parameter SCREEN_CENTER_X = 320,
    parameter SCREEN_CENTER_Y = 240
) (
    input  logic clk,
    input  logic rst_n,
    
    // pixel coordinate inputs
    input  logic [9:0] pixel_x,   // 0-639
    input  logic [9:0] pixel_y,   // 0-479
    input  logic pixel_valid,     // start computation for this pixel
    
    // fractal parameters from controller module
    input  logic signed [15:0] center_x,    // complex plane center X
    input  logic signed [15:0] center_y,    // complex plane center Y
    input  logic [7:0] zoom_level,          // zoom factor
    input  logic [5:0] max_iter_limit,      // max iterations
    
    // control
    input  logic enable,
    
    // outputs
    output logic [5:0] iteration_count,    // 0-63 iterations
    output logic result_valid,             // result ready
    output logic busy                      // engine computing
);

    // zoom scaling with 8 levels (3-bit control for area efficiency)
    logic signed [11:0] scale_factor;
    always_comb begin
        case (zoom_level[2:0])  // only 3 bits used, 8 zoom levels total
            3'd0: scale_factor = 12'h200;  // 0.125 (wide view)
            3'd1: scale_factor = 12'h100;  // 0.0625
            3'd2: scale_factor = 12'h080;  // 0.03125
            3'd3: scale_factor = 12'h040;  // 0.015625
            3'd4: scale_factor = 12'h020;  // 0.0078125
            3'd5: scale_factor = 12'h010;  // 0.00390625
            3'd6: scale_factor = 12'h008;  // 0.001953125
            3'd7: scale_factor = 12'h004;  // 0.0009765625
        endcase
    end

    // minimal 2-state machine: idle and compute (was 5 states originally)
    typedef enum logic {
        IDLE = 1'b0,
        COMPUTE = 1'b1
    } state_t;
    state_t state;
    
    // mandelbrot iteration variables with reduced precision
    logic signed [11:0] c_real, c_imag;
    logic signed [11:0] z_real, z_imag;
    logic [5:0] iter_count;
    
    // map pixel coordinates to complex plane with reduced precision
    always_comb begin
        logic signed [23:0] temp_real, temp_imag;
        logic signed [23:0] pixel_x_ext, pixel_y_ext;
        pixel_x_ext = {14'b0, pixel_x} - 24'd320;
        pixel_y_ext = {14'b0, pixel_y} - 24'd240;
        temp_real = pixel_x_ext * {12'b0, scale_factor};
        temp_imag = pixel_y_ext * {12'b0, scale_factor};
        c_real = center_x[11:0] + temp_real[19:8];  // 12-bit precision for area savings
        c_imag = center_y[11:0] + temp_imag[19:8];
    end
    
    // mandelbrot computation: z = z^2 + c (single cycle for speed)
    logic signed [23:0] z_real_sq, z_imag_sq, z_cross;
    logic signed [11:0] z_real_new, z_imag_new;
    logic [23:0] magnitude_sq;
    logic escape_condition;
    
    // combinational logic for one mandelbrot iteration
    always_comb begin
        z_real_sq = z_real * z_real;
        z_imag_sq = z_imag * z_imag;
        z_cross = z_real * z_imag;
        
        z_real_new = (z_real_sq[19:8] - z_imag_sq[19:8]) + c_real;
        z_imag_new = (z_cross[18:7]) + c_imag;  // multiply by 2 via bit shift
        
        magnitude_sq = {12'b0, z_real_sq[19:8]} + {12'b0, z_imag_sq[19:8]};
        escape_condition = (magnitude_sq > 24'h1000) || (iter_count >= max_iter_limit);  // |z|^2 > 4
    end
    
    // state machine: idle -> compute iterations until escape or max reached
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            z_real <= 12'h000;
            z_imag <= 12'h000;
            iter_count <= 6'b0;
        end else if (enable) begin
            case (state)
                IDLE: begin
                    if (pixel_valid) begin
                        z_real <= 12'h000;
                        z_imag <= 12'h000;
                        iter_count <= 6'b0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    if (escape_condition) begin
                        state <= IDLE;
                    end else begin
                        z_real <= z_real_new;
                        z_imag <= z_imag_new;
                        iter_count <= iter_count + 6'b1;
                    end
                end
            endcase
        end
    end
    
    assign iteration_count = iter_count;
    assign result_valid = (state == IDLE) && (iter_count > 0);
    assign busy = (state != IDLE);

endmodule

