def binary_to_float(binary_str):
    """Convert 16-bit S7.8 binary string to float (1 sign + 7 integer + 8 fractional)"""
    
    # Remove any spaces or underscores
    binary_str = binary_str.replace('_', '').replace(' ', '')
    
    # Check if valid 16-bit binary
    if len(binary_str) != 16 or not all(c in '01' for c in binary_str):
        return None
    
    # Convert binary string to integer
    binary_value = int(binary_str, 2)
    
    # Extract sign bit (MSB)
    sign_bit = (binary_value >> 15) & 1
    
    # Extract magnitude (lower 15 bits)
    magnitude = binary_value & 0x7FFF
    
    # Convert magnitude to float (divide by 2^8 = 256)
    float_magnitude = magnitude / 256.0
    
    # Apply sign
    if sign_bit:
        return -float_magnitude
    else:
        return float_magnitude

# Main program
while True:
    try:
        user_input = input("Enter 16-bit binary (or 'q' to quit): ")
        if user_input.lower() == 'q':
            break
        
        result = binary_to_float(user_input)
        if result is not None:
            print(f"{result}")
        else:
            print("Invalid binary! Enter 16-bit binary (0s and 1s only)")
        
    except ValueError:
        print("Invalid input!")
    except KeyboardInterrupt:
        break