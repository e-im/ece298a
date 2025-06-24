# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = mandelbrot_engine.sv vga.sv tt_um_fractal.sv

# Default test module - can be overridden with make MODULE=test
MODULE ?= test

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
COMPILE_ARGS += -g2012

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DSIM
COMPILE_ARGS += -g2012
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

# convenience targets
.PHONY: iverilog_test clean_all

# simple iverilog test (when cocotb not available)
iverilog_test:
	@echo "=== Simple iverilog Test ==="
	iverilog -g2012 -o sim_test $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES)) tb.v
	vvp sim_test
	@echo "✅ Test completed! View waveforms: gtkwave tb.vcd"

# clean all generated files
clean_all: clean
	rm -f sim_test tb.vcd *.vcd
	rm -rf sim_build

# help target
help:
	@echo "Available targets:"
	@echo "  make          - Run cocotb test suite (if available)"
	@echo "  make iverilog_test - Run simple iverilog simulation"
	@echo "  make clean    - Clean cocotb build files"
	@echo "  make clean_all - Clean all generated files"
	@echo "  make help     - Show this help"
	@echo ""
	@echo "Gate level simulation:"
	@echo "  make GATES=yes - Run with gate level netlist"
