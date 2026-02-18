`timescale 1ns/1ps
module top #(
    parameter DATA_WIDTH      =16,
    parameter OUTPUT_WIDTH    = 16,
    parameter ADDR_WIDTH      = 16,
    parameter TILE_ADDR_WIDTH = 3,  // 8 locations for 4x4 tile
    parameter MATRIX_ROWS     = 376,
    parameter WEIGHT_MEM_SIZE=37600,
    parameter DATA_MEM_SIZE=94,
    parameter MATRIX_COLS     = 100,
    parameter DATA_TILE_WIDTH=2,
    parameter DATA_VECTOR_LENGTH=100,
    parameter TILE_WIDTH=4
)(
    input  wire clk,
    input  wire rst_n,
    input  wire we,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire [DATA_WIDTH-1:0] weight_in,
    input  wire [6:0] gb_data_addr
);
parameter NUM_TILES_TOTAL = (MATRIX_ROWS / TILE_WIDTH) * (MATRIX_COLS / TILE_WIDTH);
parameter FORGET_LIMIT=NUM_TILES_TOTAL/4;
parameter INPUT_LIMIT=NUM_TILES_TOTAL/2;
parameter CANDIDATE_LIMIT=(3*NUM_TILES_TOTAL)/4;
parameter OUTPUT_LIMIT=NUM_TILES_TOTAL;
parameter SWITCH_LIMIT=DATA_MEM_SIZE;
wire [OUTPUT_WIDTH-1:0] pe1,pe2,pe3,pe4;
wire mvm_en_diag4,mvm_en_diag5,mvm_en_diag6;
reg [1:0] data_sel;
wire start_compute;
reg computing;
wire row_jumped;
wire [1:0] write_count_1,write_count_2;
wire [DATA_WIDTH-1:0] tile_dout0, tile_dout1, tile_dout2, tile_dout3;
reg we_data;
// ----------------------- STATE MACHINE -------------------------
reg [1:0] state, next_state;
wire [7:0] burst_write_count;
wire we0, we1, we2, we3;
wire [TILE_ADDR_WIDTH-1:0] tile_addr;
// Ping-pong buffer A (0-3)
wire [DATA_WIDTH-1:0] weight_tile_data_out1_A, weight_tile_data_out2_A, weight_tile_data_out3_A, weight_tile_data_out4_A;
// Ping-pong buffer B (4-7)
wire [DATA_WIDTH-1:0] weight_tile_data_out1_B, weight_tile_data_out2_B, weight_tile_data_out3_B, weight_tile_data_out4_B;

// *** MODIFIED: New FSM States ***
localparam IDLE       = 2'd0;   
localparam LOAD_FIRST = 2'd1;  // Initial load state
localparam COMPUTE    = 2'd2;  // Continuous compute + load state

wire data_done_1, data_done_2;

// ----------------------- INTERNAL SIGNALS -------------------------
wire [TILE_ADDR_WIDTH-1:0] data_tile_addr1;
wire [TILE_ADDR_WIDTH-1:0] data_tile_addr2;
reg reset_done;
wire tile_done_1_A, tile_done_2_A, tile_done_3_A, tile_done_4_A;
wire tile_done_1_B, tile_done_2_B, tile_done_3_B, tile_done_4_B;
// ...existing code...

// Burst module signals
wire burst_full;  // Indicates tile buffer is completely filled
// One-cycle delayed pulse for burst_full
reg burst_full_d;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        burst_full_d <= 1'b0;
    else
        burst_full_d <= burst_full;
end
reg prev_tiles_ready;
// *** MODIFIED: Separate read and write buffer selects ***
reg read_buffer_select;   // Controls which buffer to READ from (compute)
reg write_buffer_select;  // Controls which buffer to WRITE to (load)
reg read_buffer_select_prev;
// Detect rising edge of read_buffer_select
always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            read_buffer_select_prev <= 1'b0;
        else
            read_buffer_select_prev <= read_buffer_select;
    end
wire read_buffer_select_rising = read_buffer_select & ~read_buffer_select_prev;
wire [ADDR_WIDTH-1:0] gb_rd_weight_addr; 
wire [6:0]            gb_rd_data_addr; 
wire gb_re;
wire [ADDR_WIDTH-1:0] gb_addr;
wire global_done_weight, global_done_data;
wire [DATA_WIDTH-1:0] gb_dout_weight;
wire [DATA_WIDTH-1:0] gb_dout_data;
wire start_burst_cond, done_burst,start_burst;
wire [DATA_WIDTH-1:0] tile_data0, tile_data1;
reg weight_loaded;
reg data_loaded;
reg [ADDR_WIDTH-1:0] gb_rd_weight_addr_reg;
reg [6:0]            gb_rd_data_addr_reg;
reg [6:0] tile_row_idx; 
reg [6:0] tile_col_idx;  
wire [ADDR_WIDTH-1:0] tile_base_addr;  // Calculated base address for current tile
// MATRIX_COLS/TILE_WIDTH = 100/4 = 25 = 16 + 8 + 1 = 2^4 + 2^3 + 2^0
assign tile_base_addr = (((tile_row_idx << 4) + (tile_row_idx << 3) + tile_row_idx) + tile_col_idx) << 2;
reg [3:0] base_addr_reg_1,base_addr_reg_2;
// --- Compute Read Control ---
reg [TILE_ADDR_WIDTH-1:0] weight_read_addr_1, weight_read_addr_2, weight_read_addr_3, weight_read_addr_4;  // Separate read addresses for each weight BRAM
reg [TILE_ADDR_WIDTH-1:0] data_read_addr_reg;   
wire [TILE_ADDR_WIDTH-1:0] data_read_addr;   
assign data_read_addr = data_read_addr_reg;
wire weight_tile_ready;
wire data_tile_ready;
wire tiles_ready;
wire almost_full;
reg tiles_ready_prev;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        tiles_ready_prev <= 1'b0;
    else
        tiles_ready_prev <= tiles_ready;
end
wire tiles_ready_rising = tiles_ready & ~tiles_ready_prev;

assign tiles_ready = (state==LOAD_FIRST) ? done_burst && (data_done_1 || data_done_2) : (tile_done_1_A && data_done_1) || (tile_done_1_B && data_done_2);

// --- Data Tile Write Control ---
reg [TILE_ADDR_WIDTH-1:0] data_tile_write_addr_1_reg, data_tile_write_addr_2_reg;
reg write_active;
reg [1:0] write_count;
// ------------------- SIGNAL ASSIGNMENTS ----------------------
assign gb_rd_weight_addr = gb_rd_weight_addr_reg;
assign gb_rd_data_addr   = gb_rd_data_addr_reg;
// Use write address during write, read address during compute
assign data_tile_addr1 =  data_tile_write_addr_1_reg;
assign data_tile_addr2 =  data_tile_write_addr_2_reg;
wire [DATA_WIDTH-1:0] input_vector;
assign input_vector = (read_buffer_select == 1'b1) ? tile_data0 : tile_data1;
// MVM output signals
wire mvm_en_diag0, mvm_en_diag1, mvm_en_diag2, mvm_en_diag3;
// *** MODIFIED: start_burst for new FSM states ***
assign start_burst_cond = weight_loaded && data_loaded && !done_burst && 
                     (state == LOAD_FIRST || state == COMPUTE);
reg prev_start_burst_cond;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        prev_start_burst_cond <= 1'b0;
    else
        prev_start_burst_cond <= start_burst_cond;
end
wire start_burst;
reg burst_done_d;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        burst_done_d <= 1'b0;
    else
        burst_done_d <= done_burst;
end
assign start_burst = (state==COMPUTE) ? burst_done_d :start_burst_cond & ~prev_start_burst_cond ;
wire read_done_out_1,read_done_out_2;
reg start_burst_d;
reg read_buffer_select_rising_d;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        read_buffer_select_rising_d <= 1'b0;
    else
        read_buffer_select_rising_d<=read_buffer_select_rising;
end 
// Falling edge detection for read_buffer_select
wire read_buffer_select_falling = ~read_buffer_select & read_buffer_select_prev;
reg read_buffer_select_falling_d;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        read_buffer_select_falling_d <= 1'b0;
    else
        read_buffer_select_falling_d <= read_buffer_select_falling;
end
reg signed [7:0] next_addr_reg;
assign start_compute = (read_buffer_select_rising_d || read_buffer_select_falling_d) ? 1'b1 : 1'b0;
// Example: assign start_compute_falling = (read_buffer_select_falling_d) ? 1'b1 : 1'b0;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      next_addr_reg <=0;    
    else if (almost_full && state==COMPUTE && compute_count>=1 )begin
        next_addr_reg <= next_addr_reg +4;
    end
    else if(row_jumped)begin
        next_addr_reg <=-4;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
       reset_done<=0;
    end else begin
        if(tiles_ready && !prev_tiles_ready)
            reset_done<=1;
        else
            reset_done<=0;
    end
end
// --- Data Tile Write Enable Logic ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        we_data<=1'b0;
        write_active<=0;
        base_addr_reg_1 <= 0;
        base_addr_reg_2 <= 4;
        gb_rd_data_addr_reg <= 0;
    end else begin
        write_active <= we_data;
        // LOAD_FIRST state logic
        if (state == LOAD_FIRST) begin
            if (start_burst) begin
                we_data<=1'b1;
            end else if (we_data && gb_rd_data_addr_reg == base_addr_reg_1 + 3) begin
                we_data <= 1'b0;
            end
        end
            if(write_buffer_select==0)begin
                if(gb_rd_data_addr_reg<base_addr_reg_1 + 3 && we_data)begin
                    gb_rd_data_addr_reg <= gb_rd_data_addr_reg + 1;
                end
            end
            if(write_buffer_select==1)begin
                if(gb_rd_data_addr_reg<base_addr_reg_2 + 3 && we_data)begin
                    gb_rd_data_addr_reg <= gb_rd_data_addr_reg + 1;
                end
            end 
            if (we_data && gb_rd_data_addr_reg == base_addr_reg_1 + 3) begin
                we_data <= 1'b0;
                gb_rd_data_addr_reg <= base_addr_reg_2;
            end
            if (we_data && gb_rd_data_addr_reg == base_addr_reg_2 + 3) begin
                we_data <= 1'b0;
            end
        
        if(state==COMPUTE)begin
            if(burst_full && compute_count>0)begin
               we_data<=1'b1;
               gb_rd_data_addr_reg <= next_addr_reg;
            end
            if (we_data && gb_rd_data_addr_reg == next_addr_reg+3) 
                    we_data <= 1'b0;
            if(we_data && gb_rd_data_addr_reg<next_addr_reg + 3)
                gb_rd_data_addr_reg <= gb_rd_data_addr_reg + 1;
        end
        
        if(gb_rd_data_addr_reg==DATA_VECTOR_LENGTH-1)
            gb_rd_data_addr_reg <=0;
    end
end
// --- Data Tile Address Increment Logic ---
reg [7:0] tile_count;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tile_count <= 0;
    end else begin
        if (done_burst) begin
            tile_count <= tile_count + 1;
        end
    end
end 
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gb_rd_weight_addr_reg <= 0;
        tile_row_idx <= 0;
        tile_col_idx <= 0;
        data_tile_write_addr_1_reg <= 0;
        data_tile_write_addr_2_reg <= 0;
    end else begin
        if (gb_re) begin
            gb_rd_weight_addr_reg <= gb_addr;
        end
         if (write_active && write_buffer_select==1'b0)
                data_tile_write_addr_1_reg <= data_tile_write_addr_1_reg + 1;
         if (write_active && write_buffer_select==1'b1)
                data_tile_write_addr_2_reg <= data_tile_write_addr_2_reg + 1;
        if (done_burst) begin
            // Move to next tile
            if (tile_col_idx == ((MATRIX_COLS >> 2) - 1)) begin
                tile_col_idx <= 0;
                tile_row_idx <= tile_row_idx + 1;
            end else begin
                tile_col_idx <= tile_col_idx + 1;
            end
        end
    end
end
// --- Load Flags ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        weight_loaded <= 0;
        data_loaded   <= 0;
    end else begin
        if (global_done_weight)
            weight_loaded <= 1;
        if (global_done_data)
            data_loaded <= 1;
    end
end
// ------------------- FSM STATE REGISTER -------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end
reg [16:0] compute_count;
// ------------------- FSM NEXT STATE LOGIC -------------------
always @(*) begin
    next_state = state;

    case (state)
        IDLE: begin
            if (weight_loaded && data_loaded)
                next_state = LOAD_FIRST;
        end

        LOAD_FIRST: begin
            // Wait for first buffer set to be fully loaded
            if (tiles_ready)
                next_state = COMPUTE;
        end

        COMPUTE: begin
            // Stay in COMPUTE state, buffers will ping-pong
              next_state=COMPUTE;
        end

        default: next_state = IDLE;
    endcase     
end
reg computing;
always @(posedge clk or negedge rst_n)begin
   if(!rst_n )
     compute_count<=0;
   else 
   if(compute_done)
     compute_count<=compute_count+1;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        computing <= 0;
    else if (start_compute)
        computing <= 1;
    else if (compute_done)begin
        computing <= 0;
    end
end
// Removed - compute_count now handled in dedicated always block at line 335
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_buffer_select  <= 1'b0;
        write_buffer_select <= 1'b0;
        data_sel <= 2'b00;
        weight_read_addr_1 <= {TILE_ADDR_WIDTH{1'b0}};
        weight_read_addr_2 <= {TILE_ADDR_WIDTH{1'b0}};
        weight_read_addr_3 <= {TILE_ADDR_WIDTH{1'b0}};
        weight_read_addr_4 <= {TILE_ADDR_WIDTH{1'b0}};
        data_read_addr_reg <= {TILE_ADDR_WIDTH{1'b0}};
    end
    else begin
        case (state)
            IDLE: begin
                read_buffer_select  <= 1'b0;
                write_buffer_select <= 1'b0;
                data_sel <= 2'b00;
                weight_read_addr_1 <= {TILE_ADDR_WIDTH{1'b0}};
                weight_read_addr_2 <= {TILE_ADDR_WIDTH{1'b0}};
                weight_read_addr_3 <= {TILE_ADDR_WIDTH{1'b0}};
                weight_read_addr_4 <= {TILE_ADDR_WIDTH{1'b0}};
                data_read_addr_reg <= {TILE_ADDR_WIDTH{1'b0}};
            end

            LOAD_FIRST: begin
                write_buffer_select <= 1'b0;      
                data_sel <= 2'b00;
            end
            COMPUTE: begin
                // Toggle write_buffer_select when almost_full
                if (almost_full && compute_count>=1)
                    write_buffer_select <= ~write_buffer_select;
                
                // Toggle read_buffer_select on tiles_ready
                if (compute_count==0 && tiles_ready)
                    read_buffer_select<=1'b1;
                if(tiles_ready_rising)
                    read_buffer_select<=~read_buffer_select;
            
                if(computing && !compute_done)begin
                     data_sel<=2'b00;
                end
               if(compute_done) begin
                   weight_read_addr_1 <= {TILE_ADDR_WIDTH{1'b0}};
                   weight_read_addr_2 <= {TILE_ADDR_WIDTH{1'b0}};
                   weight_read_addr_3 <= {TILE_ADDR_WIDTH{1'b0}};
                   weight_read_addr_4 <= {TILE_ADDR_WIDTH{1'b0}};
                   data_read_addr_reg <= {TILE_ADDR_WIDTH{1'b0}};
                   data_sel <= 2'b00;
               end
                // *** TRIGGER NEW COMPUTATION: When both weight and data tiles are filled ***
               if (computing && !compute_done) begin
                   if (mvm_en_diag0||mvm_en_diag1||mvm_en_diag2||mvm_en_diag3||mvm_en_diag4||mvm_en_diag5||mvm_en_diag6) 
                       weight_read_addr_1 <= weight_read_addr_1 + 1'b1;
                   if (mvm_en_diag1||mvm_en_diag2||mvm_en_diag3||mvm_en_diag4||mvm_en_diag5||mvm_en_diag6) 
                       weight_read_addr_2 <= weight_read_addr_2 + 1'b1;
                   if (mvm_en_diag2||mvm_en_diag3||mvm_en_diag4||mvm_en_diag5||mvm_en_diag6) 
                       weight_read_addr_3 <= weight_read_addr_3 + 1'b1;
                   if (mvm_en_diag3||mvm_en_diag4||mvm_en_diag5||mvm_en_diag6) 
                       weight_read_addr_4 <= weight_read_addr_4 + 1'b1;
                   if (mvm_en_diag0 || mvm_en_diag1 || mvm_en_diag2 || mvm_en_diag3) 
                       data_read_addr_reg <= data_read_addr_reg + 1'b1;
               end
               if (computing && !compute_done) begin
                   if (mvm_en_diag0  && data_sel == 2'b00) begin
                       data_sel <= 2'b01;  
                   end
                   else if (mvm_en_diag1  && data_sel == 2'b01) begin
                       data_sel <= 2'b10; 
                   end
                   else if (mvm_en_diag2 && data_sel == 2'b10) begin
                       data_sel <= 2'b11;  // Column 4 data when diag3 activates
                   end
               end
            end
        endcase
    end
end
reg [6:0] tile_in_row_counter; // Enough bits for number of tiles per row group
reg row_jumped_reg;
assign row_jumped = row_jumped_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tile_in_row_counter <= 0;
        row_jumped_reg <= 0;
    end else if (done_burst) begin
        if (tile_in_row_counter == (MATRIX_COLS/TILE_WIDTH )-1) begin
            row_jumped_reg <= 1; 
            tile_in_row_counter <= 0;
        end else begin
            row_jumped_reg <= 0;
            tile_in_row_counter <= tile_in_row_counter + 1;
        end
    end else begin
        row_jumped_reg <= 0;
    end
end
// ---------------- GLOBAL BRAMs -------------------------------
weight_global_bram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .MEM_SIZE(WEIGHT_MEM_SIZE),
    .MEM_FILE("lstm_weight_ih_l0_7_8_1.mem")
) weight_bram (
    .clk(clk), .rst_n(rst_n),
    .rd_addr(gb_addr),
    .re(gb_re),
    .dout(gb_dout_weight),
    .done(global_done_weight)
);

data_global_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(7)) data_bram (
    .clk(clk), .rst_n(rst_n),
    .wr_addr(gb_data_addr),
    .rd_addr(gb_rd_data_addr),
    .din(data_in),
    .we(we),
    .re((we_data)),  // Read enable when either buffer is being written
    .dout(gb_dout_data),
    .done(global_done_data)
);

// ---------------- BURST ENGINE ----------------------------
bram_burst #(
    .DATA_WIDTH(DATA_WIDTH), 
    .ADDR_WIDTH(ADDR_WIDTH),
    .MATRIX_COLS(MATRIX_COLS)
) bram_burst_inst (
    .clk(clk), 
    .rst_n(rst_n), 
    .start(start_burst_cond),
    .base_addr(tile_base_addr), 
    .buffer_select(write_buffer_select),  // *** MODIFIED: Use write_buffer_select ***
    .done(done_burst),
    .full_burst_pulse(burst_full),
    
    .global_dout(gb_dout_weight),
    .global_addr(gb_addr),
    .global_re(gb_re),
    
    .tile_addr(tile_addr),
    .tile_dout0(tile_dout0), .tile_dout1(tile_dout1), 
    .tile_dout2(tile_dout2), .tile_dout3(tile_dout3),
    .we0(we0), .we1(we1), .we2(we2), .we3(we3),
    .burst_write_count(burst_write_count),
    .almost_full_pulse(almost_full)
);

// ---------------- DATA TILE BRAMs (Ping Pong) -------------------
// Data buffer A - writes when write_buffer_select=0, reads when read_buffer_select=0
bram_row #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(2)) data_tile_bram0 (
    .clk(clk), .rst_n(rst_n),
    .addr(data_tile_addr1),
    .rd_addr(data_read_addr),
    .din(gb_dout_data),
    .we(write_active && write_buffer_select == 1'b0), 
    .rd_en((mvm_en_diag0||mvm_en_diag1||mvm_en_diag2||mvm_en_diag3) && (read_buffer_select == 1'b1)), 
    .reset_done(reset_done),
    .dout(tile_data0),
    .done(data_done_1),
    .read_done_out(read_done_out_1),
    .write_count(write_count_1) 
);

// Data buffer B - writes when write_buffer_select=1, reads when read_buffer_select=1
bram_row #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(2)) data_tile_bram1 (
    .clk(clk), .rst_n(rst_n),
    .addr(data_tile_addr2),
    .rd_addr(data_read_addr),
    .din(gb_dout_data),
    .we(write_active && write_buffer_select == 1'b1), 
    .reset_done(reset_done),
    .rd_en((mvm_en_diag0||mvm_en_diag1||mvm_en_diag2||mvm_en_diag3) && (read_buffer_select == 1'b0)),
    .dout(tile_data1),
    .done(data_done_2),
    .read_done_out(read_done_out_2),
    .write_count(write_count_2) 
);

// ---------------- WEIGHT TILE BRAMs (Set A - Buffer 0) -------------------
weight_tile_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(2)) weight_tile_bram0 (
    .clk(clk), .rst_n(rst_n), .addr(tile_addr),
    .rd_addr(weight_read_addr_1),
    .din(tile_dout0), .we(we0 && (write_buffer_select == 1'b0)),
    .reset_done(reset_done),
    .rd_en((mvm_en_diag0||mvm_en_diag1||mvm_en_diag2||mvm_en_diag3) && (read_buffer_select == 1'b1)),
    .dout(weight_tile_data_out1_A), .done(tile_done_1_A)
);

weight_tile_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(2)) weight_tile_bram1 (
    .clk(clk), .rst_n(rst_n), .addr(tile_addr),
    .rd_addr(weight_read_addr_2),
    .reset_done(reset_done),    
    .din(tile_dout1), .we(we1 && (write_buffer_select == 1'b0)),    
    .rd_en((mvm_en_diag1||mvm_en_diag2||mvm_en_diag3||mvm_en_diag4||mvm_en_diag5||mvm_en_diag6) && (read_buffer_select == 1'b1)), 
    .dout(weight_tile_data_out2_A), .done(tile_done_2_A)
);

weight_tile_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(2)) weight_tile_bram2 (
    .clk(clk), .rst_n(rst_n), .addr(tile_addr),
    .rd_addr(weight_read_addr_3),
    .reset_done(reset_done),
    .din(tile_dout2), .we(we2 && (write_buffer_select == 1'b0)),
    .rd_en((mvm_en_diag2||mvm_en_diag3||mvm_en_diag4||mvm_en_diag5||mvm_en_diag6) && (read_buffer_select == 1'b1)), 
    .dout(weight_tile_data_out3_A), .done(tile_done_3_A)
);

weight_tile_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(2)) weight_tile_bram3 (
    .clk(clk), .rst_n(rst_n), .addr(tile_addr),
    .rd_addr(weight_read_addr_4),
    .reset_done(reset_done),
    .din(tile_dout3), .we(we3 && (write_buffer_select == 1'b0)),
    .rd_en((mvm_en_diag3||mvm_en_diag4||mvm_en_diag5||mvm_en_diag6) && (read_buffer_select == 1'b1)), 
    .dout(weight_tile_data_out4_A), .done(tile_done_4_A)
);

// ---------------- WEIGHT TILE BRAMs (Set B - Buffer 1) -------------------
weight_tile_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(2)) weight_tile_bram4 (
    .clk(clk), .rst_n(rst_n),
    .addr(tile_addr),
    .rd_addr(weight_read_addr_1),
    .reset_done(reset_done),
    .din(tile_dout0), .we(we0 && (write_buffer_select == 1'b1)), 
    .rd_en((mvm_en_diag0||mvm_en_diag1||mvm_en_diag2||mvm_en_diag3) && (read_buffer_select == 1'b0)), 
    .dout(weight_tile_data_out1_B), .done(tile_done_1_B)
);

weight_tile_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(2)) weight_tile_bram5 (
    .clk(clk), .rst_n(rst_n), .addr(tile_addr),
    .rd_addr(weight_read_addr_2),
    .reset_done(reset_done),
    .din(tile_dout1), .we(we1 && (write_buffer_select == 1'b1)),
    .rd_en((mvm_en_diag1||mvm_en_diag2||mvm_en_diag3||mvm_en_diag4) && (read_buffer_select == 1'b0)), 
    .dout(weight_tile_data_out2_B), .done(tile_done_2_B)
);

weight_tile_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(2)) weight_tile_bram6 (
    .clk(clk), .rst_n(rst_n), .addr(tile_addr),
    .rd_addr(weight_read_addr_3),
    .reset_done(reset_done),
    .din(tile_dout2), .we(we2 && (write_buffer_select == 1'b1)),
    .rd_en((mvm_en_diag2||mvm_en_diag3||mvm_en_diag4||mvm_en_diag5) && (read_buffer_select == 1'b0)), 
    .dout(weight_tile_data_out3_B), .done(tile_done_3_B)
);

weight_tile_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(2)) weight_tile_bram7 (
    .clk(clk), .rst_n(rst_n), .addr(tile_addr),
    .rd_addr(weight_read_addr_4),
    .reset_done(reset_done),
    .din(tile_dout3), .we(we3 && (write_buffer_select == 1'b1)),
    .rd_en((mvm_en_diag3||mvm_en_diag4||mvm_en_diag5||mvm_en_diag6) && (read_buffer_select == 1'b0)), 
    .dout(weight_tile_data_out4_B), .done(tile_done_4_B)
);
// ---------------- MVM INSTANCE -------------------
mvm #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) mvm_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(computing),
    .data_sel(data_sel),
    .data_in(input_vector),
    .weight_1((read_buffer_select == 1'b1) ? weight_tile_data_out1_A : weight_tile_data_out1_B),
    .weight_2((read_buffer_select == 1'b1) ? weight_tile_data_out2_A : weight_tile_data_out2_B),
    .weight_3((read_buffer_select == 1'b1) ? weight_tile_data_out3_A : weight_tile_data_out3_B),
    .weight_4((read_buffer_select == 1'b1) ? weight_tile_data_out4_A : weight_tile_data_out4_B),
    .out1(pe1),
    .out2(pe2),
    .out3(pe3),
    .out4(pe4),
    .done(compute_done),
    .done_row1(done_row1),
    .done_row2(done_row2),
    .done_row3(done_row3),
    .en_diag0_out(mvm_en_diag0),
    .en_diag1_out(mvm_en_diag1),
    .en_diag2_out(mvm_en_diag2),
    .en_diag3_out(mvm_en_diag3),
    .en_diag4_out(mvm_en_diag4),
    .en_diag5_out(mvm_en_diag5),    
    .en_diag6_out(mvm_en_diag6)
);
wire done_row1,done_row2,done_row3;
wire [OUTPUT_WIDTH-1:0] accumulated_sum1, accumulated_sum2, accumulated_sum3, accumulated_sum4;    
//---------------- ADDING TILE OUTPUTS FROM MVM-----------------
wire acc_clear_1,acc_clear_2,acc_clear_3,acc_clear_4;
accumulated_adder #(
    .DATA_WIDTH(OUTPUT_WIDTH)
) acc_1 (
    .clk(clk),
    .rst_n(rst_n),
    .clear(acc_clear_1),  
    .valid_in(compute_done), 
    .tile_sum(pe1),         
    .acc_sum(accumulated_sum1)        
);
accumulated_adder #(
    .DATA_WIDTH(OUTPUT_WIDTH)
) acc_2 (
    .clk(clk),
    .rst_n(rst_n),
    .clear(acc_clear_2),  
    .valid_in(done_row1), 
    .tile_sum(pe2),         
    .acc_sum(accumulated_sum2)
);
accumulated_adder #(
    .DATA_WIDTH(OUTPUT_WIDTH)
) acc_3 (
    .clk(clk),
    .rst_n(rst_n),
    .clear(acc_clear_3),  
    .valid_in(done_row2), 
    .tile_sum(pe3),         
    .acc_sum(accumulated_sum3) 
);  
accumulated_adder #(
    .DATA_WIDTH(OUTPUT_WIDTH)
) acc_4 (
    .clk(clk),
    .rst_n(rst_n),
    .clear(acc_clear_4),  
    .valid_in(done_row3), 
    .tile_sum(pe4),         
    .acc_sum(accumulated_sum4)  
);
// ------------FINAL TILED OUTPUT BUFFERING-------------------- 
wire en_output_write;  
assign acc_clear_1=tile_count_reg_1==(MATRIX_COLS/TILE_WIDTH)+1 ? 1:0;
assign acc_clear_2=tile_count_reg_2==(MATRIX_COLS/TILE_WIDTH)+1 ? 1:0;
assign acc_clear_3=tile_count_reg_3==(MATRIX_COLS/TILE_WIDTH)+1 ? 1:0;
assign acc_clear_4=tile_count_reg_4==(MATRIX_COLS/TILE_WIDTH)+1 ? 1:0; 
assign en_output_write = acc_clear_1 || acc_clear_2 || acc_clear_3 || acc_clear_4;
wire [1:0] output_data_sel;
assign output_data_sel = acc_clear_1 ? 2'b00 :
                        acc_clear_2 ? 2'b01 :
                        acc_clear_3 ? 2'b10 :
                        acc_clear_4 ? 2'b11 :
                        2'b00;
reg [ADDR_WIDTH-1:0] output_write_addr,output_read_addr;
wire [ADDR_WIDTH-1:0] output_write_count_1;
wire [OUTPUT_WIDTH-1:0] output_data;
reg [4:0] tile_count_reg_1,tile_count_reg_2,tile_count_reg_3,tile_count_reg_4;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
       output_write_addr<=0;
       tile_count_reg_1<=0;
       tile_count_reg_2<=0;
       tile_count_reg_3<=0;
       tile_count_reg_4<=0;
    end else begin
            if(done_row1)begin
               tile_count_reg_1<=tile_count_reg_1+1;
            end
            else if(done_row2)begin
                tile_count_reg_2<=tile_count_reg_2+1;
            end
            else if(done_row3)begin
               tile_count_reg_3<=tile_count_reg_3+1;
            end
            else if(compute_done)begin
                tile_count_reg_4<=tile_count_reg_4+1;
            end
        end
    end
mux4to1 #(
    .WIDTH(OUTPUT_WIDTH)
) output_mux (
    .en(acc_clear_1 | acc_clear_2 | acc_clear_3 | acc_clear_4),
    .sel(output_data_sel),
    .d0(accumulated_sum1),
    .d1(accumulated_sum2),
    .d2(accumulated_sum3),
    .d3(accumulated_sum4),
    .y(output_data)
);
//---------------- ACTIVATION FUNCTION AND OUTPUT BUFFERING -------------------
reg [1:0] activation_buffer_set_select; // 2-bit signal to select among 4 buffer sets
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        activation_buffer_set_select <= 0;
    end else begin
        if(tile_count_reg_1==(MATRIX_COLS/TILE_WIDTH)+1)
            tile_count_reg_1<=1;
        if(tile_count_reg_2==(MATRIX_COLS/TILE_WIDTH)+1)
            tile_count_reg_2<=1;
        if(tile_count_reg_3==(MATRIX_COLS/TILE_WIDTH)+1)
            tile_count_reg_3<=1;
        if(tile_count_reg_4==(MATRIX_COLS/TILE_WIDTH)+1)
            tile_count_reg_4<=1;
end
end
wire [1:0] switch_data_sel;
mod4_selector #(
    .WIDTH(17),
    .MOD(4),
    .SEL_WIDTH(2)
) activation_buffer_set_selector (
    .value_in(DATA_MEM_SIZE),
    .sel(switch_data_sel)
);
// Combined activation buffer control and address management
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        activation_buffer_set_select <= 2'b00;  // Start with forget gate
        output_write_addr <= 0;
    end else begin
        // When a complete row of accumulated results is done
        if (en_output_write) begin
            output_write_addr <= output_write_addr + 1;
            
            // Check if we've filled the current buffer
            if (output_write_addr == DATA_MEM_SIZE - 1) begin
                output_write_addr <= 0;  // Reset address for next buffer
                activation_buffer_set_select <= activation_buffer_set_select + 1;  // Move to next gate
                // activation_buffer_set_select will automatically wrap: 00->01->10->11->00
            end
        end
        if (gate_read) begin
            output_read_addr <= output_read_addr + 1;
        end
    end
end
wire forget_write,input_write,candidate_write,output_write,done_data;
reg gate_read;
wire [DATA_WIDTH-1:0] forget_activation_output, input_activation_output,candidate_activation_output, output_activation_output;
wire [DATA_WIDTH-1:0] el_forget_in, el_input_in, el_candidate_in, el_output_in;
sigmoid #( .WIDTH(16),
.FRAC_BITS(8)
) forget_gate ( .input_value(output_data),
   // .we(forget_write),
    .sigmoid_out(forget_activation_output)
);
sigmoid #(.WIDTH(16),
.FRAC_BITS(8)
) input_gate ( .input_value(output_data),
   // .we(input_write),
    .sigmoid_out(input_activation_output)
);
tanh #(
    .INPUT_WIDTH(16),
    .OUTPUT_WIDTH(16),
    .FRAC_BITS(8)
) candidate_gate ( .input_value(output_data),
    //.we(candidate_write),
    .tanh_out(candidate_activation_output)
);
sigmoid #(.WIDTH(16),
.FRAC_BITS(8)
) output_gate ( .input_value(output_data),
    //.we(output_write),
    .sigmoid_out(output_activation_output)
);
reg reset_done_gate;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
    reset_done_gate<=0;
end
wire done_forget, done_input, done_candidate, done_output;
wire read_done_forget, read_done_input, read_done_candidate, read_done_output;
wire done_data,read_done_data;
assign done_data = done_forget & done_input & done_candidate & done_output; 
assign read_done_data=read_done_forget & read_done_input & read_done_candidate & read_done_output;
// Set write enables based on activation_buffer_set_select
demux1to4 #(
    .DATA_WIDTH(1)
) output_write_demux (
    .data_in(1'b1),
    .enable(acc_clear_1 | acc_clear_2 | acc_clear_3 | acc_clear_4),
    .data_sel(activation_buffer_set_select),
    .data_out1(forget_write),
    .data_out2(input_write),
    .data_out3(candidate_write),
    .data_out4(output_write)
);
bram_row #(.MEM_SIZE(DATA_MEM_SIZE), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) forget_bram (
    .clk(clk),
    .rst_n(rst_n),
    .we(forget_write),
    .reset_done(reset_done_gate),
    .addr(output_write_addr),
    .din(forget_activation_output),
    .rd_en(gate_read),
    .rd_addr(output_read_addr),
    .dout(el_forget_in),
    .done(done_forget),
    .read_done_out(read_done_forget)
);
bram_row #(.MEM_SIZE(DATA_MEM_SIZE), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) input_bram (
    .clk(clk),
    .rst_n(rst_n),
    .we(input_write),
    .reset_done(reset_done_gate),
    .addr(output_write_addr),
    .din(input_activation_output),
    .rd_en(gate_read),
    .rd_addr(output_read_addr),
    .dout(el_input_in),
    .done(done_input),
    .read_done_out(read_done_input)
);
bram_row #(.MEM_SIZE(DATA_MEM_SIZE), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) candidate_bram (
    .clk(clk),
    .rst_n(rst_n),
    .we(candidate_write),
    .addr(output_write_addr),
    .reset_done(reset_done_gate),
    .din(candidate_activation_output),
    .rd_en(gate_read),
    .rd_addr(output_read_addr),
    .dout(el_candidate_in),
    .done(done_candidate),
    .read_done_out(read_done_candidate)
);  

bram_row #(.MEM_SIZE(DATA_MEM_SIZE), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) output_bram (
    .clk(clk),
    .rst_n(rst_n),
    .we(output_write),
    .addr(output_write_addr),
    .reset_done(reset_done_gate),
    .din(output_activation_output),
    .rd_en(gate_read),
    .rd_addr(output_read_addr),
    .dout(el_output_in),
    .done(done_output),
    .read_done_out(read_done_output)
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
       gate_read<=0;
    end else begin
        if (done_data) begin
           gate_read<=1;
        end
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
       output_read_addr<=0;
    if(gate_read)
       output_read_addr<=output_read_addr+1;
    end
end
//---------------- ELEMENT-WISE COMPUTATION -------------------
integer k;
reg ct_we;
reg [DATA_WIDTH-1:0] ct_minus_1[DATA_MEM_SIZE-1:0];
reg [ADDR_WIDTH-1:0] ct_minus_1_read_addr,ct_minus_1_write_addr;
wire [DATA_WIDTH-1:0] ct_read_data,ct_output;
assign ct_read_data = (gate_read)?ct_minus_1[ct_minus_1_read_addr]:0;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (k = 0; k < DATA_MEM_SIZE; k = k + 1) begin
            ct_minus_1[k] <= 0;
        end
        ct_minus_1_read_addr<=0;
        ct_minus_1_write_addr<=0;
        ct_we<=1'b0;
    end else begin
        if(gate_read) begin
            ct_minus_1_read_addr <= ct_minus_1_read_addr + 1;
        end
        if(done_data)
          ct_we<=1'b1;
        if(ct_we) begin
            ct_minus_1_write_addr <= ct_minus_1_write_addr + 1;
    end
end
end
 element_wise #(
    .DATA_WIDTH(DATA_WIDTH)
) element_wise_inst(.clk(clk),
    .rst(rst_n),
    .start(done_data),
    .i_register_i(el_input_in),  // Input gate (i)
    .f_register_i(el_forget_in),  // Forget gate (f)
    .c_register_i(el_candidate_in),  // Cell gate (g)
    .o_register_i(el_output_in),  // Output gate (o)
    .ct_minus_1(ct_read_data),    // C(t-1)
    .ct_output(ct_output),    // New cell state C(t)
    .ht_output(ht_output)    // Hidden state h(t)
);
wire read_ct_done,write_ct_done;
wire [DATA_WIDTH-1:0]ct_in;
assign ct_in = ct_output;
bram_row_modified #(.MEM_SIZE(DATA_MEM_SIZE), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) ct_minus_1_bram (
    .clk(clk),
    .rst_n(rst_n),
    .we(ct_we),
    .addr(ct_minus_1_write_addr),
    .reset_done(reset_done_gate),
    .din(ct_in),
    .rd_en(gate_read),
    .rd_addr(ct_minus_1_read_addr),
    .dout(ct_read_data),
    .done(write_ct_done),
    .read_done_out(read_ct_done)
);
//---------------- SEQUENCE FEATURE OF LSTM -------------------
endmodule
