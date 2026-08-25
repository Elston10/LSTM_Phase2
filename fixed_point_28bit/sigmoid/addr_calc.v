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

    localparam signed [27:0] SIX = 28'sh00600000; // ? CORRECT // 6.0

    wire sign_bit = input_value[WIDTH-1];

    // ? Correct 2's complement absolute value
    wire signed [WIDTH-1:0] abs_value =
            sign_bit ? (~input_value + 1'b1) : input_value;

    reg [41:0] scaled;

    always @(*) begin
        use_symmetry = sign_bit;

        // ? FIXED saturation condition
        if (abs_value > SIX) begin
            saturate_high = 1'b1;
            lut_addr = 13'd6143;
        end else begin
            saturate_high = 1'b0;

            // scale ? multiply by ~1024
            scaled = abs_value <<< 10;

            lut_addr = scaled[32:20];

            if (lut_addr >= 13'd6144)
                lut_addr = 13'd6143;
        end
    end

endmodule