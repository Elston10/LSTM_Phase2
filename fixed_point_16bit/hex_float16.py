def hex_to_float(hex_str):
    """Convert 16-bit S7.8 hex string to float (1 sign + 7 integer + 8 fractional)"""
    
    # Remove any spaces, underscores, or '0x' prefix
    hex_str = hex_str.replace('_', '').replace(' ', '').replace('0x', '').replace('0X', '')
    
    # Check if valid hex (1 to 4 hex digits)
    if len(hex_str) == 0 or len(hex_str) > 4 or not all(c in '0123456789ABCDEFabcdef' for c in hex_str):
        return None
    
    # Pad with leading zeros to make it 4 hex digits (16 bits)
    hex_str = hex_str.zfill(4)
    
    # Convert hex string to integer
    hex_value = int(hex_str, 16)
    
    # Extract sign bit (MSB - bit 15)
    sign_bit = (hex_value >> 15) & 1
    
    # Extract magnitude (lower 15 bits)
    magnitude = hex_value & 0x7FFF
    
    # Convert magnitude to float (divide by 2^8 = 256)
    float_magnitude = magnitude / 256.0
    
    # Apply sign
    if sign_bit:
        return -float_magnitude
    else:
        return float_magnitude

# Main program
print("16-bit S7.8 Fixed-Point Hex to Float Converter")
print("=" * 50)
print("Format: 1 sign bit + 7 integer bits + 8 fractional bits")
print("=" * 50)

while True:
    try:
        user_input = input("\nEnter hex value (or 'q' to quit): ")
        if user_input.lower() == 'q':
            print("Goodbye!")
            break
        
        result = hex_to_float(user_input)
        if result is not None:
            # Also show the hex value in standard format
            clean_hex = user_input.replace('_', '').replace(' ', '').replace('0x', '').replace('0X', '').zfill(4)
            print(f"Hex: 0x{clean_hex.upper()} → Float: {result}")
        else:
            print("Invalid hex! Enter 1-4 hex digits (0-9, A-F)")
        
    except ValueError:
        print("Invalid input!")
    except KeyboardInterrupt:
        print("\nGoodbye!")
        break