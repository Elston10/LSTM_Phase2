`timescale 1ns / 1ps

module baud_rate_generator
    #(
        parameter   N = 5,      // number of counter bits (2^7, 5 = 128 > 68, 28)
                    M = 28      // counter limit value for 115200 baud at 125 MHz
                                // 125MHz / (115200 * 16) = 67.8 ≈ 68, 28
    )
    (
        input clk_125MHz,       // 125 MHz clock
        input reset,            // reset
        output tick,
        input clear_fifo             // sample tick
    );
    
    reg [N-1:0] counter;
    wire [N-1:0] next;
    
    always @(posedge clk_125MHz, negedge reset)
        if(!reset | clear_fifo)
            counter <= 0;
        else
            counter <= next;
            
    assign next = (counter == (M-1)) ? 0 : counter + 1;
    assign tick = (counter == (M-1)) ? 1'b1 : 1'b0;
       
endmodule