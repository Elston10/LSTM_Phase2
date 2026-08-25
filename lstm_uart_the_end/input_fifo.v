`timescale 1ns/1ps

module sync_fifo #(
    parameter DATA_WIDTH = 120, // 5 x 24 bits
    parameter DEPTH      = 20,
    parameter ADDR_WIDTH = 5,
    parameter INIT_COUNT = 20
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  wr_en,
    input  wire                  rd_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire                  full,
    output wire                  empty
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH-1:0] count;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);
    
// initial begin
//     // Pre-loaded data - intentional
// //mem[0] <= 120'h8A2561_06360D_1A7E80_065823_81DEAD;
// //mem[1] <= 120'h8A2587_06360D_1A7E80_065823_81DEAD;
// //mem[2] <= 120'h8A25B4_06360D_1A7E80_065823_81DEAD;
// //mem[3] <= 120'h8A25DA_06313E_1A7E80_065386_81DEAD;
// //mem[4] <= 120'h8A2608_06360D_1A7E80_065823_81DEAD;
// //mem[5] <= 120'h8A262D_06360D_1A7E80_065823_81DEAD;
// //mem[6] <= 120'h8A265B_06313E_1A7E80_065386_81DEAD;
// //mem[7] <= 120'h8A2681_06313E_1A7E80_065386_81DEAD;
// //mem[8] <= 120'h8A26EF_051690_1A7E80_0543CD_8201A3;
// //mem[9] <= 120'h8A27E0_01E593_1A7E80_023042_826A88;
// //mem[10] <= 120'h8A2A39_8463C0_1A7E80_83E8FD_833E87;
// //mem[11] <= 120'h8A2CC3_854EB8_1A7E80_84CF45_8371A9;
// //mem[12] <= 120'h8A3020_87D2B1_1A7E80_874639_83DA8D;
// //mem[13] <= 120'h8A3295_84ED8F_1A7E80_84732B_839247;
// //mem[14] <= 120'h8A34FE_84B435_1A7E80_843BE5_8396F9;
// //mem[15] <= 120'h8A38D3_8D763D_1A7E80_8CD550_84BC82;
// //mem[16] <= 120'h8A3DE9_8F4CE6_1A66EC_8EAB13_8520B3;
// //mem[17] <= 120'h8A4180_8A4788_1A66EC_89B88F_84998B;
// //mem[18] <= 120'h8A44E0_89451E_1A66EC_88BB44_848489;
// //mem[19] <= 120'h8A4834_890705_1A66EC_887F66_848B95;
// mem[0] = 120'h9E3EF9_28C971_835D64_0B7BBD_38D441;
// mem[1] = 120'h9E3B93_AEE04C_835D64_2FF9FB_3A5215;
// mem[2] = 120'h9E3828_AF26AB_835D64_2FF9FB_3A698E;
// mem[3] = 120'h9E3514_AF586F_835D64_2FF9FB_3A7A25;
// mem[4] = 120'h9E3266_7CC43D_835D64_2268B2_3A040E;
// mem[5] = 120'h9E31E5_192C28_835D64_0711DC_38F82D;
// mem[6] = 120'h9E31F4_82E4B8_835D64_80D139_38A4D3;
// mem[7] = 120'h9E3210_861230_835D64_81B761_38985F;
// mem[8] = 120'h9E3233_8636F8_835D64_81C1DD_3895A0;
// mem[9] = 120'h9E3251_865BD5_835D64_81CC4F_3894EE;
// mem[10] = 120'h9E3274_8636CE_835D64_81C1DD_38943C;
// mem[11] = 120'h9E3292_865BC0_835D64_81CC4F_38943C;
// mem[12] = 120'h9E32B5_8636CE_835D64_81C1DD_38943C;
// mem[13] = 120'h9E32D6_865BD5_835D64_81CC4F_3894EE;
// mem[14] = 120'h9E32F3_865BD5_835D64_81CC4F_3894EE;
// mem[15] = 120'h9E331A_86EFB3_835D64_81F62B_38938A;
// mem[16] = 120'h9E334C_89AD23_850C4A_82BCE8_388BF6;
// mem[17] = 120'h9E3388_8BB17B_835D64_834F61_3885BC;
// mem[18] = 120'h9E3422_9DC60B_835D64_88758E_385091;
// mem[19] = 120'h9E35F7_E3149A_835D64_9C90A1_377F63;
// end
initial begin
    $readmemh("fifo_init.mem", mem);
end
    // ? Write - mem separate, no async reset on array
    always @(posedge clk) begin
        if (wr_en && !full)
            mem[wr_ptr] <= wr_data;
    end

    // ? Write pointer - reset to 0 (all slots pre-filled, wrap correctly)
    always @(posedge clk) begin
        if (!rst_n)
            wr_ptr <= {ADDR_WIDTH{1'b0}};  // FIX: was INIT_COUNT=20 (out of bounds!)
        else if (wr_en && !full)
            wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
    end

    // ? Read - no reset on rd_data (prevents RAM dissolution)
    always @(posedge clk) begin
        if (!rst_n)
            rd_ptr <= {ADDR_WIDTH{1'b0}};
        else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr  <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
        end
    end

    // ? Count - reset to INIT_COUNT (correct, FIFO starts full)
    always @(posedge clk) begin
        if (!rst_n)
            count <= INIT_COUNT;  // intentional - starts full
        else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   count <= count + 1;
                2'b01:   count <= count - 1;
                default: count <= count;
            endcase
        end
    end

endmodule