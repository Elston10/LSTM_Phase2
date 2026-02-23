`timescale 1ns/1ps

module comparator_tb;
    parameter WIDTH = 16;
    parameter FRAC_BITS = 8;

    reg  [WIDTH-1:0] a;
    reg  [WIDTH-1:0] b;
    wire a_gt_b;
    wire a_lt_b;
    wire a_eq_b;
    wire a_gte_b;
    wire a_lte_b;

    // DUT
    fixed_point_comparator #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) uut (
        .a(a),
        .b(b),
        .a_gt_b(a_gt_b),
        .a_lt_b(a_lt_b),
        .a_eq_b(a_eq_b),
        .a_gte_b(a_gte_b),
        .a_lte_b(a_lte_b)
    );

    initial begin
        $display("Testing 16-bit S7.8 Fixed-Point Comparator");
        $display("Case | a (binary)       | b (binary)       | >  <  =  >= <=");
        $display("-----|------------------|------------------|-------------------");

        // Test 1: Equal values (3.5 == 3.5)
        a = 16'b0000001110000000; // +3.5
        b = 16'b0000001110000000; // +3.5
        #1;
        $display("  1  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 2: Positive > Positive (5.0 > 3.0)
        a = 16'b0000010100000000; // +5.0
        b = 16'b0000001100000000; // +3.0
        #1;
        $display("  2  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 3: Positive < Positive (3.0 < 5.0)
        a = 16'b0000001100000000; // +3.0
        b = 16'b0000010100000000; // +5.0
        #1;
        $display("  3  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 4: Positive > Negative (2.0 > -3.0)
        a = 16'b0000001000000000; // +2.0
        b = 16'b1000001100000000; // -3.0
        #1;
        $display("  4  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 5: Negative < Positive (-2.0 < 3.0)
        a = 16'b1000001000000000; // -2.0
        b = 16'b0000001100000000; // +3.0
        #1;
        $display("  5  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 6: Negative > Negative (-2.0 > -5.0)
        a = 16'b1000001000000000; // -2.0
        b = 16'b1000010100000000; // -5.0
        #1;
        $display("  6  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 7: Negative < Negative (-5.0 < -2.0)
        a = 16'b1000010100000000; // -5.0
        b = 16'b1000001000000000; // -2.0
        #1;
        $display("  7  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 8: Zero comparisons (0.0 == 0.0)
        a = 16'b0000000000000000; // +0.0
        b = 16'b0000000000000000; // +0.0
        #1;
        $display("  8  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 9: Zero vs Positive (0.0 < 1.0)
        a = 16'b0000000000000000; // +0.0
        b = 16'b0000000100000000; // +1.0
        #1;
        $display("  9  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 10: Zero vs Negative (0.0 > -1.0)
        a = 16'b0000000000000000; // +0.0
        b = 16'b1000000100000000; // -1.0
        #1;
        $display(" 10  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 11: Fractional comparison (1.5 > 1.25)
        a = 16'b0000000110000000; // +1.5
        b = 16'b0000000101000000; // +1.25
        #1;
        $display(" 11  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        // Test 12: Small fractions (0.25 < 0.5)
        a = 16'b0000000001000000; // +0.25
        b = 16'b0000000010000000; // +0.5
        #1;
        $display(" 12  | %b | %b | %b  %b  %b  %b  %b", a, b, a_gt_b, a_lt_b, a_eq_b, a_gte_b, a_lte_b);

        $display("\nTest completed.");
        $finish;
    end

endmodule