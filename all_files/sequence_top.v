module top  (
   input clk,
   input rst_n,
   input start,
   output done,
   output [15:0] final_output

);

wire [79:0] input_data; // 80-bit input data for each timestep
wire [15:0] weights;    // 16-bit weights read from memory
wire [15:0] output_data; // 16-bit output data from the LSTM controller
wire rd_input;        // Read enable for input buffer
wire [6:0] weight_addr; // Address for weight memory
wire [6:0] addr_counter; // Address counter for input/weight loading
wire wr_en;           // Write enable for output data
wire [6:0] load_addr_counter; // Counter for loading data into systolic array
wire done_multiply;   // Signal from systolic array indicating loading is done
wire load_data;       // Signal to load data for systolic array
wire [15:0] mul_rd_data;
wire [6:0] ht_counter; // Counter for hidden state updates
wire [15:0] ht_output; // Output from hidden state memory to multiplier
wire inter_rst;
wire [6:0] final_addr_ht; // Final address for hidden state memory access
wire start_fc_layer; // Signal to start FC layer processing
wire fc_done; // Signal from FC layer indicating completion
wire sel_fc; // Select signal for mux to choose between weight_addr and addr_fc
wire [6:0] addr_fc; // Address for FC layer weight/bias access
wire [15:0] ht_data; // Data read from hidden state memory for FC layer

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
    .sel_fc(sel_fc)
);
sync_fifo #(
    .DATA_WIDTH(80),
    .DEPTH(20),
    .ADDR_WIDTH(5),
    .INIT_COUNT(20)
) input_buffer (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(),
    .rd_en(rd_input), // Always ready to read for simplicity
    .wr_data(), // Connect to input data source
    .rd_data(input_data), // Connect to LSTM controller
    .full(),
    .empty()
);
memory_94x16 ht_mem (
    .clk(clk),
    .rst(),
    .wr_en(done_multiply),
    .wr_addr(ht_counter),
    .wr_data(ht_output),
    .rd_en(1),
    .rd_addr(final_addr_ht),
    .rd_data(ht_data)
);
memory_100x16 data_mem (
    .clk(clk),
    .rst(),
    .wr_en(wr_en),
    .wr_addr(addr_counter),
    .wr_data(output_data),
    .rd_en(1),
    .rd_addr(load_addr_counter),
    .rd_data(mul_rd_data)
);

top_multiplier #(
    .DATA_WIDTH(16),
    .OUTPUT_WIDTH(16),
    .ADDR_WIDTH(16),
    .TILE_ADDR_WIDTH(3),
    .MATRIX_ROWS(376),
    .WEIGHT_MEM_SIZE(37600),
    .DATA_MEM_SIZE(94),
    .MATRIX_COLS(100),
    .DATA_TILE_WIDTH(2),
    .DATA_VECTOR_LENGTH(100),
    .TILE_WIDTH(4)
) multiplier (
    .clk(clk),
    .rst_n(rst_n),
    .we(load_data),
    .data_in(mul_rd_data),
    .gb_data_addr(load_addr_counter),
    .ht_output(ht_output),
    .done_data(done_multiply),
    .inter_rst(inter_rst)
);

fc_pe #(
    .DATA_WIDTH(16),
    .WEIGHT_WIDTH(16),
    .BIAS_WIDTH(16),
    .OUTPUT_WIDTH(16),
    .HIDDEN_SIZE(94)
) fc_processor (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_fc_layer),
    .ht_in(ht_data),
    .weight_in(weights),
    .bias_in(16'b0000000000011101), // Example bias value
    .addr(addr_fc),
    .done(fc_done),
    .fc_out(final_output)
);
fc_weight_bram #(
    .DATA_WIDTH(16),
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

endmodule
