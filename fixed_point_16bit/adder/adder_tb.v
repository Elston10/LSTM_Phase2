`timescale 1ns/1ps

module adder_tb;
    parameter WIDTH = 16;
    parameter FRAC_BITS = 8;
    parameter INT_BITS = 7;

    reg  [WIDTH-1:0] a;
    reg  [WIDTH-1:0] b;
    wire [WIDTH-1:0] sum;
    wire overflow;

    // DUT
    add_fixed #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .INT_BITS(INT_BITS)
    ) uut (
        .a(a),
        .b(b),
        .sum(sum),
        .overflow(overflow)
    );

    initial begin
        $display("Testing 16-bit S7.8 Fixed-Point Adder");
        $display("Case | a (binary)       | b (binary)       | sum (binary)     | ovf");
        $display("-----|------------------|------------------|------------------|----");

        // Test 1: Positive + Positive (1.5 + 2.5 = 4.0)
        a = 16'b0000000110000000; // +1.5
        b = 16'b0000001010000000; // +2.5
        #1;
        $display("  1  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 2: Positive + Negative (5.0 + (-3.0) = 2.0)
        a = 16'b0000010100000000; // +5.0
        b = 16'b1000001100000000; // -3.0
        #1;
        $display("  2  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 3: Negative + Positive (-4.0 + 1.0 = -3.0)
        a = 16'b1000010000000000; // -4.0
        b = 16'b0000000100000000; // +1.0
        #1;
        $display("  3  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 4: Negative + Negative (-2.5 + (-1.5) = -4.0)
        a = 16'b1000001010000000; // -2.5
        b = 16'b1000000110000000; // -1.5
        #1;
        $display("  4  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 5: Zero cases (0.0 + 3.0 = 3.0)
        a = 16'b0000000000000000; // +0.0
        b = 16'b0000001100000000; // +3.0
        #1;
        $display("  5  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 6: Result is zero (3.0 + (-3.0) = 0.0)
        a = 16'b0000001100000000; // +3.0
        b = 16'b1000001100000000; // -3.0
        #1;
        $display("  6  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 7: Small fractions (0.25 + 0.125 = 0.375)
        a = 16'b0000000001000000; // +0.25
        b = 16'b0000000000100000; // +0.125
        #1;
        $display("  7  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 8: Positive overflow (100 + 50 = 150, should overflow)
        a = 16'b0110010000000000; // +100.0
        b = 16'b0011001000000000; // +50.0
        #1;
        $display("  8  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 9: Negative overflow (-100 + (-50) = -150, should overflow)
        a = 16'b1110010000000000; // -100.0
        b = 16'b1011001000000000; // -50.0
        #1;
        $display("  9  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 10: Max positive + small (127.996 + 0.004 = overflow)
        a = 16'b0111111111111111; // +127.996 (max)
        b = 16'b0000000000000001; // +0.004 (1 LSB)
        #1;
        $display(" 10  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 11: Max negative + small (-128.0 + (-0.004) = overflow)
        a = 16'b1000000000000000; // -128.0 (max negative)
        b = 16'b1000000000000001; // -0.004
        #1;
        $display(" 11  | %b | %b | %b | %b", a, b, sum, overflow);

        // Test 12: Large - Small (100 - 99 = 1)
        a = 16'b0110010000000000; // +100.0
        b = 16'b1110001100000000; // -99.0
        #1;
        $display(" 12  | %b | %b | %b | %b", a, b, sum, overflow);

        $display("\nTest completed.");
        $finish;
    end

endmodule