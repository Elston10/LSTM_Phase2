module accumulated_adder #(
    parameter DATA_WIDTH = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  clear,      // Synchronous clear accumulator
    input  wire                  valid_in,   // Assert when tile result is valid
    input  wire [DATA_WIDTH-1:0] tile_sum,   // Tile result to accumulate
    output reg  [DATA_WIDTH-1:0] acc_sum
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        acc_sum <= {DATA_WIDTH{1'b0}};
    else if (clear)
        acc_sum <= {DATA_WIDTH{1'b0}};
    else if (valid_in)begin
        acc_sum <= acc_sum + tile_sum;
    end 
end

endmodule