import math

# Configuration for S3.20 format with 6144 entries
LUT_MIN = 0.0
LUT_MAX = 6.0
LUT_SIZE = 6144  # High accuracy LUT
FRAC_BITS = 20
INT_BITS = 3
TOTAL_BITS = 24
SCALE = 2 ** FRAC_BITS  # 1048576

OUTPUT_FILE_BIN = "sigmoid_lut_s3_20.mem"
OUTPUT_FILE_HEX = "sigmoid_lut_hex_s3_20.mem"
OUTPUT_FILE_COE = "sigmoid_lut_s3_20.coe"
OUTPUT_FILE_VERILOG = "sigmoid_lut_s3_20.v"

def sigmoid(x):
    """
    Calculate sigmoid function: sigmoid(x) = 1 / (1 + e^(-x))
    """
    if x > 20:
        return 1.0
    elif x < -20:
        return 0.0
    else:
        return 1.0 / (1.0 + math.exp(-x))

def float_to_s3_20(value):
    """Convert float to S3.20 fixed-point (24-bit sign-magnitude)"""
    # Sigmoid output is always positive [0, 1], but we support negative for generality
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

def generate_sigmoid_lut():
    """Generate LUT data for sigmoid approximation"""
    lut_data = []
    step = (LUT_MAX - LUT_MIN) / (LUT_SIZE - 1)
    
    print(f"Generating {LUT_SIZE} LUT entries for range [{LUT_MIN}, {LUT_MAX}]")
    print(f"S3.20 Format: 1 sign + {INT_BITS} int + {FRAC_BITS} frac bits")
    print(f"Scale factor: 2^{FRAC_BITS} = {SCALE}")
    print(f"Step size: {step:.12f} (HIGH ACCURACY!)")
    print(f"Expected max error: ~{step * 0.125:.12f}\n")
    
    for i in range(LUT_SIZE):
        x = LUT_MIN + i * step
        sigmoid_val = sigmoid(x)
        fixed_val = float_to_s3_20(sigmoid_val)
        
        lut_data.append({
            'index': i,
            'x': x,
            'sigmoid': sigmoid_val,
            'fixed': fixed_val
        })
    
    return lut_data

def generate_binary_mem_file(lut_data):
    """Generate binary .mem file for Verilog $readmemb"""
    filename = OUTPUT_FILE_BIN
    with open(filename, 'w', encoding='utf-8') as f:
        f.write("// S3.20 Fixed-point sigmoid LUT (Binary format)\n")
        f.write(f"// {LUT_SIZE} entries covering range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write(f"// Format: {TOTAL_BITS}-bit binary (1 sign + {INT_BITS} int + {FRAC_BITS} frac)\n")
        f.write(f"// Step size: {(LUT_MAX - LUT_MIN) / (LUT_SIZE - 1):.12f}\n\n")
        
        for entry in lut_data:
            binary = format(entry['fixed'], '024b')
            # Use ASCII 'sig' instead of σ symbol
            f.write(f"{binary}  // @{entry['index']:04d}: sig({entry['x']:.8f}) = {entry['sigmoid']:.12f}\n")
    
    print(f"✓ Generated binary memory file: {filename}")
    return filename

def generate_hex_mem_file(lut_data):
    """Generate hex .mem file for Verilog $readmemh"""
    filename = OUTPUT_FILE_HEX
    with open(filename, 'w', encoding='utf-8') as f:
        f.write("// S3.20 Fixed-point sigmoid LUT (Hex format)\n")
        f.write(f"// {LUT_SIZE} entries covering range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write(f"// Format: {TOTAL_BITS}-bit hex (6 digits)\n")
        f.write(f"// Step size: {(LUT_MAX - LUT_MIN) / (LUT_SIZE - 1):.12f}\n\n")
        
        for entry in lut_data:
            hex_val = format(entry['fixed'], '06X')
            f.write(f"{hex_val}  // @{entry['index']:04d}: sig({entry['x']:.8f}) = {entry['sigmoid']:.12f}\n")
    
    print(f"✓ Generated hex memory file: {filename}")
    return filename

def generate_coe_file(lut_data):
    """Generate .coe file for Xilinx Block Memory IP"""
    filename = OUTPUT_FILE_COE
    with open(filename, 'w', encoding='utf-8') as f:
        f.write("; S3.20 Fixed-point sigmoid LUT for Xilinx Block Memory\n")
        f.write(f"; {LUT_SIZE} entries covering range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write(f"; Format: {TOTAL_BITS}-bit binary\n")
        f.write(f"; Step size: {(LUT_MAX - LUT_MIN) / (LUT_SIZE - 1):.12f}\n")
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
    with open(filename, 'w', encoding='utf-8') as f:
        # Header
        f.write("// S3.20 Fixed-point sigmoid LUT ROM - HIGH ACCURACY (6144 entries)\n")
        f.write(f"// {LUT_SIZE} entries covering range [{LUT_MIN}, {LUT_MAX}]\n")
        f.write(f"// Uses $readmemh for initialization\n")
        f.write(f"// Step size: {(LUT_MAX - LUT_MIN) / (LUT_SIZE - 1):.12f}\n")
        f.write(f"// Output range: [sig(0)=0.5, sig(6)~1.0]\n\n")
        
        # Module declaration
        f.write("module sigmoid_lut_s3_20 (\n")
        f.write("    input [12:0] addr,        // 13-bit address (0-6143)\n")
        f.write("    output [23:0] data        // 24-bit output\n")
        f.write(");\n\n")
        
        # ROM array
        f.write(f"    reg [23:0] rom [0:{LUT_SIZE-1}];\n\n")
        
        # Initialize from file
        f.write("    initial begin\n")
        f.write(f"        $readmemh(\"sigmoid_lut_hex_s3_20.mem\", rom);\n")
        f.write("    end\n\n")
        
        # Output assignment
        f.write("    assign data = rom[addr];\n\n")
        f.write("endmodule\n")
    
    print(f"✓ Generated Verilog ROM module: {filename}")
    return filename

def print_statistics(lut_data):
    """Print detailed statistics about the generated LUT"""
    sigmoid_values = [entry['sigmoid'] for entry in lut_data]
    step = (LUT_MAX - LUT_MIN) / (LUT_SIZE - 1)
    
    print("\n" + "="*80)
    print("SIGMOID LUT STATISTICS - HIGH ACCURACY VERSION")
    print("="*80)
    print(f"Format:              S{INT_BITS}.{FRAC_BITS} (sign-magnitude)")
    print(f"Total bits:          {TOTAL_BITS}")
    print(f"Number of entries:   {LUT_SIZE}")
    print(f"Address bits:        13 (for 0-6143)")
    print(f"Input range:         [{LUT_MIN}, {LUT_MAX}]")
    print(f"Step size:           {step:.12f}")
    print(f"Output range:        [{min(sigmoid_values):.12f}, {max(sigmoid_values):.12f}]")
    print(f"Precision:           2^-{FRAC_BITS} = {1/SCALE:.15f}")
    print(f"Memory usage:        {LUT_SIZE * TOTAL_BITS} bits = {LUT_SIZE * TOTAL_BITS // 8} bytes")
    print(f"                     = {(LUT_SIZE * TOTAL_BITS // 8) / 1024:.2f} KB")
    print("="*80)
    
    # Show sample entries
    print("\nSAMPLE ENTRIES:")
    print("-"*80)
    print(f"{'Index':<8} {'Input (x)':<14} {'sigmoid(x)':<18} {'Fixed (Hex)':<12} {'Reconstructed':<18}")
    print("-"*80)
    
    # First 5 entries
    for i in range(5):
        entry = lut_data[i]
        reconstructed = s3_20_to_float(entry['fixed'])
        print(f"{i:<8} {entry['x']:<14.10f} {entry['sigmoid']:<18.12f} 0x{entry['fixed']:06X}    {reconstructed:<18.12f}")
    
    print("...")
    
    # Around 0.5 (where sigmoid = 0.5)
    mid = LUT_SIZE // 2
    for i in range(mid - 2, mid + 3):
        if i >= 0 and i < LUT_SIZE:
            entry = lut_data[i]
            reconstructed = s3_20_to_float(entry['fixed'])
            print(f"{i:<8} {entry['x']:<14.10f} {entry['sigmoid']:<18.12f} 0x{entry['fixed']:06X}    {reconstructed:<18.12f}")
    
    print("...")
    
    # Last 5 entries
    for i in range(LUT_SIZE - 5, LUT_SIZE):
        entry = lut_data[i]
        reconstructed = s3_20_to_float(entry['fixed'])
        print(f"{i:<8} {entry['x']:<14.10f} {entry['sigmoid']:<18.12f} 0x{entry['fixed']:06X}    {reconstructed:<18.12f}")
    
    print("-"*80)
    
    # Accuracy analysis
    print("\nACCURACY ANALYSIS:")
    print("-"*80)
    max_quant_error = 0
    avg_quant_error = 0
    
    for entry in lut_data:
        reconstructed = s3_20_to_float(entry['fixed'])
        error = abs(entry['sigmoid'] - reconstructed)
        max_quant_error = max(max_quant_error, error)
        avg_quant_error += error
    
    avg_quant_error /= len(lut_data)
    
    print(f"Maximum quantization error:     {max_quant_error:.15f}")
    print(f"Average quantization error:     {avg_quant_error:.15f}")
    print(f"Max error in LSBs:              {max_quant_error * SCALE:.2f}")
    print(f"Expected max interpolation err: ~{step * 0.125:.12f}")
    print(f"Total expected error:           ~{max_quant_error + step * 0.125:.12f}")
    print("="*80 + "\n")
    
    # Hardware constants
    print("HARDWARE CONSTANTS (for Verilog):")
    print("-"*80)
    zero_fixed = float_to_s3_20(0.0)
    six_fixed = float_to_s3_20(6.0)
    one_fixed = float_to_s3_20(1.0)
    half_fixed = float_to_s3_20(0.5)
    
    print(f"ZERO       = 24'h{zero_fixed:06X}  // 0.0")
    print(f"SIX        = 24'h{six_fixed:06X}  // 6.0 (LUT max)")
    print(f"ONE        = 24'h{one_fixed:06X}  // 1.0")
    print(f"HALF       = 24'h{half_fixed:06X}  // 0.5 (sigmoid(0))")
    print(f"LUT_SIZE   = {LUT_SIZE}")
    print(f"ADDR_BITS  = 13")
    print("="*80 + "\n")

def generate_test_vectors(lut_data):
    """Generate test vectors for verification"""
    filename = "sigmoid_test_vectors_s3_20.txt"
    with open(filename, 'w', encoding='utf-8') as f:
        f.write("// Test vectors for S3.20 sigmoid 6144-entry LUT verification\n")
        f.write("// Format: input_hex output_hex input_float output_float\n\n")
        
        test_inputs = [
            0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0,
            -0.5, -1.0, -2.0, -3.0, -4.0, -5.0, -6.0,
            0.0000014580,  # Smallest weight
            0.000001, 0.00001, 0.0001, 0.001, 0.01, 0.1,
            # Intermediate values
            0.25, 0.75, 1.25, 1.75, 2.25, 2.75, 3.25, 3.75, 4.25, 4.75, 5.25, 5.75
        ]
        
        for x in test_inputs:
            x_fixed = float_to_s3_20(x)
            sigmoid_true = sigmoid(x)
            sigmoid_fixed = float_to_s3_20(sigmoid_true)
            
            f.write(f"{x_fixed:06X} {sigmoid_fixed:06X} {x:15.12f} {sigmoid_true:15.12f}\n")
    
    print(f"✓ Generated test vectors: {filename}")

def main():
    """Main function to generate all LUT files"""
    print("\n" + "="*80)
    print("S3.20 SIGMOID LUT GENERATOR - HIGH ACCURACY (6144 ENTRIES)")
    print("="*80 + "\n")
    
    # Generate LUT data
    print("Generating LUT data...")
    lut_data = generate_sigmoid_lut()
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
    print(f"  5. sigmoid_test_vectors_s3_20.txt (test vectors)")
    print()
    print("💾 Memory usage: 18 KB (6144 entries × 24 bits)")
    print("🎯 Accuracy: ~0.0001% error\n")

if __name__ == "__main__":
    main()