`timescale 1ns/1ps

module sequence_top  (
   input clk_125Mhz,
   input rst,
   input start,
   output reg done_ff,
   output [2:0] SOC

);

// 5 x 24 = 120 bits for input_data
wire [119:0] input_data; // 120-bit input data for each timestep
wire [23:0] weights;     // 24-bit weights read from memory
wire [23:0] output_data; // 24-bit output data from the LSTM controller
wire rd_input;
wire [6:0] weight_addr;
wire [6:0] addr_counter;
wire wr_en;
wire [6:0] load_addr_counter;
wire done_multiply;
wire load_data;
wire [23:0] mul_rd_data;
wire [6:0] ht_counter;
wire [23:0] ht_output;
wire inter_rst;
wire [6:0] final_addr_ht;
wire start_fc_layer;
wire fc_done;
wire sel_fc;
wire [6:0] addr_fc;
wire [23:0] ht_data;
wire [6:0] ht_write_addr;
wire wr_en_ht;
wire rst_n,match;
wire [23:0] SOC_out;
wire locked,busy;
wire [23:0] final_output; // Store FC layer output for next timestep
// wire [DATA_WIDTH-1:0] final_output; // Store FC layer output for next timestep

wire clk;

always @(posedge clk ) begin
    if (!rst_n)
        done_ff <= 1'b0;
    else if(match)
        done_ff <= 1'b1;
end



assign rst_n = rst;
assign SOC = SOC_out[2:0]; 
clk_wiz_0 u_clk_wiz_0 (
    .clk_out1(clk),   // Output clock
    .reset(),         // Reset input
    .locked(locked),       // Locked status output
    .clk_in1(clk_125Mhz)      // Input clock
);


lstm_sequence_controller lstm_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .input_data(input_data),
    .rd_input(rd_input),
    .weights(ht_data),
    .weight_addr(weight_addr),
    .output_data(output_data),
    .addr_counter(addr_counter),
    .wr_en(wr_en),
    .done(done),
    .busy(busy),
    .load_data(load_data),
    .load_addr_counter(load_addr_counter),
    .done_multiply(done_multiply),
    .ht_counter(ht_counter),
    .inter_rst(inter_rst),
    .start_fc_layer(start_fc_layer),
    .fc_done(fc_done),
    .sel_fc(sel_fc),
    .fc_output(final_output),
    .SOC(SOC_out)
);

sync_fifo #(
    .DATA_WIDTH(120), // 5 x 24 bits
    .DEPTH(20),
    .ADDR_WIDTH(5),
    .INIT_COUNT(20)
) input_buffer (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(0),
    .rd_en(rd_input),
    .wr_data(0),
    .rd_data(input_data),
    .full(),
    .empty()
);

memory_94x16 ht_mem (
    .clk(clk),
    .rst(rst_n),
    .wr_en(wr_en_ht),
    .wr_addr(ht_write_addr),
    .wr_data(ht_output),
    .rd_en(1'b1),
    .rd_addr(final_addr_ht),
    .rd_data(ht_data),
    .match()
);

memory_100x16 data_mem (
    .clk(clk),
    .rst(rst_n),
    .wr_en(wr_en),
    .wr_addr(addr_counter),
    .wr_data(output_data),
    .rd_en(1'b1),
    .rd_addr(load_addr_counter),
    .rd_data(mul_rd_data)
);

top #(
    .DATA_WIDTH(24),
    .OUTPUT_WIDTH(24),
    .ADDR_WIDTH(16),
    .TILE_ADDR_WIDTH(3),
    .MATRIX_ROWS(376),
    .WEIGHT_MEM_SIZE(37600),
    .DATA_MEM_SIZE(94),
    .MATRIX_COLS(100),
    .DATA_TILE_WIDTH(2),
    .DATA_VECTOR_LENGTH(100),
    .TILE_WIDTH(4)
) top_mul (
    .clk(clk),
    .rst_n(rst_n),
    .we(load_data),
    .data_in(mul_rd_data),
    .gb_data_addr(load_addr_counter),
    .ht_result(ht_output),
    .ew_done(done_multiply),
    .inter_rst(inter_rst),
    .ew_write_addr(ht_write_addr),
    .we_result(wr_en_ht),
    .match(match)
);

fc_pe #(
    .DATA_WIDTH(24),
    .WEIGHT_WIDTH(24),
    .BIAS_WIDTH(24),
    .OUTPUT_WIDTH(24),
    .HIDDEN_SIZE(94)
) fc_processor (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_fc_layer),
    .ht_in(ht_data),
    .weight_in(weights),
    .bias_in(24'h01D7F7), // Example bias value (24 bits)
    .addr(addr_fc),
    .done(fc_done),
    .fc_out(final_output)
);

fc_weight_bram #(
    .DATA_WIDTH(24),
    .ADDR_WIDTH(7),
    .MEM_SIZE(94)
) weight_bram (
    .clk(clk),
    .rst_n(rst_n),
    .addr(addr_fc),
    .dout(weights)
);

mux_2_1_16bit mux (
    .a(weight_addr),
    .b(addr_fc),
    .sel(sel_fc),
    .out(final_addr_ht)
);
//assign SOC_MATCH = (24'h01F3F == SOC);
endmodule