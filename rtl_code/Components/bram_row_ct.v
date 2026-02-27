`timescale 1ns / 1ps
module bram_row_ct #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4,
    parameter MEM_SIZE = 4
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [ADDR_WIDTH-1:0]    addr,       // Write address
    input  wire [ADDR_WIDTH-1:0]    rd_addr,    // Read address
    input  wire [DATA_WIDTH-1:0]    din,        // Write data
    input  wire                     we,         // Write enable
    input  wire                     rd_en,      // Read enable
    output  [DATA_WIDTH-1:0]    dout,       // Read data
    input  wire                     inter_rst
);

    // BRAM array
    reg [DATA_WIDTH-1:0] bram [0:MEM_SIZE-1];
    
    integer i;

    // Write and Read operations
    always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
            // Initialize BRAM to zero
            for (i = 0; i < MEM_SIZE; i = i + 1) begin
                bram[i] <= {DATA_WIDTH{1'b0}};
            end
            end
            // Write port
            else if (we) begin
                bram[addr] <= din;
            end
          
    end

assign dout = bram[rd_addr];
endmodule