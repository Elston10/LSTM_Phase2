`timescale 1ns / 1ps

module fc_weight_bram #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 7,   // 7 bits for 94 addresses (0-93)
    parameter MEM_SIZE = 94
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [ADDR_WIDTH-1:0]    addr,      // Read address
    output reg  [DATA_WIDTH-1:0]    dout       // Data output
);

    // BRAM array
    reg [DATA_WIDTH-1:0] bram [0:MEM_SIZE-1];
    
    // Load weights from memory file
    initial begin
        $readmemb("fc_weights.mem", bram);
    end
    
    // Simple read operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= {DATA_WIDTH{1'b0}};
        end 
        else begin
            dout <= bram[addr];
        end
    end

endmodule