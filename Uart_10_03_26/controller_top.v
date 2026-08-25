`timescale 1ns / 1ps
    module fifo_input_system #(
        parameter DATA_SIZE = 8,
        parameter ADDR_SPACE_EXP = 4,
        parameter OUTPUT_DATA_WIDTH = 80,
        parameter ADDR_WIDTH = 5
    ) (
        input clk,
        input rst_n,
        input rx,                              // Start popping and combining
        output state_reach,tx,
        input lstm_done
    );
    wire tx_start;
    wire fifo_full;
    wire done;
    wire wr_en;
    wire fifo_empty;
    wire sync_fifo_empty;
    wire [DATA_SIZE-1:0] tx_data_in;
    wire [ADDR_WIDTH-1:0] output_addr;
    wire [OUTPUT_DATA_WIDTH-1:0] output_data;
        // Internal signals
        wire read_from_fifo;
        wire [DATA_SIZE-1:0] fifo_data_out;
        wire [7:0] rx_data;
        wire rx_done;
        wire sample_tick;
        wire tx_done;

        
        // Convert active-low reset to active-high for FIFO
        // assign reset = !rst_n;

     // Baud rate generator instance
    baud_rate_generator #(
        .N(7),
        .M(68)                      // 125MHz / (115200 * 16) â‰ˆ 68
    ) baud_gen (
        .clk_125MHz(clk),
        .reset(~rst_n),
        .tick(sample_tick)
    );

    
    // UART receiver instance
    uart_receiver #(
        .DBITS(8),
        .SB_TICK(16)
    ) uart_rx (
        .clk_125MHz(clk),
        .reset(~rst_n),
        .rx(rx),
        .sample_tick(sample_tick),
        .data_ready(rx_done),
        .data_out(rx_data)
    );


        // FIFO instance (pre-filled with 10 values)
        fifo #(
            .DATA_SIZE(DATA_SIZE),
            .ADDR_SPACE_EXP(ADDR_SPACE_EXP)
        ) u_fifo (
            .clk(clk),
            .reset(~rst_n),
            .write_to_fifo(rx_done),              // No writing in this system
            .read_from_fifo(read_from_fifo),
            .write_data_in(rx_data),              // Not used
            .read_data_out(fifo_data_out),
            .fifo_empty(fifo_empty),
            .fifo_full(fifo_full)
        );
        
        // Input controller instance
        input_controller #(
            .OUTPUT_DATA_WIDTH(OUTPUT_DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .INPUT_DATA_WIDTH(DATA_SIZE)
        ) u_input_controller (
            .clk(clk),
            .start(fifo_full),
            .rst_n(~rst_n),
            .input_data(fifo_data_out),
            .pop_fifo(read_from_fifo),
            .output_addr(output_addr),                    // Not used
            .output_data(output_data),
            .done(done),
            .wr_en(wr_en),
            .tx_start(tx_start),
            .tx_data(tx_data_in),
            .lstm_done(lstm_done), // Not used in this system
            .soc(16'hAABB) ,           // Not used in this system
            .tx_done(tx_done)  ,         // Not used in this system
            .state_reach(state_reach)  // Not used in this system
        );
    sync_fifo #(
        .DATA_WIDTH(OUTPUT_DATA_WIDTH),
        .DEPTH(20),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_sync_fifo (
        .clk(clk),
        .rst_n(~rst_n),
        .wr_en(wr_en),
        .rd_en(1'b0), // No reading in this system
        .wr_data(output_data),
        .rd_data(), // Not used
        .full(sync_fifo_full),   // separate wire – avoids multi-driver on fifo_full
        .empty(sync_fifo_empty)
    );
   uart_transmitter #(
        .DBITS(8),
        .SB_TICK(16)
    ) uart_tx (
        .clk_125MHz(clk),
        .reset(~rst_n),
        .tx_start(tx_start),          // Start transmission when data is written to sync FIFO
        .sample_tick(sample_tick),
        .data_in(tx_data_in), // Transmit only the least significant byte
        .tx_done(tx_done),               // Not used in this system
        .tx(tx)             // Not connected to anything in this system
    );  

    endmodule
