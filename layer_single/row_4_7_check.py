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


def compute_tile1_rows4to7(W_all, x0, h_prev=None):
    """
    Compute TILE 1 (Columns [4:7]) for ROWS 4 to 7 only
    Show detailed computation for verification
    
    Args:
        W_all: (376, 100) weight matrix
        x0: (5,) input features for timestep 0
        h_prev: (94,) previous hidden state (default: zeros)
    
    Returns:
        Dictionary with tile 1 computation results for rows 4-7
    """
    
    print("\n" + "="*80)
    print(" TILE 1 COMPUTATION: Columns [4:7], Rows [4:7]")
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
    
    # TILE 1: Columns [4:7]
    tile_idx = 1
    start_col = 4
    end_col = 8
    
    # Extract tile weights for rows [4:7] only
    tile_weights_rows4to7 = W_all[4:8, start_col:end_col]  # (4, 4)
    
    # Extract corresponding input values: (4,)
    tile_input = input_vector[start_col:end_col]
    
    print(f"\n" + "="*80)
    print(f"TILE {tile_idx}: Columns [{start_col}:{end_col-1}], ROWS [4:7]")
    print("="*80)
    print(f"\nTile Input Vector (4 values): {tile_input.tolist()}")
    print(f"Tile Weight Matrix for Rows [4:7]: (4, 4)")
    
    # Print the 4x4 weight matrix
    print(f"\nWeight Matrix [Row 4-7, Col 4-7]:")
    for i in range(4):
        row_idx = i + 4
        print(f"  Row {row_idx}: [{tile_weights_rows4to7[i, 0]:13.10f}, {tile_weights_rows4to7[i, 1]:13.10f}, {tile_weights_rows4to7[i, 2]:13.10f}, {tile_weights_rows4to7[i, 3]:13.10f}]")
    
    # Compute partial output for rows 4-7
    partial_output_rows4to7 = tile_weights_rows4to7 @ tile_input
    
    print(f"\nPartial Output for Rows [4:7] (Tile 1 only):")
    for i in range(4):
        row_idx = i + 4
        print(f"  Row {row_idx}: {partial_output_rows4to7[i]:13.10f}")
    
    # Detailed computation breakdown
    print(f"\n" + "="*80)
    print(" DETAILED COMPUTATION BREAKDOWN")
    print("="*80)
    
    for i in range(4):
        row_idx = i + 4
        print(f"\nRow {row_idx} Computation:")
        print(f"  = W[{row_idx},4] * input[4] + W[{row_idx},5] * input[5] + W[{row_idx},6] * input[6] + W[{row_idx},7] * input[7]")
        print(f"  = ({tile_weights_rows4to7[i, 0]:13.10f}) * ({tile_input[0]:13.10f}) +")
        print(f"    ({tile_weights_rows4to7[i, 1]:13.10f}) * ({tile_input[1]:13.10f}) +")
        print(f"    ({tile_weights_rows4to7[i, 2]:13.10f}) * ({tile_input[2]:13.10f}) +")
        print(f"    ({tile_weights_rows4to7[i, 3]:13.10f}) * ({tile_input[3]:13.10f})")
        
        term1 = tile_weights_rows4to7[i, 0] * tile_input[0]
        term2 = tile_weights_rows4to7[i, 1] * tile_input[1]
        term3 = tile_weights_rows4to7[i, 2] * tile_input[2]
        term4 = tile_weights_rows4to7[i, 3] * tile_input[3]
        
        print(f"  = {term1:13.10f} + {term2:13.10f} + {term3:13.10f} + {term4:13.10f}")
        print(f"  = {partial_output_rows4to7[i]:13.10f}")
    
    return {
        'tile_weights': tile_weights_rows4to7,
        'tile_input': tile_input,
        'partial_output': partial_output_rows4to7,
        'input_vector': input_vector
    }


def compute_all_25_tiles_rows4to7(W_all, x0, h_prev=None):
    """
    Compute all 25 tiles for rows 4-7 and show accumulation
    
    Args:
        W_all: (376, 100) weight matrix
        x0: (5,) input features for timestep 0
        h_prev: (94,) previous hidden state (default: zeros)
    
    Returns:
        Dictionary with all tiles computation and final accumulated results
    """
    
    print("\n" + "="*80)
    print(" ALL 25 TILES COMPUTATION FOR ROWS [4:7]")
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
    
    print(f"\nTiling Configuration:")
    print(f"  Total columns: {total_cols}")
    print(f"  Column tiles: {num_tiles} tiles ({cols_per_tile} columns per tile)")
    print(f"  Focus rows: [4:7] (4 rows)")
    
    # Accumulator for rows 4-7
    accumulated_output_rows4to7 = np.zeros(4)
    
    # Store all tile results
    all_tile_results = []
    
    print("\n" + "="*80)
    print("TILE-BY-TILE COMPUTATION FOR ROWS [4:7]")
    print("="*80)
    
    # Process each column tile
    for tile_idx in range(num_tiles):
        start_col = tile_idx * cols_per_tile
        end_col = start_col + cols_per_tile
        
        # Extract column tile for rows [4:7]: (4, 4)
        tile_weights = W_all[4:8, start_col:end_col]
        
        # Extract corresponding input values: (4,)
        tile_input = input_vector[start_col:end_col]
        
        # Compute partial result: (4, 4) @ (4, 1) = (4, 1)
        partial_output = tile_weights @ tile_input
        
        # Accumulate
        accumulated_output_rows4to7 += partial_output
        
        # Store tile result
        all_tile_results.append({
            'tile_idx': tile_idx,
            'start_col': start_col,
            'end_col': end_col,
            'tile_weights': tile_weights,
            'tile_input': tile_input,
            'partial_output': partial_output.copy(),
            'accumulated_output': accumulated_output_rows4to7.copy()
        })
        
        # Print tile information
        print(f"\n{'='*80}")
        print(f"TILE {tile_idx}: Columns [{start_col}:{end_col-1}]")
        print("="*80)
        print(f"Tile Input Vector:  {tile_input.tolist()}")
        
        print(f"\nWeight Matrix [Rows 4-7, Cols {start_col}-{end_col-1}]:")
        for i in range(4):
            row_idx = i + 4
            print(f"  Row {row_idx}: [{tile_weights[i, 0]:13.10f}, {tile_weights[i, 1]:13.10f}, {tile_weights[i, 2]:13.10f}, {tile_weights[i, 3]:13.10f}]")
        
        print(f"\nPartial Output from Tile {tile_idx}:")
        for i in range(4):
            row_idx = i + 4
            print(f"  Row {row_idx}: {partial_output[i]:13.10f}")
        
        print(f"\nAccumulated Output After Tile {tile_idx}:")
        for i in range(4):
            row_idx = i + 4
            print(f"  Row {row_idx}: {accumulated_output_rows4to7[i]:13.10f}")
    
    print("\n" + "="*80)
    print(" FINAL ACCUMULATED OUTPUT FOR ROWS [4:7]")
    print("="*80)
    
    for i in range(4):
        row_idx = i + 4
        print(f"Row {row_idx} (Input Gate): {accumulated_output_rows4to7[i]:13.10f}")
    
    return {
        'all_tile_results': all_tile_results,
        'final_accumulated': accumulated_output_rows4to7,
        'input_vector': input_vector,
        'num_tiles': num_tiles
    }


def save_all_tiles_results(results, prefix="tile_rows4to7"):
    """
    Save detailed all 25 tiles computation results for rows 4-7
    """
    
    print("\n" + "="*80)
    print(" SAVING ALL TILES RESULTS TO FILE")
    print("="*80)
    
    with open(f"{prefix}_all_25_tiles_detailed.txt", 'w') as f:
        f.write("="*80 + "\n")
        f.write("ALL 25 TILES COMPUTATION FOR ROWS [4:7]\n")
        f.write("25 Column Tiles × 4 Columns per Tile = 100 Total Columns\n")
        f.write("Focus: Rows [4:7] (Input Gate)\n")
        f.write("="*80 + "\n\n")
        
        num_tiles = results['num_tiles']
        
        for tile_result in results['all_tile_results']:
            tile_idx = tile_result['tile_idx']
            start_col = tile_result['start_col']
            end_col = tile_result['end_col']
            tile_weights = tile_result['tile_weights']
            tile_input = tile_result['tile_input']
            partial_output = tile_result['partial_output']
            accumulated_output = tile_result['accumulated_output']
            
            f.write("="*80 + "\n")
            f.write(f"TILE {tile_idx}: Columns [{start_col}:{end_col-1}]\n")
            f.write("="*80 + "\n")
            f.write(f"Tile Input Vector (4 values): {tile_input.tolist()}\n\n")
            
            f.write(f"Weight Matrix [Rows 4-7, Cols {start_col}-{end_col-1}]:\n")
            for i in range(4):
                row_idx = i + 4
                f.write(f"  Row {row_idx}: [{tile_weights[i, 0]:13.10f}, {tile_weights[i, 1]:13.10f}, {tile_weights[i, 2]:13.10f}, {tile_weights[i, 3]:13.10f}]\n")
            
            f.write(f"\nPartial Output from Tile {tile_idx}:\n")
            for i in range(4):
                row_idx = i + 4
                f.write(f"  Row {row_idx}: {partial_output[i]:13.10f}\n")
            
            f.write(f"\nAccumulated Output After Tile {tile_idx}:\n")
            for i in range(4):
                row_idx = i + 4
                f.write(f"  Row {row_idx}: {accumulated_output[i]:13.10f}\n")
            
            f.write("\n")
        
        f.write("="*80 + "\n")
        f.write(" FINAL ACCUMULATED OUTPUT FOR ROWS [4:7]\n")
        f.write("="*80 + "\n")
        final_accumulated = results['final_accumulated']
        for i in range(4):
            row_idx = i + 4
            f.write(f"Row {row_idx} (Input Gate): {final_accumulated[i]:13.10f}\n")
    
    print(f"✓ Saved all 25 tiles details to: {prefix}_all_25_tiles_detailed.txt")


if __name__ == "__main__":
    
    print("\n" + "="*80)
    print(" LSTM TILE VERIFICATION - ROWS [4:7], ALL 25 TILES")
    print("="*80)
    
    # Step 1: Create 376x100 weight matrix
    pth_file = "../soc_lstm_model_1layer.pth"
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
    
    # Step 3: Compute TILE 1 for rows 4-7 (verification)
    print("\n" + "="*80)
    print(" STEP 1: VERIFY TILE 1 (Columns [4:7])")
    print("="*80)
    tile1_results = compute_tile1_rows4to7(W_all, x0)
    
    # Step 4: Compute all 25 tiles for rows 4-7
    print("\n" + "="*80)
    print(" STEP 2: COMPUTE ALL 25 TILES FOR ROWS [4:7]")
    print("="*80)
    all_tiles_results = compute_all_25_tiles_rows4to7(W_all, x0)
    
    # Step 5: Save all results
    save_all_tiles_results(all_tiles_results, prefix="tile_rows4to7")
    
    print("\n" + "="*80)
    print(" ✅ ALL 25 TILES COMPUTATION COMPLETE!")
    print("="*80)
    print("\nGenerated file:")
    print("  • tile_rows4to7_all_25_tiles_detailed.txt - All 25 tiles computation for rows [4:7]")
    
    print("\n" + "="*80)
    print(" SUMMARY")
    print("="*80)
    print(f"\nProcessed {all_tiles_results['num_tiles']} tiles")
    print(f"Each tile: (4 rows × 4 cols) @ (4×1 input) = (4×1 partial output)")
    print(f"\nFinal Accumulated Output for Rows [4:7] (Input Gate):")
    for i in range(4):
        row_idx = i + 4
        print(f"  Row {row_idx}: {all_tiles_results['final_accumulated'][i]:13.10f}")
    
    print("\n" + "="*80)
    print("\n✅ VERIFICATION COMPLETE!\n")