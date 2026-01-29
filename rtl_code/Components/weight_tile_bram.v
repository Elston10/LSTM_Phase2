`timescale 1ns / 1ps
module weight_tile_bram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 2
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [ADDR_WIDTH-1:0]    addr,
    input  wire [ADDR_WIDTH-1:0]    rd_addr,   // Separate read address
    input  wire [DATA_WIDTH-1:0]    din,
    input  wire                     reset_done,
    input  wire                     we,        // write enable
    input  wire                     rd_en,     // read enable
    output wire [DATA_WIDTH-1:0]    dout,
    output wire                     done,
    output wire                     almost_full_pulse // 1-cycle pulse when almost full
);

    // ----------------------------------------------------
    // BRAM declaration
    // ----------------------------------------------------
    reg [DATA_WIDTH-1:0] bram [0:(2**ADDR_WIDTH)-1];
    reg [ADDR_WIDTH-1:0] read_count;
    // Counter to track number of writes
    reg [ADDR_WIDTH:0] write_count;
    reg                done_write;
    reg                almost_full_d;
   
    assign done = reset_done ? 1'b0 : done_write;

    // Almost full logic: asserts when one location left before full (write_count == (2**ADDR_WIDTH - 2))
    wire almost_full = (write_count == (2**ADDR_WIDTH - 2));
    // Pulse generation
    assign almost_full_pulse = almost_full & ~almost_full_d;

    // ----------------------------------------------------
    // Write Operation
    // ----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            almost_full_d <= 1'b0;
        else
            almost_full_d <= almost_full;

        if (!rst_n) begin
            write_count <= 0;
            done_write  <= 0;
            read_count<=0;
        end 
        else if (we && !done_write) begin
            bram[addr] <= din;
            if (write_count == (2**ADDR_WIDTH - 1))
                done_write <= 1;
            else
                write_count <= write_count + 1;
            
        end
        else if(rd_en && done_write)begin
            if(read_count == (2**ADDR_WIDTH - 1))begin
                read_count <= 0;
                write_count<=0;
                done_write<=0;
            end else
                read_count <= read_count + 1;
        end
        else if(!done_write)begin
            read_count<=0;
        end
    end

    // ----------------------------------------------------
    // Read Operation - COMBINATIONAL (asynchronous)
    // Uses separate read address for independent read/write access
    // ----------------------------------------------------
    assign dout = (rd_en && done_write) ? bram[rd_addr] : {DATA_WIDTH{1'b0}};

endmodule