`timescale 1ns / 1ps

module tb_sigmoid;
    parameter WIDTH = 16;
    parameter FRAC_BITS = 8;
    parameter ADDR_WIDTH = 11;
    
    reg  [WIDTH-1:0] input_value;
    wire [WIDTH-1:0] sigmoid_out;
    wire overflow;

    // Instantiate the sigmoid module
    sigmoid #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .input_value(input_value),
        .sigmoid_out(sigmoid_out),
        .overflow(overflow)
    );

    integer i;
    integer test_val_int;

    initial begin
        $display("Testbench for sigmoid module");
        $display("Input\tOutput\tOverflow");
        // Negative values from 0 to -6 (32 values)
        for (i = 0; i < 32; i = i + 1) begin
            test_val_int = -6 * 256 * i / 31; // S7.8 format
            input_value = test_val_int[WIDTH-1:0];
            #10;
            $display("%h\t%h\t%b", input_value, sigmoid_out, overflow);
        end
        $finish;
    end
endmodule
