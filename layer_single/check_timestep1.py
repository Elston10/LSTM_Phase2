import torch
import numpy as np

def create_376x100_matrix(pth_file='../soc_lstm_model_1layer.pth'):
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


def compute_timestep_tiled(W_all, x_t, h_prev, c_prev, timestep=0):
    """
    Compute LSTM gates using COLUMN-WISE TILED computation for any timestep
    
    100 columns divided into 25 tiles (4 columns per tile)
    Each tile processes all 376 rows
    Results are accumulated across tiles
    
    Args:
        W_all: (376, 100) weight matrix
        x_t: (5,) input features for current timestep
        h_prev: (94,) previous hidden state
        c_prev: (94,) previous cell state
        timestep: timestep number for labeling
    
    Returns:
        Dictionary with all gate activations and states
    """
    
    print("\n" + "="*100)
    print(f" COMPUTING TIMESTEP {timestep} WITH COLUMN-WISE TILED APPROACH")
    print("="*100)
    
    # Create input vector (100,) = [x_t (5,), h_prev (94,), 1.0]
    input_vector = np.concatenate([x_t, h_prev, [1.0]])
    
    print(f"\nInput Vector (100×1):")
    print(f"  x_t (features):       {x_t.tolist()}")
    print(f"  h_prev (first 10):    {h_prev[:10].tolist()}")
    print(f"  bias:                 1.0")
    
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
    
    print("\n" + "="*100)
    print("TILE-BY-TILE COMPUTATION (COLUMN-WISE TILING)")
    print(f"{num_tiles} Column Tiles × {cols_per_tile} Columns per Tile")
    print("="*100)
    
    # Process each column tile - Show detailed computation for first 25 tiles
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
        
        # Print detailed tile information
        print(f"\n{'='*100}")
        print(f"TILE {tile_idx}: Columns [{start_col}:{end_col-1}]")
        print("="*100)
        print(f"Tile Weight Matrix: ({total_rows}, {cols_per_tile})")
        print(f"Tile Input Vector:  {tile_input.tolist()}\n")
        
        # Show detailed computation for ROWS 0-3 for each gate
        print("DETAILED COMPUTATION FOR ROWS 0-3 (First 4 neurons per gate):")
        print("-"*100)
        
        for gate_idx in range(4):
            gate_names = ['INPUT GATE', 'FORGET GATE', 'CELL GATE', 'OUTPUT GATE']
            gate_start = gate_idx * 94
            
            print(f"\n{gate_names[gate_idx]}:")
            print(f"{'Row':>5} | {'W[0]':>12} | {'W[1]':>12} | {'W[2]':>12} | {'W[3]':>12} | {'Input*W':>12} | {'Partial':>12} | {'Accum':>12}")
            print("-"*100)
            
            for row_offset in range(min(4, 94)):  # Show rows 0-3 for this gate
                row = gate_start + row_offset
                
                # Get weights for this row
                w = tile_weights[row, :]  # (4,)
                
                # Compute weighted sum
                weighted_sum = (tile_input * w).sum()
                
                print(f"{row:5d} | {w[0]:12.6f} | {w[1]:12.6f} | {w[2]:12.6f} | {w[3]:12.6f} | {weighted_sum:12.6f} | {partial_output[row]:12.6f} | {accumulated_output[row]:12.6f}")
    
    print("\n" + "="*100)
    print(f"FINAL ACCUMULATED OUTPUT - TIMESTEP {timestep} (Rows 0-3 per gate)")
    print("="*100)
    
    # Print rows 0-3 for each gate
    for gate_idx in range(4):
        gate_names = ['INPUT GATE', 'FORGET GATE', 'CELL GATE', 'OUTPUT GATE']
        gate_start = gate_idx * 94
        
        print(f"\n{gate_names[gate_idx]} (Rows {gate_start}-{gate_start+93}):")
        print(f"{'Row':>5} | {'Accumulated Value':>20}")
        print("-"*30)
        for row_offset in range(min(4, 94)):
            row = gate_start + row_offset
            print(f"{row:5d} | {accumulated_output[row]:20.10f}")
    
    print("\n" + "="*100)
    print("APPLYING ACTIVATION FUNCTIONS")
    print("="*100)
    
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
    c_t = f_t * c_prev + i_t * g_t
    h_t = o_t * np.tanh(c_t)
    
    # Print activated gates (first 10 values)
    print("\n" + "="*100)
    print(f" GATE ACTIVATIONS AFTER SIGMOID/TANH - TIMESTEP {timestep}")
    print("="*100)
    
    print("\nFirst 10 values of each gate:")
    print(f"{'Idx':>4} | {'i_t (sigmoid)':>15} | {'f_t (sigmoid)':>15} | {'g_t (tanh)':>15} | {'o_t (sigmoid)':>15}")
    print("-"*75)
    for i in range(10):
        print(f"{i:4d} | {i_t[i]:15.10f} | {f_t[i]:15.10f} | {g_t[i]:15.10f} | {o_t[i]:15.10f}")
    
    print("\n" + "="*100)
    print(f" CELL STATE (c_t) and HIDDEN STATE (h_t) COMPUTATION - TIMESTEP {timestep}")
    print("="*100)
    print(f"\nFormula: c_t = f_t * c_prev + i_t * g_t")
    print(f"Formula: h_t = o_t * tanh(c_t)")
    
    print("\nDetailed computation (first 10 neurons):")
    print(f"{'Idx':>4} | {'f_t*c_prev':>14} | {'i_t*g_t':>14} | {'c_t':>14} | {'tanh(c_t)':>14} | {'h_t':>14}")
    print("-"*90)
    for i in range(10):
        fc = f_t[i] * c_prev[i]
        ig = i_t[i] * g_t[i]
        c_val = c_t[i]
        tanh_c = np.tanh(c_val)
        h_val = h_t[i]
        print(f"{i:4d} | {fc:14.10f} | {ig:14.10f} | {c_val:14.10f} | {tanh_c:14.10f} | {h_val:14.10f}")
    
    print("\n" + "="*100)
    print(f" STATISTICS - TIMESTEP {timestep}")
    print("="*100)
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


def save_all_results(results, W_all, prefix="timestep"):
    """
    Save all computation results to files
    """
    
    print("\n" + "="*80)
    print(f" SAVING {prefix.upper()} RESULTS TO FILES")
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
    
    print("\n" + "="*80)
    print(f" {prefix.upper()} FILES SAVED SUCCESSFULLY!")
    print("="*80)


if __name__ == "__main__":
    
    print("\n" + "="*100)
    print(" LSTM TIMESTEP 0 & 1 - DETAILED COLUMN-WISE TILED COMPUTATION")
    print("="*100)
    
    # Step 1: Create 376x100 weight matrix
    pth_file = "../soc_lstm_model_1layer.pth"
    W_all = create_376x100_matrix(pth_file)
    
    # Define timestep inputs
    x0 = np.array([-0.116864, 0.396518, 1.655884, 0.388196, -0.634126])
    x1 = np.array([-0.116864, 0.396518, 1.655884, 0.388196, -0.634162])
    
    # ========================================================================
    # TIMESTEP 0
    # ========================================================================
    print("\n" + "="*100)
    print(" TIMESTEP 0 - INITIAL COMPUTATION")
    print("="*100)
    print(f"\nTimestep 0 features (x0):")
    print(f"  Voltage [V]:         {x0[0]:10.6f}")
    print(f"  Current [A]:         {x0[1]:10.6f}")
    print(f"  Temperature [degC]:  {x0[2]:10.6f}")
    print(f"  Power [W]:           {x0[3]:10.6f}")
    print(f"  CC_Capacity [Ah]:    {x0[4]:10.6f}")
    
    # Initialize h_prev and c_prev as zeros for timestep 0
    h_prev_0 = np.zeros(94)
    c_prev_0 = np.zeros(94)
    
    # Compute timestep 0
    results_0 = compute_timestep_tiled(W_all, x0, h_prev_0, c_prev_0, timestep=0)
    
    # Save timestep 0 results
    save_all_results(results_0, W_all, prefix="timestep0")
    
    # ========================================================================
    # TIMESTEP 1
    # ========================================================================
    print("\n" + "="*100)
    print(" TIMESTEP 1 - USING HIDDEN & CELL STATES FROM TIMESTEP 0")
    print("="*100)
    print(f"\nTimestep 1 features (x1):")
    print(f"  Voltage [V]:         {x1[0]:10.6f}")
    print(f"  Current [A]:         {x1[1]:10.6f}")
    print(f"  Temperature [degC]:  {x1[2]:10.6f}")
    print(f"  Power [W]:           {x1[3]:10.6f}")
    print(f"  CC_Capacity [Ah]:    {x1[4]:10.6f}")
    
    print(f"\nPrevious states from Timestep 0:")
    print(f"  h_prev (first 10): {results_0['hidden_state'][:10].tolist()}")
    print(f"  c_prev (first 10): {results_0['cell_state'][:10].tolist()}")
    
    # Use outputs from timestep 0 as inputs to timestep 1
    h_prev_1 = results_0['hidden_state']
    c_prev_1 = results_0['cell_state']
    
    # Compute timestep 1
    results_1 = compute_timestep_tiled(W_all, x1, h_prev_1, c_prev_1, timestep=1)
    
    # Save timestep 1 results
    save_all_results(results_1, W_all, prefix="timestep1")
    
    # ========================================================================
    # SUMMARY
    # ========================================================================
    print("\n" + "="*100)
    print(" ✅ COMPUTATION COMPLETE FOR TIMESTEPS 0 AND 1!")
    print("="*100)
    
    print("\nGenerated files for TIMESTEP 0:")
    print("  • timestep0_W_all_376x100.txt          - Weight matrix")
    print("  • timestep0_input_vector_100x1.txt     - Input vector [x0, h_prev, 1]")
    print("  • timestep0_raw_outputs_376x1.txt      - Final accumulated outputs")
    print("  • timestep0_raw_gates_94x4.txt         - Raw gate values (before activation)")
    print("  • timestep0_gates_activated_94x4.txt   - Activated gate values")
    print("  • timestep0_hidden_state_94x1.txt      - Hidden state (h_t)")
    print("  • timestep0_cell_state_94x1.txt        - Cell state (c_t)")
    
    print("\nGenerated files for TIMESTEP 1:")
    print("  • timestep1_W_all_376x100.txt          - Weight matrix")
    print("  • timestep1_input_vector_100x1.txt     - Input vector [x1, h_prev, 1]")
    print("  • timestep1_raw_outputs_376x1.txt      - Final accumulated outputs")
    print("  • timestep1_raw_gates_94x4.txt         - Raw gate values (before activation)")
    print("  • timestep1_gates_activated_94x4.txt   - Activated gate values")
    print("  • timestep1_hidden_state_94x1.txt      - Hidden state (h_t)")
    print("  • timestep1_cell_state_94x1.txt        - Cell state (c_t)")
    
    print("\n" + "="*100)
    print(" COMPARISON: TIMESTEP 0 vs TIMESTEP 1")
    print("="*100)
    
    print("\nHidden State Comparison (first 10 values):")
    print(f"  Timestep 0: {results_0['hidden_state'][:10].tolist()}")
    print(f"  Timestep 1: {results_1['hidden_state'][:10].tolist()}")
    
    print("\nCell State Comparison (first 10 values):")
    print(f"  Timestep 0: {results_0['cell_state'][:10].tolist()}")
    print(f"  Timestep 1: {results_1['cell_state'][:10].tolist()}")
    
    print("\n" + "="*100)
    print("\n✅ ALL COMPUTATIONS AND FILES SAVED SUCCESSFULLY!\n")