import os
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.preprocessing import StandardScaler

FEATURE_COLS = ['Voltage [V]', 'Current [A]', 'Temperature [degC]', 'Power [W]', 'CC_Capacity [Ah]']
DEFAULT_TEMPS = ['25degC', '0degC', 'n10degC', 'n20degC', '10degC', '40degC']

# Fixed-point config: 1 sign + 7 int + 8 frac (MSB is sign, not two's complement)
FIXED_FRAC_BITS = 8
FIXED_INT_BITS = 7
FIXED_TOTAL_BITS = 16
FIXED_MAX = (1 << (FIXED_TOTAL_BITS - 1)) - 1
FIXED_MIN = -FIXED_MAX

def float_to_fixed(val):
    val = np.clip(val, -2**FIXED_INT_BITS, 2**FIXED_INT_BITS - 2**-FIXED_FRAC_BITS)
    fixed = int(np.round(abs(val) * (1 << FIXED_FRAC_BITS)))
    if val < 0:
        fixed = fixed | (1 << (FIXED_TOTAL_BITS - 1))
    return fixed

def fixed_to_float(fixed):
    sign = (fixed >> (FIXED_TOTAL_BITS - 1)) & 1
    val = fixed & ((1 << (FIXED_TOTAL_BITS - 1)) - 1)
    if sign:
        val = -val
    return val / (1 << FIXED_FRAC_BITS)

def fixed_add(a, b):
    a_f = fixed_to_float(a)
    b_f = fixed_to_float(b)
    res = a_f + b_f
    return float_to_fixed(res)

def fixed_mul(a, b):
    a_f = fixed_to_float(a)
    b_f = fixed_to_float(b)
    res = a_f * b_f
    return float_to_fixed(res)

def fixed_sigmoid(x):
    # Approximate sigmoid: 0.5 + 0.25*x - 0.020833*x^3 for |x| < 2
    x_f = fixed_to_float(x)
    s = 0.5 + 0.25 * x_f - 0.020833 * (x_f ** 3)
    return float_to_fixed(np.clip(s, 0, 1))

def fixed_tanh(x):
    # Approximate tanh: x*(27 + x^2)/(27 + 9*x^2) for |x| < 3
    x_f = fixed_to_float(x)
    s = x_f * (27 + x_f ** 2) / (27 + 9 * x_f ** 2)
    return float_to_fixed(np.clip(s, -1, 1))

def tensor_to_fixed(arr):
    return np.vectorize(float_to_fixed)(arr)

def tensor_from_fixed(arr):
    return np.vectorize(fixed_to_float)(arr)

def fixed_matmul(a, b):
    # a: (batch, features), b: (out, features)
    # returns: (batch, out)
    batch, features = a.shape
    out = b.shape[0]
    result = np.zeros((batch, out), dtype=np.int32)
    for i in range(batch):
        for j in range(out):
            acc = float_to_fixed(0.0)
            for k in range(features):
                acc = fixed_add(acc, fixed_mul(a[i, k], b[j, k]))
            result[i, j] = acc
    return result

class LinearScratchFixed:
    def __init__(self, weight, bias=None):
        self.weight = tensor_to_fixed(weight)
        self.bias = tensor_to_fixed(bias) if bias is not None else None

    def forward(self, x):
        # x: (batch, features)
        y = fixed_matmul(x, self.weight)
        if self.bias is not None:
            for i in range(y.shape[0]):
                for j in range(y.shape[1]):
                    y[i, j] = fixed_add(y[i, j], self.bias[j])
        return y

class SoCLSTMFixed:
    def __init__(self, lstm, fc):
        # Convert all weights/biases to fixed-point
        hidden = lstm.hidden_size
        W_ih = lstm.weight_ih_l0.detach().cpu().numpy()
        W_hh = lstm.weight_hh_l0.detach().cpu().numpy()
        b_ih = lstm.bias_ih_l0.detach().cpu().numpy()
        b_hh = lstm.bias_hh_l0.detach().cpu().numpy()
        self.hidden_size = hidden

        self.W_ii = tensor_to_fixed(W_ih[0:hidden, :])
        self.W_if = tensor_to_fixed(W_ih[hidden:2*hidden, :])
        self.W_ig = tensor_to_fixed(W_ih[2*hidden:3*hidden, :])
        self.W_io = tensor_to_fixed(W_ih[3*hidden:4*hidden, :])

        self.W_hi = tensor_to_fixed(W_hh[0:hidden, :])
        self.W_hf = tensor_to_fixed(W_hh[hidden:2*hidden, :])
        self.W_hg = tensor_to_fixed(W_hh[2*hidden:3*hidden, :])
        self.W_ho = tensor_to_fixed(W_hh[3*hidden:4*hidden, :])

        self.b_ii = tensor_to_fixed(b_ih[0:hidden])
        self.b_if = tensor_to_fixed(b_ih[hidden:2*hidden])
        self.b_ig = tensor_to_fixed(b_ih[2*hidden:3*hidden])
        self.b_io = tensor_to_fixed(b_ih[3*hidden:4*hidden])

        self.b_hi = tensor_to_fixed(b_hh[0:hidden])
        self.b_hf = tensor_to_fixed(b_hh[hidden:2*hidden])
        self.b_hg = tensor_to_fixed(b_hh[2*hidden:3*hidden])
        self.b_ho = tensor_to_fixed(b_hh[3*hidden:4*hidden])

        self.fc = LinearScratchFixed(fc.weight.detach().cpu().numpy(), fc.bias.detach().cpu().numpy())

    def forward(self, x):
        # x: (batch, time, features) as numpy array
        batch, time, features = x.shape
        hidden = self.hidden_size
        h = np.zeros((batch, hidden), dtype=np.int32)
        c = np.zeros((batch, hidden), dtype=np.int32)
        for t in range(time):
            x_t = x[:, t, :]  # (batch, features)
            # Gates
            i_t = np.zeros((batch, hidden), dtype=np.int32)
            f_t = np.zeros((batch, hidden), dtype=np.int32)
            g_t = np.zeros((batch, hidden), dtype=np.int32)
            o_t = np.zeros((batch, hidden), dtype=np.int32)
            for b in range(batch):
                i_in = fixed_matmul(x_t[b:b+1], self.W_ii)[0]  # (hidden,)
                i_hid = fixed_matmul(h[b:b+1], self.W_hi)[0]
                i_sum = [fixed_add(fixed_add(i_in[j], self.b_ii[j]), fixed_add(i_hid[j], self.b_hi[j])) for j in range(hidden)]
                i_t[b] = np.array([fixed_sigmoid(val) for val in i_sum])

                f_in = fixed_matmul(x_t[b:b+1], self.W_if)[0]
                f_hid = fixed_matmul(h[b:b+1], self.W_hf)[0]
                f_sum = [fixed_add(fixed_add(f_in[j], self.b_if[j]), fixed_add(f_hid[j], self.b_hf[j])) for j in range(hidden)]
                f_t[b] = np.array([fixed_sigmoid(val) for val in f_sum])

                g_in = fixed_matmul(x_t[b:b+1], self.W_ig)[0]
                g_hid = fixed_matmul(h[b:b+1], self.W_hg)[0]
                g_sum = [fixed_add(fixed_add(g_in[j], self.b_ig[j]), fixed_add(g_hid[j], self.b_hg[j])) for j in range(hidden)]
                g_t[b] = np.array([fixed_tanh(val) for val in g_sum])

                o_in = fixed_matmul(x_t[b:b+1], self.W_io)[0]
                o_hid = fixed_matmul(h[b:b+1], self.W_ho)[0]
                o_sum = [fixed_add(fixed_add(o_in[j], self.b_io[j]), fixed_add(o_hid[j], self.b_ho[j])) for j in range(hidden)]
                o_t[b] = np.array([fixed_sigmoid(val) for val in o_sum])

            # Cell and hidden state
            c = fixed_add(fixed_mul(f_t, c), fixed_mul(i_t, g_t))
            h = fixed_mul(o_t, tensor_to_fixed(np.tanh(tensor_from_fixed(c))))
        # Final output
        out = self.fc.forward(h)
        return tensor_from_fixed(out)

def load_all_data(data_dir, temperatures):
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
    random_file = np.random.choice(all_files)
    print(f"Selected file: {random_file}")
    df = pd.read_csv(random_file)
    df['Power [W]'] = df['Voltage [V]'] * df['Current [A]']
    df['CC_Capacity [Ah]'] = (
        df['Current [A]'] * df['Time [s]'].diff().fillna(0) / 3600
    ).cumsum()
    max_start = len(df) - 20
    if max_start < 0:
        raise ValueError("File has less than 20 rows")
    start_idx = np.random.randint(0, max_start)
    sample = df.iloc[start_idx:start_idx+20]
    print(f"Random sample: rows {start_idx} to {start_idx+19}")
    print(f"Time range: {sample['Time [s]'].iloc[0]:.1f}s to {sample['Time [s]'].iloc[-1]:.1f}s")
    return sample

# ...existing code...
def predict_soc(sample_df, model_path="soc_lstm_model_1layer.pth", data_dir="LG_HG2_processed"):
    print("\nLoading model...")
    checkpoint = torch.load(model_path, map_location='cpu')
    # Create a dummy LSTM and LinearScratch to load weights
    dummy_lstm = nn.LSTM(input_size=5, hidden_size=94, num_layers=1, batch_first=True)
    dummy_fc = LinearScratchFixed(94, 1)
    dummy_lstm.load_state_dict({k: v for k, v in checkpoint['model_state_dict'].items() if 'lstm' in k}, strict=False)
    dummy_fc.load_state_dict({k.replace('fc.', ''): v for k, v in checkpoint['model_state_dict'].items() if 'fc' in k}, strict=False)
    print("✓ Model loaded")
    print("\nFitting scaler...")
    all_data = load_all_data(data_dir, DEFAULT_TEMPS)
    scaler = StandardScaler()
    scaler.fit(all_data[FEATURE_COLS].values)
    print("✓ Scaler fitted")
    features = sample_df[FEATURE_COLS].values
    # ...existing print code...
    features_scaled = scaler.transform(features)
    # ...existing print code...
    print("\nMaking prediction...")
    x = features_scaled.astype(np.float32).reshape(1, 20, 5)
    x_fixed = tensor_to_fixed(x)
    soc_lstm_fixed = SoCLSTMFixed(dummy_lstm, dummy_fc)
    output = soc_lstm_fixed.forward(x_fixed)
    predicted_soc = output[0, 0]
    # ...existing print code...
    actual_soc = sample_df['SOC [-]'].iloc[-1] if 'SOC [-]' in sample_df.columns else None
    # ...existing print code...
    return predicted_soc, actual_soc
# ...existing code...
if __name__ == "__main__":
    data_dir = "LG_HG2_processed"
    print("="*70)
    print("RANDOM SOC PREDICTION WITH FULL FEATURE VALUES")
    print("="*70)
    print("\nGetting random 20 timesteps from dataset...")
    sample = get_random_sample(data_dir, DEFAULT_TEMPS)
    predicted_soc, actual_soc = predict_soc(sample)
    print("\n✓ Prediction complete!")