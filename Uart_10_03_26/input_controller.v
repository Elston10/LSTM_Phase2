`timescale 1ns /1ps

module input_controller #(
    parameter OUTPUT_DATA_WIDTH = 80,
    parameter ADDR_WIDTH = 5,
    parameter ACTUAL_DATA_WIDTH = 16,
    parameter INPUT_DATA_WIDTH = 8
)(
    input clk,
    input start,
    input rst_n,
    input lstm_done,
    input tx_done,
    input [ACTUAL_DATA_WIDTH-1:0] soc,
    input [INPUT_DATA_WIDTH-1:0] input_data,
    output reg pop_fifo,
    output [ADDR_WIDTH-1:0] output_addr,
    output reg [OUTPUT_DATA_WIDTH-1:0] output_data,
    output reg done,
    output reg wr_en,
    output reg tx_start,
    output reg [INPUT_DATA_WIDTH-1:0] tx_data,
    output state_reach
);

assign output_addr = 0;

reg [INPUT_DATA_WIDTH-1:0] soc_reg_low;
reg [INPUT_DATA_WIDTH-1:0] soc_reg_high;
reg [INPUT_DATA_WIDTH-1:0] done_reg;

// Acknowledgment counter (counts 0..19)
reg [4:0] ack_counter;

// FSM States
localparam IDLE                = 4'd0;
localparam POP                 = 4'd1;
localparam WAIT_DATA           = 4'd2;
localparam OUTPUT_READY        = 4'd3;
localparam ACK_COUNT           = 4'd4;  // count ack until 19
localparam WAIT_FOR_LSTM_DONE  = 4'd5;  // wait for lstm_done after 19 acks
localparam TX_DONE_BYTE        = 4'd6;  // 1st: send done byte
localparam WAIT_TX_DONE        = 4'd7;
localparam TX_SOC_LOW          = 4'd8;  // 2nd: send soc[7:0]
localparam WAIT_TX_SOC_LOW     = 4'd9;
localparam TX_SOC_HIGH         = 4'd10; // 3rd: send soc[15:8]
localparam WAIT_TX_SOC_HIGH    = 4'd11;
localparam FINISH              = 4'd12;

reg [3:0] state, next_state;
reg [3:0] pop_counter;
reg [79:0] combined_data;

assign state_reach  = (state == WAIT_FOR_LSTM_DONE);

//------------------------------------------------
// State register
//------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

//------------------------------------------------
// Next state logic
//------------------------------------------------
always @(*) begin
    next_state = state;
    case (state)

        IDLE:
            if (start)
                next_state = POP;

        POP:
            next_state = WAIT_DATA;

        WAIT_DATA:
            if (pop_counter == 9)
                next_state = OUTPUT_READY;
            else
                next_state = POP;

        OUTPUT_READY:
            next_state = ACK_COUNT;

        // --- Acknowledgment counter ---
        // stays here until ack_counter == 19
        // before 19 -> back to IDLE each cycle (keeps looping POP..OUTPUT_READY)
        // after  19 -> go to WAIT_FOR_LSTM_DONE
        ACK_COUNT:
            if (ack_counter == 19)
                next_state = WAIT_FOR_LSTM_DONE;
            else
                next_state = IDLE;   // loop back until 19 acks

        WAIT_FOR_LSTM_DONE:
            if (lstm_done)
                next_state = TX_DONE_BYTE;

        // --- 1st: Transmit done byte ---
        TX_DONE_BYTE:
            next_state = WAIT_TX_DONE;

        WAIT_TX_DONE:
            if (tx_done)
                next_state = TX_SOC_LOW;

        // --- 2nd: Transmit soc[7:0] ---
        TX_SOC_LOW:
            next_state = WAIT_TX_SOC_LOW;

        WAIT_TX_SOC_LOW:
            if (tx_done)
                next_state = TX_SOC_HIGH;

        // --- 3rd: Transmit soc[15:8] ---
        TX_SOC_HIGH:
            next_state = WAIT_TX_SOC_HIGH;

        WAIT_TX_SOC_HIGH:
            if (tx_done)
                next_state = FINISH;

        FINISH:
            next_state = IDLE;

        default: next_state = IDLE;
    endcase
end

//------------------------------------------------
// Output / Datapath logic
//------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pop_counter   <= 0;
        pop_fifo      <= 0;
        combined_data <= 0;
        output_data   <= 0;
        tx_start      <= 0;
        tx_data       <= 0;
        done          <= 0;
        wr_en         <= 0;
        soc_reg_low   <= 0;
        soc_reg_high  <= 0;
        done_reg      <= 0;
        ack_counter   <= 0;
    end
    else begin
        // Default: deassert pulses


        case (state)

            IDLE: begin
                pop_counter   <= 0;
                done          <= 0;
                combined_data <= 0;
                output_data   <= 0;
                soc_reg_low   <= 0;
                soc_reg_high  <= 0;
                done_reg      <= 0;
                        tx_start <= 0;
        pop_fifo <= 0;
        wr_en    <= 0;

            end

            POP: begin
                pop_fifo <= 1;
            end

            WAIT_DATA: begin
                pop_fifo <= 0; // deassert pop after one cycle
                case (pop_counter)
                    4'd0: combined_data[7:0]   <= input_data;
                    4'd1: combined_data[15:8]  <= input_data;
                    4'd2: combined_data[23:16] <= input_data;
                    4'd3: combined_data[31:24] <= input_data;
                    4'd4: combined_data[39:32] <= input_data;
                    4'd5: combined_data[47:40] <= input_data;
                    4'd6: combined_data[55:48] <= input_data;
                    4'd7: combined_data[63:56] <= input_data;
                    4'd8: combined_data[71:64] <= input_data;
                    4'd9: combined_data[79:72] <= input_data;
                endcase
                pop_counter <= pop_counter + 1;
            end

            OUTPUT_READY: begin
                pop_fifo      <= 0;
                output_data <= combined_data;
                wr_en       <= 1;
                done        <= 1;
            end

            // --- Acknowledgment counter ---
            ACK_COUNT: begin
                wr_en <= 0;
                done  <= 0;
                tx_start <= 1;
                tx_data <= 8'b0000_0001; // ACK byte
                if (ack_counter < 19)
                    ack_counter <= ack_counter + 1;
            end

            WAIT_FOR_LSTM_DONE: begin
                ack_counter <= 0; // reset ack counter for next round
                if(lstm_done) begin
                    soc_reg_low  <= soc[7:0];
                    soc_reg_high <= soc[15:8];
                    done_reg     <= 1; // can be any non-zero value to indicate "done"
                end
            end

            // --- 1st: Send done byte ---
            TX_DONE_BYTE: begin
                tx_data  <= 8'b0000_0010;
                tx_start <= 1;
            end

            WAIT_TX_DONE: begin
                tx_start <= 0;
            end

            // --- 2nd: Send soc[7:0] ---
            TX_SOC_LOW: begin
                tx_data  <= soc_reg_low;
                tx_start <= 1;
            end

            WAIT_TX_SOC_LOW: begin
                tx_start <= 0;
            end

            // --- 3rd: Send soc[15:8] ---
            TX_SOC_HIGH: begin
                tx_data  <= soc_reg_high;
                tx_start <= 1;
            end

            WAIT_TX_SOC_HIGH: begin
                tx_start <= 0;
            end

            FINISH: begin
                ack_counter <= 0;       // reset for next round

            end

        endcase
    end
end

endmodule