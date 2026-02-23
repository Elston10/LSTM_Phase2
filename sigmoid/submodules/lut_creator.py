import numpy as np
import math

def sigmoid(x):
    """Standard sigmoid function"""
    return 1.0 / (1.0 + math.exp(-x))

def float_to_s7_8(value):
    """
    Convert float to 16-bit S7.8 fixed-point format
    1 sign bit + 7 integer bits + 8 fractional bits
    Range: -128.0 to +127.99609375
    Resolution: 1/256 = 0.00390625
    """
    # Clamp to S7.8 range
    max_val = 127.99609375
    min_val = -128.0
    
    clamped = max(min(value, max_val), min_val)
    
    # Sign-magnitude representation
    is_negative = clamped < 0
    abs_val = abs(clamped)
    
    # Scale by 2^8 and quantize
    scaled = abs_val * 256
    quantized_mag = int(round(scaled))
    
    # Clamp magnitude to 15 bits (32767)
    quantized_mag = min(quantized_mag, 32767)
    
    # Create 16-bit sign-magnitude representation
    if is_negative:
        binary_value = (1 << 15) | quantized_mag  # Set sign bit
    else:
        binary_value = quantized_mag
    
    return binary_value

def s7_8_to_float(binary_value):
    """Convert 16-bit S7.8 binary back to float for verification"""
    sign_bit = (binary_value >> 15) & 1
    magnitude = binary_value & 0x7FFF
    
    float_magnitude = magnitude / 256.0
    
    if sign_bit:
        return -float_magnitude
    else:
        return float_magnitude

def generate_sigmoid_lut():
    """Generate sigmoid LUT for range [0, 6] with S7.8 quantization"""
    
    # Input range and step size
    x_min = 0.0
    x_max = 6.0
    
    # Calculate step size for S7.8 format
    # We want to cover [0, 6] with maximum resolution
    step_size = 1.0 / 256.0  # S7.8 resolution
    
    # Generate input values
    num_steps = int((x_max - x_min) / step_size) + 1
    x_values = [x_min + i * step_size for i in range(num_steps)]
    
    # Clamp to exactly 6.0 to avoid floating point errors
    if x_values[-1] > x_max:
        x_values = x_values[:-1]
    x_values.append(x_max)
    
    print(f"Generating LUT with {len(x_values)} entries")
    print(f"Input range: [{x_min}, {x_max}]")
    print(f"Step size: {step_size}")
    print(f"Address width needed: {math.ceil(math.log2(len(x_values)))} bits")
    
    # Generate LUT entries
    lut_entries = []
    
    for i, x in enumerate(x_values):
        # Calculate sigmoid
        y_float = sigmoid(x)
        
        # Convert to S7.8 fixed-point
        y_fixed = float_to_s7_8(y_float)
        
        # Verify conversion
        y_verify = s7_8_to_float(y_fixed)
        
        lut_entries.append({
            'index': i,
            'x_float': x,
            'y_float': y_float,
            'y_fixed_binary': y_fixed,
            'y_fixed_hex': f"0x{y_fixed:04X}",
            'y_verify': y_verify,
            'error': abs(y_float - y_verify)
        })
    
    return lut_entries

def write_verilog_lut(lut_entries, filename):
    """Write LUT as Verilog module"""
    
    lut_size = len(lut_entries)
    addr_width = math.ceil(math.log2(lut_size))
    
    with open(filename, 'w') as f:
        f.write(f"""// Sigmoid LUT for 16-bit S7.8 Fixed-Point Format
// Generated automatically - DO NOT EDIT MANUALLY
// Input range: [0.0, 6.0]
// Output range: [0.5, ~1.0] in sigmoid format
// LUT size: {lut_size} entries
// Address width: {addr_width} bits

module sigmoid_lut_s7_8 #(
    parameter WIDTH = 16,           // 16-bit S7.8 format
    parameter FRAC_BITS = 8,        // 8 fractional bits
    parameter LUT_SIZE = {lut_size},     // Size of the LUT
    parameter ADDR_WIDTH = {addr_width}        // Address width for the LUT
) (
    input [ADDR_WIDTH-1:0] addr,
    output [WIDTH-1:0] sigmoid_out
);

// Sigmoid LUT values for range [0,6] in 16-bit S7.8 format (sign-magnitude)
reg [WIDTH-1:0] lut [0:LUT_SIZE-1];

initial begin
""")
        
        # Write LUT entries
        for entry in lut_entries:
            x = entry['x_float']
            y = entry['y_float']
            binary = entry['y_fixed_binary']
            hex_val = entry['y_fixed_hex']
            
            f.write(f"    lut[{entry['index']:4d}] = 16'b{binary:016b}; // x={x:.4f}, y={y:.6f}, hex={hex_val}\n")
        
        f.write("""end

assign sigmoid_out = lut[addr];

endmodule
""")

def write_analysis_report(lut_entries, filename):
    """Write detailed analysis report"""
    
    with open(filename, 'w') as f:
        f.write("SIGMOID LUT ANALYSIS REPORT\n")
        f.write("=" * 50 + "\n\n")
        
        f.write("CONFIGURATION:\n")
        f.write(f"Format: 16-bit S7.8 (1 sign + 7 integer + 8 fractional)\n")
        f.write(f"Range: -128.0 to +127.99609375\n")
        f.write(f"Resolution: {1/256} (1/256)\n")
        f.write(f"Input range: [0.0, 6.0]\n")
        f.write(f"LUT size: {len(lut_entries)} entries\n")
        f.write(f"Address width: {math.ceil(math.log2(len(lut_entries)))} bits\n\n")
        
        # Calculate statistics
        errors = [entry['error'] for entry in lut_entries]
        max_error = max(errors)
        avg_error = sum(errors) / len(errors)
        rms_error = math.sqrt(sum(e*e for e in errors) / len(errors))
        
        f.write("QUANTIZATION ERROR ANALYSIS:\n")
        f.write(f"Maximum error: {max_error:.8f}\n")
        f.write(f"Average error: {avg_error:.8f}\n")
        f.write(f"RMS error: {rms_error:.8f}\n")
        f.write(f"Max error as % of range: {(max_error/0.5)*100:.4f}%\n\n")
        
        # Output range analysis
        y_values = [entry['y_float'] for entry in lut_entries]
        y_fixed_values = [entry['y_verify'] for entry in lut_entries]
        
        f.write("OUTPUT RANGE ANALYSIS:\n")
        f.write(f"Theoretical sigmoid range: [{min(y_values):.6f}, {max(y_values):.6f}]\n")
        f.write(f"Quantized range: [{min(y_fixed_values):.6f}, {max(y_fixed_values):.6f}]\n\n")
        
        f.write("SAMPLE ENTRIES:\n")
        f.write("Index |    X    |  Y_float  | Y_fixed | Binary           | Hex    | Error\n")
        f.write("-" * 75 + "\n")
        
        # Show every 256th entry for overview
        step = max(1, len(lut_entries) // 20)
        for i in range(0, len(lut_entries), step):
            entry = lut_entries[i]
            f.write(f"{entry['index']:5d} | {entry['x_float']:7.4f} | {entry['y_float']:9.6f} | "
                   f"{entry['y_verify']:7.6f} | {entry['y_fixed_binary']:016b} | "
                   f"{entry['y_fixed_hex']} | {entry['error']:.8f}\n")

def write_c_header(lut_entries, filename):
    """Write C header file with LUT"""
    
    lut_size = len(lut_entries)
    addr_width = math.ceil(math.log2(lut_size))
    
    with open(filename, 'w') as f:
        f.write(f"""// Sigmoid LUT for 16-bit S7.8 Fixed-Point Format
// Generated automatically - DO NOT EDIT MANUALLY

#ifndef SIGMOID_LUT_S7_8_H
#define SIGMOID_LUT_S7_8_H

#include <stdint.h>

#define SIGMOID_LUT_SIZE {lut_size}
#define SIGMOID_ADDR_WIDTH {addr_width}
#define SIGMOID_INPUT_MIN 0.0f
#define SIGMOID_INPUT_MAX 6.0f
#define SIGMOID_STEP_SIZE {1.0/256}f

// 16-bit S7.8 format LUT
static const uint16_t sigmoid_lut_s7_8[SIGMOID_LUT_SIZE] = {{
""")
        
        # Write LUT data in C format
        for i, entry in enumerate(lut_entries):
            if i % 8 == 0:
                f.write("    ")
            
            f.write(f"0x{entry['y_fixed_binary']:04X}")
            
            if i < len(lut_entries) - 1:
                f.write(", ")
            
            if i % 8 == 7 or i == len(lut_entries) - 1:
                f.write(f"  // {i-7 if i >= 7 else 0}-{i}\n")
        
        f.write("""};

// Function to get sigmoid value from LUT
static inline uint16_t sigmoid_lookup_s7_8(uint16_t addr) {
    if (addr >= SIGMOID_LUT_SIZE) {
        return sigmoid_lut_s7_8[SIGMOID_LUT_SIZE - 1];  // Clamp to max
    }
    return sigmoid_lut_s7_8[addr];
}

// Convert float input to LUT address
static inline uint16_t float_to_sigmoid_addr(float x) {
    if (x < SIGMOID_INPUT_MIN) return 0;
    if (x >= SIGMOID_INPUT_MAX) return SIGMOID_LUT_SIZE - 1;
    
    uint16_t addr = (uint16_t)((x - SIGMOID_INPUT_MIN) / SIGMOID_STEP_SIZE);
    return (addr < SIGMOID_LUT_SIZE) ? addr : (SIGMOID_LUT_SIZE - 1);
}

#endif // SIGMOID_LUT_S7_8_H
""")

def main():
    print("Generating Sigmoid LUT for 16-bit S7.8 Fixed-Point Format")
    print("=" * 60)
    
    # Generate LUT
    lut_entries = generate_sigmoid_lut()
    
    # Write output files
    print(f"\nWriting output files...")
    
    # Verilog module
    verilog_file = "sigmoid_lut_s7_8.v"
    write_verilog_lut(lut_entries, verilog_file)
    print(f"Verilog LUT: {verilog_file}")
    
    # Analysis report
    report_file = "sigmoid_lut_analysis.txt"
    write_analysis_report(lut_entries, report_file)
    print(f"Analysis report: {report_file}")
    
    # C header
    c_header_file = "sigmoid_lut_s7_8.h"
    write_c_header(lut_entries, c_header_file)
    print(f"C header: {c_header_file}")
    
    # Summary
    print(f"\nSUMMARY:")
    print(f"LUT size: {len(lut_entries)} entries")
    print(f"Address width: {math.ceil(math.log2(len(lut_entries)))} bits")
    print(f"Memory usage: {len(lut_entries) * 16} bits ({len(lut_entries) * 2} bytes)")
    
    errors = [entry['error'] for entry in lut_entries]
    print(f"Max quantization error: {max(errors):.8f}")
    print(f"Average quantization error: {sum(errors)/len(errors):.8f}")
    
    print(f"\nFiles generated successfully!")

if __name__ == "__main__":
    main()