import numpy as np
import matplotlib.pyplot as plt

class TanhS7p8:
    """Tanh approximator using S7.8 fixed-point with 176-entry LUT"""
    
    def __init__(self):
        self.frac_bits = 8
        self.lut_size = 176
        self.lut_min = 0.25
        self.lut_max = 3.0
        
        # Generate LUT
        self.lut = self._generate_lut()
        self.lut_step = (self.lut_max - self.lut_min) / (self.lut_size - 1)
    
    def _generate_lut(self):
        """Generate 176-entry LUT for range [0.25, 3.0]"""
        lut = []
        for i in range(self.lut_size):
            x = self.lut_min + i * (self.lut_max - self.lut_min) / (self.lut_size - 1)
            tanh_val = np.tanh(x)
            # Convert to S7.8: multiply by 2^8 = 256
            tanh_s7p8 = int(np.clip(tanh_val * 256, 0, 32767))
            lut.append(tanh_s7p8)
        return np.array(lut)
    
    def s7p8_to_real(self, s7p8_val):
        """Convert S7.8 fixed-point to real number"""
        # Handle signed values
        if s7p8_val > 32767:
            s7p8_val = s7p8_val - 65536
        return s7p8_val / 256.0
    
    def real_to_s7p8(self, real_val):
        """Convert real number to S7.8 fixed-point"""
        s7p8 = int(np.clip(real_val * 256, -32768, 32767))
        if s7p8 < 0:
            s7p8 = s7p8 + 65536
        return s7p8
    
    def tanh_approx(self, x_real):
        """Approximate tanh using piecewise method (Formula 8)"""
        # Handle negative values using symmetry: tanh(-x) = -tanh(x)
        if x_real < 0:
            return -self.tanh_approx(-x_real)
        
        # Case 1: Linear region [0, 0.25)
        if x_real < 0.25:
            return x_real
        
        # Case 2: LUT region [0.25, 3.0]
        elif x_real <= 3.0:
            # Find index in LUT
            idx_float = (x_real - self.lut_min) / self.lut_step
            idx = int(np.clip(idx_float, 0, self.lut_size - 1))
            
            # Linear interpolation between LUT entries
            if idx < self.lut_size - 1:
                frac = idx_float - idx
                lut_lower = self.s7p8_to_real(self.lut[idx])
                lut_upper = self.s7p8_to_real(self.lut[idx + 1])
                return lut_lower * (1 - frac) + lut_upper * frac
            else:
                return self.s7p8_to_real(self.lut[self.lut_size - 1])
        
        # Case 3: Saturation region (x > 3.0)
        else:
            return 1.0
    
    def print_lut(self):
        """Print LUT in Verilog format"""
        print("// tanh LUT for range [0.25, 3.0] in S7.8 fixed-point")
        print("// 176 entries\n")
        print("initial begin")
        for i in range(self.lut_size):
            x = self.lut_min + i * (self.lut_max - self.lut_min) / (self.lut_size - 1)
            tanh_real = self.s7p8_to_real(self.lut[i])
            print(f"    lut[{i:3d}] = 16'h{self.lut[i]:04X};  // tanh({x:.4f}) = {tanh_real:.6f}")
        print("end\n")


# Main execution
if __name__ == "__main__":
    approx = TanhS7p8()
    
    # Generate test data
    x_test = np.linspace(-4, 4, 2000)
    y_true = np.tanh(x_test)
    y_approx = np.array([approx.tanh_approx(x) for x in x_test])
    
    # Calculate error
    error = np.abs(y_true - y_approx)
    
    # Create figure with subplots
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    
    # Plot 1: Tanh comparison
    ax = axes[0, 0]
    ax.plot(x_test, y_true, 'b-', linewidth=2, label='True tanh(x)', alpha=0.7)
    ax.plot(x_test, y_approx, 'r--', linewidth=2, label='S7.8 LUT Approximation', alpha=0.7)
    ax.axvline(x=-3, color='gray', linestyle=':', alpha=0.5, label='Boundaries')
    ax.axvline(x=-0.25, color='gray', linestyle=':', alpha=0.5)
    ax.axvline(x=0.25, color='gray', linestyle=':', alpha=0.5)
    ax.axvline(x=3, color='gray', linestyle=':', alpha=0.5)
    ax.grid(True, alpha=0.3)
    ax.set_xlabel('x (real)')
    ax.set_ylabel('tanh(x)')
    ax.set_title('Tanh Approximation (Formula 8 with 176 LUT entries)')
    ax.legend()
    
    # Plot 2: Error
    ax = axes[0, 1]
    ax.semilogy(x_test, error + 1e-7, 'g-', linewidth=2)
    ax.axvline(x=-3, color='gray', linestyle=':', alpha=0.5)
    ax.axvline(x=-0.25, color='gray', linestyle=':', alpha=0.5)
    ax.axvline(x=0.25, color='gray', linestyle=':', alpha=0.5)
    ax.axvline(x=3, color='gray', linestyle=':', alpha=0.5)
    ax.grid(True, alpha=0.3, which='both')
    ax.set_xlabel('x (real)')
    ax.set_ylabel('Absolute Error')
    ax.set_title('Approximation Error')
    
    # Plot 3: Linear region zoom
    x_linear = np.linspace(-0.25, 0.25, 500)
    y_true_linear = np.tanh(x_linear)
    y_approx_linear = np.array([approx.tanh_approx(x) for x in x_linear])
    ax = axes[1, 0]
    ax.plot(x_linear, y_true_linear, 'b-', linewidth=2, label='True tanh(x)')
    ax.plot(x_linear, y_approx_linear, 'r--', linewidth=2, label='Approximation')
    ax.grid(True, alpha=0.3)
    ax.set_xlabel('x (real)')
    ax.set_ylabel('tanh(x)')
    ax.set_title('Linear Region [-0.25, 0.25]')
    ax.legend()
    
    # Plot 4: LUT region zoom
    x_lut = np.linspace(0.25, 3.0, 500)
    y_true_lut = np.tanh(x_lut)
    y_approx_lut = np.array([approx.tanh_approx(x) for x in x_lut])
    ax = axes[1, 1]
    ax.plot(x_lut, y_true_lut, 'b-', linewidth=2, label='True tanh(x)')
    ax.plot(x_lut, y_approx_lut, 'r--', linewidth=2, label='LUT Approximation')
    ax.scatter([approx.lut_min + i * approx.lut_step for i in range(approx.lut_size)],
               [approx.s7p8_to_real(approx.lut[i]) for i in range(approx.lut_size)],
               c='red', s=20, alpha=0.5, label='LUT entries')
    ax.grid(True, alpha=0.3)
    ax.set_xlabel('x (real)')
    ax.set_ylabel('tanh(x)')
    ax.set_title('LUT Region [0.25, 3.0] (176 entries)')
    ax.legend()
    
    plt.tight_layout()
    plt.savefig('tanh_s7p8_analysis.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    # Print statistics
    print("=" * 60)
    print("Tanh S7.8 Approximation Analysis")
    print("=" * 60)
    print(f"LUT Size: {approx.lut_size} entries")
    print(f"LUT Range: [{approx.lut_min}, {approx.lut_max}]")
    print(f"LUT Step: {approx.lut_step:.6f}")
    print(f"\nMax Error: {error.max():.6f}")
    print(f"Mean Error: {error.mean():.6f}")
    print(f"RMS Error: {np.sqrt((error**2).mean()):.6f}")
    
    print("\n" + "=" * 60)
    print("Sample Test Values (S7.8 Fixed-Point)")
    print("=" * 60)
    test_vals = [-3.0, -2.0, -1.0, -0.5, -0.25, 0, 0.125, 0.25, 0.5, 1.0, 2.0, 3.0, 4.0]
    print(f"{'x (real)':>10} | {'True':>10} | {'Approx':>10} | {'Error':>10} | {'S7.8 (hex)':>12}")
    print("-" * 65)
    for x in test_vals:
        true_val = np.tanh(x)
        approx_val = approx.tanh_approx(x)
        err = abs(true_val - approx_val)
        s7p8_val = approx.real_to_s7p8(approx_val)
        print(f"{x:10.3f} | {true_val:10.6f} | {approx_val:10.6f} | {err:10.6f} | 0x{s7p8_val:04X}")
    
    # Print Verilog LUT
    print("\n" + "=" * 60)
    print("Verilog LUT Output")
    print("=" * 60)
    approx.print_lut()