`default_nettype none

/* verilator lint_off UNUSEDSIGNAL */

// parameter controller for zoom/pan controls and iteration limits
// optimized for minimal area usage in 1x2 tinytapeout tile
module param_controller #(
    parameter COORD_WIDTH = 16, 
    parameter ZOOM_WIDTH  = 8,
    parameter ITER_WIDTH  = 6
) (
    input  logic clk,
    input  logic rst_n,

    input  logic v_begin,
    input  logic [7:0] ui_in,
    input  logic [7:0] uio_in,

    output logic signed [COORD_WIDTH-1:0] centre_x,
    output logic signed [COORD_WIDTH-1:0] centre_y,
    output logic [ZOOM_WIDTH-1:0]         zoom_level,
    output logic [ITER_WIDTH-1:0]         max_iter_limit
);

    // decode user interface control signals
    wire zoom_in     = ui_in[0];
    wire zoom_out    = ui_in[1]; 
    wire pan_left    = ui_in[2];
    wire pan_right   = ui_in[3];
    wire pan_up      = ui_in[4];
    wire pan_down    = ui_in[5];
    wire reset_view  = ui_in[6];
    wire max_iter_sel = ui_in[5]; // iteration count select (fast/detailed)

    // default mandelbrot view showing main features
    localparam signed [COORD_WIDTH-1:0] DEFAULT_CENTRE_X = -16'h4000; // -1.0 shows main bulb
    localparam signed [COORD_WIDTH-1:0] DEFAULT_CENTRE_Y = 16'h0000;  // 0.0 center
    localparam [ZOOM_WIDTH-1:0] DEFAULT_ZOOM = '0; // wide view initial zoom
    
    // iteration count limits for speed vs quality tradeoff
    localparam [ITER_WIDTH-1:0] ITER_LIMIT_FAST = 31;
    localparam [ITER_WIDTH-1:0] ITER_LIMIT_DETAIL = 63;

    // current fractal view parameters
    logic signed [COORD_WIDTH-1:0] curr_center_x, curr_center_y;
    logic [ZOOM_WIDTH-1:0] curr_zoom;
    logic [ITER_WIDTH-1:0] curr_max_iter;
    
    // pan step size calculation (smaller at higher zoom)
    logic [11:0] pan_step;
    always_comb begin
        pan_step = 12'h080 >> curr_zoom[2:0];  // divide by 2^zoom for natural feel
    end
    
    // update parameters at frame boundary for smooth animation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_center_x <= DEFAULT_CENTRE_X;
            curr_center_y <= DEFAULT_CENTRE_Y;
            curr_zoom <= DEFAULT_ZOOM;
            curr_max_iter <= ITER_LIMIT_DETAIL;
        end else if (v_begin) begin
            if (reset_view) begin
                curr_center_x <= DEFAULT_CENTRE_X;
                curr_center_y <= DEFAULT_CENTRE_Y;
                curr_zoom <= DEFAULT_ZOOM;
            end else begin
                // zoom control using only 3 bits (8 levels) for area efficiency
                if (zoom_in && curr_zoom[2:0] < 3'd7) begin
                    curr_zoom[2:0] <= curr_zoom[2:0] + 1;
                end else if (zoom_out && curr_zoom[2:0] > 3'd0) begin
                    curr_zoom[2:0] <= curr_zoom[2:0] - 1;
                end
                
                // pan control with zoom-adjusted step size
                if (pan_left) begin
                    curr_center_x <= curr_center_x - {4'b0, pan_step};
                end else if (pan_right) begin
                    curr_center_x <= curr_center_x + {4'b0, pan_step};
                end
                
                if (pan_up) begin
                    curr_center_y <= curr_center_y - {4'b0, pan_step};
                end else if (pan_down) begin
                    curr_center_y <= curr_center_y + {4'b0, pan_step};
                end
                
                // iteration limit control
                if (max_iter_sel) begin
                    curr_max_iter <= ITER_LIMIT_DETAIL;
                end else begin
                    curr_max_iter <= ITER_LIMIT_FAST;
                end
            end
        end
    end
    
    assign centre_x = curr_center_x;
    assign centre_y = curr_center_y;
    assign zoom_level = curr_zoom;
    assign max_iter_limit = curr_max_iter;

endmodule

/* verilator lint_on UNUSEDSIGNAL */
