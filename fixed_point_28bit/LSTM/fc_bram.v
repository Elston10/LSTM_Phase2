`timescale 1ns / 1ps

module fc_weight_bram #(
    parameter DATA_WIDTH = 28,           // Changed from 16 to 24
    parameter ADDR_WIDTH = 7,            // 7 bits for 94 addresses (0-93)
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
        $readmemh("fc_weights.mem", bram);
    end
    
    // Simple read operation
    always @(posedge clk ) begin
        if (!rst_n) begin
            dout <= {DATA_WIDTH{1'b0}};
        end 
        else begin
            dout <= bram[addr];
        end
    end

endmodule