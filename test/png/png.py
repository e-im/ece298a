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
    dut.ena.value = 1        # Add missing ena initialization
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    await Timer(CLK_50MHZ_PERIOD_NS * 2, units="ns")
    
    dut.rst_n.value = 1
    dut._log.info("reset")

@cocotb.test()
async def test_full_frame_colour_oracle_small_mode(dut):
    """small vga mode oracle: verify every pixel is captured and rgb within 2-bit bounds."""
    clock = Clock(dut.clk, CLK_50MHZ_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # enable, greyscale mode (uio_in[1:0]=0) for determinism
    dut.ui_in.value = 0b10000000
    dut.uio_in.value = 0
    await Timer(1, units="ns")

    await RisingEdge(dut.v_begin)

    async def frame_stopper():
        await RisingEdge(dut.v_begin)
        dut._log.info("v_begin v2 found")

    stopper_task = cocotb.start_soon(frame_stopper())

    # tiny oracle window
    width, height = 8, 6
    pixels_captured = 0
    captured = [[False]*height for _ in range(width)]

    timeout_cycles = H_TOTAL * V_TOTAL * 2
    for _ in range(timeout_cycles):
        if stopper_task.done():
            break
        await RisingEdge(dut.clk_25mhz)
        if dut.vga_active.value:
            x = dut.pixel_x.value.integer
            y = dut.pixel_y.value.integer
            if x < width and y < height and not captured[x][y]:
                captured[x][y] = True
                r_val = (dut.uo_out.value[0] << 1) | dut.uo_out.value[4]
                g_val = (dut.uo_out.value[1] << 1) | dut.uo_out.value[5]
                b_val = (dut.uo_out.value[2] << 1) | dut.uo_out.value[6]
                assert 0 <= r_val <= 3 and 0 <= g_val <= 3 and 0 <= b_val <= 3
                pixels_captured += 1
    else:
        stopper_task.kill()
        assert False, "timeout waiting for full frame"

    expected_pixels = width * height
    assert pixels_captured == expected_pixels, (
        f"captured {pixels_captured} pixels, expected {expected_pixels}"
    )


@cocotb.test()
async def test_capture_full_frame_png(dut):
    """capture a full 640x480 frame and save out.png for visual inspection."""
    clock = Clock(dut.clk, CLK_50MHZ_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())

    img = Image.new('RGB', (H_DISPLAY, V_DISPLAY))
    pixels = img.load()

    await reset_dut(dut)

    # enable rendering; choose a deterministic colour mode (greyscale)
    dut.ui_in.value = 0b10000000  # enable
    dut.uio_in.value = 0          # colour mode = 0
    await Timer(1, units="ns")

    await RisingEdge(dut.v_begin)

    async def frame_stopper():
        await RisingEdge(dut.v_begin)

    stopper_task = cocotb.start_soon(frame_stopper())

    pixels_captured = 0
    captured_pixels = set()

    timeout_cycles = H_TOTAL * V_TOTAL * 2
    for _ in range(timeout_cycles):
        if stopper_task.done():
            break
        await RisingEdge(dut.clk_25mhz)
        if dut.vga_active.value:
            x = dut.pixel_x.value.integer
            y = dut.pixel_y.value.integer
            if x < H_DISPLAY and y < V_DISPLAY:
                coord = (x, y)
                if coord not in captured_pixels:
                    captured_pixels.add(coord)
                    r_val = (dut.uo_out.value[0] << 1) | dut.uo_out.value[4]
                    g_val = (dut.uo_out.value[1] << 1) | dut.uo_out.value[5]
                    b_val = (dut.uo_out.value[2] << 1) | dut.uo_out.value[6]
                    r_8 = int(r_val) * 85
                    g_8 = int(g_val) * 85
                    b_8 = int(b_val) * 85
                    pixels[x, y] = (r_8, g_8, b_8)
                    pixels_captured += 1
    else:
        stopper_task.kill()
        assert False, f"timeout in {timeout_cycles} reached"

    if pixels_captured == 0:
        assert False, "no pixels captured"

    output_filename = "out.png"
    img.save(output_filename)
    dut._log.info(f"Saved '{os.path.abspath(output_filename)}' with {pixels_captured} pixels")

    expected_pixels = H_DISPLAY * V_DISPLAY
    assert pixels_captured == expected_pixels, (
        f"captured {pixels_captured} pixels, expected {expected_pixels}"
    )

