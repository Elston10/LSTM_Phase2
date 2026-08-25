module tanh (
    input  signed [27:0] x,
    output reg signed [27:0] y
);

    // Absolute value
    wire signed [27:0] x_abs = (x < 0) ? -x : x;

    // Constants
    localparam signed [27:0] MIN_LUT = 28'sd262144;   // 0.25
    localparam signed [27:0] MAX_LUT = 28'sd3145728;  // 3.0
    localparam signed [27:0] ONE     = 28'sd1048576;  // 1.0

    wire [8:0] addr;
    wire valid;
    wire signed [27:0] lut_out;

    reg signed [27:0] y_abs;

    // Address calc
    tanh_addr_calc_s7_20 addr_calc (
        .x(x),
        .addr(addr),
        .valid(valid)
    );

    // LUT
    tanh_lut_rom_s7_20_512 lut (
        .addr(addr),
        .data(lut_out)
    );

    always @(*) begin
        if (x_abs < MIN_LUT) begin
            y_abs = x_abs;          // linear region
        end
        else if (x_abs <= MAX_LUT) begin
            y_abs = lut_out;        // LUT region
        end
        else begin
            y_abs = ONE;            // saturation
        end

        // Apply sign automatically
        y = (x < 0) ? -y_abs : y_abs;
    end

endmodule