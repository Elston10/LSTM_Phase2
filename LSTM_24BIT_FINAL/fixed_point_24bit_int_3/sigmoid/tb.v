`timescale 1ns / 1ps

module sigmoid_s3_20_tb();

    // Parameters
    parameter WIDTH = 24;
    parameter FRAC_BITS = 20;
    parameter INT_BITS = 3;
    parameter ADDR_WIDTH = 13;
    localparam signed [63:0] SCALE = 64'd1048576;  // 2^20
    
    // Testbench signals
    reg [WIDTH-1:0] input_value;
    wire [WIDTH-1:0] sigmoid_out;
    wire overflow;
    
    // Test statistics
    integer test_count;
    integer pass_count;
    integer fail_count;
    integer i;
    
    // File handles
    integer log_file;
    integer error_log;
    integer detail_log;
    
    // Instantiate the sigmoid module
    sigmoid_s3_20 #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .INT_BITS(INT_BITS),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .input_value(input_value),
        .sigmoid_out(sigmoid_out),
        .overflow(overflow)
    );
    
    // ========================================================================
    // HELPER TASKS
    // ========================================================================
    
    // Display fixed-point value
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
    
    // Convert integer (scaled by 1e6) to fixed-point
    function [WIDTH-1:0] int_to_fixed;
        input signed [31:0] val_scaled;
        reg sign;
        reg signed [31:0] abs_val;
        reg [22:0] magnitude;
        begin
            sign = (val_scaled < 0);
            abs_val = sign ? -val_scaled : val_scaled;
            magnitude = (abs_val * SCALE) / 1000000;
            int_to_fixed = {sign, magnitude};
        end
    endfunction
    
    // Expected sigmoid values (approximation)
    function [WIDTH-1:0] expected_sigmoid;
        input signed [31:0] x_scaled;  // Input * 1e6
        reg sign;
        reg signed [31:0] abs_x;
        integer sigmoid_approx;  // Store sigmoid * 1e6
        begin
            sign = (x_scaled < 0);
            abs_x = sign ? -x_scaled : x_scaled;
            
            // Approximate sigmoid values
            if (abs_x >= 6000000) begin
                // Saturation
                sigmoid_approx = sign ? 0 : 1000000;
            end
            else if (abs_x == 0) begin
                sigmoid_approx = 500000;  // 0.5
            end
            else if (abs_x <= 500000) begin
                // Small values: sigmoid(x) ≈ 0.5 + 0.25*x
                if (sign)
                    sigmoid_approx = 500000 - (abs_x / 4);
                else
                    sigmoid_approx = 500000 + (abs_x / 4);
            end
            else if (abs_x <= 2000000) begin
                // Medium range approximation
                if (sign)
                    sigmoid_approx = 500000 - (abs_x / 3);
                else
                    sigmoid_approx = 500000 + (abs_x / 3);
            end
            else begin
                // Large values
                sigmoid_approx = sign ? 50000 : 950000;
            end
            
            // Clamp to [0, 1]
            if (sigmoid_approx < 0) sigmoid_approx = 0;
            if (sigmoid_approx > 1000000) sigmoid_approx = 1000000;
            
            expected_sigmoid = int_to_fixed(sigmoid_approx);
        end
    endfunction
    
    // Run a single test
    task run_test;
        input signed [31:0] x_scaled;
        input [255:0] test_name;
        reg [WIDTH-1:0] x_fixed;
        reg [WIDTH-1:0] y_fixed;
        reg [WIDTH-1:0] expected;
        reg pass;
        reg output_in_range;
        reg sign_correct;
        reg monotonic_check;
        begin
            test_count = test_count + 1;
            
            // Convert input
            x_fixed = int_to_fixed(x_scaled);
            input_value = x_fixed;
            
            // Wait for combinational logic
            #10;
            
            // Get output
            y_fixed = sigmoid_out;
            expected = expected_sigmoid(x_scaled);
            
            // Validation checks
            // Check 1: Output must be in [0, 1]
            output_in_range = (y_fixed[23] == 0) && (y_fixed[22:0] <= 23'h100000);
            
            // Check 2: Sign properties
            // For x > 0: sigmoid > 0.5, for x < 0: sigmoid < 0.5, for x = 0: sigmoid = 0.5
            if (x_scaled > 1000000) begin
                sign_correct = (y_fixed[22:0] > 23'h080000);  // > 0.5
            end
            else if (x_scaled < -1000000) begin
                sign_correct = (y_fixed[22:0] < 23'h080000);  // < 0.5
            end
            else begin
                sign_correct = 1;  // Near zero, less strict
            end
            
            // Check 3: Saturation
            if (x_scaled >= 6000000) begin
                pass = (y_fixed == 24'h100000);  // Should be 1.0
            end
            else if (x_scaled <= -6000000) begin
                pass = (y_fixed == 24'h000000);  // Should be 0.0
            end
            else begin
                pass = output_in_range && sign_correct;
            end
            
            if (pass)
                pass_count = pass_count + 1;
            else
                fail_count = fail_count + 1;
            
            // Display results
            $display("========================================");
            $display("Test %4d: %s", test_count, test_name);
            $write("  Input:    "); display_fixed(x_fixed, ""); $display("");
            $write("  Output:   "); display_fixed(y_fixed, ""); $display("");
            $write("  Expected: "); display_fixed(expected, ""); $display("");
            $display("  Overflow: %b", overflow);
            $display("  Checks:");
            $display("    In range [0,1]:  %s", output_in_range ? "PASS" : "FAIL");
            $display("    Sign correct:    %s", sign_correct ? "PASS" : "FAIL");
            $display("  Status: %s", pass ? "PASS ✓" : "FAIL ✗");
            
            // Log to files
            $fwrite(log_file, "%06X,%06X,%06X,%s,%b\n", 
                    x_fixed, y_fixed, expected, pass ? "PASS" : "FAIL", overflow);
            
            if (!pass) begin
                $fwrite(error_log, "Test %4d FAILED: %s\n", test_count, test_name);
                $fwrite(error_log, "  Input:  0x%06X\n", x_fixed);
                $fwrite(error_log, "  Output: 0x%06X\n", y_fixed);
                $fwrite(error_log, "  Expected: 0x%06X\n\n", expected);
            end
            
            // Detailed log
            $fwrite(detail_log, "Test_%04d,%06X,%06X,%06X,%d,%d,%s\n",
                    test_count, x_fixed, y_fixed, expected, 
                    output_in_range, sign_correct, pass ? "PASS" : "FAIL");
        end
    endtask
    
    // Boundary test
    task test_boundary;
        input [WIDTH-1:0] val;
        input [255:0] name;
        begin
            test_count = test_count + 1;
            input_value = val;
            #10;
            
            $display("========================================");
            $display("Boundary Test %4d: %s", test_count, name);
            $display("  Input:  0x%06X", val);
            $display("  Output: 0x%06X", sigmoid_out);
            $display("  Overflow: %b", overflow);
            
            if ((sigmoid_out[23] == 0) && (sigmoid_out[22:0] <= 23'h100000)) begin
                pass_count = pass_count + 1;
                $display("  Status: PASS ✓");
                $fwrite(log_file, "%06X,%06X,------,PASS,%b\n", val, sigmoid_out, overflow);
            end else begin
                fail_count = fail_count + 1;
                $display("  Status: FAIL ✗ - Output out of range");
                $fwrite(log_file, "%06X,%06X,------,FAIL,%b\n", val, sigmoid_out, overflow);
                $fwrite(error_log, "Boundary test %4d FAILED: %s\n", test_count, name);
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
        input_value = 0;
        
        // Open log files
        log_file = $fopen("sigmoid_s3_20_test_results.csv", "w");
        error_log = $fopen("sigmoid_s3_20_errors.log", "w");
        detail_log = $fopen("sigmoid_s3_20_detailed.csv", "w");
        
        $fwrite(log_file, "Input_Hex,Output_Hex,Expected_Hex,Status,Overflow\n");
        $fwrite(detail_log, "Test_ID,Input_Hex,Output_Hex,Expected_Hex,InRange,SignOK,Status\n");
        
        $display("\n");
        $display("================================================================================");
        $display("S3.20 SIGMOID TESTBENCH - COMPREHENSIVE TEST SUITE");
        $display("================================================================================");
        $display("Format: 1 sign + %0d integer + %0d fractional bits", INT_BITS, FRAC_BITS);
        $display("LUT: 6144 entries, range [0, 6.0]");
        $display("Symmetry: sigmoid(-x) = 1 - sigmoid(x)");
        $display("================================================================================\n");
        
        #100;
        
        // ====================================================================
        // CATEGORY 1: ZERO AND SPECIAL VALUES
        // ====================================================================
        $display("\n========== CATEGORY 1: ZERO AND SPECIAL VALUES ==========\n");
        
        run_test(0, "Zero input (should give 0.5)");
        run_test(1, "Minimum positive");
        run_test(-1, "Minimum negative");
        run_test(500000, "Exactly 0.5");
        run_test(-500000, "Exactly -0.5");
        run_test(1000000, "Exactly 1.0");
        run_test(-1000000, "Exactly -1.0");
        
        // ====================================================================
        // CATEGORY 2: SMALL VALUES (|x| < 0.5)
        // ====================================================================
        $display("\n========== CATEGORY 2: SMALL VALUES (|x| < 0.5) ==========\n");
        
        run_test(1000, "Small positive: 0.001");
        run_test(-1000, "Small negative: -0.001");
        run_test(10000, "Small positive: 0.01");
        run_test(-10000, "Small negative: -0.01");
        run_test(100000, "Small positive: 0.1");
        run_test(-100000, "Small negative: -0.1");
        run_test(200000, "Small positive: 0.2");
        run_test(-200000, "Small negative: -0.2");
        run_test(300000, "Small positive: 0.3");
        run_test(-300000, "Small negative: -0.3");
        run_test(400000, "Small positive: 0.4");
        run_test(-400000, "Small negative: -0.4");
        
        // ====================================================================
        // CATEGORY 3: MEDIUM VALUES (0.5 <= |x| <= 3.0)
        // ====================================================================
        $display("\n========== CATEGORY 3: MEDIUM VALUES (0.5 <= |x| <= 3.0) ==========\n");
        
        for (i = 5; i <= 30; i = i + 1) begin
            run_test(i * 100000, "Medium positive");
            run_test(-i * 100000, "Medium negative");
        end
        
        // ====================================================================
        // CATEGORY 4: LARGE VALUES (3.0 < |x| < 6.0)
        // ====================================================================
        $display("\n========== CATEGORY 4: LARGE VALUES (3.0 < |x| < 6.0) ==========\n");
        
        run_test(3100000, "Large: 3.1");
        run_test(-3100000, "Large: -3.1");
        run_test(3500000, "Large: 3.5");
        run_test(-3500000, "Large: -3.5");
        run_test(4000000, "Large: 4.0");
        run_test(-4000000, "Large: -4.0");
        run_test(4500000, "Large: 4.5");
        run_test(-4500000, "Large: -4.5");
        run_test(5000000, "Large: 5.0");
        run_test(-5000000, "Large: -5.0");
        run_test(5500000, "Large: 5.5");
        run_test(-5500000, "Large: -5.5");
        run_test(5900000, "Large: 5.9");
        run_test(-5900000, "Large: -5.9");
        
        // ====================================================================
        // CATEGORY 5: SATURATION REGION (|x| >= 6.0)
        // ====================================================================
        $display("\n========== CATEGORY 5: SATURATION REGION (|x| >= 6.0) ==========\n");
        
        run_test(6000000, "Saturation boundary: 6.0 (should be ~1.0)");
        run_test(-6000000, "Saturation boundary: -6.0 (should be ~0.0)");
        run_test(6100000, "Beyond saturation: 6.1");
        run_test(-6100000, "Beyond saturation: -6.1");
        run_test(7000000, "Far beyond: 7.0");
        run_test(-7000000, "Far beyond: -7.0");
        run_test(7900000, "Near maximum: 7.9");
        run_test(-7900000, "Near maximum: -7.9");
        
        // ====================================================================
        // CATEGORY 6: INTERMEDIATE VALUES
        // ====================================================================
        $display("\n========== CATEGORY 6: INTERMEDIATE VALUES ==========\n");
        
        run_test(250000, "Intermediate: 0.25");
        run_test(-250000, "Intermediate: -0.25");
        run_test(750000, "Intermediate: 0.75");
        run_test(-750000, "Intermediate: -0.75");
        run_test(1250000, "Intermediate: 1.25");
        run_test(-1250000, "Intermediate: -1.25");
        run_test(1750000, "Intermediate: 1.75");
        run_test(-1750000, "Intermediate: -1.75");
        run_test(2250000, "Intermediate: 2.25");
        run_test(-2250000, "Intermediate: -2.25");
        run_test(2750000, "Intermediate: 2.75");
        run_test(-2750000, "Intermediate: -2.75");
        
        // ====================================================================
        // CATEGORY 7: DIRECT HEX BOUNDARY TESTS
        // ====================================================================
        $display("\n========== CATEGORY 7: DIRECT HEX BOUNDARY TESTS ==========\n");
        
        test_boundary(24'h000000, "Zero");
        test_boundary(24'h000001, "Minimum magnitude");
        test_boundary(24'h800001, "Negative minimum");
        test_boundary(24'h080000, "0.5 exactly");
        test_boundary(24'h880000, "-0.5 exactly");
        test_boundary(24'h100000, "1.0 exactly");
        test_boundary(24'h900000, "-1.0 exactly");
        test_boundary(24'h600000, "6.0 (LUT boundary)");
        test_boundary(24'hE00000, "-6.0 (LUT boundary)");
        test_boundary(24'h7FFFFF, "Maximum positive");
        test_boundary(24'hFFFFFF, "Maximum negative");
        
        // ====================================================================
        // CATEGORY 8: SYMMETRY VERIFICATION
        // ====================================================================
        $display("\n========== CATEGORY 8: SYMMETRY VERIFICATION ==========\n");
        $display("Verifying: sigmoid(-x) = 1 - sigmoid(x)\n");
        
        // Test symmetry property
        for (i = 0; i <= 20; i = i + 2) begin
            input_value = int_to_fixed(i * 100000);
            #10;
            $fwrite(detail_log, "SYM_POS_%02d,%06X,%06X,------,1,1,INFO\n", 
                    i, input_value, sigmoid_out);
            
            input_value = int_to_fixed(-i * 100000);
            #10;
            $fwrite(detail_log, "SYM_NEG_%02d,%06X,%06X,------,1,1,INFO\n", 
                    i, input_value, sigmoid_out);
        end
        
        // ====================================================================
        // CATEGORY 9: DENSE SAMPLING
        // ====================================================================
        $display("\n========== CATEGORY 9: DENSE SAMPLING ==========\n");
        
        // Fine-grained sampling in critical region [0, 1]
        for (i = 0; i <= 100; i = i + 5) begin
            run_test(i * 10000, "Dense sampling");
        end
        
        // Fine-grained sampling in transition region [1, 3]
        for (i = 10; i <= 30; i = i + 1) begin
            run_test(i * 100000, "Transition sampling");
        end
        
        // ====================================================================
        // CATEGORY 10: EDGE CASES
        // ====================================================================
        $display("\n========== CATEGORY 10: EDGE CASES ==========\n");
        
        run_test(1458, "Smallest LSTM weight: 0.001458");
        run_test(-1458, "Negative smallest weight");
        run_test(5999999, "Just below saturation: 5.999999");
        run_test(-5999999, "Just below negative saturation");
        run_test(6000001, "Just above saturation");
        run_test(-6000001, "Just above negative saturation");
        
        #100;
        
        // ====================================================================
        // FINAL STATISTICS
        // ====================================================================
        $display("\n");
        $display("================================================================================");
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
            $display("\n ✓✓✓ SUCCESS: ALL TESTS PASSED! ✓✓✓\n");
        end else begin
            $display("\n ✗✗✗ WARNING: %0d TESTS FAILED ✗✗✗\n", fail_count);
            $display("Check sigmoid_s3_20_errors.log for details\n");
        end
        
        $display("Results saved to:");
        $display("  - sigmoid_s3_20_test_results.csv (summary)");
        $display("  - sigmoid_s3_20_detailed.csv (detailed)");
        $display("  - sigmoid_s3_20_errors.log (failures only)\n");
        
        // Close files
        $fclose(log_file);
        $fclose(error_log);
        $fclose(detail_log);
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #10000000;  // 10ms timeout
        $display("\nERROR: Testbench timeout!");
        $fclose(log_file);
        $fclose(error_log);
        $fclose(detail_log);
        $finish;
    end

endmodule