`timescale 1ns / 1ps

module adder_tb();

    // Parameters
    parameter WIDTH = 28;        // 1 sign + 7 integer + 20 fraction
    parameter FRAC_BITS = 20;    // 20 fractional bits
    parameter INT_BITS = 7;      // 7 integer bits
    parameter CLK_PERIOD = 10;
    
    // Testbench signals
    reg [WIDTH-1:0] a;
    reg [WIDTH-1:0] b;
    wire [WIDTH-1:0] sum;
    wire overflow;
    
    // Test statistics
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // Instantiate the adder
    adder #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .INT_BITS(INT_BITS)
    ) dut (
        .a(a),
        .b(b),
        .sum(sum),
        .overflow(overflow)
    );
    
    // Helper function to convert 2's complement fixed-point to real
    function real fixed_to_real;
        input [WIDTH-1:0] fixed_val;
        integer signed_val;
        begin
            signed_val = $signed(fixed_val);
            fixed_to_real = signed_val / (2.0 ** FRAC_BITS);
        end
    endfunction
    
    // Helper function to convert real to 2's complement fixed-point
    function [WIDTH-1:0] real_to_fixed;
        input real real_val;
        integer scaled;
        begin
            scaled = $rtoi(real_val * (2.0 ** FRAC_BITS));
            real_to_fixed = scaled[WIDTH-1:0];
        end
    endfunction
    
    // Function to check if result is within tolerance
    function automatic is_result_correct;
        input [WIDTH-1:0] actual;
        input [WIDTH-1:0] expected;
        input real tolerance;
        real actual_real, expected_real, diff;
        begin
            actual_real = fixed_to_real(actual);
            expected_real = fixed_to_real(expected);
            diff = actual_real - expected_real;
            if (diff < 0) diff = -diff;
            is_result_correct = (diff <= tolerance);
        end
    endfunction
    
    // Task to display test results
    task display_test;
        input [WIDTH-1:0] val_a;
        input [WIDTH-1:0] val_b;
        input [WIDTH-1:0] result;
        input ovf;
        input [255:0] test_name;
        real real_a, real_b, real_sum, expected_val;
        begin
            real_a = fixed_to_real(val_a);
            real_b = fixed_to_real(val_b);
            real_sum = fixed_to_real(result);
            expected_val = real_a + real_b;
            
            $display("----------------------------------------");
            $display("Test #%0d: %s", test_count, test_name);
            $display("A        = %h (%.12f)", val_a, real_a);
            $display("B        = %h (%.12f)", val_b, real_b);
            $display("Sum      = %h (%.12f)", result, real_sum);
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
        real max_val, min_val;
        begin
            test_count = test_count + 1;
            tolerance = 1.0 / (2.0 ** FRAC_BITS);  // One LSB tolerance
            
            // Calculate expected result
            real_a = fixed_to_real(a);
            real_b = fixed_to_real(b);
            expected_result = real_a + real_b;
            
            // 2's complement range for S7.20
            max_val = (2 ** (INT_BITS)) - (1.0 / (2 ** FRAC_BITS));
            min_val = -(2 ** (INT_BITS));
            expected_ovf = (expected_result > max_val) || (expected_result < min_val);
            
            // Calculate expected fixed-point value
            if (expected_ovf) begin
                if (expected_result > 0)
                    expected = real_to_fixed(max_val);
                else
                    expected = real_to_fixed(min_val);
            end else begin
                expected = real_to_fixed(expected_result);
            end
            
            display_test(a, b, sum, overflow, test_name);
            
            // Verify result
            if (is_result_correct(sum, expected, tolerance) && (overflow === expected_ovf)) begin
                $display("PASS");
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL - Expected sum=%h (%.12f), ovf=%b", expected, fixed_to_real(expected), expected_ovf);
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
        $display("Fixed-Point Adder Testbench (2's Complement)");
        $display("Format: 1 sign + %0d integer + %0d fractional bits", INT_BITS, FRAC_BITS);
        $display("Range: -128.0 to +127.99999904632568359375");
        $display("Precision: 0.00000095367431640625 (2^-20)");
        $display("========================================\n");
        
        #100;
        
        // Test 1: Zero + Zero
        a = real_to_fixed(0.0);
        b = real_to_fixed(0.0);
        #10;
        check_result_auto("Zero + Zero");
        
        // Test 2: Positive + Positive (no overflow)
        a = real_to_fixed(1.5);
        b = real_to_fixed(2.25);
        #10;
        check_result_auto("Positive + Positive");
        
        // Test 3: Negative + Negative (no overflow)
        a = real_to_fixed(-1.5);
        b = real_to_fixed(-2.25);
        #10;
        check_result_auto("Negative + Negative");
        
        // Test 4: Positive + Negative (result positive)
        a = real_to_fixed(5.0);
        b = real_to_fixed(-2.5);
        #10;
        check_result_auto("Positive + Negative (pos result)");
        
        // Test 5: Positive + Negative (result negative)
        a = real_to_fixed(2.5);
        b = real_to_fixed(-5.0);
        #10;
        check_result_auto("Positive + Negative (neg result)");
        
        // Test 6: Opposite numbers (result zero)
        a = real_to_fixed(3.5);
        b = real_to_fixed(-3.5);
        #10;
        check_result_auto("Opposite numbers");
        
        // Test 7: Positive overflow
        a = real_to_fixed(120.0);
        b = real_to_fixed(20.0);
        #10;
        check_result_auto("Positive Overflow");
        
        // Test 8: Negative overflow
        a = real_to_fixed(-120.0);
        b = real_to_fixed(-20.0);
        #10;
        check_result_auto("Negative Overflow");
        
        // Test 9: Maximum positive value
        a = real_to_fixed(127.99999904632568359375);
        b = real_to_fixed(0.0);
        #10;
        check_result_auto("Maximum Positive Value");
        
        // Test 10: Maximum negative value
        a = real_to_fixed(-128.0);
        b = real_to_fixed(0.0);
        #10;
        check_result_auto("Maximum Negative Value");
        
        // Test 11: Small fractional values
        a = real_to_fixed(0.125);
        b = real_to_fixed(0.375);
        #10;
        check_result_auto("Small Fractional Values");
        
        // Test 12: Very small fractional values (testing precision)
        a = real_to_fixed(0.000001);
        b = real_to_fixed(0.000002);
        #10;
        check_result_auto("Very Small Fractional Values");
        
        // Test 13: Near overflow boundary (positive)
        a = real_to_fixed(127.5);
        b = real_to_fixed(0.6);
        #10;
        check_result_auto("Near Positive Boundary");
        
        // Test 14: Near overflow boundary (negative)
        a = real_to_fixed(-127.5);
        b = real_to_fixed(-0.6);
        #10;
        check_result_auto("Near Negative Boundary");
        
        // Test 15: One + One
        a = real_to_fixed(1.0);
        b = real_to_fixed(1.0);
        #10;
        check_result_auto("One + One");
        
        // Test 16: Random mixed values
        a = real_to_fixed(3.75);
        b = real_to_fixed(-1.25);
        #10;
        check_result_auto("Random Mixed Values");
        
        // Test 17: Very small values (near precision limit)
        a = real_to_fixed(0.0000015);
        b = real_to_fixed(0.0000025);
        #10;
        check_result_auto("Very Small Values (Near Precision)");
        
        // Test 18: Edge case - both max positive
        a = real_to_fixed(127.99999904632568359375);
        b = real_to_fixed(127.99999904632568359375);
        #10;
        check_result_auto("Both Max Positive (Overflow)");
        
        // Test 19: Edge case - both max negative
        a = real_to_fixed(-128.0);
        b = real_to_fixed(-128.0);
        #10;
        check_result_auto("Both Max Negative (Overflow)");
        
        // Test 20: Precision test - smallest representable value
        a = real_to_fixed(0.00000095367431640625);  // 2^-20
        b = real_to_fixed(0.00000095367431640625);  // 2^-20
        #10;
        check_result_auto("Smallest Representable Value");
        
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