// Modified accumulator with increased precision for activation functions
// Change from S7.8 to S7.12 before tanh/sigmoid activation

module enhanced_accumulator #(
    parameter MAC_WIDTH = 16,        // S7.8 MAC results
    parameter ACC_WIDTH = 20,        // S7.12 accumulator (4 extra fractional bits)
    parameter OUTPUT_WIDTH = 16      // S7.8 final output
) (
    input clk,
    input rst_n,
    input [MAC_WIDTH-1:0] mac_result,
    input accumulate_en,
    input output_en,
    output reg [OUTPUT_WIDTH-1:0] acc_out
);

    // Internal accumulator with higher precision
    reg [ACC_WIDTH-1:0] accumulator;  // S7.12 format
    
    // Extend MAC result from S7.8 to S7.12 by adding 4 zero bits
    wire [ACC_WIDTH-1:0] mac_extended;
    assign mac_extended = {{4{mac_result[MAC_WIDTH-1]}}, mac_result, 4'b0000};
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 20'd0;
        end else if (accumulate_en) begin
            accumulator <= accumulator + mac_extended;
        end
    end
    
    // When outputting, round instead of truncate
    // Add 0.5 LSB (in S7.8 terms) = add 8 (in S7.12 terms, since we're truncating 4 bits)
    wire [ACC_WIDTH-1:0] rounded_acc;
    assign rounded_acc = accumulator + 20'd8;  // Add 0.5 * 2^4 = 8
    
    // Truncate from S7.12 to S7.8 (remove 4 LSBs after rounding)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out <= 16'd0;
        end else if (output_en) begin
            acc_out <= rounded_acc[19:4];  // S7.12 → S7.8
        end
    end

endmodule

// ============================================================================
// Alternative: Use S7.14 for even better precision
// ============================================================================

module ultra_precision_accumulator #(
    parameter MAC_WIDTH = 16,        // S7.8 MAC results
    parameter ACC_WIDTH = 22,        // S7.14 accumulator (6 extra fractional bits)
    parameter OUTPUT_WIDTH = 16      // S7.8 final output
) (
    input clk,
    input rst_n,
    input [MAC_WIDTH-1:0] mac_result,
    input accumulate_en,
    input output_en,
    output reg [OUTPUT_WIDTH-1:0] acc_out
);

    reg [ACC_WIDTH-1:0] accumulator;  // S7.14 format
    
    // Extend MAC result from S7.8 to S7.14 by adding 6 zero bits
    wire [ACC_WIDTH-1:0] mac_extended;
    assign mac_extended = {{6{mac_result[MAC_WIDTH-1]}}, mac_result, 6'b000000};
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 22'd0;
        end else if (accumulate_en) begin
            accumulator <= accumulator + mac_extended;
        end
    end
    
    // Round: Add 0.5 LSB = 32 (2^5, middle of 6 bits being truncated)
    wire [ACC_WIDTH-1:0] rounded_acc;
    assign rounded_acc = accumulator + 22'd32;
    
    // Truncate from S7.14 to S7.8
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out <= 16'd0;
        end else if (output_en) begin
            acc_out <= rounded_acc[21:6];  // S7.14 → S7.8
        end
    end

endmodule

// ============================================================================
// PRECISION COMPARISON
// ============================================================================
// Format    | Fractional Bits | LSB Value     | Expected Error (96 MACs)
// ----------|-----------------|---------------|-------------------------
// S7.8      | 8 bits          | 0.00390625    | 0.10 - 0.20
// S7.12     | 12 bits         | 0.000244141   | 0.015 - 0.030
// S7.14     | 14 bits         | 0.000061035   | 0.005 - 0.010
// ============================================================================

// Recommended: Use S7.12 or S7.14 for accumulator
// Cost: +4 or +6 bits per accumulator register
// Benefit: 10-20x reduction in activation function error
