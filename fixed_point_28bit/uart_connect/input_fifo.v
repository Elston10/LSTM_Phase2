`timescale 1ns /1ps

module sync_fifo #(
    parameter DATA_WIDTH = 140,
    parameter DEPTH      = 20,
    parameter ADDR_WIDTH = 5
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     wr_en,
    input  wire                     rd_en,
    input  wire [DATA_WIDTH-1:0]    wr_data,
    output reg  [DATA_WIDTH-1:0]    rd_data,
    output wire                     full,
    output wire                     empty,
    output match,
    input clear_fifo
);  

    reg [DATA_WIDTH-1:0]  mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0]  wr_ptr;
    reg [ADDR_WIDTH-1:0]  rd_ptr;
    reg [ADDR_WIDTH-1:0]  count;

    integer i;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);
    //--------------------------------------------------
    // Write logic — clean reset, no pre-loaded data
    //--------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n ) begin
            wr_ptr <= {ADDR_WIDTH{1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {DATA_WIDTH{1'b0}};
        end else if (clear_fifo ) begin
            wr_ptr <= {ADDR_WIDTH{1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {DATA_WIDTH{1'b0}};
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
        end
    end

    //--------------------------------------------------
    // Read logic
    //--------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr  <= {ADDR_WIDTH{1'b0}};
            rd_data <= {DATA_WIDTH{1'b0}};
       end else if(clear_fifo)begin
          rd_ptr  <= {ADDR_WIDTH{1'b0}};
           rd_data <= {DATA_WIDTH{1'b0}};
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr  <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
        end
    end

    //--------------------------------------------------
    // Count logic
    //--------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {ADDR_WIDTH{1'b0}};
        end
        else if(clear_fifo) begin
           count<= {ADDR_WIDTH{1'b0}};
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   count <= count + 1;  // write only
                2'b01:   count <= count - 1;  // read only
                default: count <= count;       // both or neither
            endcase
        end
    end
//    assign match = (mem[0] == 140'h8A2561_06360D_1A7E80_065823_81DEAD);
endmodule