import numpy as np

# Load the weights with comma delimiter
weights = np.loadtxt('d:/Github/SOC_LSTM/dataset/timestep0_W_all_376x100.txt', delimiter=',')

print("=" * 60)
print("Fixed-Point S3.12 Format Analysis for Weights")
print("=" * 60)
print(f"Format: 1 sign + 3 integer + 12 fractional bits")
print(f"Range: -8.0 to +7.999755859375")
print(f"Precision: 2^-12 = 0.000244140625")
print()

# Weight statistics
print("Weight Statistics:")
print(f"Shape: {weights.shape}")
print(f"Min: {np.min(weights):.10f}")
print(f"Max: {np.max(weights):.10f}")
print(f"Mean: {np.mean(weights):.10f}")
print(f"Std: {np.std(weights):.10f}")
print()

# Check if weights fit in S3.12 range
S3_12_MIN = -8.0
S3_12_MAX = 7.999755859375

out_of_range = (weights < S3_12_MIN) | (weights > S3_12_MAX)
num_out_of_range = np.sum(out_of_range)
percent_out_of_range = 100 * num_out_of_range / weights.size

print("Range Check:")
print(f"Values out of range [-8, +7.999]: {num_out_of_range} ({percent_out_of_range:.2f}%)")

if num_out_of_range > 0:
    print(f"Min out-of-range value: {np.min(weights[out_of_range]):.10f}")
    print(f"Max out-of-range value: {np.max(weights[out_of_range]):.10f}")
print()

# Quantization error analysis
def quantize_s3_12(value):
    """Quantize to S3.12 format"""
    # Clip to range
    clipped = np.clip(value, S3_12_MIN, S3_12_MAX)
    # Quantize
    scale = 2**12
    quantized = np.round(clipped * scale) / scale
    return quantized

quantized_weights = quantize_s3_12(weights)
quantization_error = weights - quantized_weights

print("Quantization Error Analysis:")
print(f"Max quantization error: {np.max(np.abs(quantization_error)):.10f}")
print(f"Mean absolute error: {np.mean(np.abs(quantization_error)):.10f}")
print(f"RMS error: {np.sqrt(np.mean(quantization_error**2)):.10f}")
print()

# Check precision adequacy
print("Precision Check:")
print(f"Smallest non-zero weight: {np.min(np.abs(weights[weights != 0])):.10f}")
print(f"S3.12 precision: 0.000244140625")
small_weights = np.sum((np.abs(weights) > 0) & (np.abs(weights) < 0.000244140625))
print(f"Weights smaller than precision (will be lost): {small_weights}")
print()

# Distribution analysis
print("Value Distribution:")
ranges = [
    (-8, -4), (-4, -2), (-2, -1), (-1, -0.5), (-0.5, 0),
    (0, 0.5), (0.5, 1), (1, 2), (2, 4), (4, 8)
]
for r_min, r_max in ranges:
    count = np.sum((weights >= r_min) & (weights < r_max))
    percent = 100 * count / weights.size
    print(f"  [{r_min:+5.1f}, {r_max:+5.1f}): {count:6d} ({percent:5.2f}%)")
print()

# Recommendation
print("=" * 60)
print("RECOMMENDATION:")
print("=" * 60)
if num_out_of_range == 0:
    print("✓ S3.12 format is SUFFICIENT - all weights fit in range")
    if np.max(np.abs(quantization_error)) < 0.001:
        print("✓ Quantization error is ACCEPTABLE")
    else:
        print("⚠ Quantization error may affect accuracy")
else:
    print("✗ S3.12 format is INSUFFICIENT - weights out of range detected")
    print(f"  Consider using S4.11 or S5.10 format instead")
    
# Suggest alternative formats if needed
if num_out_of_range > 0 or np.max(np.abs(weights)) > 4:
    print("\nAlternative Formats:")
    print("  S4.11: Range [-16, +15.9995], Precision 0.00048828")
    print("  S5.10: Range [-32, +31.999], Precision 0.0009765")
    print("  S6.9:  Range [-64, +63.998], Precision 0.001953")

print("=" * 60)