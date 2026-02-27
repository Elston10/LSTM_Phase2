module sync_fifo #(
    parameter DATA_WIDTH = 80,
    parameter DEPTH = 20,
    parameter ADDR_WIDTH = 5,
    parameter INIT_COUNT = 20
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

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH-1:0] count;
    
    assign full = (count == DEPTH);
    assign empty = (count == 0);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= INIT_COUNT;
            
            // Format: [Voltage][Current][Temp][Power][Capacity]
            // Sign-magnitude Q7.8: bit[15]=sign, bits[14:0]=magnitude
            
        mem[0]  <= 80'h80A2_0063_01A8_0065_801E;
        mem[1]  <= 80'h80A2_0063_01A8_0065_801E;
        mem[2]  <= 80'h80A2_0063_01A8_0065_801E;
        mem[3]  <= 80'h80A2_0063_01A8_0065_801E;
        mem[4]  <= 80'h80A2_0063_01A8_0065_801E;
        mem[5]  <= 80'h80A2_0063_01A8_0065_801E;
        mem[6]  <= 80'h80A2_0063_01A8_0065_801E;
        mem[7]  <= 80'h80A2_0063_01A8_0065_801E;
        mem[8]  <= 80'h80A2_0051_01A8_0054_8020;
        mem[9]  <= 80'h80A2_001E_01A8_0023_8027;
        mem[10] <= 80'h80A3_8046_01A8_803E_8034;
        mem[11] <= 80'h80A3_8055_01A8_804D_8037;
        mem[12] <= 80'h80A3_807D_01A8_8074_803D;
        mem[13] <= 80'h80A3_804E_01A8_8046_8039;
        mem[14] <= 80'h80A3_804B_01A8_8043_8039;
        mem[15] <= 80'h80A3_80D6_01A8_80CD_804B;
        mem[16] <= 80'h80A4_810F_01A6_80EB_8052;
        mem[17] <= 80'h80A4_80A4_01A6_809B_8049;
        mem[18] <= 80'h80A4_8093_01A6_8088_8048;
        mem[19] <= 80'h80A4_808D_01A6_8085_8048;
            
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            rd_data <= 0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= INIT_COUNT;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: count <= count;
            endcase
        end
    end

endmodule
