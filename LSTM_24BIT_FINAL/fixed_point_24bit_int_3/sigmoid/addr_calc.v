module sigmoid_addr_calculator_s7_20 #(
    parameter WIDTH = 28,
    parameter FRAC_BITS = 20,
    parameter ADDR_WIDTH = 13
)(
    input  signed [WIDTH-1:0] input_value,
    output reg [ADDR_WIDTH-1:0] lut_addr,
    output reg use_symmetry,
    output reg saturate_high
);

    localparam signed [WIDTH-1:0] SIX = 28'sh00600000;

    // 1/step ≈ 1023.833 → use scaled integer
    localparam integer K = 1024;  // very close (safe)

    wire sign_bit = input_value[WIDTH-1];

    wire signed [WIDTH-1:0] abs_value =
        sign_bit ? (~input_value + 1'b1) : input_value;

    reg [47:0] mult;

    always @(*) begin
        use_symmetry = sign_bit;

        if (abs_value >= SIX) begin
            saturate_high = 1'b1;
            lut_addr = 13'd6143;
        end else begin
            saturate_high = 1'b0;

            // addr = (abs_value * K) >> FRAC_BITS
            mult = abs_value * K;
            lut_addr = mult >>> FRAC_BITS;

            if (lut_addr >= 13'd6144)
                lut_addr = 13'd6143;
        end
    end

endmodule