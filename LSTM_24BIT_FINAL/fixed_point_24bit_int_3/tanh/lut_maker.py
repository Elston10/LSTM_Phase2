import math

# Configuration for S3.20 format with 512 entries (HIGHER ACCURACY)
LUT_MIN = 0.25
LUT_MAX = 3.0
LUT_SIZE = 512  # Doubled for better accuracy
FRAC_BITS = 20
INT_BITS = 3
TOTAL_BITS = 24
SCALE = 2 ** FRAC_BITS  # 1048576

OUTPUT_FILE_BIN = "tanh_lut_s3_20_512.mem"
OUTPUT_FILE_HEX = "tanh_lut_hex_s3_20_512.mem"
OUTPUT_FILE_COE = "tanh_lut_s3_20_512.coe"
OUTPUT_FILE_VERILOG = "tanh_lut_data_s3_20_512.v"

def tanh(x):
    """Compute tanh using standard formula"""
    return math.tanh(x)

def float_to_s3_20(value):
    """Convert float to S3.20 fixed-point (24-bit sign-magnitude)"""
    # Clip to valid range
    max_val = 7.99999904632568359375
    if value > max_val:
        value = max_val
    elif value < -max_val:
        value = -max_val
    
    # Extract sign and magnitude
    sign = 1 if value < 0 else 0
    abs_value = abs(value)
    magnitude = int(round(abs_value * SCALE))
    
    # Ensure magnitude fits in 23 bits
    if magnitude > 0x7FFFFF:
        magnitude = 0x7FFFFF
    
    # Combine sign and magnitude
    fixed_val = (sign << 23) | magnitude
    return fixed_val

def s3_20_to_float(fixed_val):
    """Convert S3.20 fixed-point to float"""
    sign = (fixed_val >> 23) & 1
    magnitude = fixed_val & 0x7FFFFF
    float_val = magnitude / SCALE
    if sign:
        float_val = -float_val
    return float_val

def generate_lut_data():
    """Generate LUT data for tanh approximation"""
    lut_data = []
    step = (LUT_MAX - LUT_MIN) / (LUT_SIZE - 1)
    
    print(f"Generating {LUT_SIZE} LUT entries for range [{LUT_MIN}, {LUT_MAX}]")
    print(f"S3.20 Format: 1 sign + {INT_BITS} int + {FRAC_BITS} frac bits")
    print(f"Scale factor: 2^{FRAC_BITS} = {SCALE}")
    print(f"Step size: {step:.10f} (IMPROVED ACCURACY!)")
    print(f"Expected max interpolation error: ~{step * 0.005:.10f}\n")
    
    for i in range(LUT_SIZE):
        x = LUT_MIN + i * step
        tanh_val = tanh(x)
        fixed_val = float_to_s3_20(tanh_val)
        
        lut_data.append({
            'index': i,
            'x': x,
            'tanh': tanh_val,
            'fixed': fixed_val
        })
    
    return lut_data

def generate_binary_mem_file(lut_data):
    """Generate binary .mem file for Verilog $readmemb"""
    filename = OUTPUT_FILE_BIN
    with open(filename, 'w') as f:
        f.write("// S3.20 Fixed-point tanh LUT (Binary format) - HIGH ACCURACY\n")
        f.write(f"// {LUT_SIZE} entries covering range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write(f"// Format: {TOTAL_BITS}-bit binary (1 sign + {INT_BITS} int + {FRAC_BITS} frac)\n")
        f.write(f"// Step size: {(LUT_MAX - LUT_MIN) / (LUT_SIZE - 1):.10f}\n\n")
        
        for entry in lut_data:
            binary = format(entry['fixed'], '024b')
            f.write(f"{binary}  // @{entry['index']:03d}: tanh({entry['x']:.8f}) = {entry['tanh']:.12f}\n")
    
    print(f"✓ Generated binary memory file: {filename}")
    return filename

def generate_hex_mem_file(lut_data):
    """Generate hex .mem file for Verilog $readmemh"""
    filename = OUTPUT_FILE_HEX
    with open(filename, 'w') as f:
        f.write("// S3.20 Fixed-point tanh LUT (Hex format) - HIGH ACCURACY\n")
        f.write(f"// {LUT_SIZE} entries covering range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write(f"// Format: {TOTAL_BITS}-bit hex (6 digits)\n")
        f.write(f"// Step size: {(LUT_MAX - LUT_MIN) / (LUT_SIZE - 1):.10f}\n\n")
        
        for entry in lut_data:
            hex_val = format(entry['fixed'], '06X')
            f.write(f"{hex_val}  // @{entry['index']:03d}: tanh({entry['x']:.8f}) = {entry['tanh']:.12f}\n")
    
    print(f"✓ Generated hex memory file: {filename}")
    return filename

def generate_coe_file(lut_data):
    """Generate .coe file for Xilinx Block Memory IP"""
    filename = OUTPUT_FILE_COE
    with open(filename, 'w') as f:
        f.write("; S3.20 Fixed-point tanh LUT for Xilinx Block Memory - HIGH ACCURACY\n")
        f.write(f"; {LUT_SIZE} entries covering range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write(f"; Format: {TOTAL_BITS}-bit binary\n")
        f.write(f"; Step size: {(LUT_MAX - LUT_MIN) / (LUT_SIZE - 1):.10f}\n")
        f.write("memory_initialization_radix=2;\n")
        f.write("memory_initialization_vector=\n")
        
        for i, entry in enumerate(lut_data):
            binary = format(entry['fixed'], '024b')
            if i < len(lut_data) - 1:
                f.write(f"{binary},\n")
            else:
                f.write(f"{binary};\n")
    
    print(f"✓ Generated COE file: {filename}")
    return filename

def generate_verilog_rom_module(lut_data):
    """Generate Verilog ROM module using memory array"""
    filename = OUTPUT_FILE_VERILOG
    with open(filename, 'w') as f:
        # Header
        f.write("// S3.20 Fixed-point tanh LUT ROM - HIGH ACCURACY (512 entries)\n")
        f.write(f"// {LUT_SIZE} entries covering range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write(f"// Uses $readmemh for initialization\n")
        f.write(f"// Step size: {(LUT_MAX - LUT_MIN) / (LUT_SIZE - 1):.10f}\n\n")
        
        # Module declaration
        f.write("module tanh_lut_rom_s3_20_512 (\n")
        f.write("    input [8:0] addr,         // 9-bit address (0-511)\n")
        f.write("    output [23:0] data        // 24-bit output\n")
        f.write(");\n\n")
        
        # ROM array
        f.write(f"    reg [23:0] rom [0:{LUT_SIZE-1}];\n\n")
        
        # Initialize from file
        f.write("    initial begin\n")
        f.write(f"        $readmemh(\"tanh_lut_hex_s3_20_512.mem\", rom);\n")
        f.write("    end\n\n")
        
        # Output assignment
        f.write("    assign data = rom[addr];\n\n")
        f.write("endmodule\n")
    
    print(f"✓ Generated Verilog ROM module: {filename}")
    return filename

def generate_case_module(lut_data):
    """Generate Verilog module with case statement (for synthesis comparison)"""
    filename = "tanh_lut_case_s3_20_512.v"
    
    # Only generate first 64 entries to avoid huge file
    print(f"⚠ Warning: Case module with {LUT_SIZE} entries is VERY large!")
    print(f"  Generating ROM module instead (recommended for synthesis)")
    
    # Generate ROM module instead
    return generate_verilog_rom_module(lut_data)

def print_statistics(lut_data):
    """Print detailed statistics about the generated LUT"""
    tanh_values = [entry['tanh'] for entry in lut_data]
    step = (LUT_MAX - LUT_MIN) / (LUT_SIZE - 1)
    
    print("\n" + "="*80)
    print("LUT STATISTICS - HIGH ACCURACY VERSION")
    print("="*80)
    print(f"Format:              S{INT_BITS}.{FRAC_BITS} (sign-magnitude)")
    print(f"Total bits:          {TOTAL_BITS}")
    print(f"Number of entries:   {LUT_SIZE}")
    print(f"Address bits:        {LUT_SIZE.bit_length() - 1}")
    print(f"Input range:         [{LUT_MIN}, {LUT_MAX}]")
    print(f"Step size:           {step:.10f} (2× better than 256)")
    print(f"Output range:        [{min(tanh_values):.12f}, {max(tanh_values):.12f}]")
    print(f"Precision:           2^-{FRAC_BITS} = {1/SCALE:.15f}")
    print(f"Memory usage:        {LUT_SIZE * TOTAL_BITS} bits = {LUT_SIZE * TOTAL_BITS // 8} bytes")
    print(f"Memory increase:     +100% from 256 entries (768 → 1536 bytes)")
    print("="*80)
    
    # Show sample entries
    print("\nSAMPLE ENTRIES:")
    print("-"*80)
    print(f"{'Index':<8} {'Input':<14} {'tanh(x)':<18} {'Fixed (Hex)':<12} {'Reconstructed':<18}")
    print("-"*80)
    
    # First 5 entries
    for i in range(5):
        entry = lut_data[i]
        reconstructed = s3_20_to_float(entry['fixed'])
        print(f"{i:<8} {entry['x']:<14.8f} {entry['tanh']:<18.12f} 0x{entry['fixed']:06X}    {reconstructed:<18.12f}")
    
    print("...")
    
    # Middle entries
    mid = LUT_SIZE // 2
    for i in range(mid - 2, mid + 3):
        entry = lut_data[i]
        reconstructed = s3_20_to_float(entry['fixed'])
        print(f"{i:<8} {entry['x']:<14.8f} {entry['tanh']:<18.12f} 0x{entry['fixed']:06X}    {reconstructed:<18.12f}")
    
    print("...")
    
    # Last 5 entries
    for i in range(LUT_SIZE - 5, LUT_SIZE):
        entry = lut_data[i]
        reconstructed = s3_20_to_float(entry['fixed'])
        print(f"{i:<8} {entry['x']:<14.8f} {entry['tanh']:<18.12f} 0x{entry['fixed']:06X}    {reconstructed:<18.12f}")
    
    print("-"*80)
    
    # Accuracy analysis
    print("\nACCURACY ANALYSIS:")
    print("-"*80)
    max_quant_error = 0
    avg_quant_error = 0
    
    for entry in lut_data:
        reconstructed = s3_20_to_float(entry['fixed'])
        error = abs(entry['tanh'] - reconstructed)
        max_quant_error = max(max_quant_error, error)
        avg_quant_error += error
    
    avg_quant_error /= len(lut_data)
    
    print(f"Maximum quantization error:     {max_quant_error:.15f}")
    print(f"Average quantization error:     {avg_quant_error:.15f}")
    print(f"Max error in LSBs:              {max_quant_error * SCALE:.2f}")
    print(f"Expected max interpolation err: ~{step * 0.005:.12f}")
    print(f"Total expected error:           ~{max_quant_error + step * 0.005:.12f}")
    print(f"Relative error:                 ~{((max_quant_error + step * 0.005) / 0.995) * 100:.6f}%")
    print("="*80 + "\n")
    
    # Hardware constants
    print("HARDWARE CONSTANTS (for Verilog):")
    print("-"*80)
    min_lut_fixed = float_to_s3_20(LUT_MIN)
    max_lut_fixed = float_to_s3_20(LUT_MAX)
    one_fixed = float_to_s3_20(1.0)
    
    print(f"LUT_MIN    = 24'h{min_lut_fixed:06X}  // {LUT_MIN}")
    print(f"LUT_MAX    = 24'h{max_lut_fixed:06X}  // {LUT_MAX}")
    print(f"ONE        = 24'h{one_fixed:06X}  // 1.0")
    print(f"LUT_SIZE   = {LUT_SIZE}")
    print(f"ADDR_BITS  = {LUT_SIZE.bit_length() - 1}")
    print("="*80 + "\n")

def compare_with_256():
    """Compare 512-entry vs 256-entry accuracy"""
    print("\n" + "="*80)
    print("COMPARISON: 512 vs 256 ENTRIES")
    print("="*80)
    
    step_256 = (LUT_MAX - LUT_MIN) / (256 - 1)
    step_512 = (LUT_MAX - LUT_MIN) / (512 - 1)
    
    print(f"256 entries: step = {step_256:.10f}, max interp error ≈ {step_256 * 0.005:.10f}")
    print(f"512 entries: step = {step_512:.10f}, max interp error ≈ {step_512 * 0.005:.10f}")
    print(f"Improvement: {(step_256 / step_512):.2f}× better accuracy")
    print(f"Memory cost: +{((512 - 256) * 24 // 8)} bytes (+100%)")
    print("="*80 + "\n")

def generate_test_vectors(lut_data):
    """Generate test vectors for verification"""
    filename = "tanh_test_vectors_s3_20_512.txt"
    with open(filename, 'w') as f:
        f.write("// Test vectors for S3.20 tanh 512-entry LUT verification\n")
        f.write("// Format: input_hex output_hex input_float output_float\n\n")
        
        test_inputs = [
            0.0, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0,
            -0.1, -0.25, -0.5, -1.0, -2.0, -3.0,
            0.0000014580,  # Smallest weight
            0.000001, 0.00001, 0.0001, 0.001, 0.01,  # Small values
            # Test intermediate values (between LUT entries)
            0.252, 0.503, 1.001, 1.502, 2.001, 2.501
        ]
        
        for x in test_inputs:
            x_fixed = float_to_s3_20(x)
            tanh_true = math.tanh(x)
            tanh_fixed = float_to_s3_20(tanh_true)
            
            f.write(f"{x_fixed:06X} {tanh_fixed:06X} {x:15.12f} {tanh_true:15.12f}\n")
    
    print(f"✓ Generated test vectors: {filename}")

def main():
    """Main function to generate all LUT files"""
    print("\n" + "="*80)
    print("S3.20 TANH LUT GENERATOR - HIGH ACCURACY (512 ENTRIES)")
    print("="*80 + "\n")
    
    # Show comparison first
    compare_with_256()
    
    # Generate LUT data
    print("Generating LUT data...")
    lut_data = generate_lut_data()
    print(f"✓ Generated {len(lut_data)} LUT entries\n")
    
    # Generate output files
    print("Generating output files...")
    generate_binary_mem_file(lut_data)
    generate_hex_mem_file(lut_data)
    generate_coe_file(lut_data)
    generate_verilog_rom_module(lut_data)
    generate_test_vectors(lut_data)
    print()
    
    # Print statistics
    print_statistics(lut_data)
    
    print("\n✅ ALL FILES GENERATED SUCCESSFULLY!\n")
    print("Generated files:")
    print(f"  1. {OUTPUT_FILE_BIN} (binary format)")
    print(f"  2. {OUTPUT_FILE_HEX} (hex format)")
    print(f"  3. {OUTPUT_FILE_COE} (Xilinx COE)")
    print(f"  4. {OUTPUT_FILE_VERILOG} (Verilog ROM module)")
    print(f"  5. tanh_test_vectors_s3_20_512.txt (test vectors)")
    print()
    print("💡 Recommended: Use ROM module (not case statement) for synthesis")
    print()

if __name__ == "__main__":
    main()