module tanh_lut_rom_s7_20_512 (
    input  [8:0] addr,
    output [27:0] data
);

    reg [27:0] rom [0:511];

    initial begin
        $readmemh("tanh_lut_hex_s7_20_512.mem", rom);
    end

    assign data = rom[addr];

endmodule