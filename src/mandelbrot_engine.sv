`default_nettype none

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

    // fixed-point arithmetic constants
    localparam signed [COORD_WIDTH-1:0] ESCAPE_THRESHOLD = 16'h4000; // 4.0 in Q4.12
    localparam signed [COORD_WIDTH-1:0] BASE_SCALE = 16'h1000;       // 1.0 in Q4.12

    // state machine for the mandelbrot engine
    typedef enum logic [2:0] {
        IDLE, // idle state
        INIT, // initialize state
        ITERATE, // iterate state
        CHECK_ESCAPE, // check escape state
        DONE // done state
    } state_t;
    
    state_t state, next_state;
    
    // internal registers
    logic signed [COORD_WIDTH-1:0] c_real, c_imag;    // complex constant c
    logic signed [COORD_WIDTH-1:0] z_real, z_imag;    // complex variable z
    logic signed [COORD_WIDTH-1:0] z_real_sq, z_imag_sq, z_real_temp;
    logic [5:0] iter_count;
    logic [5:0] iter_count_next;
    logic signed [31:0] magnitude_sq;  // for escape test (z_real^2 + z_imag^2)
    
    // coordinate mapping logic
    logic signed [COORD_WIDTH-1:0] scale_factor;
    logic signed [COORD_WIDTH-1:0] pixel_offset_x, pixel_offset_y;
    
    // extract bit ranges outside always blocks
    logic [2:0] zoom_level_bits;
    assign zoom_level_bits = zoom_level[2:0];
    
    // calculate scale factor based on zoom level (smaller = more zoomed in)
    always_comb begin
        case (zoom_level_bits)  // use bottom 3 bits for 8 zoom levels
            3'b000: scale_factor = BASE_SCALE;         // 1.0 - widest view
            3'b001: scale_factor = BASE_SCALE >> 1;    // 0.5
            3'b010: scale_factor = BASE_SCALE >> 2;    // 0.25
            3'b011: scale_factor = BASE_SCALE >> 3;    // 0.125
            3'b100: scale_factor = BASE_SCALE >> 4;    // 0.0625
            3'b101: scale_factor = BASE_SCALE >> 5;    // 0.03125
            3'b110: scale_factor = BASE_SCALE >> 6;    // 0.015625
            3'b111: scale_factor = BASE_SCALE >> 7;    // 0.0078125
        endcase
    end
    
    // map pixel coordinates to complex plane
    always_comb begin
        // center coordinates around configurable screen center
        // Use proper width intermediate variables to avoid width warnings
        logic signed [31:0] pixel_offset_x_temp, pixel_offset_y_temp;
        
        pixel_offset_x_temp = ($signed({1'b0, pixel_x}) - $signed(SCREEN_CENTER_X)) * $signed(scale_factor);
        pixel_offset_y_temp = ($signed({1'b0, pixel_y}) - $signed(SCREEN_CENTER_Y)) * $signed(scale_factor);
        
        pixel_offset_x = pixel_offset_x_temp[COORD_WIDTH-1:0];
        pixel_offset_y = pixel_offset_y_temp[COORD_WIDTH-1:0];
        
        // apply centering and scaling to map pixels to complex plane
        c_real = center_x + (pixel_offset_x >>> FRAC_BITS);
        c_imag = center_y + (pixel_offset_y >>> FRAC_BITS);
    end
    
    // multiplier logic for z^2 computation
    always_comb begin
        // compute z_real^2 and z_imag^2 with proper scaling using intermediate variables
        logic signed [31:0] z_real_mult, z_imag_mult, z_cross_mult;
        
        z_real_mult = $signed(z_real) * $signed(z_real);
        z_imag_mult = $signed(z_imag) * $signed(z_imag);
        z_cross_mult = $signed(z_real) * $signed(z_imag);
        
        z_real_sq = z_real_mult[COORD_WIDTH+FRAC_BITS-1:FRAC_BITS];
        z_imag_sq = z_imag_mult[COORD_WIDTH+FRAC_BITS-1:FRAC_BITS];
        
        // magnitude squared for escape test - extend to 32 bits properly
        magnitude_sq = $signed({{(32-COORD_WIDTH){z_real_sq[COORD_WIDTH-1]}}, z_real_sq}) + 
                      $signed({{(32-COORD_WIDTH){z_imag_sq[COORD_WIDTH-1]}}, z_imag_sq});
        
        // temporary for z_real update (z_real_new = z_real^2 - z_imag^2 + c_real)
        z_real_temp = z_real_sq - z_imag_sq + c_real;
    end
    
    // state machine logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            z_real <= '0;
            z_imag <= '0;
            iter_count <= '0;
            result_valid <= 1'b0;
        end else begin
            state <= next_state;
            iter_count <= iter_count_next;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    if (pixel_valid && enable) begin
                        z_real <= '0;  // init z = 0
                        z_imag <= '0;
                        iter_count <= '0;
                    end
                end
                
                INIT: begin
                    // one cycle to let coordinate mapping settle
                    result_valid <= 1'b0;
                end
                
                ITERATE: begin
                    // perform one iteration: z = z^2 + c
                    logic signed [31:0] z_cross_mult_temp;
                    z_cross_mult_temp = $signed(z_real) * $signed(z_imag);
                    
                    z_real <= z_real_temp;  // z_real^2 - z_imag^2 + c_real
                    z_imag <= z_cross_mult_temp[COORD_WIDTH+FRAC_BITS-2:FRAC_BITS-1] + c_imag; // 2*z_real*z_imag + c_imag
                    result_valid <= 1'b0;
                end
                
                CHECK_ESCAPE: begin
                    result_valid <= 1'b0;
                end
                
                DONE: begin
                    result_valid <= 1'b1;
                end
            endcase
        end
    end
    
    // next state logic (combinational)
    always_comb begin
        next_state = state;
        iter_count_next = iter_count;
        
        case (state)
            IDLE: begin
                if (pixel_valid && enable) begin
                    next_state = INIT;
                end
            end
            
            INIT: begin
                next_state = ITERATE;
            end
            
            ITERATE: begin
                next_state = CHECK_ESCAPE;
                iter_count_next = iter_count + 1;
            end
            
            // check escape condition
            CHECK_ESCAPE: begin
                // check if magnitude squared is greater than escape threshold or if iteration count is greater than max iterations
                if (magnitude_sq >= $signed({{(32-COORD_WIDTH){ESCAPE_THRESHOLD[COORD_WIDTH-1]}}, ESCAPE_THRESHOLD}) || 
                    iter_count >= max_iter_limit) begin
                    next_state = DONE;
                end else begin
                    next_state = ITERATE;
                end
            end
            
            DONE: begin
                if (!pixel_valid) begin
                    next_state = IDLE;
                end
            end
        endcase
    end
    
    // output assignments
    assign iteration_count = iter_count;
    assign busy = (state != IDLE) && (state != DONE);

endmodule
