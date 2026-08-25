module adder #(
    parameter WIDTH = 28,        // Total bits: 1 sign + 7 integer + 20 fraction
    parameter FRAC_BITS = 20,    // Number of fractional bits
    parameter INT_BITS  = 7      // Number of integer bits
)(
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] sum,
    output overflow
);

    // 2's complement addition
    wire [WIDTH-1:0] result = a + b;

    // Overflow detection for 2's complement
    assign overflow = ((a[WIDTH-1] == b[WIDTH-1]) && (result[WIDTH-1] != a[WIDTH-1]));

    assign sum = result;

endmodule