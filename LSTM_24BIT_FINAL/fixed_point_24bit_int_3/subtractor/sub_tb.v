`timescale 1ns / 1ps

module subtractor_tb();

    // Parameters
    parameter WIDTH = 24;        // Updated for 1+3+20 format
    parameter FRAC_BITS = 20;    // Updated for 1+3+20 format
    parameter INT_BITS = 3;
    parameter CLK_PERIOD = 10;
    
    // Testbench signals
    reg [WIDTH-1:0] a;
    reg [WIDTH-1:0] b;
    wire [WIDTH-1:0] diff;
    wire overflow;
    
    // Test statistics
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // Instantiate the subtractor
    sub_fixed #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .INT_BITS(INT_BITS)
    ) dut (
        .a(a),
        .b(b),
        .diff(diff),
        .overflow(overflow)
    );
    
    // Helper function to convert fixed-point to real (sign-magnitude)
    function real fixed_to_real;
        input [WIDTH-1:0] fixed_val;
        reg sign;
        reg [WIDTH-2:0] magnitude;
        real result;
        begin
            sign = fixed_val[WIDTH-1];
            magnitude = fixed_val[WIDTH-2:0];
            result = magnitude / (2.0 ** FRAC_BITS);
            if (sign)
                result = -result;
            fixed_to_real = result;
        end
    endfunction
    
    // Helper function to convert real to fixed-point (sign-magnitude)
    function [WIDTH-1:0] real_to_fixed;
        input real real_val;
        reg sign;
        reg [WIDTH-2:0] magnitude;
        real abs_val;
        begin
            sign = (real_val < 0);
            abs_val = (real_val < 0) ? -real_val : real_val;
            magnitude = abs_val * (2.0 ** FRAC_BITS);
            real_to_fixed = {sign, magnitude};
        end
    endfunction
    
    // Function to check if result is within tolerance
    function automatic is_result_correct;
        input [WIDTH-1:0] actual;
        input [WIDTH-1:0] expected;
        input real tolerance;
        
        real actual_real, expected_real, diff_val;
        
        begin
            actual_real = fixed_to_real(actual);
            expected_real = fixed_to_real(expected);
            diff_val = actual_real - expected_real;
            if (diff_val < 0) diff_val = -diff_val;
            
            is_result_correct = (diff_val <= tolerance);
        end
    endfunction
    
    // Task to display test results
    task display_test;
        input [WIDTH-1:0] val_a;
        input [WIDTH-1:0] val_b;
        input [WIDTH-1:0] result;
        input ovf;
        input [255:0] test_name;
        real real_a, real_b, real_diff, expected_val;
        begin
            real_a = fixed_to_real(val_a);
            real_b = fixed_to_real(val_b);
            real_diff = fixed_to_real(result);
            expected_val = real_a - real_b;
            
            $display("----------------------------------------");
            $display("Test #%0d: %s", test_count, test_name);
            $display("A        = %h (%.12f)", val_a, real_a);
            $display("B        = %h (%.12f)", val_b, real_b);
            $display("Diff     = %h (%.12f)", result, real_diff);
            $display("Expected = %.12f", expected_val);
            $display("Overflow = %b", ovf);
        end
    endtask
    
    // Enhanced task to check result with automatic verification
    task check_result_auto;
        input [255:0] test_name;
        reg [WIDTH-1:0] expected;
        real tolerance;
        real real_a, real_b, expected_result;
        reg expected_ovf;
        
        begin
            test_count = test_count + 1;
            tolerance = 1.0 / (2.0 ** FRAC_BITS);  // One LSB tolerance
            
            // Calculate expected result
            real_a = fixed_to_real(a);
            real_b = fixed_to_real(b);
            expected_result = real_a - real_b;
            
            // Check for expected overflow (S3.20 range)
            expected_ovf = (expected_result > 7.99999904632568359375) || (expected_result < -7.99999904632568359375);
            
            // Calculate expected fixed-point value
            if (expected_ovf) begin
                if (expected_result > 0)
                    expected = 24'h7FFFFF;  // Max positive magnitude
                else
                    expected = 24'hFFFFFF;  // Max negative magnitude
            end else begin
                expected = real_to_fixed(expected_result);
            end
            
            display_test(a, b, diff, overflow, test_name);
            
            // Verify result
            if (is_result_correct(diff, expected, tolerance) && (overflow === expected_ovf)) begin
                $display("PASS");
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL - Expected diff=%h (%.12f), ovf=%b", expected, fixed_to_real(expected), expected_ovf);
                fail_count = fail_count + 1;
            end
            $display("----------------------------------------\n");
        end
    endtask
    
    // Main test sequence
    initial begin
        // Initialize
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        a = 0;
        b = 0;
        
        $display("\n========================================");
        $display("Fixed-Point Subtractor Testbench (Sign-Magnitude)");
        $display("Format: 1 sign + %0d integer + %0d fractional bits", INT_BITS, FRAC_BITS);
        $display("Range: -7.99999904632568359375 to +7.99999904632568359375");
        $display("Precision: 0.00000095367431640625 (2^-20)");
        $display("========================================\n");
        
        #100;
        
        // Test 1: Zero - Zero
        a = 24'h000000;  // 0.0
        b = 24'h000000;  // 0.0
        #10;
        check_result_auto("Zero - Zero");
        
        // Test 2: Positive - Positive (result positive)
        a = real_to_fixed(5.5);    // 5.5
        b = real_to_fixed(2.25);   // 2.25
        #10;
        check_result_auto("Positive - Positive (pos result)");
        
        // Test 3: Positive - Positive (result negative)
        a = real_to_fixed(2.25);   // 2.25
        b = real_to_fixed(5.5);    // 5.5
        #10;
        check_result_auto("Positive - Positive (neg result)");
        
        // Test 4: Negative - Negative (result negative)
        a = real_to_fixed(-5.5);   // -5.5
        b = real_to_fixed(-2.25);  // -2.25
        #10;
        check_result_auto("Negative - Negative (neg result)");
        
        // Test 5: Negative - Negative (result positive)
        a = real_to_fixed(-2.25);  // -2.25
        b = real_to_fixed(-5.5);   // -5.5
        #10;
        check_result_auto("Negative - Negative (pos result)");
        
        // Test 6: Positive - Negative (adds up)
        a = real_to_fixed(3.5);    // 3.5
        b = real_to_fixed(-2.5);   // -2.5
        #10;
        check_result_auto("Positive - Negative");
        
        // Test 7: Negative - Positive (adds magnitudes)
        a = real_to_fixed(-3.5);   // -3.5
        b = real_to_fixed(2.5);    // 2.5
        #10;
        check_result_auto("Negative - Positive");
        
        // Test 8: Same numbers (result zero)
        a = real_to_fixed(4.5);    // 4.5
        b = real_to_fixed(4.5);    // 4.5
        #10;
        check_result_auto("Same numbers");
        
        // Test 9: Positive overflow
        a = real_to_fixed(7.0);    // 7.0
        b = real_to_fixed(-2.0);   // -2.0
        #10;
        check_result_auto("Positive Overflow");
        
        // Test 10: Negative overflow
        a = real_to_fixed(-7.0);   // -7.0
        b = real_to_fixed(2.0);    // 2.0
        #10;
        check_result_auto("Negative Overflow");
        
        // Test 11: Maximum positive - zero
        a = 24'h7FFFFF;  // Max positive (~7.9999990)
        b = 24'h000000;  // 0.0
        #10;
        check_result_auto("Maximum Positive - Zero");
        
        // Test 12: Maximum negative - zero
        a = 24'hFFFFFF;  // Max negative (~-7.9999990)
        b = 24'h000000;  // 0.0
        #10;
        check_result_auto("Maximum Negative - Zero");
        
        // Test 13: Zero - positive
        a = 24'h000000;  // 0.0
        b = real_to_fixed(3.5);    // 3.5
        #10;
        check_result_auto("Zero - Positive");
        
        // Test 14: Zero - negative
        a = 24'h000000;  // 0.0
        b = real_to_fixed(-3.5);   // -3.5
        #10;
        check_result_auto("Zero - Negative");
        
        // Test 15: Small fractional values
        a = real_to_fixed(0.5);    // 0.5
        b = real_to_fixed(0.125);  // 0.125
        #10;
        check_result_auto("Small Fractional Values");
        
        // Test 16: Very small fractional values (testing precision)
        a = real_to_fixed(0.000003);  // 0.000003
        b = real_to_fixed(0.000001);  // 0.000001
        #10;
        check_result_auto("Very Small Fractional Values");
        
        // Test 17: One - One
        a = real_to_fixed(1.0);    // 1.0
        b = real_to_fixed(1.0);    // 1.0
        #10;
        check_result_auto("One - One");
        
        // Test 18: Large positive - small positive
        a = real_to_fixed(7.5);    // 7.5
        b = real_to_fixed(0.25);   // 0.25
        #10;
        check_result_auto("Large - Small Positive");
        
        // Test 19: Large negative - small negative
        a = real_to_fixed(-7.5);   // -7.5
        b = real_to_fixed(-0.25);  // -0.25
        #10;
        check_result_auto("Large - Small Negative");
        
        // Test 20: Near overflow boundary (positive)
        a = real_to_fixed(7.8);    // 7.8
        b = real_to_fixed(-0.5);   // -0.5
        #10;
        check_result_auto("Near Positive Boundary");
        
        // Test 21: Near overflow boundary (negative)
        a = real_to_fixed(-7.8);   // -7.8
        b = real_to_fixed(0.5);    // 0.5
        #10;
        check_result_auto("Near Negative Boundary");
        
        // Test 22: Very small difference
        a = real_to_fixed(1.000001);  // 1.000001
        b = real_to_fixed(1.0);       // 1.0
        #10;
        check_result_auto("Very Small Difference");
        
        // Test 23: Max positive - Max positive
        a = 24'h7FFFFF;  // Max positive
        b = 24'h7FFFFF;  // Max positive
        #10;
        check_result_auto("Max Pos - Max Pos");
        
        // Test 24: Max negative - Max negative
        a = 24'hFFFFFF;  // Max negative
        b = 24'hFFFFFF;  // Max negative
        #10;
        check_result_auto("Max Neg - Max Neg");
        
        // Test 25: Max positive - Max negative (overflow)
        a = 24'h7FFFFF;  // Max positive
        b = 24'hFFFFFF;  // Max negative
        #10;
        check_result_auto("Max Pos - Max Neg (Overflow)");
        
        // Test 26: Random mixed values
        a = real_to_fixed(3.75);   // 3.75
        b = real_to_fixed(1.25);   // 1.25
        #10;
        check_result_auto("Random Mixed Values");
        
        // Test 27: Precision limit test
        a = real_to_fixed(0.00000095367431640625);  // 2^-20 (smallest step)
        b = 24'h000000;  // 0.0
        #10;
        check_result_auto("Smallest Representable Value");
        
        // Test 28: Double precision limit
        a = real_to_fixed(0.0000019073486328125);  // 2 * 2^-20
        b = real_to_fixed(0.00000095367431640625);  // 2^-20
        #10;
        check_result_auto("Two Smallest Values");
        
        #100;
        
        // Display final statistics
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("Pass Rate:   %.2f%%", (pass_count * 100.0) / test_count);
        $display("========================================\n");
        
        if (fail_count == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");
        
        $finish;
    end

endmodule