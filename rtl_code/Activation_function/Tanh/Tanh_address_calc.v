module tanh_address_calculator #(
    parameter INPUT_WIDTH = 16,
    parameter ADDR_WIDTH = 9,
    parameter FRAC_BITS = 8
) (
    input  [INPUT_WIDTH-1:0] input_value,    // S7.8 input value
    output [ADDR_WIDTH-1:0]  lut_addr,       // Address for LUT
    output                   addr_valid,     // Address is within valid range
    output                   use_symmetry,   // Use tanh symmetry for negative inputs
    output                   saturate_low,   // Input below minimum range
    output                   saturate_high   // Input above maximum range
);

    // LUT parameters
    localparam [INPUT_WIDTH-1:0] INPUT_MIN = 16'h0040;  // 0.25 * 256 = 64
    localparam [INPUT_WIDTH-1:0] INPUT_MAX = 16'h0300;  // 3.0 * 256 = 768
    localparam MAX_ADDR = 275;

    // Internal signals
    wire signed [INPUT_WIDTH-1:0] signed_input;
    wire [INPUT_WIDTH-1:0] abs_input;
    wire input_negative;
    wire [INPUT_WIDTH-1:0] offset_input;
    
    // Shift-add approximation signals for multiply by 51
    wire [INPUT_WIDTH+5:0] offset_x32;     // offset * 32
    wire [INPUT_WIDTH+4:0] offset_x16;     // offset * 16
    wire [INPUT_WIDTH+1:0] offset_x2;      // offset * 2
    wire [INPUT_WIDTH+5:0] mult_51_result; // offset * (32+16+2+1) = offset * 51
    wire [ADDR_WIDTH-1:0] calculated_addr;

    // Input processing
    assign signed_input = input_value;
    assign input_negative = signed_input[INPUT_WIDTH-1];
    assign abs_input = input_negative ? (~input_value + 1'b1) : input_value;

    // Check saturation conditions
    assign saturate_low = (abs_input < INPUT_MIN);
    assign saturate_high = (abs_input > INPUT_MAX);

    // Calculate offset from minimum input
    assign offset_input = abs_input - INPUT_MIN;
    
    // Multiply by 51 using shift-add: 51 = 32 + 16 + 2 + 1
    assign offset_x2 = offset_input << 1;   // * 2
    assign offset_x16 = offset_input << 4;  // * 16  
    assign offset_x32 = offset_input << 5;  // * 32
    
    // Add them together: 32 + 16 + 2 + 1 = 51
    assign mult_51_result = offset_x32 + offset_x16 + offset_x2 + offset_input;
    
    // Divide by 128 (shift right by 7) to get final address
    // This implements: address = (offset * 51) / 128 ≈ offset / 2.51
    assign calculated_addr = mult_51_result[INPUT_WIDTH+5:7];

    // Generate final address with bounds checking
    assign lut_addr = saturate_low ? 9'd0 :
                      saturate_high ? MAX_ADDR :
                      (calculated_addr > MAX_ADDR) ? MAX_ADDR :
                      calculated_addr;

    // Control signals
    assign addr_valid = ~saturate_low && ~saturate_high;
    assign use_symmetry = input_negative;

endmodule