import math

class TanhS3p20:
    """Tanh approximator using S3.20 fixed-point with 176-entry LUT"""
    
    def __init__(self):
        # S3.20 format parameters
        self.FRAC_BITS = 20
        self.SCALE = 2 ** self.FRAC_BITS  # 1048576
        self.WIDTH = 24
        
        # LUT parameters
        self.LUT_MIN = 0.25
        self.LUT_MAX = 3.0
        self.LUT_SIZE = 176
        
        # Fixed-point constants
        self.MIN_LUT_FIXED = self.float_to_fixed(self.LUT_MIN)  # 0x040000
        self.MAX_LUT_FIXED = self.float_to_fixed(self.LUT_MAX)  # 0x300000
        self.ONE_FIXED = self.float_to_fixed(1.0)                # 0x100000
        
        # Generate LUT
        self.lut = self._generate_lut()
        
        print(f"TanhS3p20 initialized:")
        print(f"  Format: 1 sign + 3 int + {self.FRAC_BITS} frac bits")
        print(f"  Range: ±7.99999904632568359375")
        print(f"  Precision: {1/self.SCALE:.15f}")
        print(f"  LUT entries: {self.LUT_SIZE}")
        print(f"  LUT range: [{self.LUT_MIN}, {self.LUT_MAX}]")
    
    def float_to_fixed(self, value):
        """Convert float to S3.20 fixed-point"""
        # Clip to valid range
        if value > 7.99999904632568359375:
            value = 7.99999904632568359375
        elif value < -7.99999904632568359375:
            value = -7.99999904632568359375
        
        sign = 1 if value < 0 else 0
        abs_value = abs(value)
        magnitude = int(round(abs_value * self.SCALE))
        
        # Ensure magnitude fits in 23 bits
        if magnitude > 0x7FFFFF:
            magnitude = 0x7FFFFF
        
        # Combine sign and magnitude
        fixed_val = (sign << 23) | magnitude
        return fixed_val
    
    def fixed_to_float(self, fixed_val):
        """Convert S3.20 fixed-point to float"""
        sign = (fixed_val >> 23) & 1
        magnitude = fixed_val & 0x7FFFFF
        float_val = magnitude / self.SCALE
        if sign:
            float_val = -float_val
        return float_val
    
    def _generate_lut(self):
        """Generate tanh LUT"""
        lut = []
        step = (self.LUT_MAX - self.LUT_MIN) / (self.LUT_SIZE - 1)
        
        for i in range(self.LUT_SIZE):
            x = self.LUT_MIN + i * step
            tanh_val = math.tanh(x)
            fixed_val = self.float_to_fixed(tanh_val)
            lut.append(fixed_val)
        
        return lut
    
    def get_lut_address(self, x_abs_fixed):
        """Calculate LUT address from absolute value"""
        # Check if within LUT range
        if x_abs_fixed < self.MIN_LUT_FIXED:
            return None  # Below LUT range
        if x_abs_fixed >= self.MAX_LUT_FIXED:
            return None  # Above LUT range
        
        # Calculate address: addr = (x_abs - MIN) / step
        # step = (MAX - MIN) / (SIZE - 1)
        numerator = (x_abs_fixed - self.MIN_LUT_FIXED) * (self.LUT_SIZE - 1)
        denominator = self.MAX_LUT_FIXED - self.MIN_LUT_FIXED
        addr = numerator // denominator
        
        # Clamp to valid range
        if addr >= self.LUT_SIZE:
            addr = self.LUT_SIZE - 1
        
        return addr
    
    def tanh_fixed(self, x_fixed):
        """Compute tanh using fixed-point LUT"""
        # Extract sign and magnitude
        sign = (x_fixed >> 23) & 1
        magnitude = x_fixed & 0x7FFFFF
        
        # Handle special cases
        if magnitude == 0:
            return 0x000000  # tanh(0) = 0
        
        # Check if below LUT range (use linear approximation: tanh(x) ≈ x for small x)
        if magnitude < self.MIN_LUT_FIXED:
            # For small values, tanh(x) ≈ x
            result = x_fixed
            return result
        
        # Check if above LUT range (saturate to ±1)
        if magnitude >= self.MAX_LUT_FIXED:
            result = self.ONE_FIXED
            if sign:
                result |= (1 << 23)  # Set sign bit
            return result
        
        # Get LUT address
        addr = self.get_lut_address(magnitude)
        if addr is None:
            return x_fixed  # Fallback
        
        # Lookup tanh value
        tanh_val = self.lut[addr]
        
        # Apply sign
        if sign:
            tanh_val |= (1 << 23)
        
        return tanh_val
    
    def tanh(self, x):
        """Compute tanh from float input"""
        x_fixed = self.float_to_fixed(x)
        result_fixed = self.tanh_fixed(x_fixed)
        result_float = self.fixed_to_float(result_fixed)
        return result_float


def test_tanh_s3p20():
    """Test the S3.20 tanh approximator"""
    tanh_calc = TanhS3p20()
    
    print("\n" + "="*80)
    print("Testing S3.20 Tanh Approximator")
    print("="*80)
    
    # Test values
    test_values = [
        0.0, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0,
        -0.1, -0.25, -0.5, -1.0, -2.0, -3.0,
        0.0000014580,  # Your smallest weight
        0.000001, 0.00001, 0.0001,  # Very small values
    ]
    
    print(f"\n{'Input':<12} {'Expected':<15} {'Approx':<15} {'Error':<15} {'Rel Error %':<12}")
    print("-"*80)
    
    max_abs_error = 0
    max_rel_error = 0
    
    for x in test_values:
        expected = math.tanh(x)
        approx = tanh_calc.tanh(x)
        abs_error = abs(expected - approx)
        rel_error = (abs_error / abs(expected) * 100) if expected != 0 else 0
        
        max_abs_error = max(max_abs_error, abs_error)
        max_rel_error = max(max_rel_error, rel_error)
        
        print(f"{x:<12.6f} {expected:<15.12f} {approx:<15.12f} {abs_error:<15.12f} {rel_error:<12.6f}")
    
    print("-"*80)
    print(f"Maximum absolute error: {max_abs_error:.12f}")
    print(f"Maximum relative error: {max_rel_error:.6f}%")
    print("="*80 + "\n")
    
    # Show fixed-point representations
    print("\n" + "="*80)
    print("Fixed-Point Representations (Hex)")
    print("="*80)
    print(f"{'Value':<12} {'Fixed (Hex)':<15} {'Back to Float':<15}")
    print("-"*80)
    
    for x in [0.0, 0.25, 1.0, 2.0, 3.0, -1.0, -2.0, 0.0000014580]:
        fixed = tanh_calc.float_to_fixed(x)
        back = tanh_calc.fixed_to_float(fixed)
        print(f"{x:<12.6f} 0x{fixed:06X}       {back:<15.12f}")
    
    print("="*80 + "\n")


# Main execution
if __name__ == "__main__":
    test_tanh_s3p20()