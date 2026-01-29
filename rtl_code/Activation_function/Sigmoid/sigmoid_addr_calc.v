// Sigmoid Address Calculator (Sign Independent)
// Converts input value magnitude in range [0, 6] to LUT address [0, 383]
// Input format: S1.5.6 (12-bit: 1 sign + 5 integer + 6 fractional bits)
// LUT covers range [0, 6] with 384 entries, so step = 6/384 = 0.015625
// Uses absolute value (magnitude) regardless of sign
module sigmoid_addr_calc #(
    parameter INPUT_WIDTH = 16,      // Input width (S7.8 format)
    parameter ADDR_WIDTH = 11,       // Address width for LUT
    parameter LUT_SIZE = 1538,       // Size of the LUT
    parameter FRAC_BITS = 8          // Fractional bits in input
) (
    input  [INPUT_WIDTH-1:0] input_value,    // S7.8 input value
    output [ADDR_WIDTH-1:0]  lut_addr,       // Address for LUT
    output                   addr_valid,      // Address is within valid range
    output                   use_symmetry,    // Use sigmoid symmetry for negative inputs
    output                   saturate_high    // Input saturated to maximum
);

// LUT Parameters (matching your sigmoid_lut_s7_8.v)
localparam SIGMOID_INPUT_MIN = 16'h0000;     // 0.0 in S7.8
localparam SIGMOID_INPUT_MAX = 16'h0600;     // 6.0 in S7.8 (6 * 256 = 1536)
localparam SIGMOID_STEP_SIZE = 16'h0001;     // Step size in S7.8 (approximately 0.00390625)
localparam MAX_ADDR = LUT_SIZE - 1;

// Internal signals
wire signed [INPUT_WIDTH-1:0] signed_input;
wire [INPUT_WIDTH-1:0] abs_input;
wire input_negative;
wire [INPUT_WIDTH-1:0] scaled_addr;
wire addr_overflow;

// Convert input to signed for easier processing
assign signed_input = input_value;
assign input_negative = signed_input[INPUT_WIDTH-1];

// Get absolute value of input
assign abs_input = input_negative ? (~input_value + 1'b1) : input_value;

// Check if absolute input exceeds maximum LUT range
assign saturate_high = (abs_input > SIGMOID_INPUT_MAX);

// Calculate raw address by dividing by step size
// Since step size is 1 in our S7.8 representation, this is just the value itself
assign scaled_addr = abs_input;

// Check for address overflow
assign addr_overflow = (scaled_addr >= LUT_SIZE);

// Generate final address with bounds checking
assign lut_addr = saturate_high ? MAX_ADDR :
                  addr_overflow ? MAX_ADDR :
                  scaled_addr[ADDR_WIDTH-1:0];

// Address is valid if we're in the LUT range
assign addr_valid = ~addr_overflow && ~saturate_high;

// Use symmetry for negative inputs
assign use_symmetry = input_negative;

endmodule