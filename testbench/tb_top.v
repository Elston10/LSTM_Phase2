`timescale 1ns / 1ps
module tb_top;
    // Monitor: Print gb_rd_weight_addr at every positive clock edge


    localparam DATA_WIDTH      = 32;
    localparam OUTPUT_WIDTH    = 64;
    localparam ADDR_WIDTH      = 16;   // 256 locations per tile
    localparam TILE_ADDR_WIDTH = 4;   // 16 locations
    localparam MATRIX_ROWS     = 384;
    localparam MATRIX_COLS     = 96;

    reg clk;
    reg rst_n;

    reg we;
    reg [DATA_WIDTH-1:0] data_in;
    reg [DATA_WIDTH-1:0] weight_in;
    reg [ADDR_WIDTH-1:0] gb_wr_weight_addr;
    reg [6:0]            gb_data_addr;

    wire [OUTPUT_WIDTH-1:0] pe1, pe2, pe3, pe4;
    wire compute_done;
    // DUT ------------------------------------------------------------
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
        .gb_wr_weight_addr(gb_wr_weight_addr),
        .gb_data_addr(gb_data_addr),
        .pe1(pe1),
        .pe2(pe2),
        .pe3(pe3),
        .pe4(pe4),
        .compute_done(compute_done),
        .gb_rd_weight_addr(gb_rd_weight_addr)
    );
    // Monitor: Print gb_rd_weight_addr when row_jumped is high
    // row_jumped is internal, so use a waveform viewer or add a temporary debug output in RTL if needed.

    // ------------------- Clock (100 MHz) -----------------------------
    always #5 clk = ~clk;

    // ------------------- Reset ---------------------------------------
    task reset;
    begin
        rst_n = 0;
        we = 0;
        gb_wr_weight_addr = 0;
        gb_data_addr = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    end
    endtask

    // ================================================================
    //   STREAM 96x1 VECTOR (values 1 to 96)
    // ================================================================
    task stream_vector_96x1;
        integer i;
        begin
            $display("Streaming 96x1 vector (values 1 to 96)");
            for (i = 0; i < 96; i = i + 1) begin
                @(posedge clk);
                data_in = i + 1;
                we = 1;
                gb_data_addr = i;
            end
            @(posedge clk);
            we = 0;
        end
    endtask
    always @(posedge clk) begin
        if (uut.row_jumped) begin
            $display("rd address at the time %0t %d", $time, uut.gb_rd_weight_addr);
        end
    end 
    // =================================================================
    //  MAIN TB SEQUENCE
    // =================================================================
    initial begin
        clk = 0;
        reset;

        stream_vector_96x1;

        repeat(5000) @(posedge clk);

        $display("---- PE OUTPUTS ----");
        $display("PE1 = %0d", pe1);
        $display("PE2 = %0d", pe2);
        $display("PE3 = %0d", pe3);
        $display("PE4 = %0d", pe4);
        $display("compute_done = %b", compute_done);

        $stop;
    end

endmodule
