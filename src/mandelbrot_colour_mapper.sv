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

    // extract bit ranges outside always block to avoid iverilog warnings
    logic [1:0] iter_high_bits;
    logic [2:0] iter_rainbow_bits;
    logic iter_bit5;
    
    // intermediate signals for combinational logic
    logic [1:0] red_next, green_next, blue_next;
    
    assign iter_high_bits = iteration_count[5:4];
    assign iter_rainbow_bits = iteration_count[5:3];
    assign iter_bit5 = iteration_count[5];

    always_comb begin
        if (in_set) begin
            // point is in the set - always black
            red_next = 2'b00;
            green_next = 2'b00;
            blue_next = 2'b00;
        end else begin
            // point escaped - colour based on iteration count and mode
            case (colour_mode)
                2'b00: begin // Grayscale mode
                    red_next = iter_high_bits;
                    green_next = iter_high_bits;
                    blue_next = iter_high_bits;
                end
                
                2'b01: begin // Hot colours (red->yellow->white)
                    red_next = 2'b11;
                    green_next = iter_high_bits;
                    blue_next = {1'b0, iter_bit5};
                end
                
                2'b10: begin // cool colours (blue->cyan->white)
                    red_next = {1'b0, iter_bit5};
                    green_next = iter_high_bits;
                    blue_next = 2'b11;
                end
                
                2'b11: begin // rainbow mode
                    case (iter_rainbow_bits) // use top 3 bits for 8 colours
                        3'b000: {red_next, green_next, blue_next} = 6'b110000; // Red
                        3'b001: {red_next, green_next, blue_next} = 6'b111100; // Yellow
                        3'b010: {red_next, green_next, blue_next} = 6'b001100; // Green
                        3'b011: {red_next, green_next, blue_next} = 6'b001111; // Cyan
                        3'b100: {red_next, green_next, blue_next} = 6'b000011; // Blue
                        3'b101: {red_next, green_next, blue_next} = 6'b110011; // Magenta
                        3'b110: {red_next, green_next, blue_next} = 6'b111111; // White
                        3'b111: {red_next, green_next, blue_next} = 6'b101010; // Gray
                        default: {red_next, green_next, blue_next} = 6'b101010; // Gray (default)
                    endcase
                end
                
                default: begin // default case for any unexpected colour_mode values
                    red_next = iter_high_bits;
                    green_next = iter_high_bits;
                    blue_next = iter_high_bits;
                end
            endcase
        end
    end

    // register the outputs
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
