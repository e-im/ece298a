// colour mapper for converting iteration count to rgb
/* verilator lint_off UNUSEDSIGNAL */
module mandelbrot_colour_mapper (
    input  logic clk,               
    input  logic rst_n,             
    input  logic [5:0] iteration_count,
    input  logic [1:0] colour_mode,      // colour scheme select (bit 0 used)
    input  logic in_set,
    
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
            // simplified to 2 colour schemes only for area reduction
            case (colour_mode[0]) // only use 1 bit instead of 2
                1'b0: begin // high-contrast greyscale with smooth gradients
                    if (iteration_count < 8) begin
                        red_next = 2'b11;    // bright white for quick escapes
                        green_next = 2'b11;
                        blue_next = 2'b11;
                    end else if (iteration_count < 24) begin
                        red_next = 2'b10;    // medium grey
                        green_next = 2'b10;
                        blue_next = 2'b10;
                    end else begin
                        red_next = 2'b01;    // dark grey for slow escapes
                        green_next = 2'b01;
                        blue_next = 2'b01;
                    end
                end
                
                1'b1: begin // fire theme (deep red -> orange -> yellow -> white)
                    case (color_index[1:0]) // reduce from 3 bits to 2 bits
                        2'b00: {red_next, green_next, blue_next} = 6'b110000; // deep red
                        2'b01: {red_next, green_next, blue_next} = 6'b111100; // orange
                        2'b10: {red_next, green_next, blue_next} = 6'b111111; // bright yellow
                        2'b11: {red_next, green_next, blue_next} = 6'b111111; // white hot
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
