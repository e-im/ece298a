import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.regression import TestFactory
import logging

class VGATestbench:
    def __init__(self, dut, h_active=640, h_front_porch=16, h_sync=96, h_back_porch=48,
                 v_active=480, v_front_porch=10, v_sync=2, v_back_porch=33):
        self.dut = dut
        self.log = logging.getLogger("cocotb.tb")
        
        # VGA timing parameters
        self.H_ACTIVE = h_active
        self.H_FRONT_PORCH = h_front_porch
        self.H_SYNC = h_sync
        self.H_BACK_PORCH = h_back_porch
        
        self.V_ACTIVE = v_active
        self.V_FRONT_PORCH = v_front_porch
        self.V_SYNC = v_sync
        self.V_BACK_PORCH = v_back_porch
        
        # Calculated parameters
        self.H_SYNC_START = self.H_ACTIVE + self.H_FRONT_PORCH
        self.H_SYNC_END = self.H_ACTIVE + self.H_FRONT_PORCH + self.H_SYNC - 1
        self.H_MAX = self.H_ACTIVE + self.H_BACK_PORCH + self.H_FRONT_PORCH + self.H_SYNC - 1
        
        self.V_SYNC_START = self.V_ACTIVE + self.V_FRONT_PORCH
        self.V_SYNC_END = self.V_ACTIVE + self.V_FRONT_PORCH + self.V_SYNC - 1
        self.V_MAX = self.V_ACTIVE + self.V_FRONT_PORCH + self.V_BACK_PORCH + self.V_SYNC - 1
        
        self.error_count = 0
        
    def calculate_expected_signals(self, hpos, vpos):
        """Calculate expected signal values for given position"""
        expected_active = (hpos < self.H_ACTIVE) and (vpos < self.V_ACTIVE)
        expected_hsync = not ((hpos >= self.H_SYNC_START) and (hpos <= self.H_SYNC_END))
        expected_vsync = not ((vpos >= self.V_SYNC_START) and (vpos <= self.V_SYNC_END))
        expected_h_begin = (hpos == self.H_MAX) and (vpos < self.V_ACTIVE)
        expected_v_begin = (hpos == self.H_MAX) and (vpos == self.V_MAX)
        
        return expected_active, expected_hsync, expected_vsync, expected_h_begin, expected_v_begin
    
    def check_signals(self, hpos, vpos, description=""):
        """Check all signals against expected values"""
        expected_active, expected_hsync, expected_vsync, expected_h_begin, expected_v_begin = \
            self.calculate_expected_signals(hpos, vpos)
        
        # Check active signal
        if int(self.dut.active.value) != int(expected_active):
            self.log.error(f"ERROR: active mismatch at h={hpos}, v={vpos}. Expected={expected_active}, Got={self.dut.active.value} {description}")
            self.error_count += 1
            
        # Check hsync signal
        if int(self.dut.hsync.value) != int(expected_hsync):
            self.log.error(f"ERROR: hsync mismatch at h={hpos}, v={vpos}. Expected={expected_hsync}, Got={self.dut.hsync.value} {description}")
            self.error_count += 1
            
        # Check vsync signal
        if int(self.dut.vsync.value) != int(expected_vsync):
            self.log.error(f"ERROR: vsync mismatch at h={hpos}, v={vpos}. Expected={expected_vsync}, Got={self.dut.vsync.value} {description}")
            self.error_count += 1
            
        # Check h_begin signal
        if int(self.dut.h_begin.value) != int(expected_h_begin):
            self.log.error(f"ERROR: h_begin mismatch at h={hpos}, v={vpos}. Expected={expected_h_begin}, Got={self.dut.h_begin.value} {description}")
            self.error_count += 1
            
        # Check v_begin signal
        if int(self.dut.v_begin.value) != int(expected_v_begin):
            self.log.error(f"ERROR: v_begin mismatch at h={hpos}, v={vpos}. Expected={expected_v_begin}, Got={self.dut.v_begin.value} {description}")
            self.error_count += 1

@cocotb.test()
async def test_vga_small(dut):
    """Test with small parameters for faster simulation"""
    # Small test parameters
    tb = VGATestbench(dut, h_active=8, h_front_porch=2, h_sync=4, h_back_porch=2,
                      v_active=6, v_front_porch=1, v_sync=2, v_back_porch=1)
    await run_vga_test(dut, tb)

@cocotb.test()
async def test_vga_standard(dut):
    """Test with standard VGA parameters"""
    # Standard VGA parameters
    tb = VGATestbench(dut, h_active=640, h_front_porch=16, h_sync=96, h_back_porch=48,
                      v_active=480, v_front_porch=10, v_sync=2, v_back_porch=33)
    await run_vga_test(dut, tb)

async def run_vga_test(dut, tb):
    """Main test function"""
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz clock
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.reset.value = 1
    dut.clk_en.value = 0
    
    tb.log.info("=== VGA Timing Generator Test ===")
    tb.log.info(f"H_ACTIVE={tb.H_ACTIVE}, H_FRONT_PORCH={tb.H_FRONT_PORCH}, H_SYNC={tb.H_SYNC}, H_BACK_PORCH={tb.H_BACK_PORCH}")
    tb.log.info(f"V_ACTIVE={tb.V_ACTIVE}, V_FRONT_PORCH={tb.V_FRONT_PORCH}, V_SYNC={tb.V_SYNC}, V_BACK_PORCH={tb.V_BACK_PORCH}")
    tb.log.info(f"H_MAX={tb.H_MAX}, V_MAX={tb.V_MAX}")
    tb.log.info(f"Expected pixels per line: {tb.H_MAX + 1}")
    tb.log.info(f"Expected lines per frame: {tb.V_MAX + 1}")
    
    # Wait a few clocks then release reset
    await ClockCycles(dut.clk, 10)
    dut.reset.value = 0
    
    # Test 1: Reset behavior
    tb.log.info("--- Test 1: Reset Behavior ---")
    await RisingEdge(dut.clk)
    if (int(dut.active.value) != 1 or int(dut.hsync.value) != 1 or int(dut.vsync.value) != 1):
        tb.log.error(f"ERROR: Outputs not in expected reset state")
        tb.log.error(f"  active={dut.active.value} (expected 1), hsync={dut.hsync.value} (expected 1), vsync={dut.vsync.value} (expected 1)")
        tb.error_count += 1
    else:
        tb.log.info("PASS: Reset state correct")
    
    # Test 2: Clock enable functionality
    tb.log.info("--- Test 2: Clock Enable Functionality ---")
    dut.clk_en.value = 0
    await ClockCycles(dut.clk, 10)
    if (int(dut.active.value) != 1 or int(dut.hsync.value) != 1 or int(dut.vsync.value) != 1):
        tb.log.error("ERROR: Outputs changed when clk_en was low")
        tb.error_count += 1
    else:
        tb.log.info("PASS: Clock enable working correctly")
    
    # Test 3: Full frame timing
    tb.log.info("--- Test 3: Full Frame Timing ---")
    dut.clk_en.value = 1
    
    # Monitor for multiple complete frames
    pixel_count = 0
    line_count = 0
    frame_count = 0
    
    for frame in range(2):
        tb.log.info(f"Frame {frame}:")
        
        # Reset position tracking
        hpos_expected = 0
        vpos_expected = 0
        
        for line in range(tb.V_MAX + 1):
            for pixel in range(tb.H_MAX + 1):
                await RisingEdge(dut.clk)
                
                # Update expected position
                if hpos_expected == tb.H_MAX:
                    hpos_expected = 0
                    if vpos_expected == tb.V_MAX:
                        vpos_expected = 0
                    else:
                        vpos_expected += 1
                else:
                    hpos_expected += 1
                
                # Check all signals
                tb.check_signals(hpos_expected, vpos_expected)
                
                # Update event counters
                if int(dut.h_begin.value):
                    line_count += 1
                if int(dut.v_begin.value):
                    frame_count += 1
                pixel_count += 1
        
        tb.log.info(f"  Completed frame {frame}")
    
    # Test 4: Intermittent clock enable
    tb.log.info("--- Test 4: Intermittent Clock Enable ---")
    prev_active = int(dut.active.value)
    prev_hsync = int(dut.hsync.value)
    prev_vsync = int(dut.vsync.value)
    
    # Disable clock enable for a few cycles
    dut.clk_en.value = 0
    await ClockCycles(dut.clk, 5)
    
    # Check that outputs didn't change
    if (int(dut.active.value) != prev_active or 
        int(dut.hsync.value) != prev_hsync or 
        int(dut.vsync.value) != prev_vsync):
        tb.log.error("ERROR: Outputs changed during clk_en = 0")
        tb.error_count += 1
    else:
        tb.log.info("PASS: Outputs stable during clk_en = 0")
    
    # Re-enable and continue
    dut.clk_en.value = 1
    await ClockCycles(dut.clk, 20)
    
    # Test 5: Statistical verification
    tb.log.info("--- Test 5: Statistical Verification ---")
    
    # Reset counters
    hsync_count = 0
    vsync_count = 0
    active_count = 0
    
    # Count signals over one complete frame (count LOW cycles for sync)
    total_cycles = (tb.H_MAX + 1) * (tb.V_MAX + 1)
    for i in range(total_cycles):
        await RisingEdge(dut.clk)
        if int(dut.hsync.value) == 0:  # Count low cycles
            hsync_count += 1
        if int(dut.vsync.value) == 0:  # Count low cycles
            vsync_count += 1
        if int(dut.active.value) == 1:
            active_count += 1
    
    expected_hsync_per_frame = tb.H_SYNC * (tb.V_MAX + 1)
    expected_vsync_per_frame = tb.V_SYNC * (tb.H_MAX + 1)
    expected_active_per_frame = tb.H_ACTIVE * tb.V_ACTIVE
    
    tb.log.info(f"HSYNC low cycles per frame: {hsync_count} (expected {expected_hsync_per_frame})")
    tb.log.info(f"VSYNC low cycles per frame: {vsync_count} (expected {expected_vsync_per_frame})")
    tb.log.info(f"Active cycles per frame: {active_count} (expected {expected_active_per_frame})")
    
    if hsync_count != expected_hsync_per_frame:
        tb.log.error("ERROR: HSYNC count mismatch")
        tb.error_count += 1
    if vsync_count != expected_vsync_per_frame:
        tb.log.error("ERROR: VSYNC count mismatch")
        tb.error_count += 1
    if active_count != expected_active_per_frame:
        tb.log.error("ERROR: Active count mismatch")
        tb.error_count += 1
    
    # Final results
    tb.log.info("=== Test Results ===")
    tb.log.info(f"Total pixels processed: {pixel_count}")
    tb.log.info(f"Lines detected: {line_count}")
    tb.log.info(f"Frames detected: {frame_count}")
    tb.log.info(f"Errors detected: {tb.error_count}")
    
    if tb.error_count == 0:
        tb.log.info("*** ALL TESTS PASSED ***")
    else:
        tb.log.error(f"*** {tb.error_count} TESTS FAILED ***")
        assert False, f"Test failed with {tb.error_count} errors"
    
    tb.log.info("Simulation completed")

# Optional: Test factory for parametric testing
def test_vga_parametric():
    """Factory for generating tests with different parameters"""
    factory = TestFactory(run_vga_test)
    
    # Add different parameter sets
    small_params = VGATestbench(None, h_active=8, h_front_porch=2, h_sync=4, h_back_porch=2,
                               v_active=6, v_front_porch=1, v_sync=2, v_back_porch=1)
    
    standard_params = VGATestbench(None, h_active=640, h_front_porch=16, h_sync=96, h_back_porch=48,
                                  v_active=480, v_front_porch=10, v_sync=2, v_back_porch=33)
    
    factory.add_option("tb", [small_params, standard_params])
    factory.generate_tests()
    s``