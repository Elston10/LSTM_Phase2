module sync_fifo #(
    parameter DATA_WIDTH = 80,
    parameter DEPTH = 20,
    parameter ADDR_WIDTH = 5,  // log2(20) rounded up
    parameter INIT_COUNT = 2,   // Number of preloaded values
    parameter [DATA_WIDTH-1:0] INIT_VAL_0 = 80'h80A2006301A80065801E,  // First initial value
    parameter [DATA_WIDTH-1:0] INIT_VAL_1 = 80'h0   // Second initial value
)(
    input wire clk,
    input wire rst_n,
    input wire wr_en,
    input wire rd_en,
    input wire [DATA_WIDTH-1:0] wr_data,
    output reg [DATA_WIDTH-1:0] rd_data,
    output wire full,
    output wire empty
);

    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Read and write pointers
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH-1:0] count;
    
    // Full and empty flags
    assign full = (count == DEPTH);
    assign empty = (count == 0);
    
    // Write operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= INIT_COUNT;  // Start after preloaded values
            // Initialize memory with preset values
            mem[0] <= INIT_VAL_0;
            mem[1] <= INIT_VAL_1;
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
        end
    end
    
    // Read operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            rd_data <= 0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
        end
    end
    
    // Count management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= INIT_COUNT;  // Start with 2 values already in FIFO
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1;  // Write only
                2'b01: count <= count - 1;  // Read only
                default: count <= count;     // Both or neither
            endcase
        end
    end

endmodule