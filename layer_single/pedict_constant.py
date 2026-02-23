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
        nn.init.kaiming_uniform_(self.weight, a=np.sqrt(5))
        if self.bias is not None:
            fan_in = in_features
            bound = 1 / np.sqrt(fan_in)
            nn.init.uniform_(self.bias, -bound, bound)

    def forward(self, x):
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
        
        # Manual computation to get gate values
        W_ih = self.lstm.weight_ih_l0  # (4*hidden, input)
        W_hh = self.lstm.weight_hh_l0  # (4*hidden, hidden)
        b_ih = self.lstm.bias_ih_l0    # (4*hidden,)
        b_hh = self.lstm.bias_hh_l0    # (4*hidden,)
        
        # Split into gates: input, forget, cell, output
        hidden = self.hidden_size
        W_ii, W_if, W_ig, W_io = W_ih.split(hidden, 0)
        W_hi, W_hf, W_hg, W_ho = W_hh.split(hidden, 0)
        b_ii, b_if, b_ig, b_io = b_ih.split(hidden, 0)
        b_hi, b_hf, b_hg, b_ho = b_hh.split(hidden, 0)
        
        # Get first input
        x_t = x_first.squeeze(1)  # (batch, features)
        h_prev = h0.squeeze(0)     # (batch, hidden)
        c_prev = c0.squeeze(0)     # (batch, hidden)
        
        # ====================================================================
        # DETAILED TILE COMPUTATION (First 25 tiles for rows 0-3)
        # ====================================================================
        print("\n" + "="*100)
        print("DETAILED TILE-BY-TILE COMPUTATION FOR TIMESTEP 0 (First 25 tiles, Rows 0-3)")
        print("="*100)
        print("\nInput x_t (5 features):", x_t[0].tolist())
        print("\n" + "-"*100)
        
        # For each of the 4 gates
        gate_names = ['Input Gate (i)', 'Forget Gate (f)', 'Cell Gate (g)', 'Output Gate (o)']
        W_gates = [W_ii, W_if, W_ig, W_io]
        b_i_gates = [b_ii, b_if, b_ig, b_io]
        b_h_gates = [b_hi, b_hf, b_hg, b_ho]
        
        for gate_idx, (gate_name, W_i, b_i, b_h) in enumerate(zip(gate_names, W_gates, b_i_gates, b_h_gates)):
            print(f"\n{'='*100}")
            print(f"GATE {gate_idx}: {gate_name}")
            print(f"{'='*100}")
            
            # Compute input contribution: x_t @ W_i.t()
            input_contrib = x_t @ W_i.t()  # (batch, hidden)
            
            # Compute hidden contribution: h_prev @ W_h.t() (all zeros for timestep 0)
            # hidden_contrib = h_prev @ W_h.t()  # Not needed for timestep 0
            
            # Show first 25 tiles (neurons 0-24) for rows 0-3
            print(f"\nShowing computation for neurons 0-24:")
            print(f"{'Neuron':>6} | {'W[0]':>12} | {'W[1]':>12} | {'W[2]':>12} | {'W[3]':>12} | {'W[4]':>12} | {'x*W':>12} | {'b_ih':>12} | {'b_hh':>12} | {'Total':>12}")
            print("-"*150)
            
            for neuron in range(min(25, hidden)):
                # Get weights for this neuron
                w = W_i[neuron, :]  # (5,)
                
                # Compute weighted sum
                weighted_sum = (x_t[0] * w).sum().item()
                
                # Add biases
                bias_ih = b_i[neuron].item()
                bias_hh = b_h[neuron].item()
                total = weighted_sum + bias_ih + bias_hh
                
                print(f"{neuron:6d} | {w[0].item():12.6f} | {w[1].item():12.6f} | {w[2].item():12.6f} | {w[3].item():12.6f} | {w[4].item():12.6f} | {weighted_sum:12.6f} | {bias_ih:12.6f} | {bias_hh:12.6f} | {total:12.6f}")
        
        print("\n" + "="*100)
        
        # Compute gates
        i_t = torch.sigmoid(x_t @ W_ii.t() + b_ii + h_prev @ W_hi.t() + b_hi)
        f_t = torch.sigmoid(x_t @ W_if.t() + b_if + h_prev @ W_hf.t() + b_hf)
        g_t = torch.tanh(x_t @ W_ig.t() + b_ig + h_prev @ W_hg.t() + b_hg)
        o_t = torch.sigmoid(x_t @ W_io.t() + b_io + h_prev @ W_ho.t() + b_ho)
        
        # Compute cell and hidden
        c_t = f_t * c_prev + i_t * g_t
        h_t = o_t * torch.tanh(c_t)
        
        print("\n" + "="*100)
        print("GATE ACTIVATIONS AFTER TIMESTEP 0 (After sigmoid/tanh)")
        print("="*100)
        print(f"\nShowing first 25 neurons (0-24):")
        print(f"{'Neuron':>6} | {'i_t':>12} | {'f_t':>12} | {'g_t':>12} | {'o_t':>12}")
        print("-"*70)
        for neuron in range(min(25, hidden)):
            print(f"{neuron:6d} | {i_t[0, neuron].item():12.6f} | {f_t[0, neuron].item():12.6f} | {g_t[0, neuron].item():12.6f} | {o_t[0, neuron].item():12.6f}")
        print("="*100 + "\n")
        
        print("\n" + "="*100)
        print("CELL STATE (c_t) and HIDDEN STATE (h_t) COMPUTATION")
        print("="*100)
        print(f"\nFormula: c_t = f_t * c_prev + i_t * g_t")
        print(f"Formula: h_t = o_t * tanh(c_t)")
        print(f"\nNote: c_prev and h_prev are all zeros for timestep 0")
        print(f"\nShowing first 25 neurons (0-24):")
        print(f"{'Neuron':>6} | {'i_t*g_t':>12} | {'c_t':>12} | {'tanh(c_t)':>12} | {'h_t':>12}")
        print("-"*70)
        for neuron in range(min(25, hidden)):
            i_g = (i_t[0, neuron] * g_t[0, neuron]).item()
            c_val = c_t[0, neuron].item()
            tanh_c = torch.tanh(c_t[0, neuron]).item()
            h_val = h_t[0, neuron].item()
            print(f"{neuron:6d} | {i_g:12.6f} | {c_val:12.6f} | {tanh_c:12.6f} | {h_val:12.6f}")
        print("="*100 + "\n")
        
        print("\n" + "="*70)
        print("FINAL GATE ACTIVATIONS SUMMARY")
        print("="*70)
        print(f"Input gate (i_t) - first 10 values: {i_t[0, :10].tolist()}")
        print(f"Forget gate (f_t) - first 10 values: {f_t[0, :10].tolist()}")
        print(f"Cell gate (g_t) - first 10 values: {g_t[0, :10].tolist()}")
        print(f"Output gate (o_t) - first 10 values: {o_t[0, :10].tolist()}")
        print("="*70 + "\n")
        
        print("\n" + "="*70)
        print("HIDDEN STATE (h_t) and CELL STATE (c_t) AFTER TIMESTEP 0")
        print("="*70)
        print(f"h_t shape: {h_t.shape}")
        print(f"c_t shape: {c_t.shape}")
        print(f"\nh_t (first 10 values): {h_t[0, :10].tolist()}")
        print(f"c_t (first 10 values): {c_t[0, :10].tolist()}")
        print("="*70 + "\n")
        
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
    print("SOC PREDICTION WITH DETAILED TILE COMPUTATION")
    print("="*70)
    
    # Predict using fixed data
    predicted_soc = predict_soc_fixed()
    
    print("\n✓ Prediction complete!")