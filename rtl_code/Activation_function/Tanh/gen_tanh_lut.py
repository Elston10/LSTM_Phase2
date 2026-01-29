# Python script to generate correct tanh LUT for S7.8 format
lut_size = 276
start = 0.25
step = 0.01
width = 16

def float_to_s7_8(val):
    return int(round(val * 256)) & 0xFFFF

def gen_lut():
    print('// tanh LUT for S7.8 format, range [0.25, 3.0], step 0.01')
    for i in range(lut_size):
        x = start + i * step
        tanh_val = float_to_s7_8(__import__('math').tanh(x))
        print(f'    tanh_lut[{i:3d}] = 16\'h{tanh_val:04X}; // tanh({x:.2f})')

gen_lut()
