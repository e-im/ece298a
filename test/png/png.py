import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from PIL import Image
import os

H_DISPLAY = 640
V_DISPLAY = 480

H_TOTAL = 800
V_TOTAL = 525

CLK_50MHZ_PERIOD_NS = 20

async def reset_dut(dut):
    """
    Applies a reset to the DUT and initializes inputs.
    """
    dut._log.info("start reset")
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    await Timer(CLK_50MHZ_PERIOD_NS * 2, units="ns")
    
    dut.rst_n.value = 1
    dut._log.info("reset")

@cocotb.test()
async def test_capture_first_frame(dut):
    clock = Clock(dut.clk, CLK_50MHZ_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())

    img = Image.new('RGB', (H_DISPLAY, V_DISPLAY))
    pixels = img.load()

    await reset_dut(dut)

    # ui_in[7] ena
    # ui_in[4:3] colour mode
    dut.ui_in.value = 0b10011000  # enable, colour = 3
    await Timer(1, units="ns")
    dut._log.info(f"fractal: {dut.ui_in.value.binstr}")

    dut._log.info("wait v_begin")
    await RisingEdge(dut.v_begin)
    dut._log.info("v_begin found")

    async def frame_stopper():
        await RisingEdge(dut.v_begin)
        dut._log.info("v_begin v2 found")

    stopper_task = cocotb.start_soon(frame_stopper())

    pixels_captured = 0
    
    timeout_cycles = H_TOTAL * V_TOTAL * 2 
    for _ in range(timeout_cycles):
        if stopper_task.done():
            break

        await RisingEdge(dut.clk_25mhz)

        if dut.vga_active.value:
            x = dut.pixel_x.value.integer
            y = dut.pixel_y.value.integer

            if x < H_DISPLAY and y < V_DISPLAY:
                # red[1:0] = {uo_out[0], uo_out[4]}
                # green[1:0] = {uo_out[1], uo_out[5]}
                # blue[1:0]  = {uo_out[2], uo_out[6]}
                r_val = (dut.uo_out.value[0] << 1) | dut.uo_out.value[4]
                g_val = (dut.uo_out.value[1] << 1) | dut.uo_out.value[5]
                b_val = (dut.uo_out.value[2] << 1) | dut.uo_out.value[6]

                # pillow only does 8 bit
                # 255 / 3 (0, 1, 2, 3) = 85
                r_8bit = r_val * 85
                g_8bit = g_val * 85
                b_8bit = b_val * 85

                pixels[x, y] = (r_8bit, g_8bit, b_8bit)
                pixels_captured += 1
    else:
        dut._log.error(f"timeout in {timeout_cycles} reached")
        stopper_task.kill()

    if pixels_captured == 0:
        dut._log.error("rip no pixels")

    output_filename = "out.png"
    img.save(output_filename)
    dut._log.info(f" '{os.path.abspath(output_filename)}'")
    dut._log.info(f"pixels: {pixels_captured}")

    expected_pixels = H_DISPLAY * V_DISPLAY
    assert pixels_captured == expected_pixels, \
        f"captured {pixels_captured} pixels, expected {expected_pixels}"

