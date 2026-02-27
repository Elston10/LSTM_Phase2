module memory_100x16 #(
    parameter DATA_WIDTH = 16,      // Each location stores 16 bits
    parameter DEPTH = 100,          // 100 locations
    parameter ADDR_WIDTH = 7        // log2(100) = 7 bits for address (0-127 supported)
)(
    input clk,
    input rst,
    
    // Write port
    input wr_en,                                    // Write enable
    input [ADDR_WIDTH-1:0] wr_addr,                // Write address (0-99)
    input [DATA_WIDTH-1:0] wr_data,                // Data to write (16 bits)
    
    // Read port
    input rd_en,                                    // Read enable
    input [ADDR_WIDTH-1:0] rd_addr,                // Read address (0-99)
    output  [DATA_WIDTH-1:0] rd_data            // Data read out (16 bits)
);

    // Memory array: 100 locations × 16 bits each
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Initialize memory to zero
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 16'h0;
        end
    end
    
    // Write operation (synchronous)
    always @(posedge clk) begin
        if (!rst) begin
            // On reset, memory is cleared (already initialized)
        end else begin
            if (wr_en) begin
                mem[wr_addr] <= wr_data;
            end
        end
    end
    

assign  rd_data = mem[rd_addr];

    
    
endmodule