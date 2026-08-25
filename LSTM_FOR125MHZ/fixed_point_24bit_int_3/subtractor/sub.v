module subtractor #(
    parameter WIDTH = 24,        // Total bits: 1 sign + 3 integer + 20 fraction
    parameter FRAC_BITS = 20,    // Number of fractional bits
    parameter INT_BITS  = 3      // Number of integer bits
)(
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] diff,
    output overflow
);

    // Split sign and magnitude
    wire sign_a = a[WIDTH-1];
    wire sign_b = b[WIDTH-1];
    wire [WIDTH-2:0] mag_a = a[WIDTH-2:0];  // 23 bits (3 int + 20 frac)
    wire [WIDTH-2:0] mag_b = b[WIDTH-2:0];  // 23 bits

    // Convert magnitudes to unsigned integers for arithmetic
    wire [WIDTH-1:0] ext_mag_a = {1'b0, mag_a};
    wire [WIDTH-1:0] ext_mag_b = {1'b0, mag_b};

    // Intermediate difference
    reg [WIDTH:0] temp_mag;      // One extra bit for overflow on magnitude (25 bits)
    reg temp_sign;

    always @(*) begin
        if (sign_a == sign_b) begin
            // Same sign: subtract magnitudes (a - b)
            if (ext_mag_a >= ext_mag_b) begin
                temp_mag  = ext_mag_a - ext_mag_b;
                temp_sign = sign_a;  // Keep sign of a
            end else begin
                temp_mag  = ext_mag_b - ext_mag_a;
                temp_sign = ~sign_a; // Flip sign (result is negative of a's sign)
            end
        end else begin
            // Different signs: add magnitudes (subtracting a negative = adding)
            temp_mag  = ext_mag_a + ext_mag_b;
            temp_sign = sign_a;  // Keep sign of a
        end
    end

    // Maximum magnitudes for 1+3+20 format
    // Maximum positive magnitude: 0 111 11111111111111111111 = 7.99999904632568359375
    // Maximum negative magnitude: 0 111 11111111111111111111 = 7.99999904632568359375 (but with sign=1)
    localparam [WIDTH-2:0] MAX_MAG = 23'h7FFFFF;  // Maximum magnitude (same for +/-)

    // Overflow detection
    wire mag_overflow = (temp_mag[WIDTH-1:0] > {1'b0, MAX_MAG});
    assign overflow = mag_overflow;

    // Saturate magnitude if overflow
    wire [WIDTH-2:0] sat_mag = mag_overflow ? MAX_MAG : temp_mag[WIDTH-2:0];

    // Construct output: sign + magnitude (handle zero case)
    assign diff = {temp_mag == 0 ? 1'b0 : temp_sign, sat_mag};

endmodule