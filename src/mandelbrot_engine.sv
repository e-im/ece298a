`default_nettype none

// Add lint suppression for unused bits and signals
/* verilator lint_off UNUSEDSIGNAL */

// mandelbrot computation engine with pixel coordinate interface
// implements the escape time algorithm: z(n+1) = z(n)^2 + c
// https://en.wikipedia.org/wiki/Plotting_algorithms_for_the_Mandelbrot_set


// Space-optimized mandelbrot computation engine
module mandelbrot_engine #(
    parameter COORD_WIDTH = 11,      // 11 bits for coordinates (optimized for 1x2 tile)
    parameter FRAC_BITS = 8,         // 8 bits for fractional part (optimized for 1x2 tile)
    parameter SCREEN_CENTER_X = 320,
    parameter SCREEN_CENTER_Y = 240
) (
    input  logic clk,
    input  logic rst_n,
    
    // pixel coordinate inputs
    input  logic [9:0] pixel_x,   // 0-639
    input  logic [9:0] pixel_y,   // 0-479
    input  logic pixel_valid,     // start computation for this pixel
    
    // parameter inputs
    input  logic signed [15:0] center_x,    // 16 bits for center coordinates
    input  logic signed [15:0] center_y,
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
    
    // simplified scale factor using shifts (much smaller than lookup table)
    logic [3:0] zoom_shift;
    always_comb begin
        zoom_shift = (zoom_level > 15) ? 4'd15 : zoom_level[3:0];
    end
    
    // coordinate mapping - optimized for 1x2 tile (Q3.8 format)
    logic signed [COORD_WIDTH-1:0] base_scale;
    assign base_scale = 11'h100; // base scale factor (1.0 in Q3.8)
    
    always_comb begin
        logic signed [21:0] temp_real, temp_imag;
        logic signed [COORD_WIDTH-1:0] scale_factor;
        
        // scale factor using right shift
        scale_factor = base_scale >> zoom_shift;
        
        // coordinate calculation for Q3.8 format
        temp_real = ($signed({1'b0, pixel_x}) - 16'd320) * scale_factor;
        temp_imag = ($signed({1'b0, pixel_y}) - 16'd240) * scale_factor;
        
        // truncation for Q3.8 format (one bit less precision)
        c_real = center_x[15:5] + temp_real[16:5]; // Q3.8 bit slicing
        c_imag = center_y[15:5] + temp_imag[16:5];
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
                    // combined iteration and escape check in single cycle
                    logic signed [21:0] z_real_sq, z_imag_sq, z_cross;
                    logic signed [COORD_WIDTH-1:0] z_real_new, z_imag_new;
                    logic [21:0] magnitude_sq;
                    
                    // mandelbrot iteration: z = z^2 + c
                    z_real_sq = z_real * z_real;
                    z_imag_sq = z_imag * z_imag;
                    z_cross = z_real * z_imag;
                    
                    // new z value (Q3.8 bit slicing for area optimization)
                    z_real_new = (z_real_sq[18:8] - z_imag_sq[18:8]) + c_real;
                    z_imag_new = (z_cross[17:7]) + c_imag; // 2 * z_real * z_imag
                    
                    // escape condition: |z|^2 > 4 (4.0 in Q3.8 is 0x400)
                    magnitude_sq = z_real_sq[18:8] + z_imag_sq[18:8];
                    
                    if (magnitude_sq > 22'h400 || iter_count >= max_iter_limit) begin 
                        // Escaped or max iterations
                        state <= DONE;
                    end else begin
                        // Continue iterating
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