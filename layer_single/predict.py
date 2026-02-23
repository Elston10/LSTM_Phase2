import os
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
import matplotlib.pyplot as plt


FEATURE_COLS = ['Voltage [V]', 'Current [A]', 'Temperature [degC]', 'Power [W]', 'CC_Capacity [Ah]']
LABEL_COL = 'SOC [-]'
DEFAULT_TEMPS = ['25degC', '0degC', 'n10degC', 'n20degC', '10degC', '40degC']


def load_data(directory: str, temperatures):
    if not os.path.isdir(directory):
        raise FileNotFoundError(f"Data directory not found: {directory}")

    frames = []
    for temp_folder in os.listdir(directory):
        if temp_folder in temperatures:
            temp_path = os.path.join(directory, temp_folder)
            if not os.path.isdir(temp_path):
                continue
            for file in os.listdir(temp_path):
                if 'Charge' in file or 'Dis' in file:
                    continue
                if file.endswith('.csv'):
                    df = pd.read_csv(os.path.join(temp_path, file))
                    df['SourceFile'] = file
                    df['Power [W]'] = df['Voltage [V]'] * df['Current [A]']
                    df['CC_Capacity [Ah]'] = (
                        df['Current [A]'] * df['Time [s]'].diff().fillna(0) / 3600
                    ).cumsum()
                    frames.append(df)
    if not frames:
        raise RuntimeError(f"No CSV files found for temperatures {temperatures} in {directory}.")
    return pd.concat(frames, ignore_index=True)


class BatteryDatasetLSTM(Dataset):
    def __init__(self, data_tensor, labels_tensor, sequence_length=20, filenames=None, times=None):
        self.sequence_length = sequence_length
        self.features = data_tensor
        self.labels = labels_tensor
        self.filenames = filenames
        self.times = times

    def __len__(self):
        return max(0, len(self.features) - self.sequence_length)

    def __getitem__(self, idx):
        idx_end = idx + self.sequence_length
        sequence = self.features[idx:idx_end]
        label = self.labels[idx_end - 1]
        filename = self.filenames[idx_end - 1] if self.filenames is not None else ""
        time = self.times[idx_end - 1] if self.times is not None else 0.0
        return sequence, label, filename, time


class SoCLSTM(nn.Module):
    def __init__(self, input_size: int, hidden_size: int, num_layers: int):
        super().__init__()
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.lstm = nn.LSTM(input_size, hidden_size, num_layers, batch_first=True)
        self.fc = nn.Linear(hidden_size, 1)

    def forward(self, x):
        h0 = torch.zeros(self.num_layers, x.size(0), self.hidden_size, dtype=x.dtype, device=x.device)
        c0 = torch.zeros(self.num_layers, x.size(0), self.hidden_size, dtype=x.dtype, device=x.device)
        out, _ = self.lstm(x, (h0, c0))
    
    # Print first timestep hidden state (after processing timestep 0)
        first_timestep_ht = out[:, 0, :]  # shape: (batch_size, hidden_size)
        print("\n" + "="*70)
        print("FIRST TIMESTEP HIDDEN STATE (h_t after timestep 0)")
        print("="*70)
        print(f"Shape: {first_timestep_ht.shape}")
        print(f"First sample h_t:\n{first_timestep_ht[0]}")
        print(f"Statistics - Mean: {first_timestep_ht[0].mean():.6f}, Std: {first_timestep_ht[0].std():.6f}")
        print("="*70 + "\n")
    
        out = self.fc(out[:, -1, :])
        return out


@torch.no_grad()
def evaluate_model(model, loader, device):
    model.eval()
    preds, labels = [], []
    for x, y, _, _ in loader:
        x = x.to(device)
        out = model(x)
        preds.extend(out.cpu().view(-1).tolist())
        labels.extend(y.cpu().view(-1).tolist())
    
    preds = np.array(preds)
    labels = np.array(labels)
    
    mse = mean_squared_error(labels, preds)
    mae = mean_absolute_error(labels, preds)
    rmse = np.sqrt(mse)
    r2 = r2_score(labels, labels)
    
    return preds, labels, mse, mae, rmse, r2


def build_loaders(df: pd.DataFrame, sequence_length: int, batch_size: int, device):
    scaler = StandardScaler()
    df = df.copy()
    df[FEATURE_COLS] = scaler.fit_transform(df[FEATURE_COLS])

    unique_files = np.array(list(set(df['SourceFile'])))
    train_files, temp_files = train_test_split(unique_files, test_size=0.2, random_state=24)
    val_files, test_files = train_test_split(temp_files, test_size=0.5, random_state=24)

    def filter_by_files(d, names):
        return d[d['SourceFile'].isin(names)]

    test_df = filter_by_files(df, test_files)

    def to_dataset(dframe):
        feats = torch.tensor(dframe[FEATURE_COLS].values, dtype=torch.float32, device=device)
        labs = torch.tensor(dframe[LABEL_COL].values, dtype=torch.float32, device=device)
        fn = dframe['SourceFile'].values
        ts = dframe['Time [s]'].values
        return BatteryDatasetLSTM(feats, labs, sequence_length, fn, ts)

    test_ds = to_dataset(test_df)
    test_loader = DataLoader(test_ds, batch_size=batch_size, shuffle=False)
    
    print(f"Test set: {len(test_ds)} samples from {len(test_files)} files")
    
    return test_loader


def plot_results(labels, preds, mse, mae, rmse, r2, save_path='evaluation_results.png'):
    """Plot prediction scatter and error distribution"""
    fig, axes = plt.subplots(1, 2, figsize=(15, 6))
    
    # Plot 1: Scatter plot
    axes[0].scatter(labels, preds, alpha=0.5, s=20)
    axes[0].plot([0, 1], [0, 1], 'r-', linewidth=2, label='Perfect Prediction')
    axes[0].set_xlabel('True SOC', fontsize=12)
    axes[0].set_ylabel('Predicted SOC', fontsize=12)
    axes[0].set_xlim([0, 1])
    axes[0].set_ylim([0, 1])
    axes[0].set_aspect('equal')
    axes[0].grid(True, alpha=0.3)
    axes[0].legend()
    axes[0].set_title(f'Predicted vs True SOC\nMSE={mse:.6f}, MAE={mae:.6f}', fontsize=12)
    
    # Plot 2: Error distribution
    errors = preds - labels
    axes[1].hist(errors, bins=50, edgecolor='black', alpha=0.7)
    axes[1].axvline(x=0, color='r', linestyle='--', linewidth=2, label='Zero Error')
    axes[1].axvline(x=np.mean(errors), color='g', linestyle='--', linewidth=2, label=f'Mean Error: {np.mean(errors):.6f}')
    axes[1].set_xlabel('Prediction Error (Predicted - True)', fontsize=12)
    axes[1].set_ylabel('Frequency', fontsize=12)
    axes[1].set_title('Prediction Error Distribution', fontsize=12)
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    print(f"✓ Plot saved to: {save_path}")
    plt.show()


def main():
    print("="*70)
    print("EVALUATING TRAINED 1-LAYER LSTM MODEL")
    print("="*70)
    
    # Configuration
    model_path = "soc_lstm_model_1layer.pth"
    data_dir = "LG_HG2_processed"
    seq_len = 20
    batch_size = 128
    hidden_size = 94
    num_layers = 1
    
    device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
    print(f"Device: {device}")
    print(f"Model: {num_layers} layer LSTM, hidden_size={hidden_size}\n")
    
    # Load data
    print(f"Loading data from: {data_dir}")
    data = load_data(data_dir, DEFAULT_TEMPS)
    print(f"Total samples: {len(data)}\n")
    
    # Build test loader
    test_loader = build_loaders(data, seq_len, batch_size, device)
    
    # Load model
    print(f"\nLoading model from: {model_path}")
    model = SoCLSTM(input_size=len(FEATURE_COLS), hidden_size=hidden_size, num_layers=num_layers)
    model = model.to(device).type(torch.float32)
    
    checkpoint = torch.load(model_path, map_location=device)
    model.load_state_dict(checkpoint['model_state_dict'])
    print("✓ Model loaded successfully\n")
    
    # Evaluate
    print("Evaluating on test set...")
    preds, labels, mse, mae, rmse, r2 = evaluate_model(model, test_loader, device)
    
    # Print results
    print("\n" + "="*70)
    print("EVALUATION RESULTS")
    print("="*70)
    print(f"Number of test samples: {len(labels)}")
    print(f"\nMetrics:")
    print(f"  Mean Squared Error (MSE):  {mse:.8f}")
    print(f"  Mean Absolute Error (MAE): {mae:.8f}")
    print(f"  Root Mean Squared Error:   {rmse:.8f}")
    print(f"  R² Score:                  {r2:.8f}")
    print(f"\nPercentage Metrics:")
    print(f"  MAE (%):  {mae*100:.4f}%")
    print(f"  RMSE (%): {rmse*100:.4f}%")
    print(f"\nError Statistics:")
    errors = preds - labels
    print(f"  Mean Error:  {np.mean(errors):.8f}")
    print(f"  Std Error:   {np.std(errors):.8f}")
    print(f"  Max Error:   {np.max(np.abs(errors)):.8f}")
    print(f"  Min Error:   {np.min(np.abs(errors)):.8f}")
    print("="*70)
    
    # Plot
    plot_results(labels, preds, mse, mae, rmse, r2)
    
    # Save predictions
    results_df = pd.DataFrame({
        'True_SOC': labels,
        'Predicted_SOC': preds,
        'Error': preds - labels,
        'Absolute_Error': np.abs(preds - labels)
    })
    results_df.to_csv('test_predictions.csv', index=False)
    print(f"\n✓ Predictions saved to: test_predictions.csv")


if __name__ == "__main__":
    main()