`timescale 1ns/1ps
module bram_burst #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter MATRIX_COLS = 8  // Number of columns in the matrix
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   start,
    input  wire [ADDR_WIDTH-1:0]  base_addr,
    input  wire                   buffer_select,  // <-- newly added for ping-pong buffer selection
    output reg                    done,
    output wire                   full_burst_pulse,  // Indicates tile_buf is completely filled with 16 elements
     
    // Global BRAM interface
    input  wire [DATA_WIDTH-1:0]  global_dout,
    output reg  [ADDR_WIDTH-1:0]  global_addr,
    output reg                    global_re,

    // Tile BRAM interfaces (same names preserved)
    output reg  [ADDR_WIDTH-1:0]  tile_addr,
    output reg  [DATA_WIDTH-1:0]  tile_dout0,
    output reg  [DATA_WIDTH-1:0]  tile_dout1,
    output reg  [DATA_WIDTH-1:0]  tile_dout2,
    output reg  [DATA_WIDTH-1:0]  tile_dout3,
    output reg                    we0,
    output reg                    we1,
    output reg                    we2,
    output reg                    we3,
    output reg [7:0]              burst_write_count
    ,output wire                  almost_full_pulse // 1-cycle pulse when almost full (2 or fewer locations left)
);

    // FSM states
    localparam IDLE        = 3'd0;
    localparam READ_SETUP  = 3'd1;
    localparam READ_TILE   = 3'd2;
    localparam BURST_WRITE = 3'd3;
    localparam DONE        = 3'd4;

    reg [2:0] state;
    reg [3:0] read_cnt;
    reg [1:0] burst_row;
    reg [DATA_WIDTH-1:0] tile_buf [0:15];
    integer i;
    
    // For calculating addresses within a 4x4 tile
    wire [1:0] tile_row_pos;  // Row position within tile (0-3)
    wire [1:0] tile_col_pos;  // Column position within tile (0-3)
    wire [ADDR_WIDTH-1:0] next_row_addr;
    wire [3:0] next_read_cnt;
    wire [1:0] next_col_pos;
    
    // Extract row and column position from read counter
    assign tile_row_pos = read_cnt[3:2];
    assign tile_col_pos = read_cnt[1:0];
    assign next_read_cnt = read_cnt + 1'b1;
    assign next_col_pos = next_read_cnt[1:0];
    
    // Calculate address with row stride: base_addr + (row * MATRIX_COLS) + col
    assign next_row_addr = base_addr + (tile_row_pos * MATRIX_COLS) + tile_col_pos;
reg full_d; // delayed version of full
// Almost full logic: asserts when 2 or fewer locations left before full (i.e., read_cnt >= 13)
wire almost_full = (read_cnt >= 4'd13);
reg almost_full_d;
assign almost_full_pulse = almost_full & ~almost_full_d;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        almost_full_d <= 1'b0;
    else
        almost_full_d <= almost_full;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        full_d <= 1'b0;
    else
        full_d <= full;
end
reg full;
wire full_burst_pulse;
assign full_burst_pulse = full & ~full_d; // 1-cycle pulse when full goes
    //==================================================
    // Main sequential block
    //==================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            full <= 1'b0;
            global_addr <= 0;
            global_re <= 1'b0;
            tile_addr <= 0;
            read_cnt <= 0;
            burst_row <= 0;
            we0 <= 1'b0;
            we1 <= 1'b0;
            we2 <= 1'b0;
            we3 <= 1'b0;
            tile_dout0 <= 0;
            tile_dout1 <= 0;
            tile_dout2 <= 0;
            tile_dout3 <= 0;
            burst_write_count <= 0;
            for (i=0; i<16; i=i+1)
                tile_buf[i] <= 0;
        end else begin
            // Default assignments
            done <= 1'b0;
            full <= 1'b0;
            global_re <= 1'b0;
            we0 <= 1'b0;
            we1 <= 1'b0;
            we2 <= 1'b0;
            we3 <= 1'b0;

            case (state)
            //------------------------------------------
            IDLE: begin
                if (start) begin
                    global_addr <= base_addr;  // Request address [0,0]
                    global_re <= 1'b1;
                    read_cnt <= 0;
                    burst_write_count <= 0; 
                    state <= READ_SETUP;
                end
            end
            //------------------------------------------
            READ_SETUP: begin
                // Request address for element [0,1] (same row, next column)
                global_addr <= base_addr + 1;
                global_re <= 1'b1;
                state <= READ_TILE;
            end
            //------------------------------------------
            READ_TILE: begin
                tile_buf[read_cnt] <= global_dout;

                if (read_cnt < 4'd15) begin
                    read_cnt <= read_cnt + 1'b1;
                    
                    // Check current global_addr column position (relative to base_addr)
                    // If we're at last column of a 4-element row, jump to next row
                    if ((global_addr - base_addr) % MATRIX_COLS == 3) begin
                        // At column 3 (e.g., addr 3, 11, 19, 27)
                        // Jump to start of next row (e.g., 8, 16, 24, 32)
                        global_addr <= global_addr + (MATRIX_COLS - 3);
                        global_re <= 1'b1;
                
                    end else begin
                        // Normal increment within row
                        global_addr <= global_addr + 1'b1;
                        global_re <= 1'b1;
                    end
                end else begin
                    read_cnt <= read_cnt + 1'b1;
                    burst_row <= 0;
                    tile_addr <= 0;
                    full <= 1'b1;  // tile_buf is now completely filled with 16 elements
                    state <= BURST_WRITE;
                end
            end
            //------------------------------------------
            BURST_WRITE: begin
                if (full) begin
                    // Fill "buffer 1" set
                    tile_dout0 <= tile_buf[{burst_row, 2'b00}];
                    tile_dout1 <= tile_buf[{burst_row, 2'b01}];
                    tile_dout2 <= tile_buf[{burst_row, 2'b10}];
                    tile_dout3 <= tile_buf[{burst_row, 2'b11}];
                end else begin
                    tile_dout0 <= tile_buf[{burst_row, 2'b00}];
                    tile_dout1 <= tile_buf[{burst_row, 2'b01}];
                    tile_dout2 <= tile_buf[{burst_row, 2'b10}];
                    tile_dout3 <= tile_buf[{burst_row, 2'b11}];
                end

                // Assert write enables
                we0 <= 1'b1;
                we1 <= 1'b1;
                we2 <= 1'b1;
                we3 <= 1'b1;

                tile_addr <= burst_row;
                burst_write_count <= burst_write_count + 4;

                if (burst_row == 2'd3)
                    state <= DONE;
                else
                    burst_row <= burst_row + 1'b1;
            end
            //------------------------------------------
            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            //------------------------------------------
            endcase
        end
    end

endmodule
