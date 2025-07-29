`default_nettype none

module param_controller #(
    parameter COORD_WIDTH = 16, // Q4.12
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

    // extract control signals from UI inputs
    wire zoom_in     = ui_in[0];
    wire zoom_out    = ui_in[1]; 
    wire pan_left    = ui_in[2];
    wire pan_right   = ui_in[3];
    wire pan_up      = ui_in[4];
    wire pan_down    = ui_in[5];
    wire reset_view  = ui_in[6];
    wire max_iter_sel = ui_in[5]; // reuse bit 5 for iteration control

    // default view (shows classic Mandelbrot features)
    localparam signed [COORD_WIDTH-1:0] DEFAULT_CENTRE_X = -16'h1000; // -0.5
    localparam signed [COORD_WIDTH-1:0] DEFAULT_CENTRE_Y = 16'h0000;
    localparam [ZOOM_WIDTH-1:0] DEFAULT_ZOOM = 8'd0;
    
    // iteration limits
    localparam [ITER_WIDTH-1:0] ITER_LIMIT_FAST = 31;
    localparam [ITER_WIDTH-1:0] ITER_LIMIT_DETAIL = 63;

    // current parameters
    logic signed [COORD_WIDTH-1:0] curr_center_x, curr_center_y;
    logic [ZOOM_WIDTH-1:0] curr_zoom;
    logic [ITER_WIDTH-1:0] curr_max_iter;
    
    // calculate pan step size based on zoom level (natural feel)
    localparam signed [COORD_WIDTH-1:0] BASE_PAN_STEP = 16'd819; // 0.1
    logic signed [COORD_WIDTH-1:0] pan_step;
    assign pan_step = BASE_PAN_STEP >> curr_zoom[3:0];
    
    // update parameters only at frame start to avoid visual glitches
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
                // zoom control with limits
                if (zoom_in && curr_zoom < '1) begin
                    curr_zoom <= curr_zoom + 1;
                end else if (zoom_out && curr_zoom > 0) begin
                    curr_zoom <= curr_zoom - 1;
                end
                
                // pan control (speed scales with zoom level for natural feel)
                if (pan_left) begin
                    curr_center_x <= curr_center_x - pan_step;
                end else if (pan_right) begin
                    curr_center_x <= curr_center_x + pan_step;
                end
                
                if (pan_up) begin
                    curr_center_y <= curr_center_y - pan_step;
                end else if (pan_down) begin
                    curr_center_y <= curr_center_y + pan_step;
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
