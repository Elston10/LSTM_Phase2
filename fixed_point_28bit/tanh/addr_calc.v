module tanh_addr_calc_s7_20  (
    input  signed [27:0] x,
    output reg [8:0] addr,
    output reg valid
);

    wire signed [27:0] x_abs = x[27] ? -x : x;

    localparam signed [27:0] MIN_LUT = 28'h0040000;  // 0.25
    localparam signed [27:0] MAX_LUT = 28'h0300000;  // 3.0

    wire in_range = (x_abs >= MIN_LUT) && (x_abs < MAX_LUT);

    wire signed [27:0] x_shifted = x_abs - MIN_LUT;

    wire [8:0] addr_fast = x_shifted[19:11];  // ? NO MULTIPLY

    always @(*) begin
        if (!in_range) begin
            valid = 0;
            addr  = (x_abs < MIN_LUT) ? 9'd0 : 9'd511;
        end else begin
            valid = 1;
            addr  = addr_fast;
        end
    end

endmodule