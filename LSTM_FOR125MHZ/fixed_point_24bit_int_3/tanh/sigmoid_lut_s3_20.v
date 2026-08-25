// S3.20 Fixed-point sigmoid LUT ROM - HIGH ACCURACY (6144 entries)
// 6144 entries covering range [0.0, 6.0]
// Uses $readmemh for initialization
// Step size: 0.000976721472
// Output range: [sig(0)=0.5, sig(6)~1.0]

module sigmoid_lut_s3_20 (
    input [12:0] addr,        // 13-bit address (0-6143)
    output [23:0] data        // 24-bit output
);

    reg [23:0] rom [0:6143];

    initial begin
        $readmemh("sigmoid_lut_hex_s3_20.mem", rom);
    end

    assign data = rom[addr];

endmodule
