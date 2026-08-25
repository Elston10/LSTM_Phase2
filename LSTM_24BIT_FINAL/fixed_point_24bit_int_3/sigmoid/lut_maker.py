import math

# ================= CONFIG =================
LUT_MIN = 0.0
LUT_MAX = 6.0
LUT_SIZE = 6144

FRAC_BITS = 20
TOTAL_BITS = 28
SCALE = 2 ** FRAC_BITS

STEP = (LUT_MAX - LUT_MIN) / (LUT_SIZE - 1)

OUTPUT_FILE = "sigmoid_lut_hex_s7_20.mem"

# ================= SIGMOID =================
def sigmoid(x):
    return 1.0 / (1.0 + math.exp(-x))

# ================= FIXED POINT =================
def float_to_s7_20(value):
    max_val = (2**7) - (1 / SCALE)
    min_val = -(2**7)

    value = max(min(value, max_val), min_val)

    scaled = int(round(value * SCALE))

    if scaled < 0:
        scaled += (1 << TOTAL_BITS)

    return scaled & ((1 << TOTAL_BITS) - 1)

# ================= LUT =================
def generate_lut():
    lut = []

    print(f"Step size = {STEP:.12f}")

    for i in range(LUT_SIZE):
        x = LUT_MIN + i * STEP

        # High precision sigmoid
        y = sigmoid(x)

        # Saturation consistency
        if x >= LUT_MAX:
            y = 1.0

        fixed = float_to_s7_20(y)

        lut.append(fixed)

        # Print sample
        if i < 5 or i > LUT_SIZE - 5:
            print(f"i={i} x={x:.6f} y={y:.6f} hex=0x{fixed:07X}")

    return lut

# ================= WRITE =================
def write_lut(lut):
    with open(OUTPUT_FILE, "w") as f:
        for val in lut:
            f.write(f"{val:07X}\n")

# ================= MAIN =================
if __name__ == "__main__":
    lut = generate_lut()
    write_lut(lut)
    print("LUT generated successfully.")