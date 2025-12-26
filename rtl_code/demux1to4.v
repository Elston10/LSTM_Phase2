`timescale 1ns/1ps
module demux1to4 #(
    parameter DATA_WIDTH = 32
)(
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire [1:0]            data_sel,
    input  wire                  enable,
    output reg  [DATA_WIDTH-1:0] data_out1,
    output reg  [DATA_WIDTH-1:0] data_out2,
    output reg  [DATA_WIDTH-1:0] data_out3,
    output reg  [DATA_WIDTH-1:0] data_out4
);

    // Combinational logic - select which output gets the data based on sel
    always @(*) begin
        // Default: all outputs to zero
        data_out1 = {DATA_WIDTH{1'b0}};
        data_out2 = {DATA_WIDTH{1'b0}};
        data_out3 = {DATA_WIDTH{1'b0}};
        data_out4 = {DATA_WIDTH{1'b0}};
        
        if (enable) begin
            case (data_sel)
                2'b00: data_out1 = data_in;
                2'b01: data_out2 = data_in;
                2'b10: data_out3 = data_in;
                2'b11: data_out4 = data_in;
                default: begin
                    data_out1 = {DATA_WIDTH{1'b0}};
                    data_out2 = {DATA_WIDTH{1'b0}};
                    data_out3 = {DATA_WIDTH{1'b0}};
                    data_out4 = {DATA_WIDTH{1'b0}};
                end
            endcase
        end
    end

endmodule