// Matrix/Memory with 100 locations, each 16-bit wide
module xt_ht_1_bias_matrix #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 7,      // 2^7 = 128 > 100
    parameter DEPTH = 100
) (
    input  clk,
    input  rst,
    input  wr_en,              // Write enable
    input  [ADDR_WIDTH-1:0] addr,  // Address (0-99)
    input  [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] output_data
);

// ============================================================================
// Memory Array: 100 locations x 16 bits
// ============================================================================

reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];

// ============================================================================
// Write Operation
// ============================================================================

always @(posedge clk or negedge rst) begin
    if (rst) begin
        // Optional: Initialize to zero on reset
        integer i;
        for (i = 0; i < DEPTH; i = i + 1) begin
            memory[i] <= {DATA_WIDTH{1'b0}};
        end
    end else if (wr_en && addr < DEPTH) begin
        memory[addr] <= data_in;
    end
end

// ============================================================================
// Read Operation
// ============================================================================

always @(posedge clk or posedge rst) begin
    if (rst) begin
        output_data <= {DATA_WIDTH{1'b0}};
    end else begin
        if (addr < DEPTH)
            output_data <= memory[addr];
        else
            output_data <= {DATA_WIDTH{1'b0}};  // Return 0 for invalid address
    end
end

endmodule