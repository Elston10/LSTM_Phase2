module dff_16bit (
    input wire clk,
    input wire [15:0] d,
    output reg [15:0] q
);

always @(posedge clk) begin
    q <= d;
end

endmodule