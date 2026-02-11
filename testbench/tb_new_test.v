`timescale 1ns / 1ps

module tb_top;
    localparam DATA_WIDTH      = 16;
    localparam OUTPUT_WIDTH    = 16;
    localparam ADDR_WIDTH      = 16;
    localparam TILE_ADDR_WIDTH = 4;
    localparam MATRIX_ROWS     = 376;
    localparam MATRIX_COLS     = 100;

    reg clk;
    reg rst_n;
    reg we;
    reg [DATA_WIDTH-1:0] data_in;
    reg [DATA_WIDTH-1:0] weight_in;
    reg [6:0] gb_data_addr;
    reg [31:0] i;

    // DUT instantiation
    top #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TILE_ADDR_WIDTH(TILE_ADDR_WIDTH),
        .MATRIX_ROWS(MATRIX_ROWS),
        .MATRIX_COLS(MATRIX_COLS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .we(we),
        .data_in(data_in),
        .weight_in(weight_in),
        .gb_data_addr(gb_data_addr)
    );

    initial begin
        clk = 0;
        rst_n = 0;
        we = 0;
        gb_data_addr = 0;
        data_in = 0;
        weight_in = 0;
        #30;
        rst_n = 1;
        #10;

        // Stream 100 values: 94 zeros, then [0.1, 0.2, 0.3, 0.4, 0.5], then 1.0
        // S7.8 fixed-point: multiply by 256 (2^8)
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            
            if (i < 94) begin
                data_in = 16'h0000;  // Zero
            end else if (i == 94) begin
                data_in = 16'h0019;  // 0.1 * 256 = 25.6 -> 26 (0x1A) or 25 (0x19)
            end else if (i == 95) begin
                data_in = 16'h0033;  // 0.2 * 256 = 51.2 -> 51 (0x33)
            end else if (i == 96) begin
                data_in = 16'h004D;  // 0.3 * 256 = 76.8 -> 77 (0x4D)
            end else if (i == 97) begin
                data_in = 16'h0066;  // 0.4 * 256 = 102.4 -> 102 (0x66)
            end else if (i == 98) begin
                data_in = 16'h0080;  // 0.5 * 256 = 128 (0x80)
            end else if (i == 99) begin
                data_in = 16'h0100;  // 1.0 * 256 = 256 (0x100)
            end
            
            we = 1;
            gb_data_addr = i;
        end

        @(posedge clk);
        we = 0;
        #10000;
        $stop;
    end

    always #5 clk = ~clk;

endmodule