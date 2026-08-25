`timescale 1ns / 1ps

module tanh_s3_20_tb();

    // Parameters
    parameter WIDTH = 24;
    parameter FRAC_BITS = 20;
    parameter INT_BITS = 3;
    localparam signed [63:0] SCALE = 64'd1048576;  // 2^20
    parameter CLK_PERIOD = 10;
    
    // Testbench signals
    reg [WIDTH-1:0] x;
    wire [WIDTH-1:0] y;
    
    // Test statistics
    integer test_count;
    integer pass_count;
    integer fail_count;
    integer i;
    
    // File handles
    integer log_file;
    integer error_log;
    
    // Instantiate the tanh module
    tanh_s3_20 dut (
        .x(x),
        .y(y)
    );
    
    // ========================================================================
    // HELPER TASKS (Vivado-compatible, no real numbers)
    // ========================================================================
    
    // Task to display fixed-point value in decimal format
    task display_fixed;
        input [WIDTH-1:0] val;
        input [255:0] name;
        reg sign;
        reg [22:0] magnitude;
        integer int_part;
        integer frac_part;
        begin
            sign = val[23];
            magnitude = val[22:0];
            int_part = magnitude >> FRAC_BITS;
            frac_part = magnitude & 24'hFFFFF;
            
            if (sign)
                $write("%s: -%0d.%06d (0x%06X)", name, int_part, (frac_part * 1000000) / SCALE, val);
            else
                $write("%s: +%0d.%06d (0x%06X)", name, int_part, (frac_part * 1000000) / SCALE, val);
        end
    endtask
    
    // Task to convert integer representation to fixed-point
    // Input: integer scaled by 1000000 (e.g., 1500000 = 1.5)
    function [WIDTH-1:0] int_to_fixed;
        input signed [31:0] val_scaled;  // Value * 1000000
        reg sign;
        reg signed [31:0] abs_val;
        reg [22:0] magnitude;
        begin
            sign = (val_scaled < 0);
            abs_val = sign ? -val_scaled : val_scaled;
            // Convert from 1e6 scale to 2^20 scale
            magnitude = (abs_val * SCALE) / 1000000;
            int_to_fixed = {sign, magnitude};
        end
    endfunction
    
    // Task to run a single test
    task run_test;
        input signed [31:0] x_scaled;  // Input scaled by 1000000
        input [255:0] test_name;
        reg [WIDTH-1:0] x_fixed;
        reg [WIDTH-1:0] y_fixed;
        reg sign_match;
        reg magnitude_reasonable;
        reg pass;
        begin
            test_count = test_count + 1;
            
            // Convert to fixed-point
            x_fixed = int_to_fixed(x_scaled);
            x = x_fixed;
            
            // Wait for combinational logic
            #10;
            
            // Get output
            y_fixed = y;
            
            // Basic sanity checks (Vivado-compatible)
            // Check 1: Sign should match for most cases
            sign_match = (x_fixed[23] == y_fixed[23]) || (x_fixed == 24'h000000);
            
            // Check 2: Output magnitude should be <= 1.0 (tanh property)
            magnitude_reasonable = (y_fixed[22:0] <= 23'h100000);  // |y| <= 1.0
            
            // Check 3: Zero input should give zero output
            if (x_fixed == 24'h000000)
                pass = (y_fixed == 24'h000000);
            else
                pass = sign_match && magnitude_reasonable;
            
            if (pass)
                pass_count = pass_count + 1;
            else
                fail_count = fail_count + 1;
            
            // Display results
            $display("----------------------------------------");
            $display("Test %4d: %s", test_count, test_name);
            $write("  Input:  "); display_fixed(x_fixed, ""); $display("");
            $write("  Output: "); display_fixed(y_fixed, ""); $display("");
            $display("  Sign match: %b, Magnitude OK: %b", sign_match, magnitude_reasonable);
            $display("  Status: %s", pass ? "PASS" : "FAIL");
            
            // Write to log file
            $fwrite(log_file, "%06X,%06X,%s\n", x_fixed, y_fixed, pass ? "PASS" : "FAIL");
            
            if (!pass) begin
                $fwrite(error_log, "Test %4d FAILED: %s\n", test_count, test_name);
                $fwrite(error_log, "  Input:  0x%06X\n", x_fixed);
                $fwrite(error_log, "  Output: 0x%06X\n", y_fixed);
            end
        end
    endtask
    
    // Task for boundary test
    task test_boundary;
        input [WIDTH-1:0] val;
        input [255:0] name;
        begin
            test_count = test_count + 1;
            x = val;
            #10;
            
            $display("Boundary Test %4d: %s", test_count, name);
            $display("  Input:  0x%06X", val);
            $display("  Output: 0x%06X", y);
            
            if (y[22:0] <= 23'h100000) begin
                pass_count = pass_count + 1;
                $display("  Status: PASS");
                $fwrite(log_file, "%06X,%06X,PASS\n", val, y);
            end else begin
                fail_count = fail_count + 1;
                $display("  Status: FAIL - Output magnitude > 1.0");
                $fwrite(log_file, "%06X,%06X,FAIL\n", val, y);
                $fwrite(error_log, "Boundary test FAILED: %s\n", name);
            end
        end
    endtask
    
    // ========================================================================
    // MAIN TEST SEQUENCE
    // ========================================================================
    
    initial begin
        // Initialize
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        x = 0;
        
        // Open log files
        log_file = $fopen("tanh_s3_20_test_results.csv", "w");
        error_log = $fopen("tanh_s3_20_errors.log", "w");
        
        $fwrite(log_file, "Input_Hex,Output_Hex,Status\n");
        
        $display("\n================================================================================");
        $display("S3.20 TANH TESTBENCH - VIVADO COMPATIBLE");
        $display("================================================================================");
        $display("Format: 1 sign + %0d integer + %0d fractional bits", INT_BITS, FRAC_BITS);
        $display("LUT: 512 entries, range [0.25, 3.0]");
        $display("================================================================================\n");
        
        #100;
        
        // ====================================================================
        // CATEGORY 1: ZERO AND NEAR-ZERO
        // ====================================================================
        $display("========== CATEGORY 1: ZERO AND NEAR-ZERO ==========\n");
        
        run_test(0, "Zero input");
        run_test(1, "Minimum positive (0.000001)");
        run_test(-1, "Minimum negative (-0.000001)");
        run_test(10, "Small positive (0.00001)");
        run_test(-10, "Small negative (-0.00001)");
        run_test(100, "Small positive (0.0001)");
        run_test(-100, "Small negative (-0.0001)");
        run_test(1000, "Small positive (0.001)");
        run_test(-1000, "Small negative (-0.001)");
        run_test(1458, "Smallest weight (0.001458)");
        run_test(-1458, "Negative smallest weight");
        
        // ====================================================================
        // CATEGORY 2: LINEAR REGION (|x| < 0.25)
        // ====================================================================
        $display("\n========== CATEGORY 2: LINEAR REGION (|x| < 0.25) ==========\n");
        
        run_test(10000, "Linear: 0.01");
        run_test(-10000, "Linear: -0.01");
        run_test(50000, "Linear: 0.05");
        run_test(-50000, "Linear: -0.05");
        run_test(100000, "Linear: 0.1");
        run_test(-100000, "Linear: -0.1");
        run_test(150000, "Linear: 0.15");
        run_test(-150000, "Linear: -0.15");
        run_test(200000, "Linear: 0.2");
        run_test(-200000, "Linear: -0.2");
        run_test(240000, "Linear boundary: 0.24");
        run_test(-240000, "Linear boundary: -0.24");
        run_test(249000, "Just below LUT: 0.249");
        run_test(-249000, "Just below LUT: -0.249");
        
        // ====================================================================
        // CATEGORY 3: LUT BOUNDARY CONDITIONS
        // ====================================================================
        $display("\n========== CATEGORY 3: LUT BOUNDARY CONDITIONS ==========\n");
        
        run_test(250000, "LUT start: 0.25");
        run_test(-250000, "LUT start: -0.25");
        run_test(251000, "Just after LUT start: 0.251");
        run_test(-251000, "Just after LUT start: -0.251");
        run_test(2990000, "Just before LUT end: 2.99");
        run_test(-2990000, "Just before LUT end: -2.99");
        run_test(3000000, "LUT end: 3.0");
        run_test(-3000000, "LUT end: -3.0");
        
        // ====================================================================
        // CATEGORY 4: LUT REGION - UNIFORM SAMPLING
        // ====================================================================
        $display("\n========== CATEGORY 4: LUT REGION - UNIFORM SAMPLING ==========\n");
        
        for (i = 3; i <= 30; i = i + 1) begin
            run_test(i * 100000, "LUT region positive");
            run_test(-i * 100000, "LUT region negative");
        end
        
        // ====================================================================
        // CATEGORY 5: INTERMEDIATE VALUES
        // ====================================================================
        $display("\n========== CATEGORY 5: INTERMEDIATE VALUES ==========\n");
        
        run_test(330000, "Intermediate: 0.33");
        run_test(670000, "Intermediate: 0.67");
        run_test(990000, "Intermediate: 0.99");
        run_test(1250000, "Intermediate: 1.25");
        run_test(1750000, "Intermediate: 1.75");
        run_test(2250000, "Intermediate: 2.25");
        run_test(2750000, "Intermediate: 2.75");
        
        // ====================================================================
        // CATEGORY 6: SATURATION REGION (|x| > 3.0)
        // ====================================================================
        $display("\n========== CATEGORY 6: SATURATION REGION (|x| > 3.0) ==========\n");
        
        run_test(3010000, "Just above saturation: 3.01");
        run_test(-3010000, "Just above saturation: -3.01");
        run_test(3500000, "Saturation: 3.5");
        run_test(-3500000, "Saturation: -3.5");
        run_test(4000000, "Saturation: 4.0");
        run_test(-4000000, "Saturation: -4.0");
        run_test(5000000, "Saturation: 5.0");
        run_test(-5000000, "Saturation: -5.0");
        run_test(6000000, "Saturation: 6.0");
        run_test(-6000000, "Saturation: -6.0");
        run_test(7000000, "Saturation: 7.0");
        run_test(-7000000, "Saturation: -7.0");
        run_test(7900000, "Near maximum: 7.9");
        run_test(-7900000, "Near maximum: -7.9");
        
        // ====================================================================
        // CATEGORY 7: SPECIAL VALUES
        // ====================================================================
        $display("\n========== CATEGORY 7: SPECIAL VALUES ==========\n");
        
        run_test(500000, "Half: 0.5");
        run_test(-500000, "Negative half: -0.5");
        run_test(1000000, "One: 1.0");
        run_test(-1000000, "Negative one: -1.0");
        run_test(2000000, "Two: 2.0");
        run_test(-2000000, "Negative two: -2.0");
        
        // ====================================================================
        // CATEGORY 8: DIRECT HEX BOUNDARY TESTS
        // ====================================================================
        $display("\n========== CATEGORY 8: DIRECT HEX BOUNDARY TESTS ==========\n");
        
        test_boundary(24'h000000, "Zero");
        test_boundary(24'h000001, "Minimum positive magnitude");
        test_boundary(24'h800001, "Minimum negative magnitude");
        test_boundary(24'h040000, "0.25 (LUT min)");
        test_boundary(24'h840000, "-0.25 (LUT min negative)");
        test_boundary(24'h300000, "3.0 (LUT max)");
        test_boundary(24'hB00000, "-3.0 (LUT max negative)");
        test_boundary(24'h100000, "1.0");
        test_boundary(24'h900000, "-1.0");
        test_boundary(24'h7FFFFF, "Maximum positive");
        test_boundary(24'hFFFFFF, "Maximum negative");
        
        // ====================================================================
        // CATEGORY 9: STEP RESPONSE
        // ====================================================================
        $display("\n========== CATEGORY 9: STEP RESPONSE ==========\n");
        
        run_test(250000, "Step: 0.250000");
        run_test(250100, "Step: 0.250100");
        run_test(251000, "Step: 0.251000");
        run_test(255000, "Step: 0.255000");
        
        run_test(1625000, "Step: 1.625000");
        run_test(1625100, "Step: 1.625100");
        
        // ====================================================================
        // CATEGORY 10: DENSE SAMPLING
        // ====================================================================
        $display("\n========== CATEGORY 10: DENSE SAMPLING ==========\n");
        
        // Linear region dense
        for (i = 2; i <= 24; i = i + 2) begin
            run_test(i * 10000, "Dense linear positive");
        end
        
        // LUT region dense
        for (i = 3; i <= 29; i = i + 1) begin
            run_test(i * 100000 + 50000, "Dense LUT intermediate");
        end
        
        #100;
        
        // ====================================================================
        // FINAL STATISTICS
        // ====================================================================
        $display("\n================================================================================");
        $display("TEST SUMMARY");
        $display("================================================================================");
        $display("Total tests:      %0d", test_count);
        $display("Passed:           %0d", pass_count);
        $display("Failed:           %0d", fail_count);
        $display("Pass rate:        %0d.%02d%%", 
                 (pass_count * 100) / test_count,
                 ((pass_count * 10000) / test_count) % 100);
        $display("================================================================================");
        
        if (fail_count == 0) begin
            $display("\n SUCCESS: ALL TESTS PASSED!\n");
        end else begin
            $display("\n WARNING: SOME TESTS FAILED - Check tanh_s3_20_errors.log\n");
        end
        
        $display("Results saved to:");
        $display("  - tanh_s3_20_test_results.csv");
        $display("  - tanh_s3_20_errors.log\n");
        
        // Close files
        $fclose(log_file);
        $fclose(error_log);
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #1000000;  // 1ms timeout
        $display("\nERROR: Testbench timeout!");
        $finish;
    end

endmodule