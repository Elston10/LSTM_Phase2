`timescale 1ns / 1ps

module tb_tanh;
    parameter INPUT_WIDTH = 16;
    parameter OUTPUT_WIDTH = 16;
    parameter ADDR_WIDTH = 9;
    parameter FRAC_BITS = 8;
    
    reg  [INPUT_WIDTH-1:0] input_value;
    wire [OUTPUT_WIDTH-1:0] tanh_out;

    // Instantiate the tanh module
    tanh #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) dut (
        .input_value(input_value),
        .tanh_out(tanh_out)
    );

    integer i;
    integer test_val_int;

    initial begin
        $display("Testbench for tanh module");
        $display("Input\tOutput");
        // Test both negative and positive values of same magnitude from 0 to 4 (32 values each)
        for (i = 0; i < 32; i = i + 1) begin
            // Negative value
            test_val_int = -4 * 256 * i / 31; // S7.8 format
            input_value = test_val_int[INPUT_WIDTH-1:0];
            #10;
            $display("%h\t%h", input_value, tanh_out);
            // Positive value (same magnitude)
            test_val_int = 4 * 256 * i / 31; // S7.8 format
            input_value = test_val_int[INPUT_WIDTH-1:0];
            #10;
            $display("%h\t%h", input_value, tanh_out);
        end
        $finish;
    end
endmodule
