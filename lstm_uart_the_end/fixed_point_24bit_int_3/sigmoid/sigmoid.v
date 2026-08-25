// S3.20 Fixed-point sigmoid function
// Uses 6144-entry LUT with symmetry property: sigmoid(-x) = 1 - sigmoid(x)

module sigmoid #(
    parameter WIDTH = 24,           // 24-bit S3.20 format
    parameter FRAC_BITS = 20,       // 20 fractional bits
    parameter INT_BITS = 3,         // 3 integer bits
    parameter ADDR_WIDTH = 13       // 13-bit address for 6144 entries
) (
    input [WIDTH-1:0] input_value,      // S3.20 input value
    output [WIDTH-1:0] sigmoid_out,     // S3.20 sigmoid output
    output overflow                     // Overflow flag
);

    // Internal signals
    wire [ADDR_WIDTH-1:0] lut_addr;
    wire addr_valid;
    wire use_symmetry;
    wire saturate_high;
    wire [WIDTH-1:0] lut_output;
    wire [WIDTH-1:0] one_minus_lut;
    wire sub_overflow;
    
    // Constants in S3.20 format
    localparam [WIDTH-1:0] ONE  = 24'h100000;  // 1.0 * 2^20
    localparam [WIDTH-1:0] ZERO = 24'h000000;  // 0.0
    localparam [WIDTH-1:0] MAX_OUT = 24'h0FFFFE; // ~0.999999 (closest to 1.0)
    
    // ========================================================================
    // ADDRESS CALCULATOR: Determine LUT address and control flags
    // ========================================================================
    
    sigmoid_addr_calculator_s3_20_opt #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) addr_calc (
        .input_value(input_value),
        .lut_addr(lut_addr),
        .addr_valid(addr_valid),
        .use_symmetry(use_symmetry),
        .saturate_high(saturate_high)
    );
    
    // ========================================================================
    // LUT: Lookup table for sigmoid values
    // ========================================================================
    
    sigmoid_lut_s3_20 lut_inst (
        .addr(lut_addr),
        .data(lut_output)
    );
    
    // ========================================================================
    // SUBTRACTOR: Compute 1 - sigmoid(|x|) for negative inputs
    // ========================================================================
    
    subtractor #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .INT_BITS(INT_BITS)
    ) sub_inst (
        .a(ONE),                    // 1.0
        .b(lut_output),            // sigmoid(|x|)
        .diff(one_minus_lut),      // 1 - sigmoid(|x|)
        .overflow(sub_overflow)
    );
    
    // ========================================================================
    // OUTPUT LOGIC: Select appropriate output based on region
    // ========================================================================
    
    /*
     * Piecewise function:
     * - If x > 6.0:  sigmoid(x) = 1.0
     * - If x < -6.0: sigmoid(x) = 0.0 (via symmetry: 1 - 1.0 = 0.0)
     * - If x >= 0:   sigmoid(x) = LUT(x)
     * - If x < 0:    sigmoid(x) = 1 - LUT(|x|)
     */
    
    assign sigmoid_out = saturate_high ? 
                        (use_symmetry ? ZERO : ONE) :      // Saturation cases
                        (use_symmetry ? one_minus_lut : lut_output);  // Normal cases
    
    // ========================================================================
    // OVERFLOW: Report arithmetic overflow
    // ========================================================================
    
    assign overflow = sub_overflow;

endmodule