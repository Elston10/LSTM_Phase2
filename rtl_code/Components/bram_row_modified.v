`timescale 1ns / 1ps
module bram_row_modified #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4,
    parameter MEM_SIZE= 4
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
    output wire                     done,read_done_out,
    output reg [ADDR_WIDTH:0] write_count
);
  assign read_done_out=read_done;

    // ----------------------------------------------------
    // BRAM declaration
    // ------------------------------a----------------------
    reg [DATA_WIDTH-1:0] bram [0:MEM_SIZE-1];
    reg [ADDR_WIDTH-1:0] read_count;    
    // Counter to track number of writes
    reg                done_write;
    reg read_done;
    integer i;
    assign done = (reset_done == 1'b0) ? done_write : 1'b0;

    // ----------------------------------------------------
    // Write Operation
    // ----------------------------------------------------
   always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_count <= 0;
        done_write  <= 0;
        read_count  <= 0;  
        read_done   <= 0;
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            bram[i] <= {DATA_WIDTH{1'b0}};
        end
    end 
    // Write operation
    else if (we && !done_write) begin
        bram[addr] <= din;
        if (write_count == (MEM_SIZE- 1)) begin
            done_write <= 1;
            write_count <= 0;
        end else begin
            write_count <= write_count + 1;
        end
    end
    // Read operation
    else if (rd_en && done_write && !read_done) begin
        if (read_count == (MEM_SIZE - 1)) begin
            read_count <= 0;
            done_write <= 0;
            read_done  <= 1;
        end else begin
            read_count <= read_count + 1;
        end
    end
    else if (read_count == 0) begin
        read_done <= 0;
    end
    // Clear read_done and write_count only on new write or reset
    else if (we && done_write) begin
        read_done   <= 0;
    end
end


    // ----------------------------------------------------
    // Read Operation - COMBINATIONAL (asynchronous)
    // Uses separate read address for independent read/write access
    // ----------------------------------------------------
    assign dout = (rd_en && done_write) ? bram[rd_addr] : {DATA_WIDTH{1'b0}};

endmodule