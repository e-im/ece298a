# OpenSTA timing analysis script for Mandelbrot fractal generator
# This script performs comprehensive timing analysis using OpenSTA

# Define design parameters
set design "tt_um_fractal"
set top_module $design
set verilog_files {
    src/mandelbrot_engine.sv
    src/mandelbrot_colour_mapper.sv
    src/vga.sv
    src/param_controller.sv
    src/tt_um_fractal.sv
}

# clock definitions
set clk_50mhz_period 20.0;  # 50MHz system clock (20ns period)
set clk_25mhz_period 40.0;  # 25MHz VGA clock (40ns period)

# load liberty file for Sky130
set liberty_file "test/synth/sky130_fd_sc_hd__tt_025C_1v80.lib"

# read liberty file
if {[file exists $liberty_file]} {
    read_liberty $liberty_file
    puts "Liberty file loaded: $liberty_file"
} else {
    puts "Warning: Liberty file not found: $liberty_file"
    exit 1
}

# read Verilog files
foreach vfile $verilog_files {
    if {[file exists $vfile]} {
        read_verilog $vfile
        puts "Loaded Verilog: $vfile"
    } else {
        puts "Warning: Verilog file not found: $vfile"
    }
}

# link design
link_design $top_module

# define clocks
create_clock -name "clk_50mhz" -period $clk_50mhz_period [get_ports clk]
create_clock -name "clk_25mhz" -period $clk_25mhz_period [get_pins "clk_div"]

# set input/output delays
set input_delay [expr $clk_50mhz_period * 0.1]   # 10% of clock period
set output_delay [expr $clk_50mhz_period * 0.1]  # 10% of clock period

set_input_delay $input_delay -clock [get_clocks clk_50mhz] [all_inputs]
set_output_delay $output_delay -clock [get_clocks clk_50mhz] [all_outputs]

# set load capacitance for outputs (typical TinyTapeout load)
set_load 0.05 [all_outputs]

# perform timing analysis
puts "\n=== Timing Analysis Results ==="
puts "Design: $design"
puts "50MHz Clock Period: ${clk_50mhz_period}ns"
puts "25MHz Clock Period: ${clk_25mhz_period}ns"

# check setup timing
puts "\n--- Setup Timing ---"
report_checks -path_delay max -format full_clock_expanded

# check hold timing  
puts "\n--- Hold Timing ---"
report_checks -path_delay min -format full_clock_expanded

# critical path analysis
puts "\n--- Critical Paths ---"
report_checks -path_delay max -path_group clk_50mhz -format full_clock_expanded -nworst 5

# power analysis (if available)
puts "\n--- Power Analysis ---"
if {[info commands report_power] != ""} {
    report_power
} else {
    puts "Power analysis not available in this OpenSTA build"
}

# area report
puts "\n--- Area Report ---"
report_design_area

# clock skew analysis
puts "\n--- Clock Tree Analysis ---"
report_clock_skew

# generate summary
puts "\n=== Timing Summary ==="

# get WNS using report_wns or report_timing
if {[info commands report_wns] != ""} {
    set wns [report_wns]
    puts "WNS (Worst Negative Slack): $wns"
} else {
    # Fallback: use report_timing to get worst slack
    set timing_report [report_timing -max_paths 1 -format full_clock_expanded]
    # Extract slack from timing report (this is a simplified approach)
    puts "WNS (Worst Negative Slack): Check timing report above"
}

# Get TNS using report_tns or get_tns
if {[info commands report_tns] != ""} {
    set tns [report_tns]
    puts "TNS (Total Negative Slack): $tns"
} elseif {[info commands get_tns] != ""} {
    set tns [get_tns]
    puts "TNS (Total Negative Slack): $tns"
} else {
    puts "TNS (Total Negative Slack): Use report_checks for detailed timing"
}

puts "\nTiming analysis completed!"
puts "Check for any timing violations above."