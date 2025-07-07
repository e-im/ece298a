`default_nettype none

module tb_vga (
    input  logic clk,
    input  logic rst_n,
    input  logic clk_en,

    output logic active,
    output logic hsync,
    output logic vsync,
    output logic v_begin,
    output logic [9:0] hpos,
    output logic [9:0] vpos
);

`ifdef VGA_MODE_LARGE
    parameter int H_ACTIVE      = 640;
    parameter int H_FRONT_PORCH = 16;
    parameter int H_SYNC        = 96;
    parameter int H_BACK_PORCH  = 48;

    parameter int V_ACTIVE      = 480;
    parameter int V_FRONT_PORCH = 10;
    parameter int V_SYNC        = 2;
    parameter int V_BACK_PORCH  = 33;
`else
    parameter int H_ACTIVE      = 8;
    parameter int H_FRONT_PORCH = 2;
    parameter int H_SYNC        = 4;
    parameter int H_BACK_PORCH  = 2;

    parameter int V_ACTIVE      = 6;
    parameter int V_FRONT_PORCH = 1;
    parameter int V_SYNC        = 2;
    parameter int V_BACK_PORCH  = 1;
`endif

    // vga module instantiation
    vga #(
        .H_ACTIVE(H_ACTIVE),
        .H_FRONT_PORCH(H_FRONT_PORCH),
        .H_SYNC(H_SYNC),
        .H_BACK_PORCH(H_BACK_PORCH),
        .V_ACTIVE(V_ACTIVE),
        .V_FRONT_PORCH(V_FRONT_PORCH),
        .V_SYNC(V_SYNC),
        .V_BACK_PORCH(V_BACK_PORCH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .clk_en(clk_en),
        .active(active),
        .hsync(hsync),
        .vsync(vsync),
        .v_begin(v_begin),
        .hpos(hpos),
        .vpos(vpos)
    );

endmodule
