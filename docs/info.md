<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a Mandelbrot set Fractal Generator with VGA output capability. The system generates real-time Mandelbrot set visualizations by computing the mathematical iteration for each pixel coordinate.

## How to test

### Phase 1: Unit Testing

1. Clock Domain Testing
    1. Verify clock division from 50MHz to 25MHz
    1. Test reset synchronization and deassertion
    1. Validate timing constraints at maximum frequency

1. Coordinate Generator Testing
    1. Verify X/Y counter sequences (0-639, 0-479 for VGA)
    1. Test overflow and wraparound behavior
    1. Validate coordinate mapping to the complex plane
1. Mandelbrot Computation Engine Testing
    1. Test known points: (0,0) should not escape, (-2,0) should escape quickly
    1. Verify iteration limits and escape detection
    1. Test edge cases and boundary conditions

### Phase 2: Integration Testing
1. VGA Timing Verification
    1. Verify HSYNC/VSYNC timing with VGA standards (640x480@60Hz)
    1. Test blanking periods and active video regions
    1. Validate 2-bit RGB colour output levels
1. Parameter Control System
    1. Test VSYNC-synchronized parameter updates
    1. Verify bidirectional pin data transfer during vertical blanking
    1. Test continuous pan control operation (hold pan_left, etc.)
    1. Validate the apply_params signal timing
1. End-to-End Functionality
    1. Generate test patterns (solid colours, gradients)
    1. Verify complete Mandelbrot set rendering
    1. Test real-time zoom and pan navigation
    1. Verify no visual artifacts during parameter changes

### Phase 3: System Validation 
1. Performance Testing
    1. Measure frame rate stability during parameter updates
    1. Verify real-time rendering capability with active controls
    1. Test resource utilization within TinyTapeout constraints
1. User Interface Testing
    1. Test all directional controls (zoom in/out, 4-direction pan)
    1. Verify the parameter data bus for setting specific coordinates
    1. Test parameter persistence across multiple frames
    1. Validate a smooth navigation experience

### Test Bench Structure - Primary test scenarios
- Reset behaviour verification
- Single pixel computation test
- Full frame generation test  
- VGA timing compliance test
- Input parameter change test (zoom, colour mode)
- 2-bit RGB colour output verification
### Success Criteria

VGA Timing: Maintains 60Hz refresh rate with stable sync signals

Resource: Fits within 1x2 TinyTapeout tile constraints

Interface: Directional controls respond smoothly with VSYNC synchronization

Navigation: Real-time zoom and pan with no visual artifacts during parameter updates

Parameter Bus: Bidirectional interface correctly sets specific coordinates and zoom levels

Quality: Recognizable Mandelbrot set features with a smooth navigation experience

Colour Output: Standard TinyTapeout VGA pinout

## External hardware

VGA PMOD