module memory_94x16 #(
    parameter DATA_WIDTH = 16,      // Each location stores 16 bits
    parameter DEPTH = 94,           // 94 locations
    parameter ADDR_WIDTH = 7        // log2(94) = 7 bits for address (0-127 supported)
)(
    input clk,
    input rst,                                     // Active low reset
    
    // Write port
    input wr_en,                                    // Write enable
    input [ADDR_WIDTH-1:0] wr_addr,                // Write address (0-93)
    input [DATA_WIDTH-1:0] wr_data,                // Data to write (16 bits)
    
    // Read port
    input rd_en,                                    // Read enable
    input [ADDR_WIDTH-1:0] rd_addr,                // Read address (0-93)
    output reg [DATA_WIDTH-1:0] rd_data            // Data read out (16 bits)
);

    // Memory array: 94 locations × 16 bits each
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Initialize memory to zero
     integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = i + 1;  // Initialize with 1, 2, 3, ..., 94
        end
    end
    integer j;
    // Write operation (synchronous)
    always @(posedge clk) begin
        if (!rst) begin
            // Active low reset - clear memory
            for (j = 0; j < DEPTH; j = j + 1) begin
                mem[j] <= 16'h0;
            end
        end else begin
            if (wr_en) begin
                mem[wr_addr] <= wr_data;
            end
        end
    end
    
    // Read operation (synchronous)
    always @(posedge clk) begin
        if (!rst) begin
            rd_data <= 16'h0;
        end else begin
            if (rd_en) begin
                rd_data <= mem[rd_addr];
            end
        end
    end
    
endmodule