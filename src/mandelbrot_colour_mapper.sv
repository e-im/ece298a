// colour mapper for converting iteration count to RGB
/* verilator lint_off UNUSEDSIGNAL */
module mandelbrot_colour_mapper (
    input  logic clk,               
    input  logic rst_n,             
    input  logic [5:0] iteration_count,
    input  logic [1:0] colour_mode,      // 4 different colour schemes
    input  logic in_set,                // iteration_count == MAX_ITER
    
    output logic [1:0] red,
    output logic [1:0] green,
    output logic [1:0] blue
);

    // colour processing for smooth gradients
    logic [2:0] color_index;
    logic [1:0] shade;
    logic [1:0] iter_high_bits;
    logic [2:0] iter_mid_bits;
    logic [3:0] iter_low_bits;
    logic iter_parity;
    
    // extract different bit ranges for smooth colour transitions
    assign color_index = iteration_count[5:3];      // 8 color levels (0-7)
    assign shade = iteration_count[1:0];            // 4 shade levels within each color
    assign iter_high_bits = iteration_count[5:4];   // top 2 bits (0-3)
    assign iter_mid_bits = iteration_count[4:2];    // middle 3 bits (0-7) 
    assign iter_low_bits = iteration_count[3:0];    // bottom 4 bits (0-15)
    assign iter_parity = iteration_count[0];        // even/odd iterations
    
    // intermediate signals for combinational logic
    logic [1:0] red_next, green_next, blue_next;

    always_comb begin
        if (in_set) begin
            // points in the set - dramatic black for high contrast
            red_next = 2'b00;
            green_next = 2'b00;
            blue_next = 2'b00;
        end else begin
            // colour schemes based on iteration count
            case (colour_mode)
                2'b00: begin // high-contrast grayscale with smooth gradients
                    if (iteration_count < 8) begin
                        red_next = 2'b11;    // bright white for quick escapes
                        green_next = 2'b11;
                        blue_next = 2'b11;
                    end else if (iteration_count < 24) begin
                        red_next = 2'b10;    // medium gray
                        green_next = 2'b10;
                        blue_next = 2'b10;
                    end else if (iteration_count < 48) begin
                        red_next = 2'b01;    // dark gray for slow escapes
                        green_next = 2'b01;
                        blue_next = 2'b01;
                    end else begin
                        red_next = 2'b00;    // near black for very slow escapes
                        green_next = 2'b00;
                        blue_next = 2'b00;
                    end
                end
                
                2'b01: begin // fire theme (deep red -> orange -> yellow -> white)
                    case (color_index)
                        3'b000: {red_next, green_next, blue_next} = 6'b110000; // deep red
                        3'b001: {red_next, green_next, blue_next} = 6'b111000; // red-orange
                        3'b010: {red_next, green_next, blue_next} = 6'b111100; // orange
                        3'b011: {red_next, green_next, blue_next} = 6'b111110; // yellow-orange
                        3'b100: {red_next, green_next, blue_next} = 6'b111111; // bright yellow
                        3'b101: {red_next, green_next, blue_next} = 6'b111111; // white hot
                        3'b110: {red_next, green_next, blue_next} = 6'b101111; // cool white
                        3'b111: {red_next, green_next, blue_next} = 6'b111011; // warm white
                    endcase
                end
                
                2'b10: begin // ocean theme (deep blue -> cyan -> aqua -> white)
                    case (color_index)
                        3'b000: {red_next, green_next, blue_next} = 6'b000001; // deep blue
                        3'b001: {red_next, green_next, blue_next} = 6'b000010; // navy blue
                        3'b010: {red_next, green_next, blue_next} = 6'b000011; // blue
                        3'b011: {red_next, green_next, blue_next} = 6'b001011; // blue-cyan
                        3'b100: {red_next, green_next, blue_next} = 6'b001111; // cyan
                        3'b101: {red_next, green_next, blue_next} = 6'b101111; // light cyan
                        3'b110: {red_next, green_next, blue_next} = 6'b111111; // white foam
                        3'b111: {red_next, green_next, blue_next} = 6'b111110; // warm white
                    endcase
                end
                
                2'b11: begin // psychedelic rainbow with smooth cycling
                    case (iter_low_bits[3:1]) // use top 3 bits of low nibble for smoother gradients
                        3'b000: begin // red to magenta
                            red_next = 2'b11;
                            green_next = iter_parity ? 2'b01 : 2'b00;
                            blue_next = iter_high_bits;
                        end
                        3'b001: begin // magenta to blue  
                            red_next = iter_parity ? 2'b10 : 2'b01;
                            green_next = 2'b00;
                            blue_next = 2'b11;
                        end
                        3'b010: begin // blue to cyan
                            red_next = 2'b00;
                            green_next = iter_high_bits;
                            blue_next = 2'b11;
                        end
                        3'b011: begin // cyan to green
                            red_next = 2'b00;
                            green_next = 2'b11;
                            blue_next = iter_parity ? 2'b10 : 2'b01;
                        end
                        3'b100: begin // green to yellow
                            red_next = iter_high_bits;
                            green_next = 2'b11;
                            blue_next = 2'b00;
                        end
                        3'b101: begin // yellow to orange
                            red_next = 2'b11;
                            green_next = iter_parity ? 2'b11 : 2'b10;
                            blue_next = 2'b00;
                        end
                        3'b110: begin // orange to red
                            red_next = 2'b11;
                            green_next = iter_parity ? 2'b01 : 2'b00;
                            blue_next = 2'b00;
                        end
                        3'b111: begin // white highlights for high iterations
                            red_next = 2'b11;
                            green_next = 2'b11;
                            blue_next = 2'b11;
                        end
                    endcase
                end
            endcase
        end
    end

    // register the outputs for stable timing
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
