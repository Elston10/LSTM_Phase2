`timescale 1ns/1ps

module multplier_tb;
    parameter WIDTH = 16;
    parameter FRAC_BITS = 8;
    parameter INT_BITS = 7;

    reg  [WIDTH-1:0] a;
    reg  [WIDTH-1:0] b;
    wire [WIDTH-1:0] prod;
    wire overflow;

    // DUT
    mul_fixed #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .INT_BITS(INT_BITS)
    ) uut (
        .a(a),
        .b(b),
        .prod(prod),
        .overflow(overflow)
    );

    initial begin
        $display("Testing 16-bit S7.8 Fixed-Point Multiplier");
        $display("Case | a (binary)       | b (binary)       | prod (binary)    | ovf");
        $display("-----|------------------|------------------|------------------|----");

        // Test 1: Simple positive * positive (1.5 * 0.75 = 1.125)
        a = 16'b0000_0001_0000_0000; // +1.5
        b = 16'h802b;
        #1;
        $display("  1  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 2: Positive * negative (2.0 * -1.0 = -2.0)
        a = 16'b0000001000000000; // +2.0
        b = 16'b1000000100000000; // -1.0
        #1;
        $display("  2  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 3: Negative * positive (-3.0 * 1.5 = -4.5)
        a = 16'b1000001100000000; // -3.0
        b = 16'b0000000110000000; // +1.5
        #1;
        $display("  3  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 4: Negative * negative (-2.0 * -1.5 = 3.0)
        a = 16'b1000001000000000; // -2.0
        b = 16'b1000000110000000; // -1.5
        #1;
        $display("  4  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 5: Zero * anything (0.0 * 5.0 = 0.0)
        a = 16'b0000000000000000; // +0.0
        b = 16'b0000010100000000; // +5.0
        #1;
        $display("  5  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 6: Small fractions (0.25 * 0.125 = 0.03125)
        a = 16'b0000000001000000; // +0.25
        b = 16'b0000000000100000; // +0.125
        #1;
        $display("  6  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 7: Large positive overflow (100 * 2 = 200, should overflow)
        a = 16'b0110010000000000; // +100.0
        b = 16'b0000001000000000; // +2.0
        #1;
        $display("  7  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 8: Large negative overflow (-100 * 2 = -200, should overflow)
        a = 16'b1110010000000000; // -100.0
        b = 16'b0000001000000000; // +2.0
        #1;
        $display("  8  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 9: Maximum positive * small (127.996 * 0.5 = 63.998)
        a = 16'b0111111111111111; // +127.996 (max positive)
        b = 16'b0000000010000000; // +0.5
        #1;
        $display("  9  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 10: Maximum negative * small (-128.0 * 0.5 = -64.0)
        a = 16'b1000000000000000; // -128.0 (max negative)
        b = 16'b0000000010000000; // +0.5
        #1;
        $display(" 10  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 11: LSTM range values (7.2 * -1.0 = -7.2)
        a = 16'b0000011100110011; // +7.2 (approx)
        b = 16'b1000000100000000; // -1.0
        #1;
        $display(" 11  | %b | %b | %b | %b", a, b, prod, overflow);

        // Test 12: Very small numbers (0.00390625 * 0.00390625)
        a = 16'b0000000000000001; // +0.00390625 (1 LSB)
        b = 16'b0000000000000001; // +0.00390625 (1 LSB)
        #1;
        $display(" 12  | %b | %b | %b | %b", a, b, prod, overflow);

        $display("\nTest completed.");
        $finish;
    end

endmodule