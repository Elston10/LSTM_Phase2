`timescale 1ns / 1ps

module tb_top;
    localparam DATA_WIDTH      = 16;
    localparam OUTPUT_WIDTH    = 16;
    localparam ADDR_WIDTH      = 16;
    localparam TILE_ADDR_WIDTH = 4;
    localparam MATRIX_ROWS     = 376;
    localparam MATRIX_COLS     = 100;//7;

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
        // Stimulus: Stream 96 values using repeating pattern [0.5, 0.125, 0.25, 1, 0.625]
        #10;
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            case (i % 5)
                0: data_in = $rtoi(0.5 * 256.0);    // Q8.8 fixed-point
                1: data_in = $rtoi(0.125 * 256.0);  // Q8.8 fixed-point
                2: data_in = $rtoi(0.25 * 256.0);   // Q8.8 fixed-point
                3: data_in = $rtoi(1.0 * 256.0);    // Q8.8 fixed-point
                4: data_in = $rtoi(0.625 * 256.0);  // Q8.8 fixed-point
            endcase
            we = 1;
            gb_data_addr = i;
        end
        @(posedge clk);
        we = 0;
        // End simulation
        #10000; 



        $stop;
    end

    always #5 clk = ~clk;

endmodule
