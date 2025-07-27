# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = mandelbrot_engine.sv mandelbrot_colour_mapper.sv vga.sv param_controller.sv tt_um_fractal.sv

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
COMPILE_ARGS += -g2012

else

# Gate level simulation:
SIM_BUILD		 = sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# convenience targets
.PHONY: tb-mandelbrot

tb-mandelbrot:
	$(MAKE) clean
	$(MAKE) sim \
	  MODULE=mandelbrot \
	  TOPLEVEL=tb_mandelbrot \
	  VERILOG_SOURCES="$(PWD)/mandelbrot/tb_mandelbrot.v $(VERILOG_SOURCES)" \
	  PYTHONPATH="$(PWD)/mandelbrot"

tb-vga:
	$(MAKE) clean
	$(MAKE) sim \
	  MODULE=vga \
	  TOPLEVEL=tb_vga \
	  VERILOG_SOURCES="$(PWD)/vga/tb_vga.sv $(SRC_DIR)/vga.sv" \
	  PYTHONPATH="$(PWD)/vga"

tb-png:
	$(MAKE) clean
	$(MAKE) sim \
	  MODULE=png \
	  TOPLEVEL=tb_png \
	  VERILOG_SOURCES="$(PWD)/png/tb_png.sv $(VERILOG_SOURCES)" \
	  PYTHONPATH="$(PWD)/png"

tb-engine:
	$(MAKE) clean
	$(MAKE) sim \
	  MODULE=engine \
	  TOPLEVEL=tb_engine \
	  VERILOG_SOURCES="$(PWD)/engine/tb_engine.sv $(VERILOG_SOURCES)" \
	  PYTHONPATH="$(PWD)/engine"


# clean all generated files
clean_all: clean
	rm -f sim_test tb.vcd *.vcd results.xml
	rm -rf sim_build*

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

include $(shell cocotb-config --makefiles)/Makefile.sim
