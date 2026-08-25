`timescale 1ns/1ps

module mux_2_1_16bit (
    input [6:0] a,
    input [6:0] b,
    input sel,
    output [6:0] out
);

assign out = sel ? b : a;

endmodule