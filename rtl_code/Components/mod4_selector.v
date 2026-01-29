// Module: mod4_selector
// Description: Generates a select signal based on modulus operation of input value
//              Works for any input value and configurable modulus divisor (power of 2)
//              Example: MOD=4: 93->sel=1, 94->sel=2, 95->sel=3, 96->sel=0
//              Example: MOD=8: 0->0, 1->1, ..., 7->7, 8->0, ...
// Author: Generated for MATMUL project
// Date: January 27, 2026

module mod4_selector #(
    parameter WIDTH = 16,      // Width of the input value
    parameter MOD = 4,         // Modulus divisor (must be power of 2: 2, 4, 8, 16, etc.)
    parameter SEL_WIDTH = 2    // Width of select signal (log2(MOD))
)(
    input  wire [WIDTH-1:0]       value_in,
    output wire [SEL_WIDTH-1:0]   sel
);

    // Calculate modulus by extracting lower SEL_WIDTH bits
    // For MOD=4 (SEL_WIDTH=2): value_in[1:0] gives 0,1,2,3
    // For MOD=8 (SEL_WIDTH=3): value_in[2:0] gives 0-7
    // For MOD=16 (SEL_WIDTH=4): value_in[3:0] gives 0-15
    assign sel = ~value_in[SEL_WIDTH-1:0];

endmodule

