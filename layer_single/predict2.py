import os
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.preprocessing import StandardScaler


FEATURE_COLS = ['Voltage [V]', 'Current [A]', 'Temperature [degC]', 'Power [W]', 'CC_Capacity [Ah]']
DEFAULT_TEMPS = ['25degC', '0degC', 'n10degC', 'n20degC', '10degC', '40degC']


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
        
        # Compute gates
        i_t = torch.sigmoid(x_t @ W_ii.t() + b_ii + h_prev @ W_hi.t() + b_hi)
        f_t = torch.sigmoid(x_t @ W_if.t() + b_if + h_prev @ W_hf.t() + b_hf)
        g_t = torch.tanh(x_t @ W_ig.t() + b_ig + h_prev @ W_hg.t() + b_hg)
        o_t = torch.sigmoid(x_t @ W_io.t() + b_io + h_prev @ W_ho.t() + b_ho)
        
        # Compute cell and hidden
        c_t = f_t * c_prev + i_t * g_t
        h_t = o_t * torch.tanh(c_t)
        
        print("\n" + "="*70)
        print("GATE ACTIVATIONS AFTER TIMESTEP 0")
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


def load_all_data(data_dir, temperatures):
    """Load all data for scaler fitting"""
    frames = []
    for temp_folder in os.listdir(data_dir):
        if temp_folder in temperatures:
            temp_path = os.path.join(data_dir, temp_folder)
            if not os.path.isdir(temp_path):
                continue
            for file in os.listdir(temp_path):
                if 'Charge' in file or 'Dis' in file:
                    continue
                if file.endswith('.csv'):
                    df = pd.read_csv(os.path.join(temp_path, file))
                    df['Power [W]'] = df['Voltage [V]'] * df['Current [A]']
                    df['CC_Capacity [Ah]'] = (
                        df['Current [A]'] * df['Time [s]'].diff().fillna(0) / 3600
                    ).cumsum()
                    frames.append(df)
    return pd.concat(frames, ignore_index=True)


def get_random_sample(data_dir, temperatures):
    """Get random 20 consecutive timesteps from a random file"""
    # Get all files
    all_files = []
    for temp_folder in os.listdir(data_dir):
        if temp_folder in temperatures:
            temp_path = os.path.join(data_dir, temp_folder)
            if not os.path.isdir(temp_path):
                continue
            for file in os.listdir(temp_path):
                if 'Charge' in file or 'Dis' in file:
                    continue
                if file.endswith('.csv'):
                    all_files.append(os.path.join(temp_path, file))
    
    # Pick random file
    random_file = np.random.choice(all_files)
    print(f"Selected file: {random_file}")
    
    # Load file
    df = pd.read_csv(random_file)
    df['Power [W]'] = df['Voltage [V]'] * df['Current [A]']
    df['CC_Capacity [Ah]'] = (
        df['Current [A]'] * df['Time [s]'].diff().fillna(0) / 3600
    ).cumsum()
    
    # Get random starting point
    max_start = len(df) - 20
    if max_start < 0:
        raise ValueError("File has less than 20 rows")
    
    start_idx = np.random.randint(0, max_start)
    sample = df.iloc[start_idx:start_idx+20]
    
    print(f"Random sample: rows {start_idx} to {start_idx+19}")
    print(f"Time range: {sample['Time [s]'].iloc[0]:.1f}s to {sample['Time [s]'].iloc[-1]:.1f}s")
    
    return sample


def predict_soc(sample_df, model_path="soc_lstm_model_1layer.pth", data_dir="LG_HG2_processed"):
    """Predict SOC from 20 timesteps"""
    
    # Load model
    print("\nLoading model...")
    model = SoCLSTM()
    checkpoint = torch.load(model_path, map_location='cpu')
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    print("✓ Model loaded")
    
    # Fit scaler on all training data
    print("\nFitting scaler...")
    all_data = load_all_data(data_dir, DEFAULT_TEMPS)
    scaler = StandardScaler()
    scaler.fit(all_data[FEATURE_COLS].values)
    print("✓ Scaler fitted")
    
    # Extract features
    features = sample_df[FEATURE_COLS].values
    
    # Print all 20 timesteps
    print("\n" + "="*90)
    print("ALL 20 TIMESTEPS - RAW FEATURES")
    print("="*90)
    print(f"{'Step':>4} | {'Voltage':>8} | {'Current':>8} | {'Temp':>8} | {'Power':>8} | {'Capacity':>10}")
    print("-"*90)
    for i in range(20):
        print(f"{i+1:4d} | {features[i,0]:8.5f} | {features[i,1]:8.5f} | {features[i,2]:8.4f} | {features[i,3]:8.5f} | {features[i,4]:10.7f}")
    print("="*90)
    
    # Scale features
    features_scaled = scaler.transform(features)
    
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
    
    # Get actual SOC if available
    actual_soc = sample_df['SOC [-]'].iloc[-1] if 'SOC [-]' in sample_df.columns else None
    
    print("\n" + "="*70)
    print("PREDICTION RESULT")
    print("="*70)
    print(f"Predicted SOC: {predicted_soc:.6f} ({predicted_soc*100:.4f}%)")
    
    if actual_soc is not None:
        error = abs(predicted_soc - actual_soc)
        print(f"Actual SOC:    {actual_soc:.6f} ({actual_soc*100:.4f}%)")
        print(f"Error:         {error:.6f} ({error*100:.4f}%)")
        print(f"Relative Error: {(error/actual_soc)*100:.2f}%")
    
    print("="*70)
    
    return predicted_soc, actual_soc


if __name__ == "__main__":
    data_dir = "LG_HG2_processed"
    
    print("="*70)
    print("RANDOM SOC PREDICTION WITH FULL FEATURE VALUES")
    print("="*70)
    print("\nGetting random 20 timesteps from dataset...")
    
    # Get random sample
    sample = get_random_sample(data_dir, DEFAULT_TEMPS)
    
    # Predict
    predicted_soc, actual_soc = predict_soc(sample)
    
    print("\n✓ Prediction complete!")