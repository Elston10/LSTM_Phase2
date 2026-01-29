module multiplier #(
    parameter WIDTH      = 16,
    parameter FRAC_BITS  = 8
)(
    input  signed [WIDTH-1:0] a,
    input  signed [WIDTH-1:0] b,
    output reg signed [WIDTH-1:0] prod,
    output reg overflow
);
    // 1. Perform signed multiplication (double width)
    wire signed [(2*WIDTH)-1:0] full_prod = a * b;

    // 2. Shift to align binary point
    wire signed [(2*WIDTH)-1:0] shifted_prod = full_prod >>> FRAC_BITS;

    // 3. Overflow Detection
    wire signed [WIDTH-1:0] max_pos = {1'b0, {(WIDTH-1){1'b1}}};
    wire signed [WIDTH-1:0] max_neg = {1'b1, {(WIDTH-1){1'b0}}};

    always @* begin
        if (shifted_prod > max_pos) begin
            prod = max_pos;
            overflow = 1;
        end else if (shifted_prod < max_neg) begin
            prod = max_neg;
            overflow = 1;
        end else begin
            prod = shifted_prod[WIDTH-1:0];
            overflow = 0;
        end
    end
endmodule