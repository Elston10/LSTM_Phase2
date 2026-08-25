module sigmoid_lut_s7_20 (
    input [12:0] addr,
    output signed [27:0] data   // ? FIX: signed
);

    reg signed [27:0] rom [0:6143]; // ? FIX: signed

    initial begin
        $readmemh("sigmoid_lut_hex_s7_20.mem", rom);
    end

    assign data = rom[addr];

endmodule