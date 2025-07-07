// colour mapper for converting iteration count to RGB
module mandelbrot_colour_mapper (
    input  logic [5:0] iteration_count,
    input  logic [1:0] colour_mode,      // 4 different colour schemes
    input  logic in_set,                // iteration_count == MAX_ITER
    
    output logic [1:0] red,
    output logic [1:0] green,
    output logic [1:0] blue
);

    // extract bit ranges outside always block to avoid iverilog warnings
    logic [1:0] iter_high_bits;
    logic [2:0] iter_rainbow_bits;
    logic iter_bit5;
    
    assign iter_high_bits = iteration_count[5:4];
    assign iter_rainbow_bits = iteration_count[5:3];
    assign iter_bit5 = iteration_count[5];

    always_comb begin
        if (in_set) begin
            // point is in the set - always black
            red = 2'b00;
            green = 2'b00;
            blue = 2'b00;
        end else begin
            // point escaped - colour based on iteration count and mode
            case (colour_mode)
                2'b00: begin // Grayscale mode
                    red = iter_high_bits;
                    green = iter_high_bits;
                    blue = iter_high_bits;
                end
                
                2'b01: begin // Hot colours (red->yellow->white)
                    red = 2'b11;
                    green = iter_high_bits;
                    blue = {1'b0, iter_bit5};
                end
                
                2'b10: begin // cool colours (blue->cyan->white)
                    red = {1'b0, iter_bit5};
                    green = iter_high_bits;
                    blue = 2'b11;
                end
                
                2'b11: begin // rainbow mode
                    case (iter_rainbow_bits) // use top 3 bits for 8 colours
                        3'b000: {red, green, blue} = 6'b110000; // Red
                        3'b001: {red, green, blue} = 6'b111100; // Yellow
                        3'b010: {red, green, blue} = 6'b001100; // Green
                        3'b011: {red, green, blue} = 6'b001111; // Cyan
                        3'b100: {red, green, blue} = 6'b000011; // Blue
                        3'b101: {red, green, blue} = 6'b110011; // Magenta
                        3'b110: {red, green, blue} = 6'b111111; // White
                        3'b111: {red, green, blue} = 6'b101010; // Gray
                        default: {red, green, blue} = 6'b101010; // Gray (default)
                    endcase
                end
                
                default: begin // default case for any unexpected colour_mode values
                    red = iter_high_bits;
                    green = iter_high_bits;
                    blue = iter_high_bits;
                end
            endcase
        end
    end
endmodule 
