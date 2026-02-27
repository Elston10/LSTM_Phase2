module mul_fixed #(
    parameter WIDTH      = 16, // Total bits (1 sign + integer + fraction)
    parameter FRAC_BITS  = 8,  // Number of fractional bits
    parameter INT_BITS   = 7   // Number of integer bits
)(
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] prod,
    output overflow
);

    // Extract signs and magnitudes
    wire sign_a = a[WIDTH-1];
    wire sign_b = b[WIDTH-1];
    wire [WIDTH-2:0] mag_a = a[WIDTH-2:0];  // 15 bits
    wire [WIDTH-2:0] mag_b = b[WIDTH-2:0];  // 15 bits

    // Multiply unsigned magnitudes (30-bit result)
    wire [(2*(WIDTH-1))-1:0] full_prod = mag_a * mag_b;

    // Adjust for fractional bits
    wire [(2*(WIDTH-1))-1:0] shifted = full_prod >> FRAC_BITS;

    // Compute final sign (XOR of input signs)
    wire sign_out = sign_a ^ sign_b;

    // Maximum magnitudes for positive and negative numbers
    localparam [WIDTH-2:0] MAX_POS_MAG = {(WIDTH-1){1'b1}};        // 32767 for +127.996
    localparam [WIDTH-2:0] MAX_NEG_MAG = {1'b1, {(WIDTH-2){1'b0}}}; // 32768 for -128.000

    // Candidate magnitude (truncate to WIDTH-1 bits)
    wire [WIDTH-2:0] mag_result = shifted[WIDTH-2:0];

    // Enhanced overflow detection for both positive and negative
    wire pos_overflow = (~sign_out) & (shifted > MAX_POS_MAG);  // Positive overflow
    wire neg_overflow = sign_out & (shifted > MAX_NEG_MAG);     // Negative overflow
    assign overflow = pos_overflow | neg_overflow;

    // Saturate based on sign
    wire [WIDTH-2:0] sat_mag = overflow ? 
                               (sign_out ? MAX_NEG_MAG : MAX_POS_MAG) : 
                               mag_result;

    // Zero case: if magnitude is zero, force sign to 0
    assign prod = {(sat_mag == 0) ? 1'b0 : sign_out, sat_mag};

endmodule