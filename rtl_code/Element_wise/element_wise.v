module element_wise #(
    parameter DATA_WIDTH = 12,
    parameter ADDRESS_BITS = 12
) (
    input clk,
    input rst,
    input start,
    
    // Activated gate values from buffers
    input [DATA_WIDTH-1:0] i_register_i,  // Input gate (i)
    input [DATA_WIDTH-1:0] f_register_i,  // Forget gate (f)
    input [DATA_WIDTH-1:0] c_register_i,  // Cell gate (g)
    input [DATA_WIDTH-1:0] o_register_i,  // Output gate (o)
    
    // Previous cell state input (element-by-element from buffer)
    input [DATA_WIDTH-1:0] ct_minus_1,    // C(t-1)[k] for current element k
    
    // LSTM outputs
    output wire [DATA_WIDTH-1:0] ct_output,    // New cell state C(t)[k]
    output wire [DATA_WIDTH-1:0] ht_output    // Hidden state h(t)[k]
);
wire [DATA_WIDTH-1:0] valid_i_register_i, valid_f_register_i,valid_c_register_i, valid_o_register_i;
assign valid_i_register_i=start ? i_register_i : {DATA_WIDTH{1'b0}};
assign valid_f_register_i=start ? f_register_i : {DATA_WIDTH{1'b0}};
assign valid_c_register_i=start ? c_register_i : {DATA_WIDTH{1'b0}};
assign valid_o_register_i=start ? o_register_i : {DATA_WIDTH{1'b0}};
 PE #(
    .WIDTH(DATA_WIDTH),
    .FRAC_BITS(8),
    .INT_BITS(7)
) element_pe ( .register_o(valid_o_register_i),
    .register_i(valid_i_register_i),
    .register_g(valid_c_register_i),
    .register_f(valid_f_register_i),
    .register_c_prev(ct_minus_1),
    .register_c(ct_output),
    .register_h(ht_output)); 
endmodule