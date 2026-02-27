// Testbench for S7.8 Fixed-point tanh approximator
// Tests all regions: linear, LUT, and saturation
// Vivado-compatible version with S7.8 display

`timescale 1ns/1ps

module tb_tanh_approx;

    // Testbench signals
    reg [15:0] x;
    wire [15:0] y;
    
    // Real values for display
    real x_real;
    real y_real;
    
    // S7.8 format display strings
    reg [127:0] x_s7p8_str;
    reg [127:0] y_s7p8_str;
    
    // Instantiate DUT
    tanh_approx dut (
        .x(x),
        .y(y)
    );
    
    // Function to convert S7.8 sign-magnitude to real
    function real s7p8_to_real;
        input [15:0] s7p8_val;
        reg sign;
        reg [14:0] magnitude;
        real result;
        begin
            sign = s7p8_val[15];
            magnitude = s7p8_val[14:0];
            result = magnitude / 256.0;
            s7p8_to_real = sign ? -result : result;
        end
    endfunction
    
    // Function to convert real to S7.8 sign-magnitude
    function [15:0] real_to_s7p8;
        input real val;
        reg sign;
        integer mag_int;
        reg [14:0] magnitude;
        begin
            sign = (val < 0);
            mag_int = $rtoi((val < 0 ? -val : val) * 256.0);
            magnitude = mag_int[14:0];
            real_to_s7p8 = {sign, magnitude};
        end
    endfunction
    
    // Function to format S7.8 value for display
    task format_s7p8;
        input [15:0] val;
        output [127:0] str;
        reg sign;
        reg [6:0] int_part;
        reg [7:0] frac_part;
        begin
            sign = val[15];
            int_part = val[14:8];
            frac_part = val[7:0];
            
            if (sign)
                $sformat(str, "S:1 I:%03d F:%03d", int_part, frac_part);
            else
                $sformat(str, "S:0 I:%03d F:%03d", int_part, frac_part);
        end
    endtask
    
    // Task to test a value
    task test_value;
        input [15:0] test_x;
        input [127:0] description;
        real expected_tanh;
        real error;
        real abs_diff;
        begin
            x = test_x;
            #10;
            x_real = s7p8_to_real(x);
            y_real = s7p8_to_real(y);
            
            // Format S7.8 display strings
            format_s7p8(x, x_s7p8_str);
            format_s7p8(y, y_s7p8_str);
            
            // Manual tanh approximation
            if (x_real > 5.0)
                expected_tanh = 1.0;
            else if (x_real < -5.0)
                expected_tanh = -1.0;
            else
                expected_tanh = (2.0 / (1.0 + $exp(-2.0 * x_real))) - 1.0;
            
            abs_diff = (y_real > expected_tanh) ? (y_real - expected_tanh) : (expected_tanh - y_real);
            error = abs_diff;
            
            $display("%s", description);
            $display("  Input:  x=0x%04h | %s | Real=%7.4f", x, x_s7p8_str, x_real);
            $display("  Output: y=0x%04h | %s | Real=%7.4f", y, y_s7p8_str, y_real);
            $display("  Expected=%7.4f | Error=%7.6f", expected_tanh, error);
            $display("");
        end
    endtask
    
    // Waveform-friendly real conversions
    real x_real_wave;
    real y_real_wave;
    
    // Extract components for waveform viewing
    wire x_sign = x[15];
    wire [6:0] x_int = x[14:8];
    wire [7:0] x_frac = x[7:0];
    
    wire y_sign = y[15];
    wire [6:0] y_int = y[14:8];
    wire [7:0] y_frac = y[7:0];
    
    always @(*) begin
        x_real_wave = s7p8_to_real(x);
        y_real_wave = s7p8_to_real(y);
    end
    
    // Main test
    initial begin
        $display("\n==================================================================");
        $display("  S7.8 Tanh Approximation Testbench");
        $display("  Format: S7.8 = 1 sign bit + 7 integer bits + 8 fractional bits");
        $display("  Display: S:X I:YYY F:ZZZ (Sign:X Integer:YYY Fractional:ZZZ)");
        $display("==================================================================\n");
        
        // ===== POSITIVE VALUES =====
        $display("===== POSITIVE LINEAR REGION [0, 0.25) =====");
        test_value(16'h0000, "Zero         ");
        test_value(16'h0010, "+0.0625      ");
        test_value(16'h0020, "+0.125       ");
        test_value(16'h0030, "+0.1875      ");
        test_value(16'h003F, "+0.246       ");
        
        $display("===== POSITIVE LUT REGION [0.25, 3.0] =====");
        test_value(16'h0040, "+0.25        ");
        test_value(16'h0060, "+0.375       ");
        test_value(16'h0080, "+0.5         ");
        test_value(16'h00C0, "+0.75        ");
        test_value(16'h0100, "+1.0         ");
        test_value(16'h0180, "+1.5         ");
        test_value(16'h0200, "+2.0         ");
        test_value(16'h0280, "+2.5         ");
        test_value(16'h0300, "+3.0         ");
        
        $display("===== POSITIVE SATURATION REGION (>3.0) =====");
        test_value(16'h0320, "+3.125       ");
        test_value(16'h0400, "+4.0         ");
        test_value(16'h0500, "+5.0         ");
        
        // ===== NEGATIVE VALUES =====
        $display("===== NEGATIVE LINEAR REGION (-0.25, 0) =====");
        test_value(16'h8010, "-0.0625      ");
        test_value(16'h8020, "-0.125       ");
        test_value(16'h8030, "-0.1875      ");
        test_value(16'h803F, "-0.246       ");
        
        $display("===== NEGATIVE LUT REGION [-3.0, -0.25] =====");
        test_value(16'h8040, "-0.25        ");
        test_value(16'h8060, "-0.375       ");
        test_value(16'h8080, "-0.5         ");
        test_value(16'h80C0, "-0.75        ");
        test_value(16'h8100, "-1.0         ");
        test_value(16'h8180, "-1.5         ");
        test_value(16'h8200, "-2.0         ");
        test_value(16'h8280, "-2.5         ");
        test_value(16'h8300, "-3.0         ");
        
        $display("===== NEGATIVE SATURATION REGION (<-3.0) =====");
        test_value(16'h8320, "-3.125       ");
        test_value(16'h8400, "-4.0         ");
        test_value(16'h8500, "-5.0         ");
        
        // ===== BOUNDARY TESTS =====
        $display("===== BOUNDARY TESTS =====");
        test_value(16'h003E, "Just < +0.25 ");
        test_value(16'h0041, "Just > +0.25 ");
        test_value(16'h02FF, "Just < +3.0  ");
        test_value(16'h0301, "Just > +3.0  ");
        test_value(16'h803E, "Just > -0.25 ");
        test_value(16'h8041, "Just < -0.25 ");
        test_value(16'h82FF, "Just > -3.0  ");
        test_value(16'h8301, "Just < -3.0  ");
        
        // ===== SPECIAL VALUES =====
        $display("===== SPECIAL VALUES =====");
        test_value(16'h0001, "Min Positive ");
        test_value(16'h8001, "Min Negative ");
        
        $display("==================================================================");
        $display("  Test Complete!");
        $display("  S7.8 Format Breakdown:");
        $display("  - Bit 15:    Sign (0=positive, 1=negative)");
        $display("  - Bits 14-8: Integer part (7 bits, 0-127)");
        $display("  - Bits 7-0:  Fractional part (8 bits, represents /256)");
        $display("==================================================================\n");
        
        #100;
        $finish;
    end
    
    // Continuous monitor for waveform analysis
    always @(x or y) begin
        #1;
        $display("[MONITOR] Time=%0t | x=0x%04h (S:%b I:%03d F:%03d = %7.4f) | y=0x%04h (S:%b I:%03d F:%03d = %7.4f)",
                 $time, x, x_sign, x_int, x_frac, x_real_wave,
                 y, y_sign, y_int, y_frac, y_real_wave);
    end

endmodule