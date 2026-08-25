`timescale 1ns / 1ps

module comparator_tb();

    // Parameters
    parameter WIDTH = 24;
    parameter FRAC_BITS = 20;
    parameter INT_BITS = 3;
    parameter CLK_PERIOD = 10;
    
    // Testbench signals
    reg [WIDTH-1:0] a;
    reg [WIDTH-1:0] b;
    wire a_gt_b;
    wire a_lt_b;
    wire a_eq_b;
    wire a_gte_b;
    wire a_lte_b;
    
    // Test statistics
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // Instantiate the comparator
    fixed_point_comparator #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) dut (
        .a(a),
        .b(b),
        .a_gt_b(a_gt_b),
        .a_lt_b(a_lt_b),
        .a_eq_b(a_eq_b),
        .a_gte_b(a_gte_b),
        .a_lte_b(a_lte_b)
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
    
    // Task to display test results
    task display_test;
        input [WIDTH-1:0] val_a;
        input [WIDTH-1:0] val_b;
        input [255:0] test_name;
        real real_a, real_b;
        begin
            real_a = fixed_to_real(val_a);
            real_b = fixed_to_real(val_b);
            
            $display("----------------------------------------");
            $display("Test #%0d: %s", test_count, test_name);
            $display("A        = %h (%.12f)", val_a, real_a);
            $display("B        = %h (%.12f)", val_b, real_b);
            $display("Results:");
            $display("  a > b  : %b", a_gt_b);
            $display("  a < b  : %b", a_lt_b);
            $display("  a == b : %b", a_eq_b);
            $display("  a >= b : %b", a_gte_b);
            $display("  a <= b : %b", a_lte_b);
        end
    endtask
    
    // Task to check comparison results
    task check_comparison;
        input [255:0] test_name;
        input expected_gt;
        input expected_lt;
        input expected_eq;
        input expected_gte;
        input expected_lte;
        
        reg result_correct;
        
        begin
            test_count = test_count + 1;
            
            display_test(a, b, test_name);
            
            // Check if all outputs match expected values
            result_correct = (a_gt_b === expected_gt) && 
                           (a_lt_b === expected_lt) && 
                           (a_eq_b === expected_eq) && 
                           (a_gte_b === expected_gte) && 
                           (a_lte_b === expected_lte);
            
            if (result_correct) begin
                $display("PASS");
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL");
                $display("Expected: gt=%b, lt=%b, eq=%b, gte=%b, lte=%b", 
                        expected_gt, expected_lt, expected_eq, expected_gte, expected_lte);
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
        $display("Fixed-Point Comparator Testbench (Sign-Magnitude)");
        $display("Format: 1 sign + %0d integer + %0d fractional bits", INT_BITS, FRAC_BITS);
        $display("Range: -7.99999904632568359375 to +7.99999904632568359375");
        $display("Precision: 0.00000095367431640625 (2^-20)");
        $display("========================================\n");
        
        #100;
        
        // Test 1: Equal values (both zero)
        a = 24'h000000;  // 0.0
        b = 24'h000000;  // 0.0
        #10;
        check_comparison("Both Zero", 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
        
        // Test 2: Equal positive values
        a = real_to_fixed(3.5);
        b = real_to_fixed(3.5);
        #10;
        check_comparison("Equal Positive Values", 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
        
        // Test 3: Equal negative values
        a = real_to_fixed(-3.5);
        b = real_to_fixed(-3.5);
        #10;
        check_comparison("Equal Negative Values", 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
        
        // Test 4: Positive > Positive
        a = real_to_fixed(5.0);
        b = real_to_fixed(2.5);
        #10;
        check_comparison("Positive > Positive", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 5: Positive < Positive
        a = real_to_fixed(2.5);
        b = real_to_fixed(5.0);
        #10;
        check_comparison("Positive < Positive", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        
        // Test 6: Negative > Negative (smaller magnitude)
        a = real_to_fixed(-2.5);
        b = real_to_fixed(-5.0);
        #10;
        check_comparison("Negative > Negative", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 7: Negative < Negative (larger magnitude)
        a = real_to_fixed(-5.0);
        b = real_to_fixed(-2.5);
        #10;
        check_comparison("Negative < Negative", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        
        // Test 8: Positive > Negative
        a = real_to_fixed(2.5);
        b = real_to_fixed(-2.5);
        #10;
        check_comparison("Positive > Negative", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 9: Negative < Positive
        a = real_to_fixed(-2.5);
        b = real_to_fixed(2.5);
        #10;
        check_comparison("Negative < Positive", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        
        // Test 10: Zero > Negative
        a = 24'h000000;  // 0.0
        b = real_to_fixed(-1.0);
        #10;
        check_comparison("Zero > Negative", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 11: Zero < Positive
        a = 24'h000000;  // 0.0
        b = real_to_fixed(1.0);
        #10;
        check_comparison("Zero < Positive", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        
        // Test 12: Positive > Zero
        a = real_to_fixed(1.0);
        b = 24'h000000;  // 0.0
        #10;
        check_comparison("Positive > Zero", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 13: Negative < Zero
        a = real_to_fixed(-1.0);
        b = 24'h000000;  // 0.0
        #10;
        check_comparison("Negative < Zero", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        
        // Test 14: Max positive > smaller positive
        a = 24'h7FFFFF;  // Max positive (~7.9999990)
        b = real_to_fixed(7.0);
        #10;
        check_comparison("Max Pos > Smaller Pos", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 15: Max negative < larger negative
        a = 24'hFFFFFF;  // Max negative (~-7.9999990)
        b = real_to_fixed(-7.0);
        #10;
        check_comparison("Max Neg < Larger Neg", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        
        // Test 16: Small fractional difference (positive)
        a = real_to_fixed(1.001);
        b = real_to_fixed(1.0);
        #10;
        check_comparison("Small Frac Diff (Pos)", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 17: Small fractional difference (negative)
        a = real_to_fixed(-1.001);
        b = real_to_fixed(-1.0);
        #10;
        check_comparison("Small Frac Diff (Neg)", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        
        // Test 18: Very small positive values
        a = real_to_fixed(0.00001);
        b = real_to_fixed(0.000001);
        #10;
        check_comparison("Very Small Positive", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 19: Very small negative values
        a = real_to_fixed(-0.00001);
        b = real_to_fixed(-0.000001);
        #10;
        check_comparison("Very Small Negative", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        
        // Test 20: Smallest representable value vs zero
        a = real_to_fixed(0.00000095367431640625);  // 2^-20
        b = 24'h000000;
        #10;
        check_comparison("Smallest > Zero", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 21: Large positive comparison
        a = real_to_fixed(7.5);
        b = real_to_fixed(7.25);
        #10;
        check_comparison("Large Pos Comparison", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 22: Large negative comparison
        a = real_to_fixed(-7.5);
        b = real_to_fixed(-7.25);
        #10;
        check_comparison("Large Neg Comparison", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        
        // Test 23: One vs Two
        a = real_to_fixed(1.0);
        b = real_to_fixed(2.0);
        #10;
        check_comparison("One < Two", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        
        // Test 24: -One vs -Two
        a = real_to_fixed(-1.0);
        b = real_to_fixed(-2.0);
        #10;
        check_comparison("-One > -Two", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test 25: Weight value comparison
        a = real_to_fixed(0.0000014580);
        b = real_to_fixed(0.000001);
        #10;
        check_comparison("Weight Value Comparison", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        
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