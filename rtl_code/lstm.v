module lstm(
    input wire clk,
    input wire rst_n,
    input wire we,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire [DATA_WIDTH-1:0] weight_in,
    input wire [6:0] gb_data_addr,
    output wire [DATA_WIDTH-1:0] ct_output_1,ct_output_2,ct_output_3,ct_output_4,ht_output,ht_output_2,ht_output_3,ht_output_4
);
//---------------- LAYER 1 -------------------
top #() layer_1(
    .clk(clk),
    .rst_n(rst_n),
    .we(we),
    .data_in(data_in),
    .weight_in(weight_in),
     .ct_output(ct_output_1),
     .ht_output(ht_output),
);  
//---------------- LAYER 2 -------------------
top #() layer_2(
    .clk(clk),
    .rst_n(rst_n),
    .we(we),
    .data_in(ct_output_1),
    .weight_in(weight_in),
    .ct_output(ct_output_2),
    .ht_output(ht_output_2),
);  
//---------------- LAYER 3 -------------------
top #() layer_3(
    .clk(clk),
    .rst_n(rst_n),
    .we(we),
    .data_in(ct_output_2),
    weight_in(weight_in), 
    .ct_output(ct_output_3),
    .ht_output(ht_output_3));
//---------------- LAYER 4 -------------------
top #() layer_4(
    .clk(clk),
    .rst_n(rst_n),
    .we(we),
    .data_in(ct_output_3),
    weight_in(weight_in), 
    .ct_output(ct_output_4),
    .ht_output(ht_output_4));
endmodule   