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

    wire zoom_toggle  = ui_in[0];
    wire pan_h_toggle = ui_in[1];
    wire pan_v_toggle = ui_in[2];
    wire max_iter_sel = ui_in[5];
    wire reset_view   = ui_in[6];

    // default for reset call
    localparam signed [COORD_WIDTH-1:0] DEFAULT_CENTRE_X = 16'hF800; // -0.5
    localparam signed [COORD_WIDTH-1:0] DEFAULT_CENTRE_Y = 16'h0000; //  0.0
    localparam [ZOOM_WIDTH-1:0]          DEFAULT_ZOOM     = 8'd0; // widest

    // guess, eval these
    localparam [ITER_WIDTH-1:0] ITER_LIMIT_FAST = 31;
    localparam [ITER_WIDTH-1:0] ITER_LIMIT_DETAIL = 63;

    reg signed [COORD_WIDTH-1:0] current_centre_x;
    reg signed [COORD_WIDTH-1:0] current_centre_y;
    reg [ZOOM_WIDTH-1:0]         current_zoom_level;
    reg [ITER_WIDTH-1:0]         current_max_iter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // default view on reset
            current_centre_x   <= DEFAULT_CENTRE_X;
            current_centre_y   <= DEFAULT_CENTRE_Y;
            current_zoom_level <= DEFAULT_ZOOM;
            current_max_iter   <= ITER_LIMIT_DETAIL;
        end else begin
            if (v_begin) begin // only update during vsync
                if (reset_view) begin
                    current_centre_x   <= DEFAULT_CENTRE_X;
                    current_centre_y   <= DEFAULT_CENTRE_Y;
                    current_zoom_level <= DEFAULT_ZOOM;
                end else begin
                    if (pan_h_toggle) begin
                        current_centre_x <= current_centre_x + ($signed(uio_in) <<< 4);
                    end

                    if (pan_v_toggle) begin
                        current_centre_y <= current_centre_y + ($signed(uio_in) <<< 4);
                    end

                    if (zoom_toggle) begin
                        // pos zoom in, neg zoom out
                        logic signed [ZOOM_WIDTH:0] next_zoom;
                        next_zoom = $signed(current_zoom_level) + $signed(uio_in);

                        if (next_zoom < 0) begin // underflow
                            current_zoom_level <= 0;
                        end else if (next_zoom >= (1 << ZOOM_WIDTH)) begin // overflow
                            current_zoom_level <= (1 << ZOOM_WIDTH) - 1;
                        end else begin
                            current_zoom_level <= next_zoom[ZOOM_WIDTH-1:0];
                        end
                    end

                    if (max_iter_sel) begin
                        current_max_iter <= ITER_LIMIT_DETAIL;
                    end else begin
                        current_max_iter <= ITER_LIMIT_FAST;
                    end
                end
            end
        end
    end

    assign centre_x       = current_centre_x;
    assign centre_y       = current_centre_y;
    assign zoom_level     = current_zoom_level;
    assign max_iter_limit = current_max_iter;

endmodule
