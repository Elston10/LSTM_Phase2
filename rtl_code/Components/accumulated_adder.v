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

// Wire for adder output
wire [DATA_WIDTH-1:0] acc_sum_next;

// Instantiate adder
adder #(.WIDTH(DATA_WIDTH)) acc_adder (
    .a(acc_sum),
    .b(tile_sum),
    .sum(acc_sum_next),
    .overflow()
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        acc_sum <= {DATA_WIDTH{1'b0}};
    else if (clear)
        acc_sum <= {DATA_WIDTH{1'b0}};
    else if (valid_in) begin
        acc_sum <= acc_sum_next;
    end
end

endmodule