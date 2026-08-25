module multiplier #(
    parameter WIDTH      = 24, // Total bits: 1 sign + 3 integer + 20 fraction
    parameter FRAC_BITS  = 20, // Number of fractional bits
    parameter INT_BITS   = 3   // Number of integer bits
)(
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] prod,
    output overflow
);

    // Extract signs and magnitudes
    wire sign_a = a[WIDTH-1];
    wire sign_b = b[WIDTH-1];
    wire [WIDTH-2:0] mag_a = a[WIDTH-2:0];  // 23 bits (3 int + 20 frac)
    wire [WIDTH-2:0] mag_b = b[WIDTH-2:0];  // 23 bits (3 int + 20 frac)

    // Multiply unsigned magnitudes (46-bit result)
    wire [(2*(WIDTH-1))-1:0] full_prod = mag_a * mag_b;

    // Adjust for fractional bits (divide by 2^FRAC_BITS to normalize)
    wire [(2*(WIDTH-1))-1:0] shifted = full_prod >> FRAC_BITS;

    // Compute final sign (XOR of input signs)
    wire sign_out = sign_a ^ sign_b;

    // Maximum magnitude for 1+3+20 format
    // Maximum magnitude: 0 111 11111111111111111111 = 7.99999904632568359375
    localparam [WIDTH-2:0] MAX_MAG = 23'h7FFFFF;  // Maximum magnitude (same for +/-)

    // Candidate magnitude (truncate to WIDTH-1 bits)
    wire [WIDTH-2:0] mag_result = shifted[WIDTH-2:0];

    // Overflow detection (check if shifted result exceeds max magnitude)
    wire mag_overflow = (shifted > MAX_MAG);
    assign overflow = mag_overflow;

    // Saturate magnitude if overflow
    wire [WIDTH-2:0] sat_mag = mag_overflow ? MAX_MAG : mag_result;

    // Zero case: if magnitude is zero, force sign to 0
    assign prod = {(sat_mag == 0) ? 1'b0 : sign_out, sat_mag};

endmodule