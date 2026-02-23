`timescale 1ns/1ps

module sub_tb;
    parameter WIDTH = 16;
    parameter FRAC_BITS = 8;
    parameter INT_BITS = 7;

    reg  [WIDTH-1:0] a;
    reg  [WIDTH-1:0] b;
    wire [WIDTH-1:0] diff;
    wire overflow;

    // DUT
    sub_fixed #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .INT_BITS(INT_BITS)
    ) uut (
        .a(a),
        .b(b),
        .diff(diff),
        .overflow(overflow)
    );

    initial begin
        $display("Testing 16-bit S7.8 Fixed-Point Subtractor");
        $display("Case | a (binary)       | b (binary)       | diff (binary)    | ovf");
        $display("-----|------------------|------------------|------------------|----");

        // Test 1: Positive - Positive (5.0 - 3.0 = 2.0)
        a = 16'b0000010100000000; // +5.0
        b = 16'b0000001100000000; // +3.0
        #1;
        $display("  1  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 2: Positive - Positive, result negative (3.0 - 5.0 = -2.0)
        a = 16'b0000001100000000; // +3.0
        b = 16'b0000010100000000; // +5.0
        #1;
        $display("  2  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 3: Positive - Negative (5.0 - (-3.0) = 8.0)
        a = 16'b0000010100000000; // +5.0
        b = 16'b1000001100000000; // -3.0
        #1;
        $display("  3  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 4: Negative - Positive (-5.0 - 3.0 = -8.0)
        a = 16'b1000010100000000; // -5.0
        b = 16'b0000001100000000; // +3.0
        #1;
        $display("  4  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 5: Negative - Negative (-5.0 - (-3.0) = -2.0)
        a = 16'b1000010100000000; // -5.0
        b = 16'b1000001100000000; // -3.0
        #1;
        $display("  5  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 6: Negative - Negative, result positive (-3.0 - (-5.0) = 2.0)
        a = 16'b1000001100000000; // -3.0
        b = 16'b1000010100000000; // -5.0
        #1;
        $display("  6  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 7: Zero cases (0.0 - 3.0 = -3.0)
        a = 16'b0000000000000000; // +0.0
        b = 16'b0000001100000000; // +3.0
        #1;
        $display("  7  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 8: Result is zero (3.0 - 3.0 = 0.0)
        a = 16'b0000001100000000; // +3.0
        b = 16'b0000001100000000; // +3.0
        #1;
        $display("  8  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 9: Small fractions (0.5 - 0.25 = 0.25)
        a = 16'b0000000010000000; // +0.5
        b = 16'b0000000001000000; // +0.25
        #1;
        $display("  9  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 10: Positive overflow (100 - (-50) = 150, should overflow)
        a = 16'b0110010000000000; // +100.0
        b = 16'b1011001000000000; // -50.0
        #1;
        $display(" 10  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 11: Negative overflow (-100 - 50 = -150, should overflow)
        a = 16'b1110010000000000; // -100.0
        b = 16'b0011001000000000; // +50.0
        #1;
        $display(" 11  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 12: Max positive - negative (127.996 - (-0.004) = overflow)
        a = 16'b0111111111111111; // +127.996 (max)
        b = 16'b1000000000000001; // -0.004
        #1;
        $display(" 12  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 13: Same magnitude different signs (7.0 - (-7.0) = 14.0)
        a = 16'b0000011100000000; // +7.0
        b = 16'b1000011100000000; // -7.0
        #1;
        $display(" 13  | %b | %b | %b | %b", a, b, diff, overflow);

        // Test 14: Fraction subtraction (1.75 - 0.25 = 1.5)
        a = 16'b0000000111000000; // +1.75
        b = 16'b0000000001000000; // +0.25
        #1;
        $display(" 14  | %b | %b | %b | %b", a, b, diff, overflow);

        $display("\nTest completed.");
        $finish;
    end

endmodule