import math

# ================= CONFIG =================
LUT_MIN = 0.0
LUT_MAX = 6.0
LUT_SIZE = 6144

FRAC_BITS = 20
TOTAL_BITS = 28
SCALE = 2 ** FRAC_BITS

OUTPUT_FILE_HEX = "sigmoid_lut_hex_s7_20.mem"
OUTPUT_FILE_DEBUG = "sigmoid_lut_debug.txt"

# ================= SIGMOID =================
def sigmoid(x):
    if x > 20:
        return 1.0
    elif x < -20:
        return 0.0
    return 1.0 / (1.0 + math.exp(-x))

# ================= FIXED POINT =================
def float_to_s7_20(value):
    max_val = (2**7) - (1 / SCALE)
    min_val = -(2**7)

    # Clamp
    if value > max_val:
        value = max_val
    elif value < min_val:
        value = min_val

    scaled = int(round(value * SCALE))

    if scaled < 0:
        scaled = (1 << TOTAL_BITS) + scaled

    return scaled & ((1 << TOTAL_BITS) - 1)

def s7_20_to_float(val):
    if val & (1 << (TOTAL_BITS - 1)):
        val = val - (1 << TOTAL_BITS)
    return val / SCALE

# ================= LUT GENERATION =================
def generate_lut():
    lut = []
    debug_data = []

    step = (LUT_MAX - LUT_MIN) / (LUT_SIZE - 1)
    print(f"Step size = {step}\n")

    for i in range(LUT_SIZE):
        x = LUT_MIN + i * step

        y = sigmoid(x)

        # Match hardware saturation
        if x >= LUT_MAX:
            y = 1.0

        y = max(0.0, min(1.0, y))

        fixed = float_to_s7_20(y)
        recon = s7_20_to_float(fixed)

        lut.append(fixed)

        # Store debug info
        debug_data.append((i, x, y, recon, fixed))

        # Print only first few + last few (avoid huge spam)
        if i < 10 or i > LUT_SIZE - 10:
            print(f"i={i:4d} | x={x:.6f} | sig={y:.6f} | fixed=0x{fixed:07X}")

    return lut, debug_data

# ================= WRITE FILES =================
def write_hex(lut):
    with open(OUTPUT_FILE_HEX, 'w') as f:
        for val in lut:
            f.write(f"{val:07X}\n")

def write_debug(debug_data):
    with open(OUTPUT_FILE_DEBUG, 'w') as f:
        f.write("Index\tX\tSigmoid\tRecon\tHex\n")
        for i, x, y, recon, val in debug_data:
            f.write(f"{i}\t{x:.6f}\t{y:.6f}\t{recon:.6f}\t0x{val:07X}\n")

# ================= MAIN =================
if __name__ == "__main__":
    print("Generating S7.20 sigmoid LUT (2’s complement)...\n")

    lut, debug_data = generate_lut()

    write_hex(lut)
    write_debug(debug_data)

    print("\nDone!")
    print(f"HEX  → {OUTPUT_FILE_HEX}")
    print(f"DEBUG → {OUTPUT_FILE_DEBUG}")