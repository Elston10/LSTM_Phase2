def fixed_to_float(value, total_bits=28, frac_bits=20):
    """
    Convert 2's complement S7.20 fixed-point to float
    """
    if isinstance(value, str):
        value = int(value, 16)

    # Convert from unsigned to signed
    if value & (1 << (total_bits - 1)):
        value = value - (1 << total_bits)

    return value / (2.0 ** frac_bits)


def float_to_fixed(float_value, total_bits=28, frac_bits=20):
    """
    Convert float to 2's complement S7.20
    """

    max_val = (2 ** (total_bits-1) - 1) / (2 ** frac_bits)
    min_val = -(2 ** (total_bits-1)) / (2 ** frac_bits)

    # Clamp
    if float_value > max_val:
        float_value = max_val
    elif float_value < min_val:
        float_value = min_val

    scaled = int(round(float_value * (2 ** frac_bits)))

    # Convert to 2's complement
    if scaled < 0:
        scaled = (1 << total_bits) + scaled

    return scaled & ((1 << total_bits) - 1)

# Main program
if __name__ == "__main__":
    print("=" * 80)
    print("28-bit Fixed-Point Hex ↔ Float Converter (S7.20)")
    print("Format: [Sign:1bit][Integer:7bits][Fractional:20bits]")
    print("Range: -128.0 to +127.999999046325683593750")
    print("Resolution: 0.000000953674316406250 (2^-20)")
    print("=" * 80)
    print("\nUsage:")
    print("  - Enter hex value: 0x1000000 or 1000000")
    print("  - Enter float value: f:1.5 or F:1.5")
    print("  - Type 'q' or 'quit' to exit")
    print("=" * 80)
    
    # Test examples
    print("\n📊 Example conversions (Hex → Float):")
    print("-" * 80)
    examples = {
        '0x0000000': 0.0,
        '0x1000000': 1.0,
        '0x2000000': 2.0,
        '0x2800000': 2.5,
        '0x38D8C00': 3.55181884765625,
        '0x4000000': 4.0,
        '0x7FFFFFF': 127.999999046325683593750,  # Max positive
        '0xFFFFFFF': -127.999999046325683593750, # Max negative
        '0x8000000': -128.0,                     # Min negative
        '0xE000000': -2.0,
        '0xD800000': -2.5,
        '0xF000000': -1.0,
        '0xE1E3C00': -1.88116455078125,
        '0x0000001': 0.00000095367431640625,     # Smallest positive
        '0x7FFFFFF': 127.999999046325683593750,  # Max positive
    }
    
    for hex_val, expected in examples.items():
        result = fixed_to_float(hex_val)
        match = "✓" if abs(result - expected) < 1e-10 else "✗"
        print(f"{hex_val:9s} → {result:25.15f} (expected: {expected:20.15f}) {match}")
    
    print("\n" + "=" * 80)
    print("\n📊 Example conversions (Float → Hex):")
    print("-" * 80)
    float_examples = [
        0.0, 1.0, 2.0, 2.5, 3.55182, 4.0, 127.999,
        -1.0, -2.0, -2.5, -1.8903745, -127.999, -128.0,
        0.000001, -0.000001
    ]
    
    for float_val in float_examples:
        hex_result = float_to_fixed(float_val)
        back_to_float = fixed_to_float(hex_result)
        error = abs(float_val - back_to_float)
        print(f"{float_val:14.9f} → 0x{hex_result:07X} → {back_to_float:25.15f} (err: {error:.2e})")
    
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
                binary = format(hex_result, '028b')
                sign = binary[0]
                integer = binary[1:8]
                frac = binary[8:]
                
                print(f"\n{'Input Float:':15s} {float_val:.15f}")
                print(f"{'Hex:':15s} 0x{hex_result:07X}")
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
                binary = format(value, '028b')
                sign = binary[0]
                integer = binary[1:8]
                frac = binary[8:]
                
                print(f"\n{'Hex:':15s} {user_input}")
                print(f"{'Binary:':15s} {sign}|{integer}|{frac}")
                print(f"{'Float:':15s} {result:.15f}")
                print(f"{'Sign:':15s} {'Negative' if sign == '1' else 'Positive'}")
                print(f"{'Integer bits:':15s} {int(integer, 2)}")
                
        except Exception as e:
            print(f"❌ Error: Invalid input! ({e})")
    
    print("\n" + "=" * 80)
    print("Goodbye! 👋")