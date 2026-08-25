// S3.20 Fixed-point tanh LUT ROM - HIGH ACCURACY (512 entries)
// 512 entries covering range [0.25, 3.0]
// Uses $readmemh for initialization
// Step size: 0.0053816047

module tanh_lut_rom_s3_20_512 (
    input [8:0] addr,         // 9-bit address (0-511)
    output [23:0] data        // 24-bit output
);

    reg [23:0] rom [0:511];

    initial begin
        $readmemh("tanh_lut_hex_s3_20_512.mem", rom);
    end

    assign data = rom[addr];

endmodule
