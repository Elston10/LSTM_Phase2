// Optimized address calculator using approximation for faster hardware
// For S3.20 format with 512-entry LUT

module tanh_addr_calc_s3_20 (
    input [23:0] x_abs,         // Absolute value of input (S3.20 format)
    output reg [8:0] addr,      // 9-bit address (0-511)
    output reg valid            // Valid flag
);

    // Constants in S3.20 format
    localparam [23:0] MIN_LUT = 24'h040000;  // 0.25 * 2^20
    localparam [23:0] MAX_LUT = 24'h300000;  // 3.0 * 2^20
    
    // Range calculation
    // Range = 3.0 - 0.25 = 2.75
    // In S3.20: 0x2C0000
    // addr = ((x - 0.25) * 511) / 2.75
    // Approximation: addr ≈ (x - 0.25) * 186 (since 511/2.75 ≈ 185.8)
    
    localparam [8:0] SCALE_FACTOR = 9'd186;  // 511 / 2.75 ≈ 186
    
    reg [23:0] offset;
    reg [32:0] scaled;
    
    always @(*) begin
        // Check bounds
        if (x_abs < MIN_LUT) begin
            valid = 1'b0;
            addr = 9'd0;
        end
        else if (x_abs >= MAX_LUT) begin
            valid = 1'b0;
            addr = 9'd511;
        end
        else begin
            valid = 1'b1;
            
            // Calculate offset
            offset = x_abs - MIN_LUT;
            
            // Scale by approximation factor
            // offset is S3.20, multiply by 186, then shift right by 20
            // scaled = (offset * SCALE_FACTOR) >> 20;
            scaled = (offset << 7) + (offset << 5) + (offset << 4) + (offset << 3) + (offset << 1);
            scaled = scaled >> 20;
            
            // Clamp to valid range
            if (scaled >= 512)
                addr = 9'd511;
            else
                addr = scaled[8:0];
        end
    end

endmodule