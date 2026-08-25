`timescale 1ns / 1ps

module uart_receiver
    #(
        parameter   DBITS = 8,          // number of data bits
                    SB_TICK = 16        // oversampling ticks
    )
    (
        input clk_125MHz,               // 125 MHz clock
        input reset,
        input rx,                       // receiver data line
        input sample_tick,              // sample tick from baud generator
        output reg data_ready,          // data received flag
        output [DBITS-1:0] data_out     // received data
    );
    
    localparam [1:0] idle  = 2'b00,
                     start = 2'b01,
                     data  = 2'b10,
                     stop  = 2'b11;
    
    reg [1:0] state, next_state;
    reg [3:0] tick_reg, tick_next;
    reg [2:0] nbits_reg, nbits_next;
    reg [7:0] data_reg, data_next;
    
    always @(posedge clk_125MHz, negedge reset)
        if(!reset) begin
            state <= idle;
            tick_reg <= 0;
            nbits_reg <= 0;
            data_reg <= 0;
        end
        else begin
            state <= next_state;
            tick_reg <= tick_next;
            nbits_reg <= nbits_next;
            data_reg <= data_next;
        end        

    always @* begin
        next_state = state;
        data_ready = 1'b0;
        tick_next = tick_reg;
        nbits_next = nbits_reg;
        data_next = data_reg;
        
        case(state)
            idle:
                if(~rx) begin
                    next_state = start;
                    tick_next = 0;
                end
            start:
                if(sample_tick)
                    if(tick_reg == 7) begin
                        next_state = data;
                        tick_next = 0;
                        nbits_next = 0;
                    end
                    else
                        tick_next = tick_reg + 1;
            data:
                if(sample_tick)
                    if(tick_reg == 15) begin
                        tick_next = 0;
                        data_next = {rx, data_reg[7:1]};
                        if(nbits_reg == (DBITS-1))
                            next_state = stop;
                        else
                            nbits_next = nbits_reg + 1;
                    end
                    else
                        tick_next = tick_reg + 1;
            stop:
                if(sample_tick)
                    if(tick_reg == (SB_TICK-1)) begin
                        next_state = idle;
                        data_ready = 1'b1;
                    end
                    else
                        tick_next = tick_reg + 1;
        endcase                    
    end
    
    assign data_out = data_reg;

endmodule