module subtractor #(
    parameter WIDTH = 16,        // Total bits: 1 sign + 7 integer + 8 fraction
    parameter FRAC_BITS = 8,     // Number of fractional bits
    parameter INT_BITS  = 7      // Number of integer bits
)(
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] diff,
    output overflow
);

    // Split sign and magnitude
    wire sign_a = a[WIDTH-1];
    wire sign_b = b[WIDTH-1];
    wire [WIDTH-2:0] mag_a = a[WIDTH-2:0];  // 15 bits
    wire [WIDTH-2:0] mag_b = b[WIDTH-2:0];  // 15 bits

    // Convert magnitudes to unsigned integers for arithmetic
    wire [WIDTH-1:0] ext_mag_a = {1'b0, mag_a};
    wire [WIDTH-1:0] ext_mag_b = {1'b0, mag_b};

    // Intermediate sum/diff
    reg [WIDTH:0] temp_mag;      // One extra bit for overflow on magnitude
    reg temp_sign;

    always @(*) begin
        if (sign_a != sign_b) begin
            // Different signs: a - (-b) = a + b, so add magnitudes
            temp_mag  = ext_mag_a + ext_mag_b;
            temp_sign = sign_a;
        end else begin
            // Same signs: subtract smaller magnitude from larger
            if (ext_mag_a >= ext_mag_b) begin
                temp_mag  = ext_mag_a - ext_mag_b;
                temp_sign = sign_a; // sign of the larger magnitude
            end else begin
                temp_mag  = ext_mag_b - ext_mag_a;
                temp_sign = ~sign_a; // flip sign when b > a
            end
        end
    end

    // Maximum magnitudes for positive and negative numbers
    localparam [WIDTH-2:0] MAX_POS_MAG = {(WIDTH-1){1'b1}};        // 32767 for +127.996
    localparam [WIDTH-2:0] MAX_NEG_MAG = {1'b1, {(WIDTH-2){1'b0}}}; // 32768 for -128.000

    // Enhanced overflow detection for both positive and negative
    wire pos_overflow = (~temp_sign) & (temp_mag[WIDTH-1:0] > {1'b0, MAX_POS_MAG});  // Positive overflow
    wire neg_overflow = temp_sign & (temp_mag[WIDTH-1:0] > {1'b0, MAX_NEG_MAG});     // Negative overflow
    assign overflow = pos_overflow | neg_overflow;

    // Saturate based on sign
    wire [WIDTH-2:0] sat_mag = overflow ? 
                               (temp_sign ? MAX_NEG_MAG : MAX_POS_MAG) : 
                               temp_mag[WIDTH-2:0];

    // Construct output: sign + magnitude (zero case handled)
    assign diff = { temp_mag == 0 ? 1'b0 : temp_sign, sat_mag };

endmodule