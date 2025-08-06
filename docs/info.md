## Project: Verilog Mandelbrot Fractal Generator for TinyTapeout

This project implements a Mandelbrot set Fractal Generator with VGA output capability. The system generates real-time Mandelbrot set visualizations by computing the mathematical iteration for each pixel coordinate.

### How it works

The system operates as a pipelined process synchronized to a pixel clock to generate the video signal.

1.  **Clocking**: The top module `tt_um_fractal` takes a 50MHz system clock uses a clock divider to produce a 25MHz pixel clock required for a 640x480 @ 60Hz VGA signal.

2.  **VGA Timing**: The `vga` module uses the 25MHz clock to generate standard VGA synchronization signals (`hsync`, `vsync`) and keeps track of the current pixel coordinates being drawn (`hpos`, `vpos`). It also outputs an `active` signal, which is high only when the beam is within the visible 640x480 display area. This is used to synchronize the mandelbrot pixel calculation.

3.  **User Input & Parameter Control**: The `param_controller` module reads user inputs for panning and zooming (`ui_in`). To prevent visual glitches like tearing, it only updates the fractal's parameters (center coordinates and zoom level) at the beginning of a new frame, signaled by `v_begin` from the `vga` module. The panning speed is dynamically adjusted based on the zoom level.

4.  **Fractal Calculation**: W $z_{n+1} = z_n^2 + c$

5.  **Color Mapping**: The resulting `iteration_count` from the engine is passed to the `mandelbrot_colour_mapper`. This module translates the numerical iteration count into a 6-bit RGB color value. It supports four distinct color schemes, which can be selected via the `uio_in` pins. Points determined to be inside the set are colored black for high contrast.

6.  **Top-Level Integration**: The `tt_um_fractal` module integrates all these components. It connects the user inputs to the parameter controller, pipes the fractal parameters and pixel coordinates to the calculation engine, sends the iteration count to the color mapper, and finally drives the VGA output pins with the resulting color data and sync signals.

---

### IO Table: `vga`

| **Name**            | **Verilog** | **Description**                                             | **I/O** | **Width** | **Trigger** |
| :------------------ | :---------- | :---------------------------------------------------------- | :-----: | :-------: | :---------- |
| Clock               | `clk`       | 25MHz pixel clock signal. dividided from 50MHz system clock |    I    |     1     | Rising Edge |
| Reset               | `rst_n`     | Asynchronous active-low reset                               |    I    |     1     | Active Low  |
| Clock Enable        | `clk_en`    | Enables counter updates                                     |    I    |     1     | Active High |
| Active Display      | `active`    | High when drawing visible pixels                            |    O    |     1     | N/A         |
| Horizontal Sync     | `hsync`     | Horizontal synchronization pulse                            |    O    |     1     | N/A         |
| Vertical Sync       | `vsync`     | Vertical synchronization pulse                              |    O    |     1     | N/A         |
| Frame Start         | `v_begin`   | Single-cycle pulse at the start of a new frame              |    O    |     1     | N/A         |
| Horizontal Position | `hpos`      | Current horizontal pixel coordinate (X)                     |    O    |    10     | N/A         |
| Vertical Position   | `vpos`      | Current vertical line coordinate (Y)                        |    O    |    10     | N/A         |

#### Notes
* The module is parameterized for a standard **640x480 @ 60Hz** VGA resolution.
* The `hpos` and `vpos` counters increment on each enabled clock edge, scanning the screen from left to right, top to bottom.
* The `active` signal should be used by upstream modules to know when it is valid to provide pixel data.
* The `v_begin` signal is crucial for modules like `param_controller` to synchronize their updates to the frame rate, preventing mid-frame changes.

---

### IO Table: `param_controller`

| **Name**       | **Verilog**      | **Description**                                | **I/O** | **Width** | **Trigger** |
| :------------- | :--------------- | :--------------------------------------------- | :-----: | :-------: | :---------- |
| Clock          | `clk`            | 50MHz system clock                             |    I    |     1     | Rising Edge |
| Reset          | `rst_n`          | Asynchronous active-low reset                  |    I    |     1     | Active Low  |
| Frame Start    | `v_begin`        | Pulse indicating the start of a new frame      |    I    |     1     | Active High |
| User Input     | `ui_in`          | 8-bit input for control (pan, zoom, reset)     |    I    |     8     | N/A         |
| User IO Input  | `uio_in`         | Bidirectional IO pins used as inputs           |    I    |     8     | N/A         |
| Center X       | `centre_x`       | X-coordinate of the view center (Q4.12 format) |    O    |    16     | N/A         |
| Center Y       | `centre_y`       | Y-coordinate of the view center (Q4.12 format) |    O    |    16     | N/A         |
| Zoom Level     | `zoom_level`     | Current zoom magnification level               |    O    |     8     | N/A         |

#### Notes
* This module translates switch/button presses into changes in the fractal's viewport.
* Coordinates are handled as 16-bit fixed point integer in Q4.12.
* Panning speed scales with zoom: The `pan_step` is reduced at higher zoom levels, allowing for finer control when exploring detailed areas.
* Updates to the output parameters (`centre_x`, `centre_y`, etc.) are registered and only occur when `v_begin` is high, ensuring the entire frame is rendered with the same parameters.

---

### IO Table: `mandelbrot_colour_mapper`

| **Name**        | **Verilog**       | **Description**                                | **I/O** | **Width** | **Trigger** |
| :-------------- | :---------------- | :--------------------------------------------- | :-----: | :-------: | :---------- |
| Clock           | `clk`             | System clock                                   |    I    |     1     | Rising Edge |
| Reset           | `rst_n`           | Asynchronous active-low reset                  |    I    |     1     | Active Low  |
| Iteration Count | `iteration_count` | Escape-time value from the fractal engine      |    I    |     6     | N/A         |
| Color Mode      | `colour_mode`     | Selects one of four color schemes              |    I    |     2     | N/A         |
| In Set Flag     | `in_set`          | High if the point is inside the Mandelbrot set |    I    |     1     | N/A         |
| Red Channel     | `red`             | 2-bit red color component                      |    O    |     2     | N/A         |
| Green Channel   | `green`           | 2-bit green color component                    |    O    |     2     | N/A         |
| Blue Channel    | `blue`            | 2-bit blue color component                     |    O    |     2     | N/A         |

#### Notes
* This is a purely combinational module that maps a 6-bit iteration value to a 6-bit RGB color. Outputs are registered to ensure stable timing.
* If `in_set` is high, the output is always black (`6'b000000`) regardless of the color mode.
* The four available `colour_mode` options provide distinct aesthetics:
    * `2'b00`: **Grayscale**: A simple grayscale gradient.
    * `2'b01`: **Fire**: A gradient from deep red through orange to bright yellow/white.
    * `2'b10`: **Ocean**: A gradient from deep blue through cyan to white.
    * `2'b11`: **Psychedelic**: A vibrant, cycling rainbow pattern.

---

### IO Table: `tt_um_fractal`

| **Name**       | **Verilog** | **Description**                       | **I/O** | **Width** | **Trigger** |
| :------------- | :---------- | :------------------------------------ | :-----: | :-------: | :---------- |
| User Input     | `ui_in`     | 8 dedicated input pins                |    I    |     8     | N/A         |
| User Output    | `uo_out`    | 8 dedicated output pins               |    O    |     8     | N/A         |
| User IO Input  | `uio_in`    | 8 bidirectional IO pins (input path)  |    I    |     8     | N/A         |
| User IO Output | `uio_out`   | 8 bidirectional IO pins (output path) |    O    |     8     | N/A         |
| User IO Enable | `uio_oe`    | 8 IO output enable signals            |    O    |     8     | N/A         |
| Chip Enable    | `ena`       | Always high when design is powered    |    I    |     1     | Active High |
| Clock          | `clk`       | 50MHz system clock                    |    I    |     1     | Rising Edge |
| Reset          | `rst_n`     | Active-low reset                      |    I    |     1     | Active Low  |

#### `tt_um_fractal` Notes
* This module is the top-level wrapper for the TinyTapeout ASIC platform.
* **Pin Mapping (`ui_in`)**:
    * `ui_in[0]`: Zoom In
    * `ui_in[1]`: Zoom Out
    * `ui_in[2]`: Pan Left
    * `ui_in[3]`: Pan Right
    * `ui_in[4]`: Pan Up
    * `ui_in[5]`: Pan Down
    * `ui_in[6]`: Reset View
    * `ui_in[7]`: Enable fractal rendering
* **Pin Mapping (`uio_in`)**:
    * `uio_in[1:0]`: Select Color Mode
* **Pin Mapping (`uo_out`)**:
    * `uo_out[7]`: HSync
    * `uo_out[6]`: Blue[0]
    * `uo_out[5]`: Green[0]
    * `uo_out[4]`: Red[0]
    * `uo_out[3]`: VSync
    * `uo_out[2]`: Blue[1]
    * `uo_out[1]`: Green[1]
    * `uo_out[0]`: Red[1]
* The `uio_oe` bus is tied to `0`, configuring all `uio` pins as inputs.

---

### How to Test

This section outlines a comprehensive test plan for verifying the Mandelbrot fractal generator, from individual units to the full system.

#### Phase 1: Unit Testing
1.  **Clock Domain Testing**
    * Verify clock division from 50MHz to 25MHz.
    * Test reset synchronization and deassertion.
    * Validate timing constraints at maximum frequency.
2.  **Coordinate Generator Testing**
    * Verify X/Y counter sequences (0-639, 0-479 for VGA).
    * Test overflow and wraparound behavior.
    * Validate coordinate mapping to the complex plane.
3.  **Mandelbrot Computation Engine Testing**
    * Test known points: (0,0) should not escape; (-2,0) should escape quickly.
    * Verify iteration limits and escape detection.
    * Test edge cases and boundary conditions.

#### Phase 2: Integration Testing
1.  **VGA Timing Verification**
    * Verify HSYNC/VSYNC timing with VGA standards (640x480@60Hz).
    * Test blanking periods and active video regions.
    * Validate 2-bit RGB colour output levels.
2.  **Parameter Control System**
    * Test VSYNC-synchronized parameter updates.
    * Verify bidirectional pin data transfer during vertical blanking.
    * Test continuous pan control operation (e.g., holding `pan_left`).
    * Validate the `apply_params` signal timing.
3.  **End-to-End Functionality**
    * Generate test patterns like solid colours and gradients.
    * Verify complete Mandelbrot set rendering.
    * Test real-time zoom and pan navigation.
    * Verify no visual artifacts during parameter changes.

#### Phase 3: System Validation
1.  **Performance Testing**
    * Measure frame rate stability during parameter updates.
    * Verify real-time rendering capability with active controls.
    * Test resource utilization within TinyTapeout constraints.
2.  **User Interface Testing**
    * Test all directional controls (zoom in/out, 4-direction pan).
    * Verify the parameter data bus for setting specific coordinates.
    * Test parameter persistence across multiple frames.
    * Validate a smooth navigation experience.

#### Test Bench Scenarios
* Reset behavior verification.
* Single pixel computation test.
* Full frame generation test.
* VGA timing compliance test.
* Input parameter change test (zoom, colour mode).
* 2-bit RGB colour output verification.

#### Success Criteria
* **VGA Timing**: Maintains 60Hz refresh rate with stable sync signals.
* **Resource**: Fits within 1x2 TinyTapeout tile constraints.
* **Interface**: Directional controls respond smoothly with VSYNC synchronization.
* **Navigation**: Real-time zoom and pan with no visual artifacts during parameter updates.
* **Parameter Bus**: Bidirectional interface correctly sets specific coordinates and zoom levels.
* **Quality**: Recognizable Mandelbrot set features with a smooth navigation experience.
* **Colour Output**: Conforms to the standard TinyTapeout VGA pinout.

#### Required External Hardware
* **VGA PMOD**: To connect the FPGA/ASIC output to a standard VGA monitor.