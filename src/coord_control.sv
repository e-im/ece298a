// uses concepts from https://github.com/MichaelBell/tt08-mandelbrot/tree/main

`default_nettype 

module coord_control #(
 parameter int BITS = 16;
) (
    input logic clk,
    input logic rst_n,
    
    input logic h_begin,
    input logic v_begin,

    input ctrl_cmd_e ctrl,

    input coord_t x0,
    input coord_t y0,

    output coord_t x0_next,
    output coord_t y0_next
);

typedef enum logic [2:0] {
    // todo commands
} ctrl_cmd_e;

typedef logic signed [2:-(BITS-3)] coord_t;
typedef logic signed [1:-(BITS-3)] y_coord_t;
typedef logic signed [-4:-(BITS-3)] pixel_inc_t;
typedef logic signed [-6:-(BITS-3)] row_inc_t;

// todo x not good change this
localparam coord_t   X_LEFT_DEFAULT = coord_t'(-2 << (BITS-3));
localparam y_coord_t Y_TOP_DEFAULT  = y_coord_t'(1 << (BITS-3));
localparam pixel_inc_t X_INC_PX_DEFAULT = pixel_inc_t'(240);
localparam pixel_inc_t Y_INC_PX_DEFAULT = pixel_inc_t'(0);
localparam row_inc_t   X_INC_ROW_DEFAULT = row_inc_t'(0);
localparam row_inc_t   Y_INC_ROW_DEFAULT = row_inc_t'(-170);

coord_t   current_x0, current_y0;

coord_t   x_row_start;
y_coord_t y_row_start;

// todo control impl here


// coordinate generation
always_comb begin
    unique case ({v_begin, h_begin})
        2'b10: begin // new frame
            next_x0 = X_LEFT_DEFAULT;
            next_y0 = Y_TOP_DEFAULT;
        end
        2'b01: begin // new line
            next_x0 = y_row_start;
            next_y0 = y_row_start;
        end
        default: begin
            next_x0 = x0 + coord_t'({{6{X_INC_PX_DEFAULT[-4]}}, X_INC_PX_DEFAULT});
            next_y0 = y0 + coord_t'({{5{Y_INC_PX_DEFAULT[-4]}}, Y_INC_PX_DEFAULT});
        end
    endcase
end

// current coords
always_ff @(posedge clk) begin
    if (reset) begin
        current_x0 <= X_LEFT_DEFAULT;
        current y0 <= Y_TOP_DEFAULT;
    end else begin
        current_x0 <= next_x0;
        current_y0 <= next_y0;
    end
end

// row start pos

always_ff @(posedge clk) begin
    if (reset) begin
        x_row_start <= X_LEFT_DEFAULT;
        y_row_start <= Y_TOP_DEFAULT;
    end else begin
        if (v_begin) begin
            x_row_start <= X_LEFT_DEFAULT;
            y_row_start <= Y_TOP_DEFAULT;
        end else if (h_begin) begin
            x_row_start <= x_row_start + coord_t'({{8{X_INC_ROW_DEFAULT[-6]}}, X_INC_ROW_DEFAULT});
            y_row_start <= y_row_start + y_coord_t'({{7{Y_INC_ROW_DEFAULT[-6]}}, Y_INC_ROW_DEFAULT});
        end
    end
end

endmodule