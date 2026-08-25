`timescale 1ns / 1ps

module sigmoid_tb;

    parameter WIDTH = 28;
    parameter FRAC_BITS = 20;

    reg  signed [WIDTH-1:0] input_value;
    wire signed [WIDTH-1:0] sigmoid_out;
    wire overflow;

    integer pass = 0;
    integer fail = 0;
    integer i;

    // DUT
    sigmoid #(WIDTH, FRAC_BITS, 7) dut (
        .input_value(input_value),
        .sigmoid_out(sigmoid_out),
        .overflow(overflow)
    );

    // ===============================
    // FIXED â†’ REAL
    // ===============================
    function real fixed_to_real;
        input signed [WIDTH-1:0] val;
        begin
            fixed_to_real = val / (2.0 ** FRAC_BITS);
        end
    endfunction

    // ===============================
    // REAL â†’ FIXED (2's complement)
    // ===============================
    function signed [WIDTH-1:0] real_to_fixed;
        input real val;
        integer scaled;
        begin
            scaled = $rtoi(val * (2.0 ** FRAC_BITS));

            if (scaled < 0)
                scaled = (1 << WIDTH) + scaled;

            real_to_fixed = scaled & ((1 << WIDTH) - 1);
        end
    endfunction

    // ===============================
    // REFERENCE SIGMOID
    // ===============================
    function real real_sigmoid;
        input real x;
        begin
            if (x > 20.0) real_sigmoid = 1.0;
            else if (x < -20.0) real_sigmoid = 0.0;
            else real_sigmoid = 1.0 / (1.0 + $exp(-x));
        end
    endfunction

    // ===============================
    // TEST TASK
    // ===============================
    task run_test;
        input real x;
        input [100:0] name;

        real expected;
        real actual;
        real error;

        begin
            input_value = real_to_fixed(x);
            #5;

            actual   = fixed_to_real(sigmoid_out);
            expected = real_sigmoid(x);

            error = (actual > expected) ? (actual - expected) : (expected - actual);

            if (error < 0.01) begin
                $display("PASS: %-20s x=%f  -> %f", name, x, actual);
                pass = pass + 1;
            end else begin
                $display("FAIL: %-20s", name);
                $display(" x   = %f", x);
                $display(" DUT = %f", actual);
                $display(" EXP = %f", expected);
                fail = fail + 1;
            end
        end
    endtask

    // ===============================
    // SYMMETRY CHECK
    // ===============================
    task symmetry_test;
        input real x;

        real y1, y2, sum;

        begin
            input_value = real_to_fixed(x);
            #5;
            y1 = fixed_to_real(sigmoid_out);

            input_value = real_to_fixed(-x);
            #5;
            y2 = fixed_to_real(sigmoid_out);

            sum = y1 + y2;

            if ((sum > 0.99) && (sum < 1.01)) begin
                $display("SYM PASS: x=%f", x);
                pass = pass + 1;
            end else begin
                $display("SYM FAIL: x=%f | y1=%f y2=%f", x, y1, y2);
                fail = fail + 1;
            end
        end
    endtask

    // ===============================
    // MAIN
    // ===============================
    initial begin

        $display("\n===== SIGMOID TEST START =====\n");

        // ===============================
        // BASIC
        // ===============================
        run_test(0.0,   "sig(0)");
        run_test(1.0,   "sig(1)");
        run_test(-1.0,  "sig(-1)");

        // ===============================
        // FRACTIONAL
        // ===============================
        run_test(0.5,   "sig(0.5)");
        run_test(-0.5,  "sig(-0.5)");

        // ===============================
        // MID RANGE
        // ===============================
        run_test(2.0,   "sig(2)");
        run_test(-2.0,  "sig(-2)");
        run_test(3.0,   "sig(3)");
        run_test(-3.0,  "sig(-3)");

        // ===============================
        // EDGE
        // ===============================
        run_test(6.0,   "sig(6)");
        run_test(-6.0,  "sig(-6)");

        // ===============================
        // SATURATION
        // ===============================
        run_test(10.0,  "sig(10)");
        run_test(-10.0, "sig(-10)");

        // ===============================
        // SMALL VALUES
        // ===============================
        run_test(0.001,  "sig(0.001)");
        run_test(-0.001, "sig(-0.001)");
// ===============================
// CRITICAL DECIMAL VALUES
// ===============================
run_test(0.123,   "sig(0.123)");
run_test(-0.123,  "sig(-0.123)");

run_test(1.234,   "sig(1.234)");
run_test(-1.234,  "sig(-1.234)");

run_test(2.718,   "sig(e approx)");
run_test(-2.718,  "sig(-e approx)");

run_test(3.1415,  "sig(pi approx)");
run_test(-3.1415, "sig(-pi approx)");

run_test(5.999,   "near +6");
run_test(-5.999,  "near -6");

run_test(6.001,   "beyond +6");
run_test(-6.001,  "beyond -6");
        // ===============================
        // SYMMETRY
        // ===============================
        symmetry_test(0.5);
        symmetry_test(1.0);
        symmetry_test(2.5);

        // ===============================
        // RANDOM TESTS
        // ===============================
        for (i = 0; i < 50; i = i + 1) begin
            run_test(($random % 120) / 10.0, "random");
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