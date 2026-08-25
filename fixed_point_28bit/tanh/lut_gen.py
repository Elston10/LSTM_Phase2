import math

# ================= CONFIG =================
LUT_SIZE = 512
FRAC_BITS = 20
TOTAL_BITS = 28
SCALE = 1 << FRAC_BITS

LUT_MIN = 0.25
LUT_MAX = 3.0

STEP = (LUT_MAX - LUT_MIN) / (LUT_SIZE - 1)

OUT_FILE = "tanh_lut_hex_s7_20_512.mem"

# ================= FIXED-POINT =================

def float_to_s7_20(val):
    """Convert float to signed 28-bit (S7.20, 2's complement)"""
    scaled = int(round(val * SCALE))

    # Clamp to 28-bit signed range
    if scaled > (2**27 - 1):
        scaled = 2**27 - 1
    elif scaled < -(2**27):
        scaled = -(2**27)

    return scaled & 0x0FFFFFFF  # 28-bit wrap


def s7_20_to_float(val):
    """Convert back (for verification)"""
    if val & (1 << 27):  # negative
        val = val - (1 << 28)
    return val / SCALE


# ================= LUT GENERATION =================

def generate_lut():
    print(f"\nGenerating LUT (S7.20, 28-bit)")
    print(f"Range: [{LUT_MIN}, {LUT_MAX}]")
    print(f"Step:  {STEP}\n")

    with open(OUT_FILE, "w") as f:
        f.write("// S7.20 tanh LUT (28-bit, 2's complement)\n")
        f.write(f"// {LUT_SIZE} entries\n\n")

        for addr in range(LUT_SIZE):

            # EXACT SAME mapping as hardware
            x = LUT_MIN + addr * STEP

            y = math.tanh(x)

            fixed = float_to_s7_20(y)

            f.write(f"{fixed:07X}  // addr={addr:03d} x={x:.8f} tanh={y:.12f}\n")

            # Debug print (optional)
            if addr < 5 or addr > LUT_SIZE - 5:
                recon = s7_20_to_float(fixed)
                print(f"{addr:3d}: x={x:.6f}, tanh={y:.6f}, fixed=0x{fixed:07X}, rec={recon:.6f}")

    print(f"\n✅ LUT saved to: {OUT_FILE}")


# ================= VALIDATION =================

def validate_mapping():
    print("\n🔍 Checking address alignment...\n")

    errors = 0

    for addr in range(LUT_SIZE):
        x_expected = LUT_MIN + addr * STEP

        # simulate your hardware approx:
        offset = x_expected - LUT_MIN
        approx_addr = int((offset * 186))  # since >>20 cancels scale

        if abs(approx_addr - addr) > 1:
            errors += 1

    print(f"Mapping mismatches: {errors} (should be very small)")


# ================= MAIN =================

if __name__ == "__main__":
    generate_lut()
    validate_mapping()