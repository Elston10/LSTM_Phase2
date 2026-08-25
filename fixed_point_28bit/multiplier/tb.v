`timescale 1ns / 1ps

module multiplier_tb;

    parameter WIDTH = 28;
    parameter FRAC_BITS = 20;

    // DUT signals (IMPORTANT: signed)
    reg  signed [WIDTH-1:0] a;
    reg  signed [WIDTH-1:0] b;
    wire signed [WIDTH-1:0] prod;
    wire overflow;

    integer i;
    integer pass = 0;
    integer fail = 0;

    // DUT
    multiplier #(WIDTH, FRAC_BITS, 7) dut (
        .a(a),
        .b(b),
        .prod(prod),
        .overflow(overflow)
    );

    // ===============================
    // GOLDEN MODEL (BIT-ACCURATE)
    // ===============================
 function automatic signed [WIDTH-1:0] golden_mult;
    input signed [WIDTH-1:0] a_in;
    input signed [WIDTH-1:0] b_in;

    reg signed [(2*WIDTH)-1:0] full;
    reg signed [(2*WIDTH)-1:0] rounded;

    begin
        full = a_in * b_in;

        // MATCH DUT (ROUNDING)
        rounded = full + (1 <<< (FRAC_BITS-1));

        golden_mult = rounded >>> FRAC_BITS;
    end
endfunction

    // ===============================
    // OVERFLOW CHECK (BIT-ACCURATE)
    // ===============================
    function automatic golden_overflow;
        input signed [WIDTH-1:0] a_in;
        input signed [WIDTH-1:0] b_in;

        reg signed [(2*WIDTH)-1:0] full;
        reg sign;
        begin
            full = a_in * b_in;
            sign = full[2*WIDTH-1];

            golden_overflow = |(full[(2*WIDTH-1):(WIDTH+FRAC_BITS)] ^ 
                                { (WIDTH-FRAC_BITS){sign} });
        end
    endfunction

    // ===============================
    // TEST TASK
    // ===============================
    task run_test;
        input signed [WIDTH-1:0] a_in;
        input signed [WIDTH-1:0] b_in;
        input [100:0] name;

        reg signed [WIDTH-1:0] expected;
        reg expected_ovf;

        begin
            a = a_in;
            b = b_in;
            #5;

            expected = golden_mult(a_in, b_in);
            expected_ovf = golden_overflow(a_in, b_in);

            if ((prod === expected) && (overflow === expected_ovf)) begin
                $display("PASS: %s | A=%h B=%h PROD=%h", name, a, b, prod);
                pass = pass + 1;
            end else begin
                $display("FAIL: %s", name);
                $display(" A=%h B=%h", a, b);
                $display(" GOT  = %h (ovf=%b)", prod, overflow);
                $display(" EXP  = %h (ovf=%b)", expected, expected_ovf);
                fail = fail + 1;
            end
        end
    endtask

    // ===============================
    // MAIN TEST
    // ===============================
 initial begin

    $display("\n===== MULTIPLIER TEST START =====\n");

    // ===============================
    // EASY / HUMAN-READABLE TESTS
    // ===============================

    // 1 * 1 = 1
    run_test(28'sd1 <<< FRAC_BITS, 28'sd1 <<< FRAC_BITS, "1 * 1");

    // 2 * 3 = 6
    run_test(28'sd2 <<< FRAC_BITS, 28'sd3 <<< FRAC_BITS, "-2 * 3");

    // 4 * 5 = 20
    run_test(28'sd4 <<< FRAC_BITS, 28'sd5 <<< FRAC_BITS, "4 * 5");

    // ===============================
    // FRACTIONAL TESTS
    // ===============================

    // 0.5 * 0.5 = 0.25
    run_test(28'sd1 <<< (FRAC_BITS-1), 28'sd1 <<< (FRAC_BITS-1), "0.5 * 0.5");

    // 0.25 * 2 = 0.5
    run_test(28'sd1 <<< (FRAC_BITS-2), 28'sd2 <<< FRAC_BITS, "0.25 * 2");

    // 1.5 * 2 = 3
    run_test((28'sd1 <<< FRAC_BITS) + (28'sd1 <<< (FRAC_BITS-1)),
             28'sd2 <<< FRAC_BITS,
             "1.5 * 2");

    // ===============================
    // SIGN TESTS
    // ===============================

    // + * - = -
    run_test(28'sd3 <<< FRAC_BITS, -28'sd2 <<< FRAC_BITS, "3 * -2");

    // - * + = -
    run_test(-28'sd3 <<< FRAC_BITS, 28'sd2 <<< FRAC_BITS, "-3 * 2");

    // - * - = +
    run_test(-28'sd3 <<< FRAC_BITS, -28'sd2 <<< FRAC_BITS, "-3 * -2");

    // ===============================
    // SMALL FRACTION TESTS
    // ===============================

    // 0.125 * 0.25 = 0.03125
    run_test(28'sd1 <<< (FRAC_BITS-3), 28'sd1 <<< (FRAC_BITS-2), "0.125 * 0.25");

    // ===============================
    // ZERO TESTS
    // ===============================

    run_test(0, 28'sd5 <<< FRAC_BITS, "0 * 5");
    run_test(28'sd5 <<< FRAC_BITS, 0, "5 * 0");

    // ===============================
    // OVERFLOW TESTS
    // ===============================

    run_test(28'sd100 <<< FRAC_BITS, 28'sd2 <<< FRAC_BITS, "Overflow +");
    run_test(-28'sd100 <<< FRAC_BITS, 28'sd2 <<< FRAC_BITS, "Overflow -");

    // ===============================
    // RANDOM TESTS
    // ===============================

    for (i = 0; i < 20; i = i + 1) begin
        run_test($random, $random, "Random");
    end

    // ===============================
    // SUMMARY
    // ===============================

    $display("\n===== TEST SUMMARY =====");
    $display("PASS = %0d", pass);
    $display("FAIL = %0d", fail);

    if (fail == 0)
        $display("ALL TESTS PASSED âœ…");
    else
        $display("SOME TESTS FAILED â?Œ");

    $finish;
end

endmodule