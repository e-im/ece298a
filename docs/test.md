# Unit Test Overview

Run tests by going into the `test` directory and running `make tb-$testname`, replacing `$testname` with the name of the test you want to run. The options are:

```
test/
├── vga/                 # VGA timing generator tests
├── engine/              # Mandelbrot calculation engine unit test
├── png/                 # PNG generation of first frame test
└── mandelbrot/          # Full system integration tests
```

## VGA Timing Generator (`vga/`)
This test validate the generation of 640x480 VGA timing signals. It tests specific functions and then runs through two full frames against a python reference.

- **Reset**: Verify counters reset to zero.
- **Clock Enable**: Confirm counters do not advance when `clk_en` is low.
- **Full Frame Simulation**: Runs the vga timing generator through two full frames and ensures the output match a python vga timing implementation.
- **Signal Counting**: Count the number of `active`, `hsync`, and `vsync` pulses over one frame to ensure they match the spec. This was mostly useful in the development of the VGA timing generator and let me quickly debug issues, it doesn't add coverage that the full frame test don't.

#### Mandelbrot Engine (`mandelbrot_engine/`)
This test validates the core escape-time algorithm for a set of individual pixels.

This contains both a replica of the fixed-point arithmetic used in the verilog implementation, as well as a simple floating point implementation of the escape time algorithm in python.

It compares the iteration count for a set of interesting coordinates. The coordinates were selected to capture potential edge cases.

| Name | Pixel X | Pixel Y | Center X | Center Y | Zoom Level | Max Iter Limit |
|------|---------|---------|----------|----------|------------|----------------|
| origin | 320 | 240 | 0 | 0 | 0 | 63 |
| immediate escape | 576 | 240 | 0 | 0 | 1 | 63 |
| cardioid | 256 | 240 | 0 | 0 | 2 | 63 |
| interesting point | 400 | 300 | to_signed(-5000, 16) | 2000 | 4 | 50 |
| max zoom | 320 | 240 | 0 | 0 | 15 | 63 |
| boundary_pixel_top_left | 0 | 0 | 0 | 0 | 0 | 63 |
| boundary_pixel_bottom_right | 639 | 479 | 0 | 0 | 0 | 63 |
| boundary_max_iter_zero | 320 | 240 | 0 | 0 | 0 | 0 |
| boundary_max_iter_one | 480 | 240 | 0 | 0 | 2 | 1 |
| boundary_zoom_clamping | 320 | 240 | 0 | 0 | 16 | 63 |
| boundary_center_x_max_neg | 320 | 240 | to_signed(-32768, 16) | 0 | 4 | 63 |
| arithmetic_boundary_c_is_minus_2 | 192 | 240 | 0 | 0 | 2 | 63 |
| arithmetic_center_coord_truncation | 320 | 240 | 15 | 0 | 0 | 63 |
| arithmetic_seahorse_valley | 320 | 240 | to_signed(-30720, 16) | to_signed(4096, 16) | 8 | 63 |

#### Top-Level System (`mandelbrot/`)
This test validates the basic functionality of the entire system.

- **Basic Computation**: Verifies the system produces valid 2-bit RGB output values within expected ranges after initialization.
- **Color Mode Variations**: Tests both color modes to ensure each produces valid RGB outputs and responds to mode changes.
- **Engine Enable/Disable**: Confirms the engine responds properly to enable/disable control signals.

## Mandelbrot Frame Capture Test (`png/`)
This test validates the complete Mandelbrot fractal rendering system by capturing a full frame of output.

- **Frame Synchronization**: Uses VGA timing signals (`v_begin`, `vga_active`) to properly synchronize frame capture with display timing.
- **Pixel Extraction**: Captures RGB pixel data during active display periods, converting 2-bit values to 8-bit RGB for image output (requirement of python pillow library used to write image).
- **Visual Output**: Generates a PNG image file of the rendered Mandelbrot fractal for manual verification.
