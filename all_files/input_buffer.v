module input_buffer #(
    parameter DATA_WIDTH = 80,      // Each location stores 80 bits
    parameter DEPTH = 20,           // 20 locations (for 20 timesteps)
    parameter ADDR_WIDTH = 5        // log2(20) = 5 bits for address
)(
    input clk,
    input rst,
    
    // Write port
    input wr_en,                                    // Write enable
    input [ADDR_WIDTH-1:0] wr_addr,                // Write address (0-19)
    input [DATA_WIDTH-1:0] wr_data,                // Data to write (80 bits)
    
    // Read port
    input rd_en,                                    // Read enable
    input [ADDR_WIDTH-1:0] rd_addr,                // Read address (0-19)
    output reg [DATA_WIDTH-1:0] rd_data          // Data read out (80 bits)
);

    // Memory array: 20 locations × 80 bits each
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Initialize memory to zero
    initial begin
    mem[0] <= 80'h80A2006301A80065801E;
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
    
    // Read operation (synchronous)
    always @(posedge clk) begin
        if (!rst) begin
            rd_data <= 80'h0;
        end else begin
                rd_data <= (rd_en)? mem[rd_addr] : 0;
        end
    end
    
endmodule