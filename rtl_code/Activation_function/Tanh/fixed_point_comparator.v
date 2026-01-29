// Fixed-Point Comparator for S7.8 format
// 1 sign bit + 7 integer bits + 8 fractional bits = 16 bits total
module fixed_point_comparator #(
    parameter WIDTH = 16,
    parameter FRAC_BITS = 8
) (
    input [WIDTH-1:0] a,        // First fixed-point number
    input [WIDTH-1:0] b,        // Second fixed-point number
    output reg a_gt_b,          // a > b
    output reg a_lt_b,          // a < b
    output reg a_eq_b,          // a == b
    output reg a_gte_b,         // a >= b
    output reg a_lte_b          // a <= b
);

    // Extract sign bits
    wire sign_a = a[WIDTH-1];
    wire sign_b = b[WIDTH-1];
    
    // Extract magnitude (integer + fractional parts)
    wire [WIDTH-2:0] mag_a = a[WIDTH-2:0];  // 15 bits
    wire [WIDTH-2:0] mag_b = b[WIDTH-2:0];  // 15 bits
    
    always @(*) begin
        // Default all outputs to 0
        a_gt_b = 1'b0;
        a_lt_b = 1'b0;
        a_eq_b = 1'b0;
        a_gte_b = 1'b0;
        a_lte_b = 1'b0;
        
        // Case 1: Both numbers are equal
        if (a == b) begin
            a_eq_b = 1'b1;
            a_gte_b = 1'b1;
            a_lte_b = 1'b1;
        end
        
        // Case 2: Different signs
        else if (sign_a != sign_b) begin
            if (sign_a == 1'b0 && sign_b == 1'b1) begin
                // a is positive, b is negative -> a > b
                a_gt_b = 1'b1;
                a_gte_b = 1'b1;
            end
            else begin
                // a is negative, b is positive -> a < b
                a_lt_b = 1'b1;
                a_lte_b = 1'b1;
            end
        end
        
        // Case 3: Same signs
        else begin
            if (sign_a == 1'b0) begin
                // Both positive: compare magnitudes directly
                if (mag_a > mag_b) begin
                    a_gt_b = 1'b1;
                    a_gte_b = 1'b1;
                end
                else begin
                    a_lt_b = 1'b1;
                    a_lte_b = 1'b1;
                end
            end
            else begin
                // Both negative: larger magnitude means smaller value
                if (mag_a > mag_b) begin
                    a_lt_b = 1'b1;
                    a_lte_b = 1'b1;
                end
                else begin
                    a_gt_b = 1'b1;
                    a_gte_b = 1'b1;
                end
            end
        end
    end

endmodule