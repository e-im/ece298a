`default_nettype none

// Add lint suppression for unused bits and signals
/* verilator lint_off UNUSEDSIGNAL */

// mandelbrot computation engine with pixel coordinate interface
// implements the escape time algorithm: z(n+1) = z(n)^2 + c
// https://en.wikipedia.org/wiki/Plotting_algorithms_for_the_Mandelbrot_set


// Space-optimized mandelbrot computation engine
module mandelbrot_engine #(
    parameter COORD_WIDTH = 11,      // 11 bits for coordinates (optimized for 1x2 tile)
    parameter FRAC_BITS = 8         // 8 bits for fractional part (optimized for 1x2 tile)
) (
    input  logic clk,
    input  logic rst_n,
    
    // pixel coordinate inputs
    input  logic [9:0] pixel_x,   // 0-639
    input  logic [9:0] pixel_y,   // 0-479
    input  logic pixel_valid,     // start computation for this pixel
    
    // parameter inputs
    input  logic signed [COORD_WIDTH-1:0] center_x,
    input  logic signed [COORD_WIDTH-1:0] center_y,
    input  logic [7:0] zoom_level,
    input  logic [5:0] max_iter_limit,
    
    // control
    input  logic enable,
    
    // outputs
    output logic [5:0] iteration_count,
    output logic result_valid,
    output logic busy
);

    // simplified 3-state machine
    typedef enum logic [1:0] {
        IDLE = 2'b00, 
        COMPUTE = 2'b01, 
        DONE = 2'b10
    } state_t;
    state_t state;
    
    // reduced-width mandelbrot variables
    logic signed [COORD_WIDTH-1:0] c_real, c_imag;
    logic signed [COORD_WIDTH-1:0] z_real, z_imag;
    logic [5:0] iter_count;
    
    // computation temporary variables
    logic signed [2*COORD_WIDTH-1:0] z_real_sq, z_imag_sq, z_cross;
    logic signed [COORD_WIDTH-1:0] z_real_new, z_imag_new;
    logic signed [2*COORD_WIDTH-1:0] magnitude_sq_full;
    
    // simplified scale factor using shifts (much smaller than lookup table)
    logic [3:0] zoom_shift;
    logic [3:0] zoom_level_clamp;
    
    // extract lower 4 bits as continuous assignment
    assign zoom_level_clamp = zoom_level[3:0];
    
    always_comb begin
        zoom_shift = (zoom_level > 15) ? 4'd15 : zoom_level_clamp;
    end
    
    // coordinate mapping for classic Mandelbrot view - optimized for timing
    logic signed [COORD_WIDTH-1:0] base_scale;
    assign base_scale = 11'h080; // base scale factor (128/256 = 0.5 for 4-unit wide view)
    
    // Pre-computed constants for better timing
    logic signed [10:0] pixel_offset_x, pixel_offset_y;
    logic signed [COORD_WIDTH-1:0] scale_factor;
    
    always_comb begin
        // Pre-compute scale factor (single shift operation)
        scale_factor = base_scale >> zoom_shift;
        
        // Pre-compute pixel offsets (simple subtraction)
        pixel_offset_x = $signed({1'b0, pixel_x}) - 11'd320;
        pixel_offset_y = $signed({1'b0, pixel_y}) - 11'd240;
    end
    
    // Pipeline coordinate computation for timing closure
    logic signed [21:0] temp_real, temp_imag;
    always_comb begin
        // multiply by scale - single multiplication per coordinate
        temp_real = pixel_offset_x * scale_factor;
        temp_imag = pixel_offset_y * scale_factor;
        
        // add to center position (optimized bit manipulation)
        c_real = center_x + signed'(temp_real >>> FRAC_BITS);
        c_imag = center_y + signed'(temp_imag >>> FRAC_BITS);
    end
    
    // Pipeline stage 1: multiplication (registered for timing)
    logic signed [2*COORD_WIDTH-1:0] z_real_sq_reg, z_imag_sq_reg, z_cross_reg;
    
    always_ff @(posedge clk) begin
        if (enable && state == COMPUTE) begin
            z_real_sq_reg <= z_real * z_real;
            z_imag_sq_reg <= z_imag * z_imag;
            z_cross_reg <= z_real * z_imag;
        end
    end
    
    // mandelbrot computation (combinational - reduced complexity)
    always_comb begin
        // Use registered multiplication results for better timing
        z_real_sq = (state == COMPUTE) ? z_real_sq_reg : z_real * z_real;
        z_imag_sq = (state == COMPUTE) ? z_imag_sq_reg : z_imag * z_imag;
        z_cross = (state == COMPUTE) ? z_cross_reg : z_real * z_imag;
        
        // new z value, converting from Q6.16 back to Q3.8 - split into stages
        z_real_new = (z_real_sq >> FRAC_BITS) - (z_imag_sq >> FRAC_BITS) + c_real;
        z_imag_new = ((z_cross << 1) >> FRAC_BITS) + c_imag; // 2*z_r*z_i
        
        // escape condition: |z|^2 > 4 - simplified comparison
        magnitude_sq_full = (z_real_sq >> FRAC_BITS) + (z_imag_sq >> FRAC_BITS);
    end
    
    // single-cycle iteration with combined escape check
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            z_real <= '0;
            z_imag <= '0;
            iter_count <= '0;
        end else if (enable) begin
            case (state)
                IDLE: begin
                    if (pixel_valid) begin
                        z_real <= '0;
                        z_imag <= '0;
                        iter_count <= '0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Optimized escape condition - pre-compute comparisons for timing
                    // 4.0 in Q3.8 is 4 * 2^8 = 1024 (0x400)
                    logic escaped, max_reached;
                    escaped = magnitude_sq_full > 11'd1024;
                    max_reached = iter_count >= max_iter_limit;
                    
                    if (escaped || max_reached) begin
                        state <= DONE;
                    end else begin
                        // Continue iterating - register updates
                        z_real <= z_real_new;
                        z_imag <= z_imag_new;
                        iter_count <= iter_count + 1;
                        // Stay in COMPUTE state
                    end
                end
                
                DONE: begin
                    if (!pixel_valid) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    assign iteration_count = iter_count;
    assign result_valid = (state == DONE);
    assign busy = (state != IDLE);

endmodule