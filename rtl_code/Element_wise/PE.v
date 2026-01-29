module PE #(
    parameter WIDTH = 12,
    parameter FRAC_BITS = 8,
    parameter INT_BITS = 7
) (

    input [WIDTH-1:0] register_o,
    input [WIDTH-1:0]  register_i,
    input [WIDTH-1:0]  register_g,
    input [WIDTH-1:0]  register_f,
    input [WIDTH-1:0]  register_c_prev,
    output [WIDTH-1:0] register_c,
    output [WIDTH-1:0] register_h
);

wire [WIDTH-1:0] mul_i_out;
wire [WIDTH-1:0] mul_f_out;
wire [WIDTH-1:0] tanh_out;



multiplier #(
    .WIDTH(WIDTH),
    .FRAC_BITS(FRAC_BITS)
) mul_i (
    .a(register_i),
    .b(register_g),
    .prod(mul_i_out),
    .overflow()
);
multiplier #(
    .WIDTH(WIDTH),
    .FRAC_BITS(FRAC_BITS)
) mul_f (
    .a(register_f),
    .b(register_c_prev),
    .prod(mul_f_out),
    .overflow()
);
adder #(
    .WIDTH(WIDTH)
) add_c (
    .a(mul_f_out),
    .b(mul_i_out),
    .sum(register_c),
    .overflow()
);
tanh #(
    .INPUT_WIDTH(WIDTH),
    .OUTPUT_WIDTH(WIDTH)
) tanh_inst (
    .input_value(register_c),
    .tanh_out(tanh_out)
);
multiplier #(
    .WIDTH(WIDTH),
    .FRAC_BITS(FRAC_BITS)
) mul_h (
    .a(tanh_out),
    .b(register_o),
    .prod(register_h),
    .overflow()
);
endmodule