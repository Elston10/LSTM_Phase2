`timescale 1ns / 1ps

module multiplier_tb();

    // Parameters
    parameter WIDTH = 24;        // Updated for 1+3+20 format
    parameter FRAC_BITS = 20;    // Updated for 1+3+20 format
    parameter INT_BITS = 3;
    parameter CLK_PERIOD = 10;
    
    // Testbench signals
    reg [WIDTH-1:0] a;
    reg [WIDTH-1:0] b;
    wire [WIDTH-1:0] prod;
    wire overflow;
    
    // Test statistics
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // Instantiate the multiplier
    multiplier #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .INT_BITS(INT_BITS)
    ) dut (
        .a(a),
        .b(b),
        .prod(prod),
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
        real real_a, real_b, real_prod, expected_val;
        begin
            real_a = fixed_to_real(val_a);
            real_b = fixed_to_real(val_b);
            real_prod = fixed_to_real(result);
            expected_val = real_a * real_b;
            
            $display("----------------------------------------");
            $display("Test #%0d: %s", test_count, test_name);
            $display("A        = %h (%.12f)", val_a, real_a);
            $display("B        = %h (%.12f)", val_b, real_b);
            $display("Product  = %h (%.12f)", result, real_prod);
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
            tolerance = 2.0 / (2.0 ** FRAC_BITS);  // Two LSB tolerance for multiplication
            
            // Calculate expected result
            real_a = fixed_to_real(a);
            real_b = fixed_to_real(b);
            expected_result = real_a * real_b;
            
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
            
            display_test(a, b, prod, overflow, test_name);
            
            // Verify result
            if (is_result_correct(prod, expected, tolerance) && (overflow === expected_ovf)) begin
                $display("PASS");
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL - Expected prod=%h (%.12f), ovf=%b", expected, fixed_to_real(expected), expected_ovf);
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
        $display("Fixed-Point Multiplier Testbench (Sign-Magnitude)");
        $display("Format: 1 sign + %0d integer + %0d fractional bits", INT_BITS, FRAC_BITS);
        $display("Range: -7.99999904632568359375 to +7.99999904632568359375");
        $display("Precision: 0.00000095367431640625 (2^-20)");
        $display("========================================\n");
        
        #100;
        
        // Test 1: Zero × Zero
        a = 24'h078322;  // 0.0
        b = 24'h810d54;  // 0.0
        #10;
        check_result_auto("Zero × Zero");
        
        // Test 2: Zero × Positive
        a = 24'h000000;  // 0.0
        b = real_to_fixed(5.5);    // 5.5
        #10;
        check_result_auto("Zero × Positive");
        
        // Test 3: Zero × Negative
        a = 24'h000000;  // 0.0
        b = real_to_fixed(-5.5);   // -5.5
        #10;
        check_result_auto("Zero × Negative");
        
        // Test 4: One × One
        a = real_to_fixed(1.0);    // 1.0
        b = real_to_fixed(1.0);    // 1.0
        #10;
        check_result_auto("One × One");
        
        // Test 5: Positive × Positive
        a = real_to_fixed(2.5);    // 2.5
        b = real_to_fixed(1.5);    // 1.5
        #10;
        check_result_auto("Positive × Positive");
        
        // Test 6: Positive × Negative
        a = real_to_fixed(2.5);    // 2.5
        b = real_to_fixed(-1.5);   // -1.5
        #10;
        check_result_auto("Positive × Negative");
        
        // Test 7: Negative × Positive
        a = real_to_fixed(-2.5);   // -2.5
        b = real_to_fixed(1.5);    // 1.5
        #10;
        check_result_auto("Negative × Positive");
        
        // Test 8: Negative × Negative
        a = real_to_fixed(-2.5);   // -2.5
        b = real_to_fixed(-1.5);   // -1.5
        #10;
        check_result_auto("Negative × Negative");
        
        // Test 9: Small fractional values
        a = real_to_fixed(0.5);    // 0.5
        b = real_to_fixed(0.25);   // 0.25
        #10;
        check_result_auto("Small Fractional Values");
        
        // Test 10: Very small fractional values
        a = real_to_fixed(0.001);  // 0.001
        b = real_to_fixed(0.001);  // 0.001
        #10;
        check_result_auto("Very Small Fractional Values");
        
        // Test 11: Small × Large
        a = real_to_fixed(0.1);    // 0.1
        b = real_to_fixed(7.0);    // 7.0
        #10;
        check_result_auto("Small × Large");
        
        // Test 12: Multiply by 2
        a = real_to_fixed(3.5);    // 3.5
        b = real_to_fixed(2.0);    // 2.0
        #10;
        check_result_auto("Multiply by 2");
        
        // Test 13: Multiply by 0.5
        a = real_to_fixed(6.0);    // 6.0
        b = real_to_fixed(0.5);    // 0.5
        #10;
        check_result_auto("Multiply by 0.5");
        
        // Test 14: Multiply by -1
        a = real_to_fixed(4.5);    // 4.5
        b = real_to_fixed(-1.0);   // -1.0
        #10;
        check_result_auto("Multiply by -1");
        
        // Test 15: Very small product
        a = real_to_fixed(0.0001);   // 0.0001
        b = real_to_fixed(0.0001);   // 0.0001
        #10;
        check_result_auto("Very Small Product");
        
        // Test 16: Positive overflow
        a = real_to_fixed(7.0);    // 7.0
        b = real_to_fixed(2.0);    // 2.0
        #10;
        check_result_auto("Positive Overflow");
        
        // Test 17: Negative overflow
        a = real_to_fixed(-7.0);   // -7.0
        b = real_to_fixed(2.0);    // 2.0
        #10;
        check_result_auto("Negative Overflow");
        
        // Test 18: Max positive × positive (overflow)
        a = 24'h7FFFFF;  // Max positive (~7.9999990)
        b = real_to_fixed(2.0);    // 2.0
        #10;
        check_result_auto("Max Pos × Pos (Overflow)");
        
        // Test 19: Max negative × positive (overflow)
        a = 24'hFFFFFF;  // Max negative (~-7.9999990)
        b = real_to_fixed(2.0);    // 2.0
        #10;
        check_result_auto("Max Neg × Pos (Overflow)");
        
        // Test 20: Max positive × 1
        a = 24'h7FFFFF;  // Max positive
        b = real_to_fixed(1.0);    // 1.0
        #10;
        check_result_auto("Max Pos × 1");
        
        // Test 21: Max negative × 1
        a = 24'hFFFFFF;  // Max negative
        b = real_to_fixed(1.0);    // 1.0
        #10;
        check_result_auto("Max Neg × 1");
        
        // Test 22: Max positive × -1
        a = 24'h7FFFFF;  // Max positive
        b = real_to_fixed(-1.0);   // -1.0
        #10;
        check_result_auto("Max Pos × -1");
        
        // Test 23: Max negative × -1
        a = 24'hFFFFFF;  // Max negative
        b = real_to_fixed(-1.0);   // -1.0
        #10;
        check_result_auto("Max Neg × -1");
        
        // Test 24: Square of positive
        a = real_to_fixed(2.0);    // 2.0
        b = real_to_fixed(2.0);    // 2.0
        #10;
        check_result_auto("Square of Positive");
        
        // Test 25: Square of negative
        a = real_to_fixed(-2.0);   // -2.0
        b = real_to_fixed(-2.0);   // -2.0
        #10;
        check_result_auto("Square of Negative");
        
        // Test 26: Near boundary multiplication
        a = real_to_fixed(3.9);    // 3.9
        b = real_to_fixed(2.0);    // 2.0
        #10;
        check_result_auto("Near Boundary");
        
        // Test 27: Fractional × fractional
        a = real_to_fixed(0.75);   // 0.75
        b = real_to_fixed(0.5);    // 0.5
        #10;
        check_result_auto("Fractional × Fractional");
        
        // Test 28: Large × large (overflow)
        a = real_to_fixed(5.0);    // 5.0
        b = real_to_fixed(5.0);    // 5.0
        #10;
        check_result_auto("Large × Large (Overflow)");
        
        // Test 29: -Large × -large (overflow)
        a = real_to_fixed(-5.0);   // -5.0
        b = real_to_fixed(-5.0);   // -5.0
        #10;
        check_result_auto("-Large × -Large (Overflow)");
        
        // Test 30: Random test 1
        a = real_to_fixed(3.25);   // 3.25
        b = real_to_fixed(1.75);   // 1.75
        #10;
        check_result_auto("Random Test 1");
        
        // Test 31: Random test 2
        a = real_to_fixed(-4.5);   // -4.5
        b = real_to_fixed(1.5);    // 1.5
        #10;
        check_result_auto("Random Test 2");
        
        // Test 32: Precision test - smallest value
        a = real_to_fixed(0.00000095367431640625);  // 2^-20
        b = real_to_fixed(1.0);    // 1.0
        #10;
        check_result_auto("Smallest Value × 1");
        
        // Test 33: Precision test - smallest × smallest
        a = real_to_fixed(0.00000095367431640625);  // 2^-20
        b = real_to_fixed(0.00000095367431640625);  // 2^-20
        #10;
        check_result_auto("Smallest × Smallest");
        
        // Test 34: Weight-like value multiplication
        a = real_to_fixed(0.0000014580);  // Your smallest weight
        b = real_to_fixed(1.0);
        #10;
        check_result_auto("Weight Value × 1");
        
        // Test 35: Weight × Weight
        a = real_to_fixed(0.0000014580);
        b = real_to_fixed(0.0000014580);
        #10;
        check_result_auto("Weight × Weight");
        
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