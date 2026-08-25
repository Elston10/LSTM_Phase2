// Optimized address calculator using shift-based approximation

module sigmoid_addr_calculator_s3_20_opt #(
    parameter WIDTH = 24,
    parameter FRAC_BITS = 20,
    parameter ADDR_WIDTH = 13
) (
    input [WIDTH-1:0] input_value,
    output reg [ADDR_WIDTH-1:0] lut_addr,
    output reg addr_valid,
    output reg use_symmetry,
    output reg saturate_high
);

    // Constants
    localparam [WIDTH-1:0] SIX = 24'h600000;  // 6.0
    
    // Extract sign and magnitude
    wire sign_bit = input_value[WIDTH-1];
    wire [22:0] magnitude = input_value[WIDTH-2:0];
    wire [WIDTH-1:0] abs_value = {1'b0, magnitude};
    
    // Address calculation using approximation
    reg [33:0] scaled;
    
    always @(*) begin
        // Determine symmetry
        use_symmetry = sign_bit;
        
        // Check saturation
        if (abs_value >= SIX) begin
            saturate_high = 1'b1;
            addr_valid = 1'b0;
            lut_addr = 13'd6143;
        end
        else begin
            saturate_high = 1'b0;
            addr_valid = 1'b1;
            
            // Approximation: addr ≈ |x| * 1024
            // Since 6143/6 ≈ 1024
            scaled = (abs_value << 10);  // Multiply by 1024
            lut_addr = scaled[32:20];     // Extract upper 13 bits
            
            // Clamp
            if (lut_addr >= 13'd6144)
                lut_addr = 13'd6143;
        end
    end

endmodule