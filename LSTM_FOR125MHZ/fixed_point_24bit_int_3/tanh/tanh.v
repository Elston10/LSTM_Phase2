// S3.20 Fixed-point tanh approximator with 512-entry LUT and comparator
// S3.20 Format: 1 sign bit + 3 integer bits + 20 fractional bits = 24 bits total
// Sign bit = MSB (bit 23), if 1 = negative, if 0 = positive

module tanh (
    input [23:0] x,             // Input in S3.20 format
    output reg [23:0] y         // Output in S3.20 format
);

    // Extract sign and magnitude
    wire sign_bit = x[23];                  // Sign bit (1=negative, 0=positive)
    wire [22:0] magnitude = x[22:0];        // Magnitude (23 bits: 3 int + 20 frac)
    
    // Convert magnitude to full 24-bit for comparisons
    wire [23:0] x_abs = {1'b0, magnitude};
    
    // LUT interface
    wire [8:0] lut_addr;                    // 9-bit address for 512 entries
    wire addr_valid;                        // Valid address flag
    wire [23:0] lut_output;                 // LUT output
    reg [23:0] y_abs;                       // Absolute value of output
    
    // Comparison flags for regions
    wire x_less_025;      // x < 0.25
    wire x_gte_025;       // x >= 0.25
    wire x_lte_30;        // x <= 3.0
    wire x_gt_30;         // x > 3.0
    
    // Constants in S3.20 format
    localparam [23:0] MIN_LUT = 24'h040000;  // 0.25 * 2^20 = 262144
    localparam [23:0] MAX_LUT = 24'h300000;  // 3.0 * 2^20  = 3145728
    localparam [23:0] ONE     = 24'h100000;  // 1.0 * 2^20  = 1048576
    
    // ========================================================================
    // COMPARATORS: Determine which region the input falls into
    // ========================================================================
    
    // Comparator 1: Check if x < 0.25 (Linear region)
    fixed_point_comparator #(
        .WIDTH(24),
        .FRAC_BITS(20)
    ) cmp_min (
        .a(x_abs),
        .b(MIN_LUT),
        .a_gt_b(),
        .a_lt_b(x_less_025),
        .a_eq_b(),
        .a_gte_b(),
        .a_lte_b()
    );
    
    // Comparator 2: Check if x >= 0.25 (LUT region start)
    fixed_point_comparator #(
        .WIDTH(24),
        .FRAC_BITS(20)
    ) cmp_min_gte (
        .a(x_abs),
        .b(MIN_LUT),
        .a_gt_b(),
        .a_lt_b(),
        .a_eq_b(),
        .a_gte_b(x_gte_025),
        .a_lte_b()
    );
    
    // Comparator 3: Check if x <= 3.0 (LUT region end)
    fixed_point_comparator #(
        .WIDTH(24),
        .FRAC_BITS(20)
    ) cmp_max_lte (
        .a(x_abs),
        .b(MAX_LUT),
        .a_gt_b(),
        .a_lt_b(),
        .a_eq_b(),
        .a_gte_b(),
        .a_lte_b(x_lte_30)
    );
    
    // Comparator 4: Check if x > 3.0 (Saturation region)
    fixed_point_comparator #(
        .WIDTH(24),
        .FRAC_BITS(20)
    ) cmp_max_gt (
        .a(x_abs),
        .b(MAX_LUT),
        .a_gt_b(x_gt_30),
        .a_lt_b(),
        .a_eq_b(),
        .a_gte_b(),
        .a_lte_b()
    );
    
    // ========================================================================
    // ADDRESS CALCULATOR: Map input to LUT address (optimized version)
    // ========================================================================
    
    tanh_addr_calc_s3_20 addr_calc (
        .x_abs(x_abs),
        .addr(lut_addr),
        .valid(addr_valid)
    );
    
    // ========================================================================
    // LUT: 512-entry lookup table
    // ========================================================================
    
    tanh_lut_rom_s3_20_512 lut (
        .addr(lut_addr),
        .data(lut_output)
    );
    
    // ========================================================================
    // REGION SELECTION: Choose output based on input magnitude
    // ========================================================================
    
    always @(*) begin
        if (x_less_025) begin
            // Region 1: Linear approximation for small inputs
            // tanh(x) ≈ x for |x| < 0.25
            y_abs = x_abs;
        end
        else if (x_gte_025 && x_lte_30) begin
            // Region 2: LUT lookup for 0.25 <= |x| <= 3.0
            y_abs = lut_output;
        end
        else if (x_gt_30) begin
            // Region 3: Saturation for large inputs
            // tanh(x) ≈ 1.0 for |x| > 3.0
            y_abs = ONE;
        end
        else begin
            // Default case (should never reach here)
            y_abs = 24'h000000;
        end
    end
    
    // ========================================================================
    // SIGN APPLICATION: Apply original sign to magnitude
    // ========================================================================
    
    always @(*) begin
        if (sign_bit)
            y = {1'b1, y_abs[22:0]};  // Negative: set sign bit to 1
        else
            y = {1'b0, y_abs[22:0]};  // Positive: set sign bit to 0
    end

endmodule