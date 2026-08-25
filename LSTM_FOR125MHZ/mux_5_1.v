`timescale 1ns/1ps

module mux_5to1 #(
    parameter DATA_WIDTH = 16
)(
    input [DATA_WIDTH-1:0] data_in0,
    input [DATA_WIDTH-1:0] data_in1,
    input [DATA_WIDTH-1:0] data_in2,
    input [DATA_WIDTH-1:0] data_in3,
    input [DATA_WIDTH-1:0] data_in4,
    
    input [2:0] sel,
    
    output [DATA_WIDTH-1:0] data_out
);

    // Combinational logic using ternary operators
    assign data_out = (sel == 3'b000) ? data_in0 :
                      (sel == 3'b001) ? data_in1 :
                      (sel == 3'b010) ? data_in2 :
                      (sel == 3'b011) ? data_in3 :
                      (sel == 3'b100) ? data_in4 :
                      16'h0000;

endmodule