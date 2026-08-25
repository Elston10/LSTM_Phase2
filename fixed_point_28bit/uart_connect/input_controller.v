
`timescale 1ns /1ps

module input_controller #(
    parameter OUTPUT_DATA_WIDTH = 140,  // UPDATED
    parameter ADDR_WIDTH = 5,
    parameter ACTUAL_DATA_WIDTH = 28,   // UPDATED
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
    output state_reach,
    input rx_done,
    input [7:0] rx_data,
    output reg clear_fifo
);

assign output_addr = 0;

// --- SOC REGISTERS (24-bit split) ---
reg [7:0] soc_reg_low;
reg [7:0] soc_reg_mid;
reg [7:0] soc_reg_high;
reg [7:0] done_reg;
reg [7:0] soc_reg_byte3;
// Acknowledgment counter
reg [4:0] ack_counter;

// FSM States
localparam IDLE                = 5'd0;
localparam POP                 = 5'd1;
localparam WAIT_DATA           = 5'd2;
localparam OUTPUT_READY        = 5'd3;
localparam ACK_COUNT           = 5'd4;
localparam WAIT_TX_ACK         = 5'd5;
localparam WAIT_FOR_LSTM_DONE  = 5'd6;
localparam TX_DONE_BYTE        = 5'd7;
localparam WAIT_TX_DONE        = 5'd8;
localparam TX_SOC_LOW          = 5'd9;
localparam WAIT_TX_SOC_LOW     = 5'd10;
localparam TX_SOC_MID          = 5'd11;   // NEW
localparam WAIT_TX_SOC_MID     = 5'd12;   // NEW
localparam TX_SOC_HIGH         = 5'd13;
localparam WAIT_TX_SOC_HIGH    = 5'd14;
localparam FINISH              = 5'd15;
localparam SOC_LOW_ACK       = 5'd16;
localparam SOC_MID_ACK       = 5'd17;
localparam SOC_HIGH_ACK       = 5'd18;

reg [4:0] state, next_state;
reg [4:0] pop_counter;
reg [139:0] combined_data;   // UPDATED

//assign state_reach = (ack_counter == 19);

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
            if (pop_counter == 17)   // UPDATED (15 bytes)
                next_state = OUTPUT_READY;
            else
                next_state = POP;

        OUTPUT_READY:
            next_state = ACK_COUNT;

        ACK_COUNT:
            if (ack_counter == 19)
                next_state = WAIT_FOR_LSTM_DONE;
            else
                next_state = WAIT_TX_ACK;

        WAIT_TX_ACK:
            if (tx_done)
                next_state = IDLE;

        WAIT_FOR_LSTM_DONE:
            if (lstm_done)
                next_state = TX_DONE_BYTE;

        TX_DONE_BYTE:
            next_state = WAIT_TX_DONE;

        WAIT_TX_DONE:
            if (tx_done)
                next_state = TX_SOC_LOW;

        TX_SOC_LOW:
            next_state = SOC_LOW_ACK;
        SOC_LOW_ACK: begin
        if(rx_done && (rx_data == 8'h01))begin
            next_state = TX_SOC_MID;
            end
            else next_state = SOC_LOW_ACK;
            end

//        WAIT_TX_SOC_LOW:
//            if (tx_done)
//                next_state = TX_SOC_MID;

        TX_SOC_MID:
            next_state = SOC_MID_ACK;
        SOC_MID_ACK: begin
        if(rx_done && (rx_data == 8'h01))begin
            next_state = TX_SOC_HIGH;
            end
            else next_state = SOC_MID_ACK;
            end
//        WAIT_TX_SOC_MID:
//            if (tx_done)
//                next_state = TX_SOC_HIGH;

        TX_SOC_HIGH:
            next_state = SOC_HIGH_ACK;
        SOC_HIGH_ACK: begin
        if(rx_done && (rx_data == 8'h01))begin
            next_state = FINISH;
            end
            else next_state = SOC_HIGH_ACK;
            end
//        WAIT_TX_SOC_HIGH:
//            if (tx_done)
//                next_state = FINISH;

        FINISH:
            next_state = IDLE;

        default: next_state = IDLE;
    endcase
end

//------------------------------------------------
// Datapath logic
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
        soc_reg_mid   <= 0;
        soc_reg_high  <= 0;
        done_reg      <= 0;
        ack_counter   <= 0;
        clear_fifo <= 0;
    end
    else begin
        case (state)

            IDLE: 
            begin
                pop_counter   <= 0;
                done          <= 0;
                combined_data <= 0;
                output_data   <= 0;
                soc_reg_low   <= 0;
                soc_reg_mid   <= 0;
                soc_reg_high  <= 0;
                tx_start      <= 0;
                pop_fifo      <= 0;
                wr_en         <= 0;
                tx_data<=0;
                clear_fifo <= 0;
            end

            POP: 
            begin
                pop_fifo <= 1;
            end

            WAIT_DATA: 
            begin
                pop_fifo <= 0;

                case (pop_counter)

    // First 17 bytes → direct mapping
    5'd0:  combined_data[7:0]     <= input_data;
    5'd1:  combined_data[15:8]    <= input_data;
    5'd2:  combined_data[23:16]   <= input_data;
    5'd3:  combined_data[31:24]   <= input_data;
    5'd4:  combined_data[39:32]   <= input_data;
    5'd5:  combined_data[47:40]   <= input_data;
    5'd6:  combined_data[55:48]   <= input_data;
    5'd7:  combined_data[63:56]   <= input_data;
    5'd8:  combined_data[71:64]   <= input_data;
    5'd9:  combined_data[79:72]   <= input_data;
    5'd10: combined_data[87:80]   <= input_data;
    5'd11: combined_data[95:88]   <= input_data;
    5'd12: combined_data[103:96]  <= input_data;
    5'd13: combined_data[111:104] <= input_data;
    5'd14: combined_data[119:112] <= input_data;
    5'd15: combined_data[127:120] <= input_data;
    5'd16: combined_data[135:128] <= input_data;

    // LAST BYTE → only lower 4 bits valid
    5'd17: combined_data[139:136] <= input_data[3:0];

endcase

                pop_counter <= pop_counter + 1;
            end

            OUTPUT_READY: 
            begin
                output_data <= combined_data;
                wr_en       <= 1;
                done        <= 1;
            end

            ACK_COUNT: 
            begin
                wr_en <= 0;
                done  <= 0;
                tx_start <= 1;
                tx_data  <= 8'b0000_0001; // ACK
            end

            WAIT_TX_ACK: 
            begin
                tx_start <= 0;
                if (tx_done)
                    ack_counter <= ack_counter + 1;
            end

            WAIT_FOR_LSTM_DONE: 
            begin
            tx_start <= 0;
                ack_counter <= 0;
                if (lstm_done) 
                begin
soc_reg_low   <= soc[7:0];
soc_reg_mid   <= soc[15:8];
soc_reg_high  <= soc[23:16];
soc_reg_byte3 <= {4'b0000, soc[27:24]};
                    done_reg     <= 1;
                end
            end

            TX_DONE_BYTE: 
            begin
                tx_data  <= 8'b0000_0010;
                tx_start <= 1;
            end

            WAIT_TX_DONE: 
            begin
                tx_start <= 0;
            end

            TX_SOC_LOW: 
            begin
                tx_data  <= soc_reg_low;
                tx_start <= 1;
            end
            SOC_LOW_ACK: 
            begin
            tx_start <= 0;
            end
//            WAIT_TX_SOC_LOW: 
//            begin
                
//            end

            TX_SOC_MID: 
            begin
                tx_data  <= soc_reg_mid;
                tx_start <= 1;
            end
            SOC_MID_ACK: 
            begin
            tx_start <= 0;
            end
//            WAIT_TX_SOC_MID: 
//            begin
//                tx_start <= 0;
//            end

            TX_SOC_HIGH: 
            begin
                tx_data  <= soc_reg_high;
                tx_start <= 1;
            end
            SOC_HIGH_ACK: 
            begin
            tx_start <= 0;
            end
//            WAIT_TX_SOC_HIGH: 
//            begin
//                tx_start <= 0;
//            end

            FINISH: 
            begin
                 clear_fifo <= 1'b1;
                ack_counter <= 0;
            end

        endcase
    end
end
assign state_reach = (state ==  TX_SOC_MID);
endmodule
