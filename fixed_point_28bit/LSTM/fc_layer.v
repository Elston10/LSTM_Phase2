`timescale 1ns / 1ps

module fc_pe #(
    parameter DATA_WIDTH = 28,
    parameter WEIGHT_WIDTH = 28,
    parameter BIAS_WIDTH = 28,
    parameter OUTPUT_WIDTH = 28,
    parameter HIDDEN_SIZE = 16
)(
    input clk,
    input rst_n,
    input start,

    input [DATA_WIDTH-1:0] ht_in,
    input [WEIGHT_WIDTH-1:0] weight_in,
    input [BIAS_WIDTH-1:0] bias_in,

    output reg [6:0] addr,
    output reg done,
    output reg [OUTPUT_WIDTH-1:0] fc_out
);

    // =====================================================
    // FSM STATES
    // =====================================================
    localparam IDLE       = 3'b000;
    localparam MULTIPLY   = 3'b001;
    localparam ADD        = 3'b010;
    localparam ADD_BIAS   = 3'b011;
    localparam DONE       = 3'b100;

    reg [2:0] state, next_state;

    // =====================================================
    // ACCUMULATOR
    // =====================================================
    reg [OUTPUT_WIDTH-1:0] accumulator;

    // =====================================================
    // MULTIPLIER
    // =====================================================
    wire [DATA_WIDTH-1:0] mult_out;
    wire mult_overflow;

    multiplier #(
        .WIDTH(DATA_WIDTH),
        .FRAC_BITS(20),
        .INT_BITS(7)
    ) mult (
        .a(ht_in),
        .b(weight_in),
        .prod(mult_out),
        .overflow(mult_overflow)
    );

    // register multiplier output
    reg [DATA_WIDTH-1:0] mult_reg;

    // =====================================================
    // ADDER (accumulator + product)
    // =====================================================
    wire [OUTPUT_WIDTH-1:0] add_out;
    wire add_overflow;

    adder #(
        .WIDTH(OUTPUT_WIDTH),
        .FRAC_BITS(20),
        .INT_BITS(7)
    ) acc_adder (
        .a(accumulator),
        .b(mult_reg),
        .sum(add_out),
        .overflow(add_overflow)
    );

    // =====================================================
    // BIAS ADDER
    // =====================================================
    wire [OUTPUT_WIDTH-1:0] bias_sum;
    wire bias_overflow;

    adder #(
        .WIDTH(OUTPUT_WIDTH),
        .FRAC_BITS(20),
        .INT_BITS(7)
    ) bias_adder (
        .a(accumulator),
        .b(bias_in),
        .sum(bias_sum),
        .overflow(bias_overflow)
    );

    // =====================================================
    // STATE REGISTER
    // =====================================================
    always @(posedge clk ) begin
        if(!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // =====================================================
    // NEXT STATE LOGIC
    // =====================================================
    always @(*) begin
        next_state = state;

        case(state)

            IDLE:
                if(start)
                    next_state = MULTIPLY;

            MULTIPLY:
                next_state = ADD;

            ADD:
                if(addr == HIDDEN_SIZE)
                    next_state = ADD_BIAS;
                else
                    next_state = MULTIPLY;

            ADD_BIAS:
                next_state = DONE;

            DONE:
                next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // =====================================================
    // DATAPATH
    // =====================================================
    always @(posedge clk ) begin
        if(!rst_n) begin
            addr <= 0;
            accumulator <= 0;
            fc_out <= 0;
            done <= 0;
            mult_reg <= 0;
        end
        else begin
            case(state)

                IDLE: begin
                    addr <= 0;
                    accumulator <= 0;
                    done <= 0;
                end

                MULTIPLY: begin
                    mult_reg <= mult_out;   // store product
                    addr <= addr + 1;
                end

                ADD: begin
                    accumulator <= add_out;

                end

                ADD_BIAS: begin
                    fc_out <= bias_sum;
                end

                DONE: begin
                    done <= 1;
                end
                default: begin
                    addr <= 0;
                    accumulator <= 0;
                    fc_out <= 0;
                    done <= 0;
                    mult_reg <= 0;
                end
            endcase
        end
    end

endmodule