`timescale 1ns/1ps

module weight_global_bram #(
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 16,      // FIXED
    parameter MEM_SIZE   = 37600,
    parameter MEM_FILE   = "weights_q3_20_signmag.mem"
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    input  wire                 re,
    output reg  [DATA_WIDTH-1:0] dout,
    output done
);

    reg [DATA_WIDTH-1:0] bram [0:MEM_SIZE-1];

    // ------------------------------
    // SIMULATION LOAD
    // ------------------------------
    initial begin
        $readmemh(MEM_FILE, bram);
    end

    always @(posedge clk) begin
        if (!rst_n)
            dout <= {DATA_WIDTH{1'b0}};
        else if (re)
            dout <= bram[rd_addr];
    end
assign done = 1;
endmodule
