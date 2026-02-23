import torch
import pickle
import numpy as np

# Load model info
try:
    info = torch.load('soc_lstm_model_1layer_info.pth', map_location='cpu')
    print("Model Training Results:")
    print(f"  Test MSE:  {info['results']['test_mse']:.6f}")
    print(f"  Test MAE:  {info['results']['test_mae']:.6f}")
    print(f"  Test RMSE: {info['results']['test_rmse']:.6f}")
    print()
    
    if info['results']['test_mse'] > 0.1:
        print("⚠️ WARNING: High MSE - model didn't train well!")
    else:
        print("✓ Model training looks OK")
except:
    print("❌ soc_lstm_model_1layer_info.pth not found")
    print("Model might not be properly trained")

print("\n" + "="*60)

# Check if scaler exists
try:
    with open('scaler.pkl', 'rb') as f:
        scaler = pickle.load(f)
    print("Scaler Statistics:")
    print(f"  Mean: {scaler.mean_}")
    print(f"  Std:  {scaler.scale_}")
except:
    print("❌ scaler.pkl not found - will be created on first prediction")