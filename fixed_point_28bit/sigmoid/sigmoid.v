module sigmoid #(
    parameter WIDTH = 28,
    parameter FRAC_BITS = 20,
    parameter INT_BITS = 7,
    parameter ADDR_WIDTH = 13
)(
    input  signed [WIDTH-1:0] input_value,
    output signed [WIDTH-1:0] sigmoid_out,
    output overflow
);

    wire [ADDR_WIDTH-1:0] lut_addr;
    wire use_symmetry;
    wire saturate_high;

    wire signed [WIDTH-1:0] lut_output;
    wire signed [WIDTH-1:0] one_minus_lut;

  localparam signed [27:0] ONE = 28'sh00100000;  // ✅ CORRECT
    localparam signed [WIDTH-1:0] ZERO = 28'sh00000000; // 0.0

    // Address calculator
    sigmoid_addr_calculator_s7_20 addr_calc (
        .input_value(input_value),
        .lut_addr(lut_addr),
        .use_symmetry(use_symmetry),
        .saturate_high(saturate_high)
    );

    // LUT
    sigmoid_lut_s7_20 lut_inst (
        .addr(lut_addr),
        .data(lut_output)
    );

    // Symmetry: sigmoid(-x) = 1 - sigmoid(x)
    assign one_minus_lut = ONE - lut_output;

    // Output selection
    assign sigmoid_out = saturate_high ?
                        (use_symmetry ? ZERO : ONE) :
                        (use_symmetry ? one_minus_lut : lut_output);

    assign overflow = 1'b0;

endmodule