`timescale 1ns/1ps

module tb_tanh;

    // DUT signals
    reg  signed [27:0] x;
    wire signed [27:0] y;

    // Instantiate DUT
    tanh dut (
        .x(x),
        .y(y)
    );

    // =========================
    // CONSTANTS
    // =========================
    localparam SCALE = 1048576.0; // 2^20

    // =========================
    // HELPER FUNCTIONS
    // =========================

    // Convert fixed -> real
    function real fixed_to_real;
        input signed [27:0] val;
        begin
            fixed_to_real = val / SCALE;
        end
    endfunction

    // Convert real -> fixed
    function signed [27:0] real_to_fixed;
        input real val;
        real tmp;
        begin
            tmp = val * SCALE;
            real_to_fixed = $rtoi(tmp);
        end
    endfunction

    // Golden tanh
    function real golden_tanh;
        input real x;
        begin
            golden_tanh = $tanh(x);
        end
    endfunction

    // =========================
    // CHECK TASK
    // =========================
    task check;
        input real in_val;
        real expected, actual, err;
        begin
            x = real_to_fixed(in_val);
            #1;

            expected = golden_tanh(in_val);
            actual   = fixed_to_real(y);
            err      = actual - expected;

            $display("x=%f | y=%f | exp=%f | err=%f",
                      in_val, actual, expected, err);

            // Error threshold (~1 LSB + LUT error)
            if (err > 0.01 || err < -0.01) begin
                $display("❌ ERROR TOO LARGE!");
                $stop;
            end
        end
    endtask

    // =========================
    // MAIN TEST
    // =========================
    integer i;
    real r;

    initial begin
        $display("\n========== TANH TEST START ==========\n");

        // ---------------------------------
        // 1. ZERO TEST
        // ---------------------------------
        check(0.0);

        // ---------------------------------
        // 2. LINEAR REGION (<0.25)
        // ---------------------------------
        check(0.01);
        check(0.1);
        check(0.249);

        // ---------------------------------
        // 3. BOUNDARY TESTS
        // ---------------------------------
        check(0.25);
        check(0.251);
        check(2.999);
        check(3.0);

        // ---------------------------------
        // 4. LUT REGION
        // ---------------------------------
        check(0.5);
        check(1.0);
        check(1.5);
        check(2.0);
        check(2.5);

        // ---------------------------------
        // 5. SATURATION REGION (>3)
        // ---------------------------------
        check(3.5);
        check(5.0);
        check(10.0);

        // ---------------------------------
        // 6. NEGATIVE VALUES
        // ---------------------------------
        check(-0.01);
        check(-0.25);
        check(-1.0);
        check(-2.0);
        check(-3.5);

        // ---------------------------------
        // 7. RANDOM STRESS TEST
        // ---------------------------------
        $display("\n---- RANDOM TEST ----\n");

        for (i = 0; i < 200; i = i + 1) begin
            r = ($urandom_range(-5000, 5000)) / 1000.0; // -5 to +5
            check(r);
        end

        // ---------------------------------
        // 8. FULL LUT SWEEP (CRITICAL 🔥)
        // ---------------------------------
        $display("\n---- LUT SWEEP ----\n");

        for (i = 0; i < 512; i = i + 1) begin
            r = 0.25 + (i * (2.75 / 511.0));
            check(r);
        end

        // ---------------------------------
        // DONE
        // ---------------------------------
        $display("\n✅ ALL TESTS PASSED\n");
        $finish;
    end

endmodule