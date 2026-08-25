def fixed_to_float(hex_value, total_bits=24, int_bits=3, frac_bits=20):
    """
    Convert 24-bit fixed-point hex to float
    Format: 1 sign + 3 int + 20 frac bits (S3.20)
    Sign-Magnitude: MSB=1 means negative, bits[22:0] are magnitude
    """
    if isinstance(hex_value, str):
        value = int(hex_value, 16)
    else:
        value = hex_value

    # Extract sign bit (MSB)
    sign_bit = (value >> (total_bits - 1)) & 1

    # Extract magnitude (lower 23 bits)
    magnitude = value & 0x7FFFFF

    # Convert magnitude to float
    float_value = magnitude / (2.0 ** frac_bits)

    # Apply sign
    if sign_bit:
        float_value = -float_value

    return float_value


def float_to_fixed(float_value, total_bits=24, int_bits=3, frac_bits=20):
    """
    Convert float to 24-bit fixed-point hex
    Format: 1 sign + 3 int + 20 frac bits (S3.20)
    Sign-Magnitude: MSB=1 means negative, bits[22:0] are magnitude
    Range: -7.999999... to +7.999999...
    """
    max_val = (2 ** int_bits) - (1.0 / (2 ** frac_bits))
    min_val = -(2 ** int_bits) + (1.0 / (2 ** frac_bits))

    if float_value > max_val:
        print(f"Warning: Clipping {float_value} to {max_val}")
        float_value = max_val
    elif float_value < min_val:
        print(f"Warning: Clipping {float_value} to {min_val}")
        float_value = min_val

    # Extract sign
    sign_bit = 1 if float_value < 0 else 0

    # Scale magnitude by 2^20
    scaled = int(round(abs(float_value) * (2 ** frac_bits)))

    # Combine: sign bit is MSB, magnitude in bits[22:0]
    fixed_value = (sign_bit << (total_bits - 1)) | (scaled & 0x7FFFFF)

    return fixed_value & ((1 << total_bits) - 1)

# ...existing code...

# Main program
if __name__ == "__main__":
    print("=" * 80)
    print("24-bit Fixed-Point Hex ↔ Float Converter (S3.20)")
    print("Format: [Sign:1bit][Integer:3bits][Fractional:20bits]")
    print("Range: -8.0 to +7.999999046325683593750")
    print("Resolution: 0.000000953674316406250 (2^-20)")
    print("=" * 80)
    print("\nUsage:")
    print("  - Enter hex value: 0x100000 or 100000")
    print("  - Enter float value: f:1.5 or F:1.5")
    print("  - Type 'q' or 'quit' to exit")
    print("=" * 80)
    
    # Test examples
    print("\n📊 Example conversions (Hex → Float):")
    print("-" * 80)
    examples = {
        '0x000000': 0.0,
        '0x100000': 1.0,
        '0x200000': 2.0,
        '0x280000': 2.5,
        '0x38D8C0': 3.55181884765625,
        '0x400000': 4.0,
        '0x7FFFFF': 7.999999046325683593750,  # Max positive
        '0x800001': -7.999999046325683593750,  # Max negative (two's complement)
        '0x800000': -8.0,                       # Min negative
        '0xE00000': -2.0,
        '0xD80000': -2.5,
        '0xF00000': -1.0,
        '0xE1E3C0': -1.88116455078125,         # Energy value
        '0x000001': 0.00000095367431640625,    # Smallest positive
        '0xFFFFFF': -0.00000095367431640625,   # Smallest negative
    }
    
    for hex_val, expected in examples.items():
        result = fixed_to_float(hex_val)
        match = "✓" if abs(result - expected) < 1e-10 else "✗"
        print(f"{hex_val:8s} → {result:25.15f} (expected: {expected:20.15f}) {match}")
    
    print("\n" + "=" * 80)
    print("\n📊 Example conversions (Float → Hex):")
    print("-" * 80)
    float_examples = [
        0.0, 1.0, 2.0, 2.5, 3.55182, 4.0, 7.999,
        -1.0, -2.0, -2.5, -1.8903745, -7.999, -8.0,
        0.000001, -0.000001
    ]
    
    for float_val in float_examples:
        hex_result = float_to_fixed(float_val)
        back_to_float = fixed_to_float(hex_result)
        error = abs(float_val - back_to_float)
        print(f"{float_val:12.9f} → 0x{hex_result:06X} → {back_to_float:25.15f} (err: {error:.2e})")
    
    print("\n" + "=" * 80)
    print("\n🔧 Interactive Mode:")
    print("-" * 80)
    
    while True:
        user_input = input("\nEnter value: ").strip()
        
        if user_input.lower() in ['quit', 'q', 'exit', '']:
            print("Exiting...")
            break
        
        try:
            if user_input.startswith('f:') or user_input.startswith('F:'):
                # Float to hex conversion
                float_val = float(user_input[2:])
                hex_result = float_to_fixed(float_val)
                back_to_float = fixed_to_float(hex_result)
                error = abs(float_val - back_to_float)
                
                # Binary representation
                binary = format(hex_result, '024b')
                sign = binary[0]
                integer = binary[1:4]
                frac = binary[4:]
                
                print(f"\n{'Input Float:':15s} {float_val:.15f}")
                print(f"{'Hex:':15s} 0x{hex_result:06X}")
                print(f"{'Binary:':15s} {sign}|{integer}|{frac}")
                print(f"{'Recovered:':15s} {back_to_float:.15f}")
                print(f"{'Error:':15s} {error:.2e}")
                
            else:
                # Hex to float conversion
                result = fixed_to_float(user_input)
                
                # Get numeric value
                if user_input.startswith('0x') or user_input.startswith('0X'):
                    value = int(user_input, 16)
                else:
                    value = int(user_input, 16)
                
                # Binary representation
                binary = format(value, '024b')
                sign = binary[0]
                integer = binary[1:4]
                frac = binary[4:]
                
                print(f"\n{'Hex:':15s} {user_input}")
                print(f"{'Binary:':15s} {sign}|{integer}|{frac}")
                print(f"{'Float:':15s} {result:.15f}")
                print(f"{'Sign:':15s} {'Negative' if sign == '1' else 'Positive'}")
                print(f"{'Integer bits:':15s} {int(integer, 2)}")
                
        except Exception as e:
            print(f"❌ Error: Invalid input! ({e})")
    
    print("\n" + "=" * 80)
    print("Goodbye! 👋")