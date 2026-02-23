import os
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.preprocessing import StandardScaler


FEATURE_COLS = ['Voltage [V]', 'Current [A]', 'Temperature [degC]', 'Power [W]', 'CC_Capacity [Ah]']
DEFAULT_TEMPS = ['25degC', '0degC', 'n10degC', 'n20degC', '10degC', '40degC']

# Fixed scaled features (20 timesteps x 5 features)
FIXED_SCALED_FEATURES = np.array([
    [-0.116864,  0.396518,  1.655884,  0.388196, -0.634126],
    [-0.116864,  0.396518,  1.655884,  0.388196, -0.634162],
    [-0.116864,  0.396518,  1.655884,  0.388196, -0.634205],
    [-0.116864,  0.395391,  1.655884,  0.387022, -0.634241],
    [-0.116864,  0.396518,  1.655884,  0.388196, -0.634285],
    [-0.116864,  0.396518,  1.655884,  0.388196, -0.634320],
    [-0.116864,  0.395391,  1.655884,  0.387022, -0.634364],
    [-0.116864,  0.395391,  1.655884,  0.387022, -0.634400],
    [-0.125400,  0.329053,  1.655884,  0.318008, -0.634505],
    [-0.151009,  0.136782,  1.655884,  0.118548, -0.634735],
    [-0.202765, -0.244382,  1.655884, -0.274353, -0.635308],
    [-0.215249, -0.300603,  1.655884, -0.331718, -0.635928],
    [-0.240857, -0.454644,  1.655884, -0.488938, -0.636749],
    [-0.223212, -0.278117,  1.655884, -0.307998, -0.637349],
    [-0.224359, -0.264623,  1.655884, -0.293996, -0.637938],
    [-0.296022, -0.802078,  1.655884, -0.841367, -0.638873],
    [-0.320483, -0.916766,  1.650127, -0.956274, -0.640115],
    [-0.287486, -0.607558,  1.650127, -0.642464, -0.640991],
    [-0.282357, -0.545719,  1.650127, -0.579374, -0.641815],
    [-0.284078, -0.531103,  1.650127, -0.564214, -0.642628]
])


class LinearScratch(nn.Module):
    def __init__(self, in_features, out_features, bias=True):
        super().__init__()
        self.weight = nn.Parameter(torch.empty(out_features, in_features))
        self.bias = nn.Parameter(torch.empty(out_features)) if bias else None
        # simple init (like Kaiming uniform)
        nn.init.kaiming_uniform_(self.weight, a=np.sqrt(5))
        if self.bias is not None:
            fan_in = in_features
            bound = 1 / np.sqrt(fan_in)
            nn.init.uniform_(self.bias, -bound, bound)

    def forward(self, x):
        # x: (batch, in_features) or (batch, time, in_features)
        y = x.matmul(self.weight.t())
        if self.bias is not None:
            y = y + self.bias
        return y


class SoCLSTM(nn.Module):
    def __init__(self, input_size=5, hidden_size=94, num_layers=1):
        super().__init__()
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.lstm = nn.LSTM(input_size, hidden_size, num_layers, batch_first=True)
        self.fc = LinearScratch(hidden_size, 1)

    def forward(self, x):
        h0 = torch.zeros(self.num_layers, x.size(0), self.hidden_size, dtype=x.dtype, device=x.device)
        c0 = torch.zeros(self.num_layers, x.size(0), self.hidden_size, dtype=x.dtype, device=x.device)
        
        # Print LSTM weight matrices
        print("\n" + "="*70)
        print("LSTM WEIGHT MATRICES")
        print("="*70)
        print(f"weight_ih_l0 shape: {self.lstm.weight_ih_l0.shape}")
        print(f"weight_hh_l0 shape: {self.lstm.weight_hh_l0.shape}")
        print(f"bias_ih_l0 shape: {self.lstm.bias_ih_l0.shape}")
        print(f"bias_hh_l0 shape: {self.lstm.bias_hh_l0.shape}")
        
        print(f"\nweight_ih_l0 (input to hidden) - first 5x5 block:")
        print(self.lstm.weight_ih_l0[:5, :5])
        
        print(f"\nweight_hh_l0 (hidden to hidden) - first 5x5 block:")
        print(self.lstm.weight_hh_l0[:5, :5])
        
        print(f"\nbias_ih_l0 (first 10 values):")
        print(self.lstm.bias_ih_l0[:10])
        
        print(f"\nbias_hh_l0 (first 10 values):")
        print(self.lstm.bias_hh_l0[:10])
        print("="*70 + "\n")
        
        # Process only first timestep to get gate activations
        x_first = x[:, 0:1, :]  # (batch, 1, features)
        
        # Manual computation to get gate values WITH TILED APPROACH
        W_ih = self.lstm.weight_ih_l0.numpy()  # (376, 5)
        W_hh = self.lstm.weight_hh_l0.numpy()  # (376, 94)
        b_ih = self.lstm.bias_ih_l0.numpy()    # (376,)
        b_hh = self.lstm.bias_hh_l0.numpy()    # (376,)
        
        # Create combined weight matrix (376 x 100)
        bias_combined = b_ih + b_hh  # (376,)
        W_all = np.concatenate([
            W_ih,                          # Columns 0-4 (5 features)
            W_hh,                          # Columns 5-98 (94 hidden)
            bias_combined.reshape(-1, 1)   # Column 99 (bias)
        ], axis=1)
        
        # Get first input
        x_t = x_first.squeeze().numpy()  # (5,)
        h_prev = np.zeros(94)             # (94,)
        
        # Create input vector (100,) = [x0 (5,), h_prev (94,), 1.0]
        input_vector = np.concatenate([x_t, h_prev, [1.0]])
        
        print("\n" + "="*90)
        print("TILED COMPUTATION - 4x4 TILES (25 TILES TOTAL)")
        print("Matrix: 376 rows × 100 columns")
        print("Input Vector: 100 values")
        print("="*90)
        
        print(f"\nInput Vector (100 values):")
        print(f"  x0 [0:4]:   {input_vector[:5].tolist()}")
        print(f"  h_prev [5:98]: all zeros (94 values)")
        print(f"  bias [99]:  {input_vector[99]}")
        
        # Tiled computation parameters
        total_cols = 100
        cols_per_tile = 4
        num_tiles = total_cols // cols_per_tile  # 25 tiles
        
        # We want to show results for first 4 rows (row 0, 1, 2, 3)
        test_rows = [0, 1, 2, 3]
        
        # Initialize accumulators for these 4 rows
        accumulated_output = {row: 0.0 for row in test_rows}
        
        print("\n" + "="*90)
        print("TILE-BY-TILE COMPUTATION FOR FIRST 4 ROWS (Rows 0, 1, 2, 3)")
        print("="*90)
        
        # Process each column tile
        for tile_idx in range(num_tiles):
            start_col = tile_idx * cols_per_tile
            end_col = start_col + cols_per_tile
            
            # Extract column tile for first 4 rows: (4, 4)
            tile_weights = W_all[test_rows, start_col:end_col]  # (4, 4)
            
            # Extract corresponding input values: (4,)
            tile_input = input_vector[start_col:end_col]
            
            # Compute partial result: (4, 4) @ (4,) = (4,)
            partial_output = tile_weights @ tile_input
            
            # Accumulate
            for i, row in enumerate(test_rows):
                accumulated_output[row] += partial_output[i]
            
            # Print tile information
            print(f"\n{'='*90}")
            print(f"TILE {tile_idx}: Columns [{start_col}:{end_col-1}]")
            print("="*90)
            print(f"Tile Input Vector (4 values): {tile_input.tolist()}")
            print(f"\nTile Weight Matrix (4 rows × 4 cols):")
            for i, row in enumerate(test_rows):
                print(f"  Row {row}: {tile_weights[i].tolist()}")
            
            print(f"\nPartial Output from this tile (4 values):")
            for i, row in enumerate(test_rows):
                print(f"  Row {row}: {partial_output[i]:13.10f}")
            
            print(f"\nAccumulated Output after Tile {tile_idx} (4 values):")
            for row in test_rows:
                print(f"  Row {row}: {accumulated_output[row]:13.10f}")
        
        print("\n" + "="*90)
        print("FINAL ACCUMULATED OUTPUT (After all 25 tiles)")
        print("="*90)
        for row in test_rows:
            print(f"Row {row}: {accumulated_output[row]:13.10f}")
        
        # Now compute full 376 output for activation
        full_output = W_all @ input_vector
        
        print("\n" + "="*90)
        print("FULL 376-ROW OUTPUT (Before Activation)")
        print("="*90)
        print(f"First 4 rows: {full_output[:4].tolist()}")
        print(f"All 376 rows computed (showing first 10):")
        for i in range(10):
            gate_name = ""
            if i < 94:
                gate_name = "Input Gate"
            elif i < 188:
                gate_name = "Forget Gate"
            elif i < 282:
                gate_name = "Cell Gate"
            else:
                gate_name = "Output Gate"
            print(f"  Row {i:3d} ({gate_name:12s}): {full_output[i]:13.10f}")
        
        # Split into 4 gates (each 94 values)
        i_gate_raw = full_output[0:94]      # Input gate
        f_gate_raw = full_output[94:188]    # Forget gate
        g_gate_raw = full_output[188:282]   # Cell gate
        o_gate_raw = full_output[282:376]   # Output gate
        
        # Apply activation functions
        i_t = 1.0 / (1.0 + np.exp(-i_gate_raw))  # Sigmoid
        f_t = 1.0 / (1.0 + np.exp(-f_gate_raw))  # Sigmoid
        g_t = np.tanh(g_gate_raw)                 # Tanh
        o_t = 1.0 / (1.0 + np.exp(-o_gate_raw))  # Sigmoid
        
        # Compute cell state and hidden state
        c_prev = np.zeros(94)  # Initial cell state
        c_t = f_t * c_prev + i_t * g_t
        h_t = o_t * np.tanh(c_t)
        
        print("\n" + "="*90)
        print("GATE ACTIVATIONS AFTER SIGMOID/TANH (First 10 values)")
        print("="*90)
        print(f"Input gate (i_t) [sigmoid]:  {i_t[:10].tolist()}")
        print(f"Forget gate (f_t) [sigmoid]: {f_t[:10].tolist()}")
        print(f"Cell gate (g_t) [tanh]:      {g_t[:10].tolist()}")
        print(f"Output gate (o_t) [sigmoid]: {o_t[:10].tolist()}")
        
        print("\n" + "="*90)
        print("HIDDEN STATE (h_t) and CELL STATE (c_t) AFTER TIMESTEP 0")
        print("="*90)
        print(f"h_t (first 10 values): {h_t[:10].tolist()}")
        print(f"c_t (first 10 values): {c_t[:10].tolist()}")
        print("="*90 + "\n")
        
        # Get full output for final prediction
        out, _ = self.lstm(x, (h0, c0))
        out = self.fc(out[:, -1, :])
        return out


def predict_soc_fixed(model_path="soc_lstm_model_1layer.pth"):
    """Predict SOC using fixed 20 timesteps"""
    
    # Load model
    print("\nLoading model...")
    model = SoCLSTM()
    checkpoint = torch.load(model_path, map_location='cpu')
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    print("✓ Model loaded")
    
    # Use fixed scaled features
    features_scaled = FIXED_SCALED_FEATURES.copy()
    
    # Print scaled features
    print("\n" + "="*90)
    print("ALL 20 TIMESTEPS - SCALED FEATURES (Fed to Model)")
    print("="*90)
    print(f"{'Step':>4} | {'Voltage':>10} | {'Current':>10} | {'Temp':>10} | {'Power':>10} | {'Capacity':>10}")
    print("-"*90)
    for i in range(20):
        print(f"{i+1:4d} | {features_scaled[i,0]:10.6f} | {features_scaled[i,1]:10.6f} | {features_scaled[i,2]:10.6f} | {features_scaled[i,3]:10.6f} | {features_scaled[i,4]:10.6f}")
    print("="*90)
    
    # Predict
    print("\nMaking prediction...")
    x = torch.FloatTensor(features_scaled).unsqueeze(0)  # (1, 20, 5)
    
    print(f"Input tensor shape: {x.shape} (batch_size=1, timesteps=20, features=5)")
    
    with torch.no_grad():
        output = model(x)
    
    predicted_soc = output.item()
    
    print("\n" + "="*70)
    print("PREDICTION RESULT")
    print("="*70)
    print(f"Predicted SOC: {predicted_soc:.6f} ({predicted_soc*100:.4f}%)")
    print("="*70)
    
    return predicted_soc


if __name__ == "__main__":
    print("="*70)
    print("SOC PREDICTION WITH FIXED 20 TIMESTEPS")
    print("="*70)
    
    # Predict using fixed data
    predicted_soc = predict_soc_fixed()
    
    print("\n✓ Prediction complete!")