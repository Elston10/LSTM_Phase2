`timescale 1ns/1ps
module mvm #(
    parameter DATA_WIDTH = 16,
    parameter OUTPUT_WIDTH = 16
)(
    input clk,
    input rst_n,
    input start,
    input [1:0] data_sel,
    input [DATA_WIDTH-1:0] data_in,
    input [DATA_WIDTH-1:0] weight_1, weight_2, weight_3, weight_4,
    output wire [OUTPUT_WIDTH-1:0] out1, out2, out3, out4,
    output wire done,done_row1,done_row2,done_row3,
    output wire en_diag0_out, en_diag1_out, en_diag2_out, en_diag3_out,en_diag4_out,en_diag5_out,en_diag6_out
);

// Internal done signal from PE16
wire done_pe16;
assign done=done_pe16;
// Diagonal enable signals (7 diagonals across the 4x4 array)
reg en_diag0;  // PE1 - controlled internally
reg en_diag1;  // PE2, PE5
reg en_diag2;  // PE3, PE6, PE9
reg en_diag3;  // PE4, PE7, PE10, PE13
reg en_diag4;  // PE8, PE11, PE14
reg en_diag5;  // PE12, PE15
reg en_diag6;  // PE16

// Output diagonal enables for weight/data control in top
assign en_diag0_out = en_diag0;
assign en_diag1_out = en_diag1;
assign en_diag2_out = en_diag2;
assign en_diag3_out = en_diag3;
assign en_diag4_out = en_diag4;
assign en_diag5_out = en_diag5;
assign en_diag6_out = en_diag6;
// Internal data column wires
wire [DATA_WIDTH-1:0] data_col1, data_col2, data_col3, data_col4;
// Demux instantiation to distribute data to columns
demux1to4 #(.DATA_WIDTH(DATA_WIDTH)) demux_data(
    .data_in(data_in),
    .data_sel(data_sel),
    .enable(start),
    .data_out1(data_col1),
    .data_out2(data_col2),
    .data_out3(data_col3),
    .data_out4(data_col4)
);

// Row-wise partial sum accumulation (LEFT to RIGHT) - results accumulate across rows
wire [OUTPUT_WIDTH-1:0] partial_sum_1_to_2, partial_sum_2_to_3, partial_sum_3_to_4;       // Row 1
wire [OUTPUT_WIDTH-1:0] partial_sum_5_to_6, partial_sum_6_to_7, partial_sum_7_to_8;       // Row 2
wire [OUTPUT_WIDTH-1:0] partial_sum_9_to_10, partial_sum_10_to_11, partial_sum_11_to_12;  // Row 3
wire [OUTPUT_WIDTH-1:0] partial_sum_13_to_14, partial_sum_14_to_15, partial_sum_15_to_16; // Row 4

//Data wires from PEs (for forwarding if needed)
wire [DATA_WIDTH-1:0] fwd_pe_1_to_5, fwd_pe_2_to_6, fwd_pe_3_to_7, fwd_pe_4_to_8;
wire [DATA_WIDTH-1:0] fwd_pe_5_to_9, fwd_pe_6_to_10, fwd_pe_7_to_11, fwd_pe_8_to_12;
wire [DATA_WIDTH-1:0] fwd_pe_9_to_13, fwd_pe_10_to_14, fwd_pe_11_to_15, fwd_pe_12_to_16;    

// Done signal wires for interdependence control (LEFT to RIGHT in each row)
wire done_1_to_2, done_2_to_3, done_3_to_4;       // Row 1
wire done_5_to_6, done_6_to_7, done_7_to_8;       // Row 2
wire done_9_to_10, done_10_to_11, done_11_to_12;  // Row 3
wire done_13_to_14, done_14_to_15, done_15_to_16; // Row 4

// Computing signals - high when add_res is computed (before partial_out registers)
wire computing_1, computing_2, computing_3, computing_4;       // Row 1
wire computing_5, computing_6, computing_7, computing_8;       // Row 2
wire computing_9, computing_10, computing_11, computing_12;    // Row 3
wire computing_13, computing_14, computing_15, computing_16;   // Row 4

// Final done outputs from each row
wire done_row1, done_row2, done_row3, done_row4;    

// ==================== ROW ENABLE GENERATION WITH DONE CASCADE ====================
// Row enable signals cascade based on done signals from previous rows
// Row 1: Starts when 'start' is asserted, shifts diagonally
// Row 2: Each PE starts when corresponding PE from Row 1 completes (done signal)
// Row 3: Each PE starts when corresponding PE from Row 2 completes
// Row 4: Each PE starts when corresponding PE from Row 3 completes

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        en_diag0 <= 1'b1;  // Initialize en_diag0 to 1 on reset
        en_diag1 <= 1'b0;
        en_diag2 <= 1'b0;
        en_diag3 <= 1'b0;
        en_diag4 <= 1'b0;
        en_diag5 <= 1'b0;
        en_diag6 <= 1'b0;
     
    end else begin
        // Diagonal enables controlled by computing signals - MUTUALLY EXCLUSIVE
        // en_diag0 (PE1) - starts on reset, disabled when en_diag1 activates
        if (start && !en_diag0) begin
            en_diag0 <= 1'b1;
        end
        
        // en_diag1 (PE2, PE5) - triggered by PE1 computing, disables en_diag0
        if (computing_1 && !en_diag1 && en_diag0) begin
            en_diag1 <= 1'b1;
            en_diag0 <= 1'b0;
        end
            
        // en_diag2 (PE3, PE6, PE9) - triggered by PE2 or PE5 computing, disables en_diag1
        if ((computing_2 || computing_5) && !en_diag2 && en_diag1) begin
            en_diag2 <= 1'b1;
            en_diag1 <= 1'b0;
        end
            
        // en_diag3 (PE4, PE7, PE10, PE13) - triggered by PE3, PE6, or PE9 computing, disables en_diag2
        if ((computing_3 || computing_6 || computing_9) && !en_diag3 && en_diag2) begin
            en_diag3 <= 1'b1;
            en_diag2 <= 1'b0;
        end
            
        // en_diag4 (PE8, PE11, PE14) - triggered by PE4, PE7, or PE10 computing, disables en_diag3
        if ((computing_4 || computing_7 || computing_10) && !en_diag4 && en_diag3) begin
            en_diag4 <= 1'b1;
            en_diag3 <= 1'b0;
        end
            
        // en_diag5 (PE12, PE15) - triggered by PE8 or PE11 computing, disables en_diag4
        if ((computing_8 || computing_11) && !en_diag5 && en_diag4) begin
            en_diag5 <= 1'b1;
            en_diag4 <= 1'b0;
        end
            
        // en_diag6 (PE16) - triggered by PE12 or PE15 computing, disables en_diag5
        if ((computing_12 || computing_15) && !en_diag6 && en_diag5) begin
            en_diag6 <= 1'b1;
            en_diag5 <= 1'b0;
        end
        
        // Clear diagonal enables when all computation done
        if (!start) begin
            en_diag0 <= 1'b0;
            en_diag1 <= 1'b0;
            en_diag2 <= 1'b0;
            en_diag3 <= 1'b0;
            en_diag4 <= 1'b0;
            en_diag5 <= 1'b0;
            en_diag6 <= 1'b0;
        end
    end
end    

// ==================== ROW 1 (PE1, PE2, PE3, PE4) ====================
// PE1: Column 1, Row 1
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe1 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_col1),
    .wr_en(en_diag0),
    .weight_in(weight_1),
    .done_in(start),
    .partial_in({OUTPUT_WIDTH{1'b0}}),
    .partial_out(partial_sum_1_to_2),
    .done_out(done_1_to_2),
    .fwd_data(fwd_pe_1_to_5),
    .computing(computing_1)
);

// PE2: Column 2, Row 1
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe2 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_col2),
    .wr_en(en_diag1),
    .weight_in(weight_2),
    .done_in(done_1_to_2),
    .partial_in(partial_sum_1_to_2),
    .partial_out(partial_sum_2_to_3),
    .done_out(done_2_to_3),
    .fwd_data(fwd_pe_2_to_6),
    .computing(computing_2)
);

// PE3: Column 3, Row 1
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe3 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_col3),
    .wr_en(en_diag2),
    .weight_in(weight_3),
    .done_in(done_2_to_3),
    .partial_in(partial_sum_2_to_3),
    .partial_out(partial_sum_3_to_4),
    .done_out(done_3_to_4),
    .fwd_data(fwd_pe_3_to_7),
    .computing(computing_3)
);

// PE4: Column 4, Row 1
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe4 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_col4),
    .wr_en(en_diag3),
    .weight_in(weight_4),
    .done_in(done_3_to_4),
    .partial_in(partial_sum_3_to_4),
    .partial_out(out1),
    .done_out(done_row1),
    .fwd_data(fwd_pe_4_to_8),
    .computing(computing_4)
);

// ==================== ROW 2 (PE5, PE6, PE7, PE8) ====================
// PE5: Column 1, Row 2
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe5 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_1_to_5),
    .wr_en(en_diag1),
    .weight_in(weight_1),
    .done_in(start),
    .partial_in({OUTPUT_WIDTH{1'b0}}),
    .partial_out(partial_sum_5_to_6),
    .done_out(done_5_to_6),
    .fwd_data(fwd_pe_5_to_9),
    .computing(computing_5)
);

// PE6: Column 2, Row 2
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe6 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_2_to_6),
    .wr_en(en_diag2),
    .weight_in(weight_2),
    .done_in(done_5_to_6),
    .partial_in(partial_sum_5_to_6),
    .partial_out(partial_sum_6_to_7),
    .done_out(done_6_to_7),
    .fwd_data(fwd_pe_6_to_10),
    .computing(computing_6)
);

// PE7: Column 3, Row 2
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe7 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_3_to_7),
    .wr_en(en_diag3),
    .weight_in(weight_3),
    .done_in(done_6_to_7),
    .partial_in(partial_sum_6_to_7),
    .partial_out(partial_sum_7_to_8),
    .done_out(done_7_to_8),
    .fwd_data(fwd_pe_7_to_11),
    .computing(computing_7)
);

// PE8: Column 4, Row 2
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe8 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_4_to_8),
    .wr_en(en_diag4),
    .weight_in(weight_4),
    .done_in(done_7_to_8),
    .partial_in(partial_sum_7_to_8),
    .partial_out(out2),
    .done_out(done_row2),
    .fwd_data(fwd_pe_8_to_12),
    .computing(computing_8)
);

// ==================== ROW 3 (PE9, PE10, PE11, PE12) ====================
// PE9: Column 1, Row 3
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe9 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_5_to_9),
    .wr_en(en_diag2),
    .weight_in(weight_1),
    .done_in(start),
    .partial_in({OUTPUT_WIDTH{1'b0}}),
    .partial_out(partial_sum_9_to_10),
    .done_out(done_9_to_10),
    .fwd_data(fwd_pe_9_to_13),
    .computing(computing_9)
);

// PE10: Column 2, Row 3
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe10 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_6_to_10),
    .wr_en(en_diag3),
    .weight_in(weight_2),
    .done_in(done_9_to_10),
    .partial_in(partial_sum_9_to_10),
    .partial_out(partial_sum_10_to_11),
    .done_out(done_10_to_11),
    .fwd_data(fwd_pe_10_to_14),
    .computing(computing_10)
);

// PE11: Column 3, Row 3
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe11 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_7_to_11),
    .wr_en(en_diag4),
    .weight_in(weight_3),
    .done_in(done_10_to_11),
    .partial_in(partial_sum_10_to_11),
    .partial_out(partial_sum_11_to_12),
    .done_out(done_11_to_12),
    .fwd_data(fwd_pe_11_to_15),
    .computing(computing_11)
);

// PE12: Column 4, Row 3
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe12 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_8_to_12),
    .wr_en(en_diag5),
    .weight_in(weight_4),
    .done_in(done_11_to_12),
    .partial_in(partial_sum_11_to_12),
    .partial_out(out3),
    .done_out(done_row3),
    .fwd_data(fwd_pe_12_to_16),
    .computing(computing_12)
);

// ==================== ROW 4 (PE13, PE14, PE15, PE16) ====================
// PE13: Column 1, Row 4
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe13 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_9_to_13),
    .wr_en(en_diag3),
    .weight_in(weight_1),
    .done_in(start),
    .partial_in({OUTPUT_WIDTH{1'b0}}),
    .partial_out(partial_sum_13_to_14),
    .done_out(done_13_to_14),
    .fwd_data(),
    .computing(computing_13)
);

// PE14: Column 2, Row 4
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe14 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_10_to_14),
    .wr_en(en_diag4),
    .weight_in(weight_2),
    .done_in(done_13_to_14),
    .partial_in(partial_sum_13_to_14),
    .partial_out(partial_sum_14_to_15),
    .done_out(done_14_to_15),
    .fwd_data(),
    .computing(computing_14)
);

// PE15: Column 3, Row 4
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe15 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_11_to_15),
    .wr_en(en_diag5),
    .weight_in(weight_3),
    .done_in(done_14_to_15),
    .partial_in(partial_sum_14_to_15),
    .partial_out(partial_sum_15_to_16),
    .done_out(done_15_to_16),
    .fwd_data(),
    .computing(computing_15)
);

// PE16: Column 4, Row 4
processing_element #(
    .DATA_WIDTH(DATA_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) pe16 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(fwd_pe_12_to_16),
    .wr_en(en_diag6),
    .weight_in(weight_4),
    .done_in(done_15_to_16),
    .partial_in(partial_sum_15_to_16),
    .partial_out(out4),
    .done_out(done_pe16),
    .fwd_data(),
    .computing(computing_16)
);

endmodule