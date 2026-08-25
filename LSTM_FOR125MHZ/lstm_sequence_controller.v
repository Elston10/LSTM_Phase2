// LSTM Sequence Controller FSM - 20 Timesteps
`timescale 1ns/1ps

module lstm_sequence_controller (
    input  clk,
    input  rst_n,
    input  start,                  // Start signal
    input  [119:0] input_data,     // 5 inputs x 24 bits = 120 bits
    output reg rd_input,
    input  [23:0] weights,         // Weights for the LSTM (packed as needed)
    output reg [6:0] weight_addr,  // Address for weight memory (0-93)
    output [23:0] output_data,     // Final output after FC layer
    output reg [6:0] addr_counter, // Address counter for input/weight loading
    output reg wr_en,              // Write enable for output data
    output reg done,               // Completion signal
    output reg busy,               // FSM is busy
    output reg load_data,          // to load data for systolic array
    output reg [6:0] load_addr_counter, // counter for loading data into systolic array
    input  done_multiply,          // signal from systolic array indicating loading is done
    output reg [6:0] ht_counter,   // counter for hidden state updates
    output reg inter_rst,          // reset signal for intermediate registers in systolic array
    output reg start_fc_layer,     // signal to start FC layer processing
    input fc_done,                 // signal from FC layer indicating completion
    output reg sel_fc ,             // select signal for mux to choose between weight_addr and addr_fc
    input [23:0] fc_output,        // Output from FC layer
    output reg [23:0] SOC           // Final output register to hold FC layer result
);

// ============================================================================
// FSM States
// ============================================================================

localparam [3:0] 
    IDLE           = 4'd0,
    LOAD_INPUT     = 4'd1,
    WAIT_FOR_INPUT = 4'd2,
    LOAD           = 4'd3,
    LOAD_TO_SYSTOLIC_ARRAY = 4'd4,
    WAIT_DONE      = 4'd5,
    UPDATE_HT      = 4'd6,
    NEXT_TIMESTEP  = 4'd7,
    FC_LAYER       = 4'd8,
    DONE           = 4'd9,
    WAIT_UPDATE_HT = 4'd10,
    WAIT_FC_LAYER = 4'd11;

reg [3:0] state, next_state;
reg [4:0] timestep;  // 5 bits to count up to 20 timesteps
reg [119:0] current_input; // Register to hold current input data for processing
// Counter for input loading (0-4 for 5 inputs)
wire [23:0] input_mux_out; // Output from input multiplexer
wire [23:0] weights_fin;
// ============================================================================
// Timestep Counter
// ============================================================================

localparam MAX_TIMESTEPS = 20;

// ============================================================================
// State Register
// ============================================================================

always @(posedge clk ) begin
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
            next_state = WAIT_UPDATE_HT;
           end
           else begin
            next_state = WAIT_DONE;
           end

        end
        WAIT_UPDATE_HT: begin
        next_state = UPDATE_HT;
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

                next_state = WAIT_FC_LAYER; // After FC layer is done, signal completion
end
        WAIT_FC_LAYER: begin
            if(fc_done) begin
                next_state = DONE; // After FC layer is done, signal completion
            end else begin
                next_state = WAIT_FC_LAYER; // Wait for FC layer to complete
            end
        end
            
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
        SOC <= 24'h0;
        sel_fc <= 0;
        start_fc_layer <= 0;

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

                sel_fc <= 0;
                start_fc_layer <= 0;

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
                if(done_multiply) begin
                    ht_counter <= ht_counter + 1;
                end
                else begin
                    ht_counter <= 0;
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
                end
            end
            FC_LAYER: begin
                start_fc_layer <= 1'b1; // Signal to start FC layer processing
                busy <= 1'b1;
                inter_rst <= 1'b0; // Ensure intermediate registers are not reset during input loading
                sel_fc <= 1'b1; // Select FC layer address for weight access
            end
            WAIT_FC_LAYER: begin
                // Wait for FC layer to complete
                if(fc_done) begin
                    SOC <= fc_output; // Capture FC layer output
                end
            end
            DONE: begin
                done <= 1'b1;
                busy <= 1'b0;
            end
            default: begin
                busy <= 1'b0;
                done <= 1'b0;
            end
        endcase
    end
end

mux_5to1 #(
    .DATA_WIDTH(24)
) input_mux (
    .data_in0(current_input[23:0]),
    .data_in1(current_input[47:24]),
    .data_in2(current_input[71:48]),
    .data_in3(current_input[95:72]),
    .data_in4(current_input[119:96]),
    .sel(addr_counter[2:0]), // Use lower 3 bits of addr_counter to select input
    .data_out(input_mux_out)
);

assign weights_fin = (timestep == 0) ? 0 : weights;
assign output_data = (addr_counter < 5) ? input_mux_out : ((addr_counter > 4) && (addr_counter < 99)) ? weights_fin : 24'h100000; // Output either input data or weights based on addr_counter

endmodule