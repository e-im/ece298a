`timescale 1ns / 1ps

module tb_vga();

    // Clock and reset
    reg clk;
    reg reset;
    reg clk_en;
    
    // DUT outputs
    wire active;
    wire hsync;
    wire vsync;
    wire h_begin;
    wire v_begin;
    
    // smol test params
    // parameter H_ACTIVE = 8;
    // parameter H_FRONT_PORCH = 2;
    // parameter H_SYNC = 4;
    // parameter H_BACK_PORCH = 2;
    
    // parameter V_ACTIVE = 6;
    // parameter V_FRONT_PORCH = 1;
    // parameter V_SYNC = 2;
    // parameter V_BACK_PORCH = 1;

    // big test -- ALSO CHANGE TIMEOUT TO 15ms
    parameter H_ACTIVE = 640;
    parameter H_FRONT_PORCH = 16;
    parameter H_SYNC = 96;
    parameter H_BACK_PORCH = 48;
    
    parameter V_ACTIVE = 480;
    parameter V_FRONT_PORCH = 10;
    parameter V_SYNC = 2;
    parameter V_BACK_PORCH = 33;

    
    // Calculated parameters for verification
    parameter H_SYNC_START = H_ACTIVE + H_FRONT_PORCH;
    parameter H_SYNC_END = H_ACTIVE + H_FRONT_PORCH + H_SYNC - 1;
    parameter H_MAX = H_ACTIVE + H_BACK_PORCH + H_FRONT_PORCH + H_SYNC - 1;
    parameter V_SYNC_START = V_ACTIVE + V_FRONT_PORCH;
    parameter V_SYNC_END = V_ACTIVE + V_FRONT_PORCH + V_SYNC - 1;
    parameter V_MAX = V_ACTIVE + V_FRONT_PORCH + V_BACK_PORCH + V_SYNC - 1;
    
    // Instantiate DUT
    vga #(
        .H_ACTIVE(H_ACTIVE),
        .H_FRONT_PORCH(H_FRONT_PORCH),
        .H_SYNC(H_SYNC),
        .H_BACK_PORCH(H_BACK_PORCH),
        .V_ACTIVE(V_ACTIVE),
        .V_FRONT_PORCH(V_FRONT_PORCH),
        .V_SYNC(V_SYNC),
        .V_BACK_PORCH(V_BACK_PORCH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .clk_en(clk_en),
        .active(active),
        .hsync(hsync),
        .vsync(vsync),
        .h_begin(h_begin),
        .v_begin(v_begin)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Test variables
    integer hpos_expected, vpos_expected;
    integer pixel_count;
    integer line_count;
    integer frame_count;
    integer error_count;
    integer i, frame, line, pixel;
    
    // Expected signal values
    reg expected_active, expected_hsync, expected_vsync;
    reg expected_h_begin, expected_v_begin;
    
    // Previous values for stability test
    reg prev_active, prev_hsync, prev_vsync;
    
    // Counters for statistical test
    integer hsync_count, vsync_count, active_count;
    integer expected_hsync_per_frame, expected_vsync_per_frame, expected_active_per_frame;
    
    // Main test sequence
    initial begin
        $dumpfile("vga_tb.vcd");
        $dumpvars(0, tb_vga);
        
        // Initialize
        reset = 1;
        clk_en = 0;
        hpos_expected = 0;
        vpos_expected = 0;
        pixel_count = 0;
        line_count = 0;
        frame_count = 0;
        error_count = 0;
        
        $display("=== VGA Timing Generator Test ===");
        $display("H_ACTIVE=%0d, H_FRONT_PORCH=%0d, H_SYNC=%0d, H_BACK_PORCH=%0d", 
                 H_ACTIVE, H_FRONT_PORCH, H_SYNC, H_BACK_PORCH);
        $display("V_ACTIVE=%0d, V_FRONT_PORCH=%0d, V_SYNC=%0d, V_BACK_PORCH=%0d", 
                 V_ACTIVE, V_FRONT_PORCH, V_SYNC, V_BACK_PORCH);
        $display("H_MAX=%0d, V_MAX=%0d", H_MAX, V_MAX);
        $display("Expected pixels per line: %0d", H_MAX + 1);
        $display("Expected lines per frame: %0d", V_MAX + 1);
        
        // Wait a few clocks then release reset
        repeat(10) @(posedge clk);
        reset = 0;
        
        // Test 1: Reset behavior
        $display("\n--- Test 1: Reset Behavior ---");
        @(posedge clk);
        if (active !== 1'b1 || hsync !== 1'b1 || vsync !== 1'b1) begin
            $display("ERROR: Outputs not in expected reset state");
            $display("  active=%b (expected 1), hsync=%b (expected 1), vsync=%b (expected 1)", active, hsync, vsync);
            error_count = error_count + 1;
        end else begin
            $display("PASS: Reset state correct");
        end
        
        // Test 2: Clock enable functionality
        $display("\n--- Test 2: Clock Enable Functionality ---");
        clk_en = 0;
        repeat(10) @(posedge clk);
        if (active !== 1'b1 || hsync !== 1'b1 || vsync !== 1'b1) begin
            $display("ERROR: Outputs changed when clk_en was low");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Clock enable working correctly");
        end
        
        // Test 3: Full frame timing
        $display("\n--- Test 3: Full Frame Timing ---");
        clk_en = 1;
        
        // Monitor for multiple complete frames
        for (frame = 0; frame < 2; frame = frame + 1) begin
            $display("Frame %0d:", frame);
            
            // Reset position tracking
            hpos_expected = 0;
            vpos_expected = 0;
            
            for (line = 0; line <= V_MAX; line = line + 1) begin
    for (pixel = 0; pixel <= H_MAX; pixel = pixel + 1) begin
        @(posedge clk);
        
        if (hpos_expected == H_MAX) begin
            hpos_expected = 0;
            if (vpos_expected == V_MAX)
                vpos_expected = 0;
            else
                vpos_expected = vpos_expected + 1;
        end else begin
            hpos_expected = hpos_expected + 1;
        end
        
        expected_active = (hpos_expected < H_ACTIVE) && (vpos_expected < V_ACTIVE);
        expected_hsync = !((hpos_expected >= H_SYNC_START) && (hpos_expected <= H_SYNC_END));
        expected_vsync = !((vpos_expected >= V_SYNC_START) && (vpos_expected <= V_SYNC_END));
        
expected_h_begin = (hpos_expected == H_MAX) && (vpos_expected < V_ACTIVE);
expected_v_begin = (hpos_expected == H_MAX) && (vpos_expected == V_MAX);
        

        // Check active signal
        if (active !== expected_active) begin
            $display("ERROR: active mismatch at h=%0d, v=%0d. Expected=%b, Got=%b", 
                     hpos_expected, vpos_expected, expected_active, active);
            error_count = error_count + 1;
        end
        
        // Check hsync signal
        if (hsync !== expected_hsync) begin
            $display("ERROR: hsync mismatch at h=%0d, v=%0d. Expected=%b, Got=%b", 
                     hpos_expected, vpos_expected, expected_hsync, hsync);
            error_count = error_count + 1;
        end
        
        // Check vsync signal
        if (vsync !== expected_vsync) begin
            $display("ERROR: vsync mismatch at h=%0d, v=%0d. Expected=%b, Got=%b", 
                     hpos_expected, vpos_expected, expected_vsync, vsync);
            error_count = error_count + 1;
        end
        
        // Check h_begin signal
        if (h_begin !== expected_h_begin) begin
            $display("ERROR: h_begin mismatch at h=%0d, v=%0d. Expected=%b, Got=%b", 
                     hpos_expected, vpos_expected, expected_h_begin, h_begin);
            error_count = error_count + 1;
        end
        
        // Check v_begin signal
        if (v_begin !== expected_v_begin) begin
            $display("ERROR: v_begin mismatch at h=%0d, v=%0d. Expected=%b, Got=%b", 
                     hpos_expected, vpos_expected, expected_v_begin, v_begin);
            error_count = error_count + 1;
        end
        
        // Update event counters
        if (h_begin) line_count = line_count + 1;
        if (v_begin) frame_count = frame_count + 1;
        pixel_count = pixel_count + 1;
    end
end

            
            $display("  Completed frame %0d", frame);
        end
        
        // Test 4: Intermittent clock enable
        $display("\n--- Test 4: Intermittent Clock Enable ---");
        prev_active = active;
        prev_hsync = hsync;
        prev_vsync = vsync;
        
        // Disable clock enable for a few cycles
        clk_en = 0;
        repeat(5) @(posedge clk);
        
        // Check that outputs didn't change
        if (active !== prev_active || hsync !== prev_hsync || vsync !== prev_vsync) begin
            $display("ERROR: Outputs changed during clk_en = 0");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Outputs stable during clk_en = 0");
        end
        
        // Re-enable and continue
        clk_en = 1;
        repeat(20) @(posedge clk);
        
        // Test 5: Edge case verification
        $display("\n--- Test 5: Statistical Verification ---");
        
        // Reset counters
        hsync_count = 0;
        vsync_count = 0;
        active_count = 0;
        
        // Count signals over one complete frame (count LOW cycles for sync)
        for (i = 0; i < (H_MAX + 1) * (V_MAX + 1); i = i + 1) begin
            @(posedge clk);
            if (!hsync) hsync_count = hsync_count + 1;  // Count low cycles
            if (!vsync) vsync_count = vsync_count + 1;  // Count low cycles
            if (active) active_count = active_count + 1;
        end
        
        expected_hsync_per_frame = H_SYNC * (V_MAX + 1);
        expected_vsync_per_frame = V_SYNC * (H_MAX + 1);
        expected_active_per_frame = H_ACTIVE * V_ACTIVE;
        
        $display("HSYNC low cycles per frame: %0d (expected %0d)", hsync_count, expected_hsync_per_frame);
        $display("VSYNC low cycles per frame: %0d (expected %0d)", vsync_count, expected_vsync_per_frame);
        $display("Active cycles per frame: %0d (expected %0d)", active_count, expected_active_per_frame);
        
        if (hsync_count !== expected_hsync_per_frame) begin
            $display("ERROR: HSYNC count mismatch");
            error_count = error_count + 1;
        end
        if (vsync_count !== expected_vsync_per_frame) begin
            $display("ERROR: VSYNC count mismatch");
            error_count = error_count + 1;
        end
        if (active_count !== expected_active_per_frame) begin
            $display("ERROR: Active count mismatch");
            error_count = error_count + 1;
        end
        
        // Final results
        $display("\n=== Test Results ===");
        $display("Total pixels processed: %0d", pixel_count);
        $display("Lines detected: %0d", line_count);
        $display("Frames detected: %0d", frame_count);
        $display("Errors detected: %0d", error_count);
        
        if (error_count == 0) begin
            $display("*** ALL TESTS PASSED ***");
        end else begin
            $display("*** %0d TESTS FAILED ***", error_count);
        end
        
        $display("\nSimulation completed at time %0t", $time);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        // #100000; // 100us timeout - for small test
        #15000000 // 15ms timeout, for big test
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule