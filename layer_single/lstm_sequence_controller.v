// LSTM Sequence Controller FSM - 20 Timesteps
module lstm_sequence_controller (
    input  clk,
    input  rst_n,
    input  start,              // Start signal
    input  [79:0] input_data,  // 5 inputs x 16 bits = 80 bits'
    output reg rd_input,
    input [15:0] weights,     // Weights for the LSTM (packed as needed)
    output reg[6:0] weight_addr,     // Address for weight memory (0-93)
    output  [15:0] output_data, // Final output after FC layer
    output reg [6:0] addr_counter, // Address counter for input/weight loading
    output reg wr_en,              // Write enable for output data
    output reg done,               // Completion signal
    output reg busy,                // FSM is busy
    output reg load_data, //to load data for systolic array
    output reg [6:0] load_addr_counter, //counter for loading data into systolic array
    input  done_multiply, //signal from systolic array indicating loading is done
    output reg [6:0] ht_counter, //counter for hidden state updates
    output reg inter_rst //reset signal for intermediate registers in systolic array
);

// ============================================================================
// FSM States
// ============================================================================

localparam [3:0] 
    IDLE           = 4'd0,
    LOAD_INPUT     = 4'd1,
    WAIT_FOR_INPUT   = 4'd2,
    LOAD    = 4'd3,
    LOAD_TO_SYSTOLIC_ARRAY = 4'd4,
    WAIT_DONE  = 4'd5,
    UPDATE_HT  = 4'd6,
    NEXT_TIMESTEP  = 4'd7,
    FC_LAYER      = 4'd8,
    DONE           = 4'd9;

reg [3:0] state, next_state;
reg [4:0] timestep;  // 5 bits to count up to 20 timesteps
reg [79:0] current_input; // Register to hold current input data for processing
 // Counter for input loading (0-4 for 5 inputs)
wire [15:0] input_mux_out; // Output from input multiplexer
wire [15:0] weights_fin;
 // ============================================================================
// Timestep Counter
// ============================================================================

localparam MAX_TIMESTEPS = 20;

// ============================================================================
// State Register
// ============================================================================

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

// ============================================================================
// Next State Logic
// ============================================================================

always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (start)
                next_state = LOAD_INPUT;  // Start loading input data
        end
        LOAD_INPUT: begin
            next_state = WAIT_FOR_INPUT;  // Wait for input data to be ready
        end
        WAIT_FOR_INPUT: begin
            next_state = LOAD;  // After loading input, move to processing
        end
        LOAD: begin
            if(addr_counter < 99) begin
                next_state = LOAD;
            end // Load all inputs and weights
            else begin
                next_state = LOAD_TO_SYSTOLIC_ARRAY; // After loading, perform multiplication
            end
        end
        LOAD_TO_SYSTOLIC_ARRAY: begin
            if(load_addr_counter < 99) begin
                next_state = LOAD_TO_SYSTOLIC_ARRAY;
            end else begin
                next_state = WAIT_DONE; // After loading, perform multiplication
            end
        end
        WAIT_DONE: begin
           if(done_multiply) begin
            next_state <= UPDATE_HT;
           end
           else begin
            next_state <= WAIT_DONE;
           end

        end
        
        UPDATE_HT: begin
            if(done_multiply) begin
                next_state = UPDATE_HT; // Wait for multiplication to complete
            end else begin
                next_state = NEXT_TIMESTEP; // Move to next timestep or FC layer
            end
        end
        NEXT_TIMESTEP: begin
            if (timestep < MAX_TIMESTEPS - 1)
                next_state = LOAD_INPUT;  // Go to next timestep
        else
                next_state = FC_LAYER; // After last timestep, output result

        end
        
        FC_LAYER: begin
        end
            
//        OUTPUT_RESULT: begin
//            next_state = DONE;
//        end
        
        DONE: begin
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

// ============================================================================
// Output Logic
// ============================================================================

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
        busy <= 1'b0;
        timestep <= 5'd0;
        addr_counter <= 7'd0;
        rd_input <= 1'b0;
        weight_addr <= 7'd0;
        wr_en <= 1'b0;
        load_data <= 1'b0;
        load_addr_counter <= 0;
        ht_counter <= 0;
        inter_rst <= 1'b0;

    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                busy <= 1'b0;
                timestep <= 5'd0;
                addr_counter <= 7'd0;

                rd_input <= 1'b0;
                weight_addr <= 7'd0;
                wr_en <= 1'b0;
                load_data <= 1'b0;
                 load_addr_counter <= 0;
                    ht_counter <= 0;
                    inter_rst <= 1'b0;
                if(start) begin
                    busy <= 1'b1;
                    rd_input <= 1'b1;  // Signal to read input data
                end

            end
            LOAD_INPUT: begin
                busy <= 1'b1;
                rd_input <= 1'b1;  // Signal to read input data
                inter_rst <= 1'b0; // Ensure intermediate registers are not reset during input loading
                
                

            end
            WAIT_FOR_INPUT: begin
                // Wait state to ensure input data is ready
                rd_input <= 1'b0; // Stop reading input data
                current_input <= input_data; // Capture input data for processing
                wr_en <= 1'b1; 
            end
            LOAD: begin
                busy <= 1'b1;
                 
                rd_input <= 1'b0; // Stop reading input data

                // Load initial input data for timestep 0the
                
                 if((addr_counter > 3) && (addr_counter < 99)) begin

                    weight_addr <= weight_addr + 1; // Increment weight address for loading
                 end
                    addr_counter <= addr_counter + 1; // Increment address counter

                if(addr_counter == 99) begin
                    wr_en <= 1'b0; // Stop writing after loading all data
                    addr_counter <= 7'd0; // Reset address counter for next phase
                    load_data <= 1'b1; // Signal to load data into systolic array
                    weight_addr <= 7'd0; // Reset weight address for next phase
                end
            end
            LOAD_TO_SYSTOLIC_ARRAY: begin

                load_addr_counter <= load_addr_counter + 1; // Increment load address counter
                if(load_addr_counter == 99) begin
                    load_data <= 1'b0; // Stop loading after all data is loaded
                    load_addr_counter <= 0; // Reset load address counter
                end
            end
            WAIT_DONE: begin
                
            end
                UPDATE_HT: begin
                    ht_counter <= ht_counter + 1; // Increment hidden state counter
                    if(!done_multiply) begin
                        ht_counter <= 0; // Reset hidden state counter after update
                    end
                end
            NEXT_TIMESTEP: begin
                if (timestep < MAX_TIMESTEPS - 1) begin
                    timestep <= timestep + 1; // Move to next timestep
                    addr_counter <= 0; // Reset address counter for next input loading
                    weight_addr <= 0; // Reset weight address for next loading
                    inter_rst <= 1'b1; // Reset intermediate registers for next timestep
                end else begin
                    timestep <= 0; // Reset timestep counter after last timestep
                     inter_rst <= 1'b0; // Deassert reset for intermediate registers
                     wr_en <= 1'b0; // Ensure write enable is low before FC layer
                     load_data <= 1'b0; // Ensure load data is low before FC layer
                     load_addr_counter <= 0; // Reset load address counter
                     ht_counter <= 0; // Reset hidden state counter
                     weight_addr <= 0; // Reset weight address for FC layer
                     addr_counter <= 0; // Reset address counter for FC layer
                    // After last timestep, prepare for FC layer or output result
                end
            end
//            OUTPUT_RESULT: begin
//                // Final output calculated here
//                done <= 1'b0;
//            end
            
            DONE: begin
                done <= 1'b1;
                busy <= 1'b0;
            end
            
            default: begin
                busy <= 1'b1;
                done <= 1'b0;
            end
        endcase
    end
end

mux_5to1 #(
    .DATA_WIDTH(16)
) input_mux (
    .data_in0(current_input[15:0]),
    .data_in1(current_input[31:16]),
    .data_in2(current_input[47:32]),
    .data_in3(current_input[63:48]),
    .data_in4(current_input[79:64]),
    .sel(addr_counter[2:0]), // Use lower 3 bits of addr_counter to select input
    .data_out(input_mux_out)
);
assign weights_fin = (timestep == 0) ? 0 : weights;
assign  output_data= (addr_counter < 5) ? input_mux_out : ((addr_counter > 4) && (addr_counter < 99))? weights_fin:16'b0000_0001_0000_0000; // Output either input data or weights based on addr_counter
endmodule
