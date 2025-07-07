import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ReadOnly, NextTimeStep
import os

CLOCK_PERIOD_NS = 40 # run on 25mhz direct. clock divider and integration into top not in scope for this.

# small, 8x6, (VGA_MODE=small)
VGA_PARAMS_SMALL = {
    "H_ACTIVE": 8, "H_FRONT_PORCH": 2, "H_SYNC": 4, "H_BACK_PORCH": 2,
    "V_ACTIVE": 6, "V_FRONT_PORCH": 1, "V_SYNC": 2, "V_BACK_PORCH": 1,
}

# real 640x480, (VGA_MODE=large)
VGA_PARAMS_LARGE = {
    "H_ACTIVE": 640, "H_FRONT_PORCH": 16, "H_SYNC": 96, "H_BACK_PORCH": 48,
    "V_ACTIVE": 480, "V_FRONT_PORCH": 10, "V_SYNC": 2, "V_BACK_PORCH": 33,
}

def get_vga_params(dut):
    vga_mode = os.getenv("VGA_MODE", "small").lower()
    if vga_mode == "large":
        params = VGA_PARAMS_LARGE
        dut._log.info("Using LARGE VGA parameters (640x480)")
    else:
        params = VGA_PARAMS_SMALL
        dut._log.info("Using SMALL VGA parameters (8x6)")

    h_total = params["H_ACTIVE"] + params["H_FRONT_PORCH"] + params["H_SYNC"] + params["H_BACK_PORCH"]
    v_total = params["V_ACTIVE"] + params["V_FRONT_PORCH"] + params["V_SYNC"] + params["V_BACK_PORCH"]
    
    return params, h_total, v_total

async def reset_dut(dut):
    dut.rst_n.value = 1
    dut.clk_en.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(100, units="ns") # 2.5 cycles
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

class VgaChecker:
    def __init__(self, dut, params, name="VgaChecker"):
        self.dut = dut
        self.params = params
        self.name = name
        self.log = dut._log

        self.H_SYNC_START = params["H_ACTIVE"] + params["H_FRONT_PORCH"]
        self.H_SYNC_END = self.H_SYNC_START + params["H_SYNC"] - 1
        self.H_MAX = self.H_SYNC_START + params["H_SYNC"] + params["H_BACK_PORCH"] - 1

        self.V_SYNC_START = params["V_ACTIVE"] + params["V_FRONT_PORCH"]
        self.V_SYNC_END = self.V_SYNC_START + params["V_SYNC"] - 1
        self.V_MAX = self.V_SYNC_START + params["V_SYNC"] + params["V_BACK_PORCH"] - 1

        self.hpos = 0
        self.vpos = 0
        self._checker_process = None

    def start(self):
        if self._checker_process is not None: self._checker_process.kill()
        self._checker_process = cocotb.start_soon(self._run_checker())

    def stop(self):
        if self._checker_process is not None:
            self._checker_process.kill()
            self._checker_process = None

    async def _run_checker(self):
        while True:
            await ReadOnly()
            if self.dut.clk_en.value.integer == 0:
                await RisingEdge(self.dut.clk)
                continue
            
            self._check_all_outputs()
            
            await RisingEdge(self.dut.clk)
            if self.hpos == self.H_MAX:
                self.hpos = 0
                if self.vpos == self.V_MAX: self.vpos = 0
                else: self.vpos += 1
            else:
                self.hpos += 1
    
    def _check_all_outputs(self):
        expected_active = (self.hpos < self.params["H_ACTIVE"]) and (self.vpos < self.params["V_ACTIVE"])
        expected_hsync = not (self.H_SYNC_START <= self.hpos <= self.H_SYNC_END)
        expected_vsync = not (self.V_SYNC_START <= self.vpos <= self.V_SYNC_END)
        expected_v_begin = (self.hpos == self.H_MAX) and (self.vpos == self.V_MAX)

        assert self.dut.hpos.value == self.hpos, f"hpos mismatch: DUT={self.dut.hpos.value}, Expected={self.hpos}"
        assert self.dut.vpos.value == self.vpos, f"vpos mismatch: DUT={self.dut.vpos.value}, Expected={self.vpos}"
        assert self.dut.active.value == expected_active, f"active mismatch: DUT={self.dut.active.value}, Expected={expected_active}"
        assert self.dut.hsync.value == expected_hsync, f"hsync mismatch: DUT={self.dut.hsync.value}, Expected={expected_hsync}"
        assert self.dut.vsync.value == expected_vsync, f"vsync mismatch: DUT={self.dut.vsync.value}, Expected={expected_vsync}"
        assert self.dut.v_begin.value == expected_v_begin, f"v_begin mismatch: DUT={self.dut.v_begin.value}, Expected={expected_v_begin}"

@cocotb.test()
async def test_reset_behavior(dut):
    """test output after reset"""
    await cocotb.start(Clock(dut.clk, CLOCK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)
    
    assert dut.hpos.value == 0, f"hpos is not 0 on reset, is {dut.hpos.value}"
    assert dut.vpos.value == 0, f"vpos is not 0 on reset, is {dut.vpos.value}"
    assert dut.active.value == 1, f"active is not 1 on reset, is {dut.active.value}"
    assert dut.hsync.value == 1, f"hsync is not 1 on reset, is {dut.hsync.value}"
    assert dut.vsync.value == 1, f"vsync is not 1 on reset, is {dut.vsync.value}"

@cocotb.test()
async def test_clock_enable_low(dut):
    """test clk_en, counters don't advance"""
    await cocotb.start(Clock(dut.clk, CLOCK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)
    
    dut.clk_en.value = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
        assert dut.hpos.value == 0, "hpos changed while clk_en was low"
        assert dut.vpos.value == 0, "vpos changed while clk_en was low"

@cocotb.test()
async def test_full_frame_timing(dut):
    """full vga checker for 2 frames"""
    params, h_total, v_total = get_vga_params(dut)
    checker = VgaChecker(dut, params)
    
    await cocotb.start(Clock(dut.clk, CLOCK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)
    
    dut.clk_en.value = 1
    checker.start()

    total_pixels_to_sim = 2 * h_total * v_total
    sim_time_ns = total_pixels_to_sim * CLOCK_PERIOD_NS + 50 # 50ns margin
    dut._log.info(f"Simulating ({total_pixels_to_sim} pixels)...")
    await Timer(sim_time_ns, units="ns")
    
    checker.stop()

@cocotb.test()
async def test_intermittent_clock_enable(dut):
    """pause and resume clk_en"""
    params, h_total, v_total = get_vga_params(dut)

    await cocotb.start(Clock(dut.clk, CLOCK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)

    dut.clk_en.value = 1
    for _ in range(50):
        await RisingEdge(dut.clk)

    await ReadOnly()
    paused_hpos = dut.hpos.value.integer
    paused_vpos = dut.vpos.value.integer

    await NextTimeStep()
    dut.clk_en.value = 0
    
    for i in range(10):
        await RisingEdge(dut.clk)
        assert dut.hpos.value == paused_hpos, f"hpos changed to {dut.hpos.value} on cycle {i+1} while clk_en was low"
        assert dut.vpos.value == paused_vpos, f"vpos changed to {dut.vpos.value} on cycle {i+1} while clk_en was low"
    
    dut.clk_en.value = 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    
    expected_next_hpos = (paused_hpos + 1) % h_total
    if paused_hpos == (h_total - 1):
        expected_next_vpos = (paused_vpos + 1) % v_total
    else:
        expected_next_vpos = paused_vpos

    assert dut.hpos.value == expected_next_hpos, f"hpos did not advance correctly. Expected {expected_next_hpos}, got {dut.hpos.value}"
    assert dut.vpos.value == expected_next_vpos, f"vpos did not advance correctly. Expected {expected_next_vpos}, got {dut.vpos.value}"


@cocotb.test()
async def test_statistical_verification(dut):
    """dumb test, counts sync and active over frame to make sure correct # are sent"""
    params, h_total, v_total = get_vga_params(dut)
    
    await cocotb.start(Clock(dut.clk, CLOCK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)

    dut.clk_en.value = 1
    hsync_low_count = 0
    vsync_low_count = 0
    active_high_count = 0

    total_pixels_per_frame = h_total * v_total
    dut._log.info(f"Counting signals over ({total_pixels_per_frame} pixels)...")
    for _ in range(total_pixels_per_frame):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if dut.hsync.value == 0: hsync_low_count += 1
        if dut.vsync.value == 0: vsync_low_count += 1
        if dut.active.value == 1: active_high_count += 1
    
    expected_hsync_low = params["H_SYNC"] * v_total
    expected_vsync_low = params["V_SYNC"] * h_total
    expected_active_high = params["H_ACTIVE"] * params["V_ACTIVE"]

    assert hsync_low_count == expected_hsync_low, "HSYNC low cycle count mismatch"
    assert vsync_low_count == expected_vsync_low, "VSYNC low cycle count mismatch"
    assert active_high_count == expected_active_high, "Active high cycle count mismatch"
