`default_nettype none

module vga #(
    /* Parameters derived from CEA-861, 640x480 @ '60hz'
       Modeline "640x480_59.94" 25.175 640 656 752 800 480 490 492 525 -HSync -VSync
    */
    parameter int H_ACTIVE = 640,
    parameter int H_FRONT_PORCH = 16, //right
    parameter int H_SYNC = 96,
    parameter int H_BACK_PORCH = 48, //left

    parameter int V_ACTIVE = 480,
    parameter int V_FRONT_PORCH = 10, //bottom
    parameter int V_SYNC = 2, //lines
    parameter int V_BACK_PORCH = 33, //top

    parameter int H_TOTAL = H_ACTIVE + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH,
    parameter int V_TOTAL = V_ACTIVE + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH,
    parameter int H_BITS  = $clog2(H_TOTAL),
    parameter int V_BITS  = $clog2(V_TOTAL)
)(
    input logic clk,
    input logic rst_n,
    input logic clk_en, // pixel clock enable

    output logic active, // high when in active region, safe to drive pixels
    output logic hsync,
    output logic vsync,
    output logic v_begin, // start of new frame
    output logic [H_BITS - 1 : 0] hpos,
    output logic [V_BITS - 1 : 0] vpos

);

localparam int H_SYNC_START = H_ACTIVE + H_FRONT_PORCH;
localparam int H_SYNC_END = H_ACTIVE + H_FRONT_PORCH + H_SYNC - 1;
localparam int H_MAX = H_ACTIVE + H_BACK_PORCH + H_FRONT_PORCH + H_SYNC - 1;
localparam int V_SYNC_START = V_ACTIVE + V_FRONT_PORCH;
localparam int V_SYNC_END = V_ACTIVE + V_FRONT_PORCH + V_SYNC - 1;
localparam int V_MAX = V_ACTIVE + V_FRONT_PORCH + V_BACK_PORCH + V_SYNC - 1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hpos <= '0;
        vpos <= '0;
    end else if (clk_en) begin
        if (hpos == H_BITS'(H_MAX)) begin
            hpos <= '0;
            //vert only on horz wrap
            if (vpos == V_BITS'(V_MAX))
                vpos <= '0;
            else
              vpos <= vpos + 1'b1;
        end else begin
            hpos <= hpos + 1'b1;
        end
    end
end

always_comb begin
    hsync = !((hpos >= H_BITS'(H_SYNC_START)) && (hpos <= H_BITS'(H_SYNC_END)));
    vsync = !((vpos >= H_BITS'(V_SYNC_START)) && (vpos <= H_BITS'(V_SYNC_END)));
    active = (hpos < H_BITS'(H_ACTIVE)) && (vpos < H_BITS'(V_ACTIVE));

    v_begin = (hpos == 0) && (vpos == 0) && clk_en;
end

endmodule