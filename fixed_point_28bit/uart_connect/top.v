`timescale 1ns / 1ps
module top_system(
    input clk_125Mhz,
    input rst,
    input rx,
    output tx,
    output state_reach,
    output state_reach2
);

// -------- Interconnect wires --------
wire [139:0] data_bus;
wire start_lstm;
wire lstm_done;
wire rd_en;
wire [27:0] soc_out;
wire clear_fifo;
// ----------------------------------
// FIFO INPUT SYSTEM
// ----------------------------------
fifo_input_system u_fifo_system (
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .tx(tx),

    .lstm_done(lstm_done),     // from sequence_top
    .lstm_start(start_lstm),   // to sequence_top

    .rd_data(data_bus),        // to sequence_top
    .rd_en(rd_en),             // from sequence_top

    .SOC(soc_out),             // from sequence_top
    .reach_ff(state_reach),
                 // optional debug
    .reach_ff2(),
    .clear_fifo(clear_fifo)
);

// ----------------------------------
// LSTM / SEQUENCE BLOCK
// ----------------------------------
sequence_top u_sequence (
    .clk(clk),
    .rst(rst),

    .start(start_lstm),        // START from FIFO system
    .done(lstm_done),          // DONE to FIFO system

    .SOC(soc_out),             // output SOC

    .input_data(data_bus),     // 120-bit input
    .rd_input(rd_en)  ,         // request next data
    .cleared(state_reach2),
    .clear_fifo(clear_fifo)
);
clk_wiz_0 u_clk_wiz_0 (
    .clk_out1(clk),   // Output clock
    .reset(),         // Reset input
    .locked(locked),       // Locked status output
    .clk_in1(clk_125Mhz)      // Input clock
);
//assign state_reach2 = (24'h01f3f3 == soc_out);
endmodule
