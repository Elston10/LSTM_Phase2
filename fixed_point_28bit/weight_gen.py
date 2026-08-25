import math

# ================= CONFIG =================
FRAC_BITS = 20
TOTAL_BITS = 28
SCALE = 1 << FRAC_BITS

INPUT_FILE = "fc_weight.txt"
OUTPUT_FILE = "fc_weights.mem"

EXPECTED_VALUES = 376 * 100


# ================= FIXED POINT =================

def float_to_s7_20(val):
    scaled = int(round(val * SCALE))

    # Clamp
    if scaled > (2**27 - 1):
        scaled = 2**27 - 1
    elif scaled < -(2**27):
        scaled = -(2**27)

    return scaled & 0x0FFFFFFF


def s7_20_to_float(val):
    if val & (1 << 27):
        val = val - (1 << 28)
    return val / SCALE


# ================= FILE READER =================

def read_input_file(filename):
    values = []

    with open(filename, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            parts = line.replace(",", " ").split()

            for p in parts:
                try:
                    values.append(float(p))
                except:
                    print(f"⚠ Skipping invalid value: {p}")

    return values


# ================= MAIN =================

def generate_mem():
    print("\n📥 Reading input file...")
    values = read_input_file(INPUT_FILE)

    print(f"Total values: {len(values)}")

    if len(values) != EXPECTED_VALUES:
        print(f"⚠ WARNING: Expected {EXPECTED_VALUES}, got {len(values)}")

    print("\n🔄 Converting + writing MEM...")

    with open(OUTPUT_FILE, "w") as f:
        f.write("// S7.20 (28-bit, 2's complement)\n")
        f.write("// Format: HEX  // idx | input | reconstructed | error\n\n")

        for i, val in enumerate(values):

            fixed = float_to_s7_20(val)
            recon = s7_20_to_float(fixed)
            error = recon - val

            f.write(f"{fixed:07X}  // {i:05d} | "
                    f"in={val:.6f} | "
                    f"out={recon:.6f} | "
                    f"err={error:.6e}\n")

            # Print first few for sanity
            if i < 5:
                print(f"[{i}] in={val:.6f} → hex=0x{fixed:07X} → out={recon:.6f} → err={error:.6e}")

    print(f"\n✅ Generated: {OUTPUT_FILE}")


# ================= RUN =================

if __name__ == "__main__":
    generate_mem()