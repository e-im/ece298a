`default_nettype none

module param_controller #(
    parameter COORD_WIDTH = 11, // Q3.8
    parameter ZOOM_WIDTH  = 8
) (
    input  logic clk,
    input  logic rst_n,

    input  logic v_begin,
    input  logic [7:0] ui_in,
    input  logic [7:0] uio_in,

    output logic signed [COORD_WIDTH-1:0] centre_x,
    output logic signed [COORD_WIDTH-1:0] centre_y,
    output logic [ZOOM_WIDTH-1:0]         zoom_level
);

    // extract control signals from UI inputs
    wire zoom_in     = ui_in[0];
    wire zoom_out    = ui_in[1]; 
    wire pan_left    = ui_in[2];
    wire pan_right   = ui_in[3];
    wire pan_up      = ui_in[4];
    wire pan_down    = ui_in[5];
    wire reset_view  = ui_in[6];

    // default view (shows classic Mandelbrot features)
    localparam signed [COORD_WIDTH-1:0] DEFAULT_CENTRE_X = -11'd128; // -0.5 in Q3.8 (-128 / 2^8) 
    localparam signed [COORD_WIDTH-1:0] DEFAULT_CENTRE_Y = 11'd0;     // 0.0 in Q3.8
    localparam [ZOOM_WIDTH-1:0] DEFAULT_ZOOM = 8'd0;

    // current parameters
    logic signed [COORD_WIDTH-1:0] curr_center_x, curr_center_y;
    logic [ZOOM_WIDTH-1:0] curr_zoom;
    
    // calculate pan step size based on zoom level (natural feel)
    localparam signed [COORD_WIDTH-1:0] BASE_PAN_STEP = 11'd32; // 0.125 in Q3.8 (32 / 2^8)
    logic signed [COORD_WIDTH-1:0] pan_step;
    assign pan_step = BASE_PAN_STEP >> curr_zoom[2:0];
    
    // update parameters only at frame start to avoid visual glitches
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_center_x <= DEFAULT_CENTRE_X;
            curr_center_y <= DEFAULT_CENTRE_Y;
            curr_zoom <= DEFAULT_ZOOM;
        end else if (v_begin) begin
            if (reset_view) begin
                curr_center_x <= DEFAULT_CENTRE_X;
                curr_center_y <= DEFAULT_CENTRE_Y;
                curr_zoom <= DEFAULT_ZOOM;
            end else begin
                // zoom control with limits (reduced max zoom for less precision)
                if (zoom_in && curr_zoom < 8'd15) begin
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
                
            end
        end
    end
    
    assign centre_x = curr_center_x;
    assign centre_y = curr_center_y;
    assign zoom_level = curr_zoom;
endmodule
