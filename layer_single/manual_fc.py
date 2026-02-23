import torch
import torch.nn as nn

# Manual FC layer implementation
class ManualFC:
    def __init__(self, input_size, output_size):
        # Initialize weights and bias randomly
        self.weight = torch.randn(output_size, input_size) * 0.01  # [1, 94]
        self.bias = torch.zeros(output_size)  # [1]
        
    def forward(self, x):
        # y = x @ W^T + b
        output = torch.matmul(x, self.weight.t()) + self.bias
        return output

# Create FC layer: 94 inputs -> 1 output
fc = ManualFC(input_size=94, output_size=1)

print("="*50)
print("Manual FC Layer")
print("="*50)
print(f"Weight shape: {fc.weight.shape}")
print(f"Bias shape: {fc.bias.shape}")
print(f"\nFirst 5 weights: {fc.weight[0, :5]}")
print(f"Bias: {fc.bias[0]}")

# Sample input (like LSTM output)
input_data = torch.randn(1, 94)  # batch_size=1, hidden_size=94

print("\n" + "="*50)
print("Forward Pass")
print("="*50)
print(f"Input shape: {input_data.shape}")
print(f"Input (first 5): {input_data[0, :5]}")

# Forward pass
output = fc.forward(input_data)

print(f"\nOutput: {output[0, 0].item():.6f}")
print(f"Output shape: {output.shape}")

# Manual calculation verification
manual_calc = (input_data[0] * fc.weight[0]).sum() + fc.bias[0]
print(f"\nManual verification: {manual_calc.item():.6f}")
print("="*50)