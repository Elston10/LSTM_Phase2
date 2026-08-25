`timescale 1ns /1ps

module fifo
    #(
       parameter DATA_SIZE      = 8,
                 ADDR_SPACE_EXP = 4,
                 FIFO_DEPTH     = 18
    )
    (
       input clk,
       input reset,           // active-LOW reset (rst_n)
       input write_to_fifo,
       input read_from_fifo,
       input  [DATA_SIZE-1:0] write_data_in,
       output [DATA_SIZE-1:0] read_data_out,
       output reg fifo_full,
       output reg fifo_empty,
       input clear_fifo
    );

    reg [DATA_SIZE-1:0]      memory [0:FIFO_DEPTH-1];
    reg [ADDR_SPACE_EXP-1:0] current_write_addr, current_write_addr_buff, next_write_addr;
    reg [ADDR_SPACE_EXP-1:0] current_read_addr,  current_read_addr_buff,  next_read_addr;
    reg full_buff, empty_buff;
    reg [ADDR_SPACE_EXP-1:0] item_count, item_count_buff;
    wire write_enabled;

    // FIX: initial block sets all regs at time 0
    // so no X even before reset is pulsed
    // integer i;
    // initial begin

    //     memory[0] = 8'h01;
    //     memory[1] = 8'h02;
    //     memory[2] = 8'h03;
    //     memory[3] = 8'h04;
    //     memory[4] = 8'h05;
    //     memory[5] = 8'h06;
    //     memory[6] = 8'h07;
    //     memory[7] = 8'h08;
    //     memory[8] = 8'h09;
    //     memory[9] = 8'h0A;
    // end

    // Write operation
    always @(posedge clk)
        if(write_enabled)
            memory[current_write_addr] <= write_data_in;

    // Read operation
    assign read_data_out = memory[current_read_addr];

    // Only write when not full
    assign write_enabled = write_to_fifo & ~fifo_full;

    // FIX: negedge reset = active-LOW, check !reset
    always @(posedge clk or negedge reset)
        if(!reset | clear_fifo) begin
            current_write_addr <= 4'd0;
            current_read_addr  <= 4'd0;
            fifo_full          <= 1'b0;
            fifo_empty         <= 1'b1;
            item_count         <= 4'd0;   // FIX: was FIFO_DEPTH; starting at 10 skipped the fill threshold
        end
        else begin
            current_write_addr <= current_write_addr_buff;
            current_read_addr  <= current_read_addr_buff;
            fifo_full          <= full_buff;
            fifo_empty         <= empty_buff;
            item_count         <= item_count_buff;
        end

    always @* begin
        next_write_addr = (current_write_addr == FIFO_DEPTH-1) ? 0 : current_write_addr + 1;
        next_read_addr  = (current_read_addr  == FIFO_DEPTH-1) ? 0 : current_read_addr  + 1;

        current_write_addr_buff = current_write_addr;
        current_read_addr_buff  = current_read_addr;
        full_buff               = fifo_full;
        empty_buff              = fifo_empty;
        item_count_buff         = item_count;

        case({write_to_fifo, read_from_fifo})

            2'b01: // read only
                if(~fifo_empty) begin
                    current_read_addr_buff = next_read_addr;
                    item_count_buff        = item_count - 1;
                    full_buff              = 1'b0;
                    if(item_count == 1)
                        empty_buff = 1'b1;
                end

            2'b10: // write only
                if(~fifo_full) begin
                    current_write_addr_buff = next_write_addr;
                    item_count_buff         = item_count + 1;
                    empty_buff              = 1'b0;
                    if(item_count == FIFO_DEPTH-1)
                        full_buff = 1'b1;
                end

            2'b11: begin // simultaneous read and write
                current_write_addr_buff = next_write_addr;
                current_read_addr_buff  = next_read_addr;
            end

        endcase
    end

    assign full  = fifo_full;
    assign empty = fifo_empty;

endmodule