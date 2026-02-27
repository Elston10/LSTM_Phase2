// Alternative using approximation for better synthesis
module tanh_addr_calc (
    input [15:0] x_abs,
    output reg [7:0] addr,
    output reg valid
);

    localparam [15:0] LUT_MIN = 16'h0040;
    localparam [15:0] LUT_MAX = 16'h0300;
    
    wire [15:0] offset;
    wire [23:0] scaled;
    
    assign offset = (x_abs >= LUT_MIN) ? (x_abs - LUT_MIN) : 16'h0000;
    
    // Use approximation: 175/704 ? 45/181 ? 0.2486
    // Better: multiply by 64 then divide by 256 (shift)
    // 175/704 * 256 ? 63.64 ? 64
    assign scaled = (offset * 64) >> 8;  // Divide by 4.02 approximately
    
    always @(*) begin
        if (x_abs < LUT_MIN) begin
            addr = 8'd0;
            valid = 1'b0;
        end
        else if (x_abs > LUT_MAX) begin
            addr = 8'd175;
            valid = 1'b0;
        end
        else begin
            if (scaled > 175)
                addr = 8'd175;
            else
                addr = scaled[7:0];
            valid = 1'b1;
        end
    end

endmodule