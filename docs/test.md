# Unit Test Overview

This project uses cocotb exclusively for verification; verilog benches are wrappers only.

Prerequisites:
- python 3.10+ with pip
- iverilog (or another supported simulator)
- `pip install -r test/requirements.txt`

Run tests by going into the `test` directory and running `make tb-$testname`, replacing `$testname` with the name of the test you want to run. The options are shown below.

Run tests from the `test/` directory:
- `make tb-engine`
- `make tb-vga`
- `make tb-mandelbrot`
- `make tb-png`

Optional:
- Randomized engine fuzz: `ENGINE_FUZZ=1 make tb-engine`
- Gate‑level sim when a netlist is available: `make tb-engine GATES=yes` (and similarly for other targets)

```
test/
├── vga/                 # vga timing generator tests
├── engine/              # mandelbrot calculation engine unit tests + fixed‑point model
├── png/                 # full‑frame png capture tests
└── mandelbrot/          # full system integration tests
```

<!-- code_chunk_output -->

- [Unit Test Overview](#unit-test-overview)
  - [VGA Timing Generator (`vga/`)](#vga-timing-generator-vga)
  - [Mandelbrot Engine (`mandelbrot_engine/`)](#mandelbrot-engine-mandelbrot_engine)
  - [Top-Level System (`mandelbrot/`)](#top-level-system-mandelbrot)
  - [Mandelbrot Frame Capture Test (`png/`)](#mandelbrot-frame-capture-test-png)

<!-- /code_chunk_output -->

## VGA Timing Generator (`vga/`)
This test validates the generation of 640x480 VGA timing signals. It tests specific functions and then runs through two full frames against a python reference.

- **reset**: verify counters reset to zero.
- **clock enable**: confirm counters do not advance when `clk_en` is low.
- **full frame simulation**: run the VGA timing generator through two full frames and ensure outputs match a python VGA timing implementation.
- **signal counting**: count the number of `active`, `hsync`, and `vsync` pulses over one frame to ensure they match the spec. this was mostly useful during development to quickly debug timing; it does not add coverage beyond the full‑frame test.

## Mandelbrot Engine (`mandelbrot_engine/`)
Validates the escape‑time core against a fixed‑point python model (quantization‑aware).
- deterministic vectors: inside/outside, boundary, arithmetic edge cases
- handshake/latency bounded by `max_iter_limit` + small overhead
- optional randomized fuzz (set `ENGINE_FUZZ=1`) for deeper exploration

Notes:
- engine instance in top uses reduced precision to fit 1×2 (FRAC_BITS = 6; 9‑bit signed coords at top‑level)
- escape check implemented as `(zr*zr >> n) + (zi*zi >> n) > (4 << n)` with n = FRAC_BITS

Engine test vectors:

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

## Top-Level System (`mandelbrot/`)
Validates integration and visible behaviours.
- enable/blanking behaviour, frame‑synchronous parameter updates
- colour‑mode switching via `uio_in[0]` (0 = greyscale, 1 = fire)
- rgb value range checks (2‑bit per channel)
- tiling replication holds the computed tile colour across its H×V block

## Mandelbrot Frame Capture Test (`png/`)
Proves the full pipeline renders a frame.
- synchronizes to `v_begin`/`active`
- captures 640×480 active pixels and saves `test/out.png`
- asserts exactly 307,200 pixels captured, values within 2‑bit channel bounds
- includes a small‑mode oracle test for faster CI iterations

---

Sample PASS summary (engine):
```
** TESTS=15 PASS=15 FAIL=0 SKIP=0
```

Gate‑level simulation (post‑layout): when CI produces `gate_level_netlist.v`, run GLS using Sky130 HD cell models:
- `make tb-engine GATES=yes`
- repeat for other targets as needed

Code chunk outputs (examples):

```text
$ make tb-png
...
png.test_capture_full_frame_png PASS
** TESTS=2 PASS=2 FAIL=0 SKIP=0
saved image to test/out.png (640x480, 307200 pixels)
```

```text
$ make tb-vga
...
vga.test_two_frame_scan PASS
** TESTS=5 PASS=5 FAIL=0 SKIP=0
active pulses=307200, hsync=640, vsync=2 (per spec)
```

Artefacts and logs:
- PASS logs in console per test target
- `test/out.png` saved by the png test (640×480)
- VCDs can be enabled via cocotb env if detailed wave debug is needed

Troubleshooting and useful knobs:
- `ENGINE_FUZZ=1` enables randomized engine vs model fuzzing
- `GATES=yes` switches to gate‑level netlist + Sky130 cell models
- `SIM` can be set to a supported simulator if needed
