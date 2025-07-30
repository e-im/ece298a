/* verilator lint_off UNUSEDSIGNAL */

// compact color mapper for mandelbrot fractal visualization
// optimized for minimal area usage in 1x2 tinytapeout tile
module mandelbrot_colour_mapper (
    input  logic clk,               
    input  logic rst_n,             
    input  logic [5:0] iteration_count,
    input  logic [1:0] colour_mode,      // 4 color palettes: grayscale, fire, ocean, rainbow
    input  logic in_set,                
    
    output logic [1:0] red,
    output logic [1:0] green,
    output logic [1:0] blue
);

    // simplified color mapping using reduced bit ranges
    logic [1:0] color_index;
    logic [1:0] intensity;
    
    assign color_index = iteration_count[5:4];  // upper 2 bits for main color
    assign intensity = iteration_count[3:2];    // middle 2 bits for brightness
    
    logic [1:0] red_next, green_next, blue_next;

    always_comb begin
        if (in_set) begin
            red_next = 2'b00;
            green_next = 2'b00;
            blue_next = 2'b00;
        end else begin
            // 4 color schemes with optimized logic for area efficiency
            case (colour_mode)
                2'b00: begin // grayscale palette
                    red_next = intensity;
                    green_next = intensity;
                    blue_next = intensity;
                end
                
                2'b01: begin // fire palette (red/orange/yellow)
                    red_next = 2'b11;
                    green_next = intensity;
                    blue_next = color_index[0] ? intensity[1:0] : 2'b00;
                end
                
                2'b10: begin // ocean palette (blue/cyan/white)
                    red_next = color_index[0] ? intensity[1:0] : 2'b00;
                    green_next = intensity;
                    blue_next = 2'b11;
                end
                
                2'b11: begin // rainbow palette
                    case (color_index)
                        2'b00: {red_next, green_next, blue_next} = {2'b11, intensity, 2'b00};  // red-yellow transition
                        2'b01: {red_next, green_next, blue_next} = {2'b00, 2'b11, intensity};  // green-cyan transition
                        2'b10: {red_next, green_next, blue_next} = {intensity, 2'b00, 2'b11};  // blue-magenta transition
                        2'b11: {red_next, green_next, blue_next} = {intensity, intensity, intensity}; // white spectrum
                    endcase
                end
            endcase
        end
    end

    // register rgb outputs for stable vga timing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            red <= 2'b00;
            green <= 2'b00;
            blue <= 2'b00;
        end else begin
            red <= red_next;
            green <= green_next;
            blue <= blue_next;
        end
    end
endmodule 
