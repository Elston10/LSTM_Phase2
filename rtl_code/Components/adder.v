module adder #(
    parameter WIDTH = 16
)(
    input  signed [WIDTH-1:0] a,
    input  signed [WIDTH-1:0] b,
    output signed [WIDTH-1:0] sum,
    output overflow
);
    // 1. Perform 17-bit addition to catch the carry/overflow bit
    wire signed [WIDTH:0] full_sum = a + b;

    // 2. Overflow detection for Two's Complement
    // Occurs if two positives make a negative, or two negatives make a positive
    assign overflow = (a[WIDTH-1] == b[WIDTH-1]) && (full_sum[WIDTH-1] != a[WIDTH-1]);

    // 3. Saturation (Optional but recommended for fixed-point)
    assign sum = overflow ? (a[WIDTH-1] ? 16'h8000 : 16'h7FFF) : full_sum[WIDTH-1:0];

endmodule