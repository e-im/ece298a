import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, ReadOnly

import random
import functools

def to_signed(n, bit_width): # int -> 2s complement
    mask = (1 << bit_width) - 1
    if n < 0:
        n = (1 << bit_width) + n
    return n & mask

def from_signed(n, bit_width): # 2s comp -> int
    if n & (1 << (bit_width - 1)):
        return n - (1 << bit_width)
    return n

test_cases = [
    # basic functionality tests
    { # point in set: hits max_iter_limit
        "name": "origin",
        "pixel_x": 320,
        "pixel_y": 240,
        "center_x": 0,
        "center_y": 0,
        "zoom_level": 0,
        "max_iter_limit": 63
    },
    { # escape right away, c = 2.0 + 0j
        "name": "immediate escape",
        "pixel_x": 576,
        "pixel_y": 240,
        "center_x": 0,
        "center_y": 0,
        "zoom_level": 1,
        "max_iter_limit": 63
    },
    { # inside cardioid, c = -0.25 + 0j
        "name": "cardioid",
        "pixel_x": 256,
        "pixel_y": 240,
        "center_x": 0,
        "center_y": 0,
        "zoom_level": 2,
        "max_iter_limit": 63
    },
    { # non trivial somewhat random point
        "name": "interesting point",
        "pixel_x": 400,
        "pixel_y": 300,
        "center_x": to_signed(-5000, 16),
        "center_y": 2000,
        "zoom_level": 4,
        "max_iter_limit": 50
    },
    { # max zoom
        "name": "max zoom",
        "pixel_x": 320,
        "pixel_y": 240,
        "center_x": 0,
        "center_y": 0,
        "zoom_level": 15,
        "max_iter_limit": 63
    },
    # boundary edge cases:
    {
        "name": "boundary_pixel_top_left",
        "pixel_x": 0,
        "pixel_y": 0,
        "center_x": 0,
        "center_y": 0,
        "zoom_level": 0,
        "max_iter_limit": 63
    },
    {
        "name": "boundary_pixel_bottom_right",
        "pixel_x": 639,
        "pixel_y": 479,
        "center_x": 0,
        "center_y": 0,
        "zoom_level": 0,
        "max_iter_limit": 63
    },
    {
        "name": "boundary_max_iter_zero",
        "pixel_x": 320,
        "pixel_y": 240,
        "center_x": 0,
        "center_y": 0,
        "zoom_level": 0,
        "max_iter_limit": 0
    },
    {
        "name": "boundary_max_iter_one",
        "pixel_x": 480, #any point that iterates more than once normally
        "pixel_y": 240,
        "center_x": 0,
        "center_y": 0,
        "zoom_level": 2,
        "max_iter_limit": 1
    },
    {
        "name": "boundary_zoom_clamping",
        "pixel_x": 320,
        "pixel_y": 240,
        "center_x": 0,
        "center_y": 0,
        "zoom_level": 16,
        "max_iter_limit": 63
    },
    {
        "name": "boundary_center_x_max_neg",
        "pixel_x": 320,
        "pixel_y": 240,
        "center_x": to_signed(-32768, 16), # Min 16-bit signed value
        "center_y": 0,
        "zoom_level": 4,
        "max_iter_limit": 63
    },
    # arith/precision
    {
        "name": "arithmetic_boundary_c_is_minus_2",
        "pixel_x": 192, # c_real ~= -2.0 at zoom=2
        "pixel_y": 240,
        "center_x": 0,
        "center_y": 0,
        "zoom_level": 2,
        "max_iter_limit": 63
    },
    {
        "name": "arithmetic_center_coord_truncation",
        "pixel_x": 320,
        "pixel_y": 240,
        "center_x": 15, # 16'h000F, will be truncated to 0 by center_x[15:4]
        "center_y": 0,
        "zoom_level": 0,
        "max_iter_limit": 63
    },
    {
        "name": "arithmetic_seahorse_valley",
        "pixel_x": 320,
        "pixel_y": 240,
        "center_x": to_signed(-30720, 16), # Center near c = -0.75
        "center_y": to_signed(4096, 16),   # Center near c = 0.1
        "zoom_level": 8,
        "max_iter_limit": 63
    }
]

def calculate_complex_c(params):
    COORD_WIDTH = 12
    FRAC_BITS = 9
    SCREEN_CENTER_X = 320
    SCREEN_CENTER_Y = 240
    
    zoom_shift = min(params['zoom_level'], 15)
    base_scale = 1 << FRAC_BITS  # 1.0, Q3.9 -> 512
    scale_factor = base_scale >> zoom_shift
    
    temp_real = (params['pixel_x'] - SCREEN_CENTER_X) * scale_factor
    temp_imag = (params['pixel_y'] - SCREEN_CENTER_Y) * scale_factor
    
    # c_real = center_x[15:4] + temp_real[15:4];
    c_r = from_signed(params['center_x'], 16) >> 4
    c_i = from_signed(params['center_y'], 16) >> 4

    # temp_real -> signed 21 bit
    c_r += from_signed(to_signed(temp_real, 21), 21) >> 4
    c_i += from_signed(to_signed(temp_imag, 21), 21) >> 4

    # truncate to fixed-point representation
    c_real_fixed = from_signed(to_signed(c_r, COORD_WIDTH), COORD_WIDTH)
    c_imag_fixed = from_signed(to_signed(c_i, COORD_WIDTH), COORD_WIDTH)
    
    # convert to floating-point representation
    c_real_float = c_real_fixed / (1 << FRAC_BITS)
    c_imag_float = c_imag_fixed / (1 << FRAC_BITS)
    c_complex = complex(c_real_float, c_imag_float)
    
    return c_real_fixed, c_imag_fixed, c_complex

def engine_model(params):
    COORD_WIDTH = 12
    FRAC_BITS = 9
    
    c_real, c_imag, _ = calculate_complex_c(params)

    # *** main loop
    z_real, z_imag = 0, 0
    
    for i in range(params['max_iter_limit'] + 1):
        # Q6.18
        z_real_sq = z_real * z_real
        z_imag_sq = z_imag * z_imag
        
        # magnitude_sq = z_real_sq[20:9] + z_imag_sq[20:9]
        mag_sq = (z_real_sq >> FRAC_BITS) + (z_imag_sq >> FRAC_BITS)
        
        # Q3.9, 4.0 -> 2048
        if mag_sq > 2048 or i >= params['max_iter_limit']:
            return i

        # z_new = z^2 + c
        z_cross = z_real * z_imag

        # z_real_new = (z_real^2 - z_imag^2) + c_real
        zrs_shifted = from_signed(to_signed(z_real_sq, 24), 24) >> FRAC_BITS
        zis_shifted = from_signed(to_signed(z_imag_sq, 24), 24) >> FRAC_BITS
        z_real_new = from_signed(to_signed(zrs_shifted - zis_shifted, 13), 13) + c_real
        z_real_new = from_signed(to_signed(z_real_new, COORD_WIDTH), COORD_WIDTH)
        
        # z_imag_new = 2*z_real*z_imag + c_imag
        z_cross_shifted = from_signed(to_signed(z_cross << 1, 24), 24) >> FRAC_BITS
        z_imag_new = from_signed(to_signed(z_cross_shifted, 13), 13) + c_imag
        z_imag_new = from_signed(to_signed(z_imag_new, COORD_WIDTH), COORD_WIDTH)

        z_real, z_imag = z_real_new, z_imag_new
        
    return params['max_iter_limit']

def float_model(params): # floating point model for comparison
    _, _, c = calculate_complex_c(params)

    z = complex(0, 0)
    for i in range(params['max_iter_limit']):
        if abs(z) > 2.0:
            return i
        z = z*z + c
        
    return params['max_iter_limit']


async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.enable.value = 0
    dut.pixel_valid.value = 0
    dut.pixel_x.value = 0
    dut.pixel_y.value = 0
    dut.center_x.value = 0
    dut.center_y.value = 0
    dut.zoom_level.value = 0
    dut.max_iter_limit.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    dut.enable.value = 1
    await ClockCycles(dut.clk, 1)
    assert dut.busy.value == 0, "DUT idle after reset"

async def run_calculation(dut, params):
    dut.pixel_x.value = params['pixel_x']
    dut.pixel_y.value = params['pixel_y']
    dut.center_x.value = params['center_x']
    dut.center_y.value = params['center_y']
    dut.zoom_level.value = params['zoom_level']
    dut.max_iter_limit.value = params['max_iter_limit']
    await ClockCycles(dut.clk, 1)

    dut.pixel_valid.value = 1
    await RisingEdge(dut.busy)
    await ClockCycles(dut.clk, 1)
    dut.pixel_valid.value = 0

    await RisingEdge(dut.result_valid)
    await ReadOnly()
    result = dut.iteration_count.value.integer

    await ClockCycles(dut.clk, 2) # idle after 2 cycles
    assert dut.busy.value == 0, "DUT not idle after result"
    
    return result

async def run_single_test_case(dut, params):
    clock = Clock(dut.clk, 20, units="ns") #50mhz
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    _, _, c_complex = calculate_complex_c(params)
    expected_iterations = engine_model(params) # python result
    float_iterations = float_model(params)
    dut_iterations = await run_calculation(dut, params) # DUT result

    dut._log.info(f"    c: {c_complex}")
    dut._log.info(f"float: {float_iterations}")
    dut._log.info(f"fixed: {expected_iterations}")
    dut._log.info(f"  DUT: {dut_iterations}")

    assert dut_iterations == expected_iterations, f"DUT={dut_iterations}, Expected={expected_iterations}"

# cooked cocotb hacks to make the output look nice:
def create_test_runner(params):
    async def actual_test(dut):
        await run_single_test_case(dut, params)

    return actual_test

for params in test_cases:
    test_name = f"test_{params['name'].lower().replace(' ', '_')}"

    test_coroutine = create_test_runner(params)

    test_coroutine.__name__ = test_name
    test_coroutine.__qualname__ = test_name

    globals()[test_name] = cocotb.test(test_coroutine)
