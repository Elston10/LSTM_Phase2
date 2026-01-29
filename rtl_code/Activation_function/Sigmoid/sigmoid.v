module sigmoid #(
    parameter WIDTH = 16,           // 16-bit S7.8 format
    parameter FRAC_BITS = 8,        // 8 fractional bits
    parameter ADDR_WIDTH = 11       // Address width for the LUT
) (
    input  [WIDTH-1:0] input_value,     // S7.8 input value
    output [WIDTH-1:0] sigmoid_out,     // S7.8 sigmoid output
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
    
    // Constants in S7.8 format
    localparam [WIDTH-1:0] ONE = 16'h0100;      // 1.0 in S7.8 format
    localparam [WIDTH-1:0] ZERO = 16'h0000;     // 0.0 in S7.8 format
    localparam [WIDTH-1:0] MAX_OUT = 16'h00FF;  // ~0.996 (closest to 1.0 in S7.8)

    // Address calculator instance
    sigmoid_addr_calc #(
        .INPUT_WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) addr_calc_inst (
        .input_value(input_value),
        .lut_addr(lut_addr),
        .addr_valid(addr_valid),
        .use_symmetry(use_symmetry),
        .saturate_high(saturate_high)
    );

    // LUT instance
    sigmoid_lut#(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) lut_inst (
        .addr(lut_addr),
        .sigmoid_out(lut_output)
    );

    // Subtractor for symmetry calculation: 1 - sigmoid(|x|)
    subtractor #(
        .WIDTH(WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) sub_inst (
        .a(ONE),                    // 1.0
        .b(lut_output),            // sigmoid(|x|)
        .diff(one_minus_lut),      // 1 - sigmoid(|x|)
        .overflow(sub_overflow)
    );

    // Output logic implementing the piecewise function
    assign sigmoid_out = saturate_high ? 
                        (use_symmetry ? ZERO : ONE) :  // Saturation cases
                        (use_symmetry ? one_minus_lut : lut_output);  // Normal cases

    // Overflow occurs if subtraction overflows or input causes saturation issues
    assign overflow = sub_overflow;

endmodule