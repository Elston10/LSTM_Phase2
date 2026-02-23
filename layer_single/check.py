import torch
import numpy as np

def create_376x100_matrix(pth_file='soc_lstm_model_1layer.pth'):
    """
    Create 376x100 matrix from LSTM .pth file
    
    Matrix structure:
    - Columns [0:5]:   W_ih (input weights, 5 features)
    - Columns [5:99]:  W_hh (hidden weights, 94 units)  
    - Column [99]:     bias (combined b_ih + b_hh)
    
    Row structure:
    - Rows [0:94]:     Input gate
    - Rows [94:188]:   Forget gate
    - Rows [188:282]:  Cell gate
    - Rows [282:376]:  Output gate
    """
    
    print("="*80)
    print(" CREATING 376x100 MATRIX FROM LSTM MODEL")
    print("="*80)
    
    # Load model
    print(f"\nLoading: {pth_file}")
    model_data = torch.load(pth_file, map_location='cpu')
    
    # Get state dict
    if isinstance(model_data, dict):
        if 'model_state_dict' in model_data:
            state_dict = model_data['model_state_dict']
        elif 'state_dict' in model_data:
            state_dict = model_data['state_dict']
        else:
            state_dict = model_data
    else:
        state_dict = model_data.state_dict() if hasattr(model_data, 'state_dict') else model_data
    
    # Extract LSTM components
    W_ih = state_dict['lstm.weight_ih_l0'].cpu().numpy()  # (376, 5)
    W_hh = state_dict['lstm.weight_hh_l0'].cpu().numpy()  # (376, 94)
    b_ih = state_dict['lstm.bias_ih_l0'].cpu().numpy()    # (376,)
    b_hh = state_dict['lstm.bias_hh_l0'].cpu().numpy()    # (376,)
    
    print(f"\n  W_ih shape: {W_ih.shape}")
    print(f"  W_hh shape: {W_hh.shape}")
    print(f"  b_ih shape: {b_ih.shape}")
    print(f"  b_hh shape: {b_hh.shape}")
    
    # Combine bias
    bias_combined = b_ih + b_hh  # (376,)
    
    # Create 376x100 matrix
    matrix = np.concatenate([
        W_ih,                          # Columns 0-4
        W_hh,                          # Columns 5-98
        bias_combined.reshape(-1, 1)   # Column 99
    ], axis=1)
    
    print(f"\n✓ Created matrix with shape: {matrix.shape}")
    
    return matrix


def compute_timestep0_tiled(W_all, x0, h_prev=None):
    """
    Compute LSTM gates using COLUMN-WISE TILED computation
    
    100 columns divided into 25 tiles (4 columns per tile)
    Each tile processes all 376 rows
    Results are accumulated across tiles
    
    Args:
        W_all: (376, 100) weight matrix
        x0: (5,) input features for timestep 0
        h_prev: (94,) previous hidden state (default: zeros)
    
    Returns:
        Dictionary with all gate activations and states
    """
    
    print("\n" + "="*80)
    print(" COMPUTING TIMESTEP 0 WITH COLUMN-WISE TILED APPROACH")
    print("="*80)
    
    # Initialize h_prev to zeros if not provided
    if h_prev is None:
        h_prev = np.zeros(94)
    
    # Create input vector (100,) = [x0 (5,), h_prev (94,), 1.0]
    input_vector = np.concatenate([x0, h_prev, [1.0]])
    
    print(f"\nInput Vector (100×1):")
    print(f"  x0 (features):       {x0.tolist()}")
    print(f"  h_prev (hidden):     all zeros (94 values)")
    print(f"  bias:                1.0")
    
    # Tiled computation parameters
    total_cols = 100
    cols_per_tile = 4
    num_tiles = total_cols // cols_per_tile  # 25 tiles
    total_rows = 376
    
    print(f"\nTiling Configuration:")
    print(f"  Matrix: {total_rows} rows × {total_cols} columns")
    print(f"  Column tiles: {num_tiles} tiles ({cols_per_tile} columns per tile)")
    print(f"  Each tile computes: ({total_rows}×{cols_per_tile}) @ ({cols_per_tile}×1) = ({total_rows}×1)")
    
    # Accumulator for final results
    accumulated_output = np.zeros(total_rows)
    
    print("\n" + "="*80)
    print("TILE-BY-TILE COMPUTATION (COLUMN-WISE TILING)")
    print(f"{num_tiles} Column Tiles × {cols_per_tile} Columns per Tile")
    print("="*80)
    
    # Process each column tile
    for tile_idx in range(num_tiles):
        start_col = tile_idx * cols_per_tile
        end_col = start_col + cols_per_tile
        
        # Extract column tile: (376, 4)
        tile_weights = W_all[:, start_col:end_col]
        
        # Extract corresponding input values: (4,)
        tile_input = input_vector[start_col:end_col]
        
        # Compute partial result: (376, 4) @ (4, 1) = (376, 1)
        partial_output = tile_weights @ tile_input
        
        # Accumulate
        accumulated_output += partial_output
        
        # Print tile information
        print(f"\n{'='*80}")
        print(f"TILE {tile_idx}: Columns [{start_col}:{end_col-1}]")
        print("="*80)
        print(f"Tile Weight Matrix: ({total_rows}, {cols_per_tile})")
        print(f"Tile Input Vector:  {tile_input.tolist()}")
        print(f"\nPartial Output (first 10 of 376 rows):")
        for i in range(10):
            print(f"  Row {i:3d}: {partial_output[i]:13.10f}")
        
        print(f"\nAccumulated Output After Tile {tile_idx} (first 10 of 376 rows):")
        for i in range(10):
            print(f"  Row {i:3d}: {accumulated_output[i]:13.10f}")
    
    print("\n" + "="*80)
    print("FINAL ACCUMULATED OUTPUT (All 376 Rows)")
    print("="*80)
    
    # Print all 376 final accumulated values
    for i in range(total_rows):
        gate_name = ""
        if i < 94:
            gate_name = "Input Gate"
        elif i < 188:
            gate_name = "Forget Gate"
        elif i < 282:
            gate_name = "Cell Gate"
        else:
            gate_name = "Output Gate"
        
        print(f"Row {i:3d} ({gate_name:12s}): {accumulated_output[i]:13.10f}")
    
    print("\n" + "="*80)
    print("APPLYING ACTIVATION FUNCTIONS")
    print("="*80)
    
    # Split into 4 gates (each 94 values)
    i_gate_raw = accumulated_output[0:94]      # Input gate
    f_gate_raw = accumulated_output[94:188]    # Forget gate
    g_gate_raw = accumulated_output[188:282]   # Cell gate
    o_gate_raw = accumulated_output[282:376]   # Output gate
    
    print(f"\nGate splits:")
    print(f"  Input gate:  Rows [0:93]     - {len(i_gate_raw)} values")
    print(f"  Forget gate: Rows [94:187]   - {len(f_gate_raw)} values")
    print(f"  Cell gate:   Rows [188:281]  - {len(g_gate_raw)} values")
    print(f"  Output gate: Rows [282:375]  - {len(o_gate_raw)} values")
    
    # Apply activation functions
    i_t = 1.0 / (1.0 + np.exp(-i_gate_raw))  # Sigmoid
    f_t = 1.0 / (1.0 + np.exp(-f_gate_raw))  # Sigmoid
    g_t = np.tanh(g_gate_raw)                 # Tanh
    o_t = 1.0 / (1.0 + np.exp(-o_gate_raw))  # Sigmoid
    
    # Compute cell state and hidden state
    c_prev = np.zeros(94)  # Initial cell state
    c_t = f_t * c_prev + i_t * g_t
    h_t = o_t * np.tanh(c_t)
    
    # Print activated gates
    print("\n" + "="*80)
    print(" GATE ACTIVATIONS AFTER SIGMOID/TANH (First 10 values)")
    print("="*80)
    print(f"\nInput gate (i_t) [sigmoid]:  {i_t[:10].tolist()}")
    print(f"Forget gate (f_t) [sigmoid]: {f_t[:10].tolist()}")
    print(f"Cell gate (g_t) [tanh]:      {g_t[:10].tolist()}")
    print(f"Output gate (o_t) [sigmoid]: {o_t[:10].tolist()}")
    
    print("\n" + "="*80)
    print(" FINAL STATES (First 10 values)")
    print("="*80)
    print(f"\nCell state (c_t):   {c_t[:10].tolist()}")
    print(f"Hidden state (h_t): {h_t[:10].tolist()}")
    
    print("\n" + "="*80)
    print(" STATISTICS")
    print("="*80)
    print(f"\nRaw outputs (before activation):")
    print(f"  Min:  {accumulated_output.min():.10f}")
    print(f"  Max:  {accumulated_output.max():.10f}")
    print(f"  Mean: {accumulated_output.mean():.10f}")
    
    print(f"\nActivated gates:")
    print(f"  Input gate  - min: {i_t.min():.10f}, max: {i_t.max():.10f}, mean: {i_t.mean():.10f}")
    print(f"  Forget gate - min: {f_t.min():.10f}, max: {f_t.max():.10f}, mean: {f_t.mean():.10f}")
    print(f"  Cell gate   - min: {g_t.min():.10f}, max: {g_t.max():.10f}, mean: {g_t.mean():.10f}")
    print(f"  Output gate - min: {o_t.min():.10f}, max: {o_t.max():.10f}, mean: {o_t.mean():.10f}")
    
    print(f"\nFinal states:")
    print(f"  Cell state   - min: {c_t.min():.10f}, max: {c_t.max():.10f}, mean: {c_t.mean():.10f}")
    print(f"  Hidden state - min: {h_t.min():.10f}, max: {h_t.max():.10f}, mean: {h_t.mean():.10f}")
    
    return {
        'input_gate': i_t,
        'forget_gate': f_t,
        'cell_gate': g_t,
        'output_gate': o_t,
        'cell_state': c_t,
        'hidden_state': h_t,
        'input_vector': input_vector,
        'raw_outputs': accumulated_output,
        'i_gate_raw': i_gate_raw,
        'f_gate_raw': f_gate_raw,
        'g_gate_raw': g_gate_raw,
        'o_gate_raw': o_gate_raw
    }


def save_tile_results(W_all, input_vector, prefix="timestep0"):
    """
    Save detailed tile-by-tile computation results
    
    Args:
        W_all: (376, 100) weight matrix
        input_vector: (100,) input vector
        prefix: File name prefix
    """
    
    total_cols = 100
    cols_per_tile = 4
    num_tiles = total_cols // cols_per_tile
    total_rows = 376
    
    accumulated_output = np.zeros(total_rows)
    
    # Save to file
    with open(f"{prefix}_column_tile_details.txt", 'w') as f:
        f.write("="*80 + "\n")
        f.write("COLUMN-WISE TILED COMPUTATION DETAILS\n")
        f.write(f"25 Column Tiles × 4 Columns per Tile = 100 Total Columns\n")
        f.write(f"Each tile processes all 376 rows\n")
        f.write("="*80 + "\n\n")
        
        for tile_idx in range(num_tiles):
            start_col = tile_idx * cols_per_tile
            end_col = start_col + cols_per_tile
            
            # Extract column tile
            tile_weights = W_all[:, start_col:end_col]
            tile_input = input_vector[start_col:end_col]
            
            # Compute partial result
            partial_output = tile_weights @ tile_input
            accumulated_output += partial_output
            
            f.write("="*80 + "\n")
            f.write(f"TILE {tile_idx}: Columns [{start_col}:{end_col-1}]\n")
            f.write("="*80 + "\n")
            f.write(f"Tile Input Vector (4 values): {tile_input.tolist()}\n")
            f.write(f"Tile Weight Matrix: ({total_rows}, {cols_per_tile})\n\n")
            
            f.write("Partial Output from this tile (376 rows):\n")
            for i in range(total_rows):
                f.write(f"  Row {i:3d}: {partial_output[i]:13.10f}\n")
            
            f.write(f"\nAccumulated Output after Tile {tile_idx} (376 rows):\n")
            for i in range(total_rows):
                f.write(f"  Row {i:3d}: {accumulated_output[i]:13.10f}\n")
            
            f.write("\n")
    
    print(f"✓ Saved column tile details to: {prefix}_column_tile_details.txt")


def save_all_results(results, W_all, prefix="timestep0"):
    """
    Save all computation results to files
    """
    
    print("\n" + "="*80)
    print(" SAVING ALL RESULTS TO FILES")
    print("="*80)
    
    # 1. Save weight matrix
    np.savetxt(f"{prefix}_W_all_376x100.txt", W_all, fmt='%.10f', delimiter=',')
    print(f"✓ Saved weight matrix (376×100) to: {prefix}_W_all_376x100.txt")
    
    # 2. Save input vector
    np.savetxt(f"{prefix}_input_vector_100x1.txt", results['input_vector'], fmt='%.10f')
    print(f"✓ Saved input vector (100,) to: {prefix}_input_vector_100x1.txt")
    
    # 3. Save raw outputs (before activation)
    np.savetxt(f"{prefix}_raw_outputs_376x1.txt", results['raw_outputs'], fmt='%.10f')
    print(f"✓ Saved raw outputs (376,) to: {prefix}_raw_outputs_376x1.txt")
    
    # 4. Save raw gate outputs (before activation)
    raw_gates = np.column_stack([
        results['i_gate_raw'],
        results['f_gate_raw'],
        results['g_gate_raw'],
        results['o_gate_raw']
    ])
    np.savetxt(f"{prefix}_raw_gates_94x4.txt", raw_gates, fmt='%.10f', delimiter=',',
               header='i_gate_raw,f_gate_raw,g_gate_raw,o_gate_raw', comments='')
    print(f"✓ Saved raw gates (94×4) to: {prefix}_raw_gates_94x4.txt")
    
    # 5. Save activated gates
    activated_gates = np.column_stack([
        results['input_gate'],
        results['forget_gate'],
        results['cell_gate'],
        results['output_gate']
    ])
    np.savetxt(f"{prefix}_gates_activated_94x4.txt", activated_gates, fmt='%.10f', delimiter=',',
               header='input_gate,forget_gate,cell_gate,output_gate', comments='')
    print(f"✓ Saved activated gates (94×4) to: {prefix}_gates_activated_94x4.txt")
    
    # 6. Save hidden state
    np.savetxt(f"{prefix}_hidden_state_94x1.txt", results['hidden_state'], fmt='%.10f')
    print(f"✓ Saved hidden state (94,) to: {prefix}_hidden_state_94x1.txt")
    
    # 7. Save cell state
    np.savetxt(f"{prefix}_cell_state_94x1.txt", results['cell_state'], fmt='%.10f')
    print(f"✓ Saved cell state (94,) to: {prefix}_cell_state_94x1.txt")
    
    # 8. Save column tile details
    save_tile_results(W_all, results['input_vector'], prefix)
    
    print("\n" + "="*80)
    print(" ALL FILES SAVED SUCCESSFULLY!")
    print("="*80)


if __name__ == "__main__":
    
    print("\n" + "="*80)
    print(" LSTM TIMESTEP 0 - COLUMN-WISE TILED COMPUTATION")
    print("="*80)
    
    # Step 1: Create 376x100 weight matrix
    pth_file = "soc_lstm_model_1layer.pth"
    W_all = create_376x100_matrix(pth_file)
    
    # Step 2: Define timestep 0 input
    x0 = np.array([-0.116864, 0.396518, 1.655884, 0.388196, -0.634126])
    
    print("\n" + "="*80)
    print(" INPUT DATA")
    print("="*80)
    print(f"\nTimestep 0 features (x0):")
    print(f"  Voltage [V]:         {x0[0]:10.6f}")
    print(f"  Current [A]:         {x0[1]:10.6f}")
    print(f"  Temperature [degC]:  {x0[2]:10.6f}")
    print(f"  Power [W]:           {x0[3]:10.6f}")
    print(f"  CC_Capacity [Ah]:    {x0[4]:10.6f}")
    
    # Step 3: Compute timestep 0 with column-wise tiling
    results = compute_timestep0_tiled(W_all, x0)
    
    # Step 4: Save all results
    save_all_results(results, W_all, prefix="timestep0")
    
    print("\n" + "="*80)
    print(" ✅ COLUMN-WISE TILED COMPUTATION COMPLETE!")
    print("="*80)
    print("\nGenerated files:")
    print("  • timestep0_W_all_376x100.txt          - Weight matrix")
    print("  • timestep0_input_vector_100x1.txt     - Input vector [x0, h_prev, 1]")
    print("  • timestep0_raw_outputs_376x1.txt      - Final accumulated outputs")
    print("  • timestep0_raw_gates_94x4.txt         - Raw gate values (before activation)")
    print("  • timestep0_gates_activated_94x4.txt   - Activated gate values")
    print("  • timestep0_hidden_state_94x1.txt      - Hidden state (h_t)")
    print("  • timestep0_cell_state_94x1.txt        - Cell state (c_t)")
    print("  • timestep0_column_tile_details.txt    - Detailed tile-by-tile computation")
    
    print("\n" + "="*80)
    print(" TILING STRATEGY")
    print("="*80)
    print("""
Column-wise Tiling:
  • 100 columns divided into 25 tiles (4 columns per tile)
  • Each tile: (376 rows × 4 cols) @ (4×1 input) = (376×1 partial output)
  • Partial outputs are accumulated across all 25 tiles
  • Final accumulated output (376×1) goes through activation functions
  
Computation Flow:
  1. Tile 0: Columns [0:3]   → Partial output (376,)
  2. Tile 1: Columns [4:7]   → Partial output (376,) → Accumulate
  3. ...
  4. Tile 24: Columns [96:99] → Partial output (376,) → Accumulate
  5. Apply activation functions to final accumulated output
    """)
    
    print("="*80)
    print("\n✅ ALL COMPUTATIONS AND FILES SAVED SUCCESSFULLY!\n")