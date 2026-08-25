module multiplier #(
    parameter WIDTH      = 28,
    parameter FRAC_BITS  = 20,
    parameter INT_BITS   = 7
)(
    input  signed [WIDTH-1:0] a,
    input  signed [WIDTH-1:0] b,
    output signed [WIDTH-1:0] prod,
    output overflow
);

    wire signed [(2*WIDTH)-1:0] full_prod;
    assign full_prod = a * b;

    // Rounding
    wire signed [(2*WIDTH)-1:0] rounded;
    assign rounded = full_prod + (1 << (FRAC_BITS-1));

    // Normalize
    wire signed [WIDTH-1:0] result;
   assign result = rounded >>> FRAC_BITS;

    // Overflow detection
    wire sign = full_prod[2*WIDTH-1];
    assign overflow = |(full_prod[(2*WIDTH-1):(WIDTH+FRAC_BITS)] ^ 
                        { (WIDTH-FRAC_BITS){sign} });

    assign prod = result;

endmodule