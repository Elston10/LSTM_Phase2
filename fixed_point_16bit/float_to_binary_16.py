def float_to_binary(value):
    """Convert float to 16-bit S7.8 binary string (1 sign + 7 integer + 8 fractional)"""
    
    # S7.8 range: -128.0 to +127.99609375
    if value > 127.99609375:
        value = 127.99609375
    elif value < -128.0:
        value = -128.0
    
    # Get sign and magnitude
    is_negative = value < 0
    abs_value = abs(value)
    
    # Convert to fixed-point (scale by 2^8 = 256)
    magnitude = int(round(abs_value * 256))
    
    # Clamp magnitude to 15 bits
    magnitude = min(magnitude, 32767)
    
    # Create 16-bit sign-magnitude: sign bit + 15-bit magnitude
    if is_negative:
        binary_value = (1 << 15) | magnitude  # Set sign bit (MSB)
    else:
        binary_value = magnitude
    
    # Return as 16-bit binary string
    return format(binary_value, '016b')

# Main program
while True:
    try:
        user_input = input("Enter float value (or 'q' to quit): ")
        if user_input.lower() == 'q':
            break
        
        value = float(user_input)
        binary = float_to_binary(value)
        print(binary)
        
    except ValueError:
        print("Invalid input!")
    except KeyboardInterrupt:
        break