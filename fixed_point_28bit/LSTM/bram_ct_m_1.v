`timescale 1ns/1ps

module ct_minus_1_bram #(
    parameter DATA_WIDTH = 28,
    parameter ADDR_WIDTH = 7,          // 2^7 = 128 > 100 locations
    parameter MEM_DEPTH  = 94          // c(t-1) vector length = 100
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  we,         // write enable
    input  wire [ADDR_WIDTH-1:0] wr_addr,    // write address
    input  wire [ADDR_WIDTH-1:0] rd_addr,    // read address
    input  wire [DATA_WIDTH-1:0] din,        // data in
    output   [DATA_WIDTH-1:0] dout,           // data out
    input clear_all
);

    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Initialize to zero
    integer i;

    // Write port
    always @(posedge clk) begin
        if(!rst_n)
            for (i = 0; i < MEM_DEPTH; i = i + 1)
                mem[i] <= 28'h0000000;
          else if(clear_all)begin
                    for (i = 0; i < MEM_DEPTH; i = i + 1)
                mem[i] <= 28'h0000000;
        end
        else if(we)
            mem[wr_addr] <= din;
    end

    assign dout = mem[rd_addr];

endmodule