# SPDX-FileCopyrightText: © 2024 ECE298A Team
# SPDX-License-Identifier: Apache-2.0

# Fast Cocotb test to generate PNG from TinyTapeout fractal generator VGA output
# Optimized for speed with reduced resolution and smart sampling
# To run: make MODULE=test_fractal_png_fast SIM=verilator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer
from PIL import Image
import numpy as np

# Reduced resolution for faster testing
CAPTURE_WIDTH = 160   # 1/4 of 640
CAPTURE_HEIGHT = 120  # 1/4 of 480
SAMPLE_RATE = 4       # Sample every 4th pixel

# VGA timing constants
VGA_WIDTH = 640
VGA_HEIGHT = 480

@cocotb.test()
async def test_fractal_png_fast(dut):
    """Fast fractal PNG generation test with reduced resolution"""
    dut._log.info("Starting FAST fractal PNG generation test")
    
    # Start the clock (50MHz system clock)
    clock = Clock(dut.clk, 20, units="ns")  # 50MHz
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    # Quick reset
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)
    
    # Configure the fractal (enable + color mode 0)
    dut.ui_in.value = 0b10000000
    dut.uio_in.value = 0
    
    dut._log.info("Starting fast frame capture")
    
    # Create smaller image buffer
    image_data = np.zeros((CAPTURE_HEIGHT, CAPTURE_WIDTH, 3), dtype=np.uint8)
    
    # Sample VGA output systematically by waiting for specific coordinates
    sample_count = 0
    total_samples = CAPTURE_WIDTH * CAPTURE_HEIGHT
    captured_pixels = set()
    
    # Wait for VGA to start
    await RisingEdge(dut.v_begin)
    
    # Capture pixels by waiting for VGA timing
    timeout_cycles = 800 * 525 * 3  # More than one full VGA frame
    for _ in range(timeout_cycles):
        if len(captured_pixels) >= total_samples:
            break
            
        await RisingEdge(dut.clk_25mhz)
        
        if dut.vga_active.value:
            vga_x = dut.pixel_x.value.integer  
            vga_y = dut.pixel_y.value.integer
            
            # Sample every SAMPLE_RATE pixels to create reduced resolution
            if (vga_x % SAMPLE_RATE == 0 and vga_y % SAMPLE_RATE == 0):
                # Map to our reduced coordinate system
                x = vga_x // SAMPLE_RATE
                y = vga_y // SAMPLE_RATE
                
                if (x < CAPTURE_WIDTH and y < CAPTURE_HEIGHT and 
                    (x, y) not in captured_pixels):
                    captured_pixels.add((x, y))
                    
                    # Extract RGB using correct TinyTapeout pinout
                    uo_val = int(dut.uo_out.value)
                    
                    # TinyTapeout VGA: R1=bit0, R0=bit4, G1=bit1, G0=bit5, B1=bit2, B0=bit6
                    red = ((uo_val >> 0) & 1) << 1 | ((uo_val >> 4) & 1)
                    green = ((uo_val >> 1) & 1) << 1 | ((uo_val >> 5) & 1)  
                    blue = ((uo_val >> 2) & 1) << 1 | ((uo_val >> 6) & 1)
                    
                    # Convert to 8-bit (0-3 -> 0-255)
                    red_8bit = red * 85
                    green_8bit = green * 85
                    blue_8bit = blue * 85
                    
                    image_data[y, x] = [red_8bit, green_8bit, blue_8bit]
                    
                    sample_count += 1
                    if sample_count % 100 == 0:
                        progress = (sample_count / total_samples) * 100
                        dut._log.info(f"Progress: {progress:.1f}%")
    
    # Create and save the image
    image = Image.fromarray(image_data, 'RGB')
    # Scale up for better visibility
    image_scaled = image.resize((CAPTURE_WIDTH * 4, CAPTURE_HEIGHT * 4), Image.NEAREST)
    image_scaled.save("fractal_fast.png")
    
    dut._log.info("Fast PNG 'fractal_fast.png' generated successfully")
    
    # Quick test of different color modes
    for color_mode in [1, 2, 3]:
        dut._log.info(f"Testing color mode {color_mode}")
        
        # Change color mode
        dut.ui_in.value = 0b10000000 | (color_mode << 3)
        
        # Wait for change to propagate
        await ClockCycles(dut.clk, 50)
        
        # Capture a smaller sample (center portion only)
        sample_data = np.zeros((40, 40, 3), dtype=np.uint8)
        
        for y in range(40):
            for x in range(40):
                await ClockCycles(dut.clk, 5)
                
                uo_val = int(dut.uo_out.value)
                red = ((uo_val >> 4) & 1) | (((uo_val) & 1) << 1)
                green = ((uo_val >> 5) & 1) | (((uo_val >> 1) & 1) << 1)
                blue = ((uo_val >> 6) & 1) | (((uo_val >> 2) & 1) << 1)
                
                red_8bit = (red * 255) // 3
                green_8bit = (green * 255) // 3
                blue_8bit = (blue * 255) // 3
                
                sample_data[y, x] = [red_8bit, green_8bit, blue_8bit]
        
        # Save color mode sample
        sample_image = Image.fromarray(sample_data, 'RGB')
        sample_scaled = sample_image.resize((160, 160), Image.NEAREST)
        sample_scaled.save(f"fractal_fast_mode{color_mode}.png")
        
        dut._log.info(f"Color mode {color_mode} sample saved")

@cocotb.test()
async def test_fractal_basic(dut):
    """Ultra-fast basic functionality test"""
    dut._log.info("Starting basic functionality test")
    
    # Start the clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)
    
    # Enable fractal generation
    dut.ui_in.value = 0b10000000
    
    # Wait and check that outputs are changing
    await ClockCycles(dut.clk, 100)
    
    # Sample outputs over time to verify activity
    samples = []
    for i in range(20):
        await ClockCycles(dut.clk, 10)
        samples.append(int(dut.uo_out.value))
    
    # Check that we get different values (system is active)
    unique_values = len(set(samples))
    dut._log.info(f"Captured {unique_values} unique output values from {len(samples)} samples")
    
    # Test different color modes
    for mode in range(4):
        dut.ui_in.value = 0b10000000 | (mode << 3)
        await ClockCycles(dut.clk, 20)
        output = int(dut.uo_out.value)
        dut._log.info(f"Color mode {mode}: output = 0x{output:02x}")
    
    assert unique_values > 1, "Output should vary over time"
    dut._log.info("Basic functionality test PASSED")
    