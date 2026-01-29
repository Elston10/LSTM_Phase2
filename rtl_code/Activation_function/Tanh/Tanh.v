`timescale 1ns / 1ps

module tanh #(
    parameter INPUT_WIDTH = 16,
    parameter OUTPUT_WIDTH = 16,
    parameter ADDR_WIDTH = 9,
    parameter FRAC_BITS = 8
) (
    input  [INPUT_WIDTH-1:0] input_value,    // S7.8 input value
    output [OUTPUT_WIDTH-1:0] tanh_out       // S7.8 output value
);

    // Internal signals
    wire [INPUT_WIDTH-1:0] abs_input;
    wire input_negative;
    wire [OUTPUT_WIDTH-1:0] neg_result;
    wire [ADDR_WIDTH-1:0] lut_addr;
    wire addr_valid, use_symmetry, saturate_low, saturate_high;
    wire [OUTPUT_WIDTH-1:0] lut_output;
    wire [OUTPUT_WIDTH-1:0] positive_result;
    
    // Comparison signals
    wire abs_lt_025, abs_lte_3, abs_gt_3;
    wire dummy_gt, dummy_eq, dummy_gte; // Unused outputs
    
    // Constants in S7.8 format
    localparam [INPUT_WIDTH-1:0] THRESHOLD_025 = 16'h0040; // 0.25 * 256 = 64
    localparam [INPUT_WIDTH-1:0] THRESHOLD_3   = 16'h0300; // 3.0 * 256 = 768
    localparam [OUTPUT_WIDTH-1:0] TANH_ONE     = 16'b0000000100000000; // 1.0 in S7.8 ≈ 255/256

    // Extract sign and absolute value (two's complement)
    assign input_negative = input_value[INPUT_WIDTH-1];
    assign abs_input = input_negative ? (~input_value + 1'b1) : input_value;

    // Fixed-point comparator for abs_input < 0.25
    fixed_point_comparator #(
        .WIDTH(INPUT_WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) comp_025 (
        .a(abs_input),
        .b(THRESHOLD_025),
        .a_gt_b(dummy_gt),
        .a_lt_b(abs_lt_025),
        .a_eq_b(dummy_eq),
        .a_gte_b(dummy_gte),
        .a_lte_b()
    );

    // Fixed-point comparator for abs_input <= 3.0
    fixed_point_comparator #(
        .WIDTH(INPUT_WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) comp_3 (
        .a(abs_input),
        .b(THRESHOLD_3),
        .a_gt_b(abs_gt_3),
        .a_lt_b(),
        .a_eq_b(dummy_eq),
        .a_gte_b(dummy_gte),
        .a_lte_b(abs_lte_3)
    );

    // Instantiate your address calculator
    tanh_address_calculator addr_calc (
        .input_value(abs_input),
        .lut_addr(lut_addr),
        .addr_valid(addr_valid),
        .use_symmetry(use_symmetry),
        .saturate_low(saturate_low),
        .saturate_high(saturate_high)
    );

    // Instantiate your LUT
    tanh_lut_ram lut (
        .addr(lut_addr),
        .tanh_out(lut_output)
    );

    // Piecewise tanh calculation for positive values using comparator results
    assign positive_result = abs_lt_025 ? abs_input :           // Case: 0 ≤ x < 0.25 → f(x) = x
                             abs_lte_3 ? lut_output :           // Case: 0.25 ≤ x ≤ 3 → tanh_table(x)
                             TANH_ONE;                          // Case: x > 3 → f(x) = 1

    // Two's complement for negative output
    assign neg_result = (~positive_result) + 1'b1;

    // Apply sign for final output (two's complement)
    assign tanh_out = input_negative ? neg_result : positive_result;

endmodule