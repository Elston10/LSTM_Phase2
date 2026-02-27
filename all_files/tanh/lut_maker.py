import numpy as np

# Configuration
LUT_MIN = 0.25
LUT_MAX = 3.0
LUT_SIZE = 176
OUTPUT_FILE = "tanh_lut.mem"

def generate_mem_file():
    """Generate binary .mem file for Verilog $readmemb"""
    
    print("="*70)
    print("Tanh LUT Memory File Generator (Binary Format)")
    print("="*70)
    print(f"Range: [{LUT_MIN}, {LUT_MAX}]")
    print(f"Entries: {LUT_SIZE}")
    print(f"Format: 1 sign bit + 7 integer bits + 8 fractional bits")
    print(f"Output: {OUTPUT_FILE}")
    print("="*70 + "\n")
    
    lut_data = []
    max_error = 0.0
    total_error = 0.0
    
    with open(OUTPUT_FILE, 'w') as f:
        # Optional: Write header as comment
        f.write("// Tanh LUT Memory Initialization File (Binary Format)\n")
        f.write(f"// {LUT_SIZE} entries for range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write("// Format: S7.8 (1 sign + 7 integer + 8 fractional bits)\n")
        f.write("// Usage: $readmemb(\"tanh_lut.mem\", memory_array);\n")
        f.write("//\n")
        f.write("// Address : Binary Value (16 bits)\n")
        f.write("// -------   ---------------------------------\n")
        
        for i in range(LUT_SIZE):
            # Calculate input x value
            x = LUT_MIN + i * (LUT_MAX - LUT_MIN) / (LUT_SIZE - 1)
            
            # Calculate tanh(x)
            tanh_val = np.tanh(x)
            
            # Convert to S7.8 fixed-point
            tanh_s7p8 = int(round(tanh_val * 256))
            tanh_s7p8 = np.clip(tanh_s7p8, 0, 32767)
            
            # Extract components
            sign_bit = 0
            int_part = (tanh_s7p8 >> 8) & 0x7F
            frac_part = tanh_s7p8 & 0xFF
            
            # Create 16-bit binary string
            binary_16bit = f"{sign_bit:01b}{int_part:07b}{frac_part:08b}"
            
            # Verify
            recovered_val = tanh_s7p8 / 256.0
            error = abs(tanh_val - recovered_val)
            max_error = max(max_error, error)
            total_error += error
            
            # Store data for verification
            lut_data.append({
                'index': i,
                'x': x,
                'tanh_real': tanh_val,
                'tanh_s7p8': tanh_s7p8,
                'binary': binary_16bit,
                'error': error
            })
            
            # Write binary value (one per line)
            f.write(f"{binary_16bit}  // @{i:03d}: tanh({x:.4f}) = {tanh_val:.6f} = 0x{tanh_s7p8:04X}\n")
    
    avg_error = total_error / LUT_SIZE
    
    print(f"✓ Memory file generated: {OUTPUT_FILE}")
    print(f"\nStatistics:")
    print(f"  Total entries: {LUT_SIZE}")
    print(f"  Max error: {max_error:.8f}")
    print(f"  Avg error: {avg_error:.8f}")
    print(f"  File size: {LUT_SIZE} lines × 16 bits\n")
    
    return lut_data, max_error, avg_error

def generate_hex_mem_file(lut_data):
    """Also generate hex format .mem file"""
    
    hex_file = "tanh_lut_hex.mem"
    
    with open(hex_file, 'w') as f:
        f.write("// Tanh LUT Memory Initialization File (Hexadecimal Format)\n")
        f.write(f"// {LUT_SIZE} entries for range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write("// Format: S7.8 (1 sign + 7 integer + 8 fractional bits)\n")
        f.write("// Usage: $readmemh(\"tanh_lut_hex.mem\", memory_array);\n")
        f.write("//\n")
        
        for entry in lut_data:
            hex_val = entry['tanh_s7p8']
            f.write(f"{hex_val:04X}  // @{entry['index']:03d}: tanh({entry['x']:.4f}) = {entry['tanh_real']:.6f}\n")
    
    print(f"✓ Hex memory file generated: {hex_file}\n")

def generate_coe_file(lut_data):
    """Generate Xilinx COE file format"""
    
    coe_file = "tanh_lut.coe"
    
    with open(coe_file, 'w') as f:
        f.write("; Tanh LUT Coefficient File for Xilinx Block Memory\n")
        f.write(f"; {LUT_SIZE} entries for range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write("; Format: S7.8 (1 sign + 7 integer + 8 fractional bits)\n")
        f.write("memory_initialization_radix=2;\n")
        f.write("memory_initialization_vector=\n")
        
        for i, entry in enumerate(lut_data):
            separator = "," if i < len(lut_data) - 1 else ";"
            f.write(f"{entry['binary']}{separator}  % @{i:03d}: tanh({entry['x']:.4f}) = {entry['tanh_real']:.6f} %\n")
    
    print(f"✓ COE file generated: {coe_file}\n")

def generate_verilog_rom(lut_data):
    """Generate Verilog ROM module using memory file"""
    
    rom_file = "tanh_lut_rom.v"
    
    with open(rom_file, 'w') as f:
        f.write("// filepath: tanh_lut_rom.v\n")
        f.write("// ROM-based LUT for tanh approximation using memory initialization\n")
        f.write("// S7.8 Format: 1 sign bit + 7 integer bits + 8 fractional bits\n\n")
        
        f.write("module tanh_lut_rom (\n")
        f.write("    input [7:0] addr,\n")
        f.write("    output [15:0] data\n")
        f.write(");\n\n")
        
        f.write(f"    // ROM storage for {LUT_SIZE} entries\n")
        f.write(f"    reg [15:0] rom [0:{LUT_SIZE-1}];\n\n")
        
        f.write("    // Initialize ROM from memory file\n")
        f.write("    initial begin\n")
        f.write("        $readmemb(\"tanh_lut.mem\", rom);\n")
        f.write("    end\n\n")
        
        f.write("    // Output data\n")
        f.write("    assign data = (addr < 8'd" + str(LUT_SIZE) + ") ? rom[addr] : 16'h0000;\n\n")
        
        f.write("endmodule\n")
    
    print(f"✓ Verilog ROM module generated: {rom_file}\n")

def verify_mem_file():
    """Verify the generated .mem file"""
    
    print("="*70)
    print("VERIFICATION: Reading back generated .mem file")
    print("="*70 + "\n")
    
    with open(OUTPUT_FILE, 'r') as f:
        lines = f.readlines()
    
    # Filter out comment lines
    data_lines = [line for line in lines if line.strip() and not line.strip().startswith('//')]
    
    print(f"Total data lines read: {len(data_lines)}")
    
    # Verify first few entries
    print("\nFirst 5 entries:")
    for i, line in enumerate(data_lines[:5]):
        binary_val = line.split()[0]
        decimal_val = int(binary_val, 2)
        float_val = decimal_val / 256.0
        print(f"  Line {i:3d}: {binary_val} = 0x{decimal_val:04X} = {float_val:.6f}")
    
    # Verify specific entry (index 21)
    print(f"\nCritical entry verification (index 21):")
    line_21 = data_lines[21]
    binary_val = line_21.split()[0]
    decimal_val = int(binary_val, 2)
    float_val = decimal_val / 256.0
    expected_tanh = np.tanh(0.58)
    error = abs(float_val - expected_tanh)
    
    print(f"  Binary:   {binary_val}")
    print(f"  Decimal:  {decimal_val}")
    print(f"  Hex:      0x{decimal_val:04X}")
    print(f"  Float:    {float_val:.6f}")
    print(f"  Expected: {expected_tanh:.6f}")
    print(f"  Error:    {error:.8f}")
    
    if error < 0.002:
        print(f"  ✓ PASS\n")
    else:
        print(f"  ✗ FAIL\n")

def generate_testbench():
    """Generate testbench that uses the ROM module"""
    
    tb_file = "tb_tanh_lut_rom.v"
    
    with open(tb_file, 'w') as f:
        f.write("// filepath: tb_tanh_lut_rom.v\n")
        f.write("// Testbench for ROM-based tanh LUT\n\n")
        f.write("`timescale 1ns/1ps\n\n")
        
        f.write("module tb_tanh_lut_rom;\n\n")
        f.write("    reg [7:0] addr;\n")
        f.write("    wire [15:0] data;\n")
        f.write("    real data_real;\n\n")
        
        f.write("    // Instantiate ROM\n")
        f.write("    tanh_lut_rom dut (\n")
        f.write("        .addr(addr),\n")
        f.write("        .data(data)\n")
        f.write("    );\n\n")
        
        f.write("    // Convert to real\n")
        f.write("    always @(*) begin\n")
        f.write("        data_real = data / 256.0;\n")
        f.write("    end\n\n")
        
        f.write("    // Test\n")
        f.write("    initial begin\n")
        f.write("        $display(\"Testing ROM-based Tanh LUT\");\n")
        f.write("        $display(\"=\"*50);\n\n")
        
        f.write("        // Test first 10 entries\n")
        f.write("        for (addr = 0; addr < 10; addr = addr + 1) begin\n")
        f.write("            #10;\n")
        f.write("            $display(\"Addr=%3d: Data=0x%04X (%7.4f)\", addr, data, data_real);\n")
        f.write("        end\n\n")
        
        f.write("        // Test critical point (index 21)\n")
        f.write("        addr = 21;\n")
        f.write("        #10;\n")
        f.write("        $display(\"\\nCritical addr=21: Data=0x%04X (%7.4f)\", data, data_real);\n\n")
        
        f.write("        // Test last entry\n")
        f.write("        addr = 175;\n")
        f.write("        #10;\n")
        f.write("        $display(\"Last addr=175: Data=0x%04X (%7.4f)\", data, data_real);\n\n")
        
        f.write("        #100;\n")
        f.write("        $finish;\n")
        f.write("    end\n\n")
        
        f.write("endmodule\n")
    
    print(f"✓ Testbench generated: {tb_file}\n")

def main():
    """Main function"""
    
    print("\n" + "="*70)
    print("TANH LUT MEMORY FILE GENERATOR")
    print("="*70 + "\n")
    
    # Generate binary .mem file
    lut_data, max_error, avg_error = generate_mem_file()
    
    # Generate hex format
    generate_hex_mem_file(lut_data)
    
    # Generate COE file for Xilinx
    generate_coe_file(lut_data)
    
    # Generate Verilog ROM module
    generate_verilog_rom(lut_data)
    
    # Generate testbench
    generate_testbench()
    
    # Verify
    verify_mem_file()
    
    # Summary
    print("="*70)
    print("GENERATION COMPLETE")
    print("="*70)
    print("\nGenerated files:")
    print("  1. tanh_lut.mem         - Binary format memory file")
    print("  2. tanh_lut_hex.mem     - Hexadecimal format memory file")
    print("  3. tanh_lut.coe         - Xilinx COE format")
    print("  4. tanh_lut_rom.v       - Verilog ROM module")
    print("  5. tb_tanh_lut_rom.v    - Testbench for ROM module")
    print("\nUsage in Verilog:")
    print("  $readmemb(\"tanh_lut.mem\", memory_array);")
    print("  $readmemh(\"tanh_lut_hex.mem\", memory_array);")
    print("="*70 + "\n")

if __name__ == "__main__":
    main()