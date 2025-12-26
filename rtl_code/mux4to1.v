module mux4to1 #(
    parameter WIDTH = 64
)(
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    input  wire [WIDTH-1:0] d2,
    input  wire [WIDTH-1:0] d3,
    input  wire [1:0]       sel,
    input  wire             en,
    output reg  [WIDTH-1:0] y
);

always @(*) begin
    if (en) begin
        case (sel)
            2'b00: y = d0;
            2'b01: y = d1;
            2'b10: y = d2;
            2'b11: y = d3;
            default: y = {WIDTH{1'b0}};
        endcase
    end else begin
        y = {WIDTH{1'b0}};
    end
end

endmodule
