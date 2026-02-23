// S7.8 Fixed-point tanh approximator with LUT and comparator
// S7.8 Format: 1 sign bit + 7 integer bits + 8 fractional bits
// Sign bit = MSB (bit 15), if 1 = negative, if 0 = positive

module tanh (
    input [15:0] x,
    output reg [15:0] y
);

    wire sign_bit = x[15];           // Extract sign bit directly (1=negative, 0=positive)
    wire [14:0] magnitude = x[14:0]; // Extract magnitude (15 bits)
    
    // Convert magnitude back to 16-bit for comparisons
    wire [15:0] x_abs = {1'b0, magnitude};
    
    wire [7:0] lut_addr;
    wire addr_valid;
    wire [15:0] lut_output;
    reg [15:0] y_abs;
    
    // Comparison wires for regions
    wire x_less_025;      // x < 0.25
    wire x_gte_025;       // x >= 0.25
    wire x_lte_30;        // x <= 3.0
    wire x_gt_30;         // x > 3.0
    
    // Constants in S7.8 format
    localparam [15:0] MIN_LUT = 16'h0040;  // 0.25
    localparam [15:0] MAX_LUT = 16'h0300;  // 3.0
    
    // Comparator instance for x < 0.25
    fixed_point_comparator #(
        .WIDTH(16),
        .FRAC_BITS(8)
    ) cmp_min (
        .a(x_abs),
        .b(MIN_LUT),
        .a_gt_b(),
        .a_lt_b(x_less_025),
        .a_eq_b(),
        .a_gte_b(),
        .a_lte_b()
    );
    
    // Comparator instance for x >= 0.25
    fixed_point_comparator #(
        .WIDTH(16),
        .FRAC_BITS(8)
    ) cmp_min_gte (
        .a(x_abs),
        .b(MIN_LUT),
        .a_gt_b(),
        .a_lt_b(),
        .a_eq_b(),
        .a_gte_b(x_gte_025),
        .a_lte_b()
    );
    
    // Comparator instance for x <= 3.0
    fixed_point_comparator #(
        .WIDTH(16),
        .FRAC_BITS(8)
    ) cmp_max_lte (
        .a(x_abs),
        .b(MAX_LUT),
        .a_gt_b(),
        .a_lt_b(),
        .a_eq_b(),
        .a_gte_b(),
        .a_lte_b(x_lte_30)
    );
    
    // Comparator instance for x > 3.0
    fixed_point_comparator #(
        .WIDTH(16),
        .FRAC_BITS(8)
    ) cmp_max_gt (
        .a(x_abs),
        .b(MAX_LUT),
        .a_gt_b(x_gt_30),
        .a_lt_b(),
        .a_eq_b(),
        .a_gte_b(),
        .a_lte_b()
    );
    
    // Instantiate address calculator
    tanh_addr_calc addr_calc (
        .x_abs(x_abs),
        .addr(lut_addr),
        .valid(addr_valid)
    );
    
    // Instantiate LUT
    tanh_lut_data lut (
        .addr(lut_addr),
        .data(lut_output)
    );
    
    // Select output based on input region using comparator results
    always @(*) begin
        if (x_less_025) begin
            // Linear region: tanh(x) ≈ x (x < 0.25)
            y_abs = x_abs;
        end
        else if (x_gte_025 && x_lte_30) begin
            // LUT region: 0.25 <= x <= 3.0
            y_abs = lut_output;
        end
        else if (x_gt_30) begin 
            // Saturation: tanh(x) ≈ 1.0 (x > 3.0)
            y_abs = 16'h0100;  // 1.0 in S7.8
        end
        else begin
            // Default (shouldn't reach here)
            y_abs = 16'h0000;
        end
    end
    
    // Apply sign to output
    // S7.8 sign format: bit[15]=1 means negative
    always @(*) begin
        if (sign_bit)
            y = {1'b1, y_abs[14:0]};  // Set sign bit to 1 (negative)
        else
            y = {1'b0, y_abs[14:0]};  // Set sign bit to 0 (positive)
    end

endmodule