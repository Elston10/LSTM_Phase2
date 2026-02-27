// LUT data for tanh approximation S7.8 format
// 176 entries covering range [0.25, 3.0]
// Uses memory initialization file

module tanh_lut_data (
    input [7:0] addr,
    output [15:0] data
);

    // ROM storage for 176 entries
    reg [15:0] rom [0:175];
    
    // Initialize ROM from memory file
    initial begin
        $readmemh("tanh_lut_hex.mem", rom);
    end
    
    // Output data with bounds checking
    assign data = (addr < 8'd176) ? rom[addr] : 16'h0000;

endmodule