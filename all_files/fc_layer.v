`timescale 1ns / 1ps

// ============================================================================
// FC PROCESSING ELEMENT
// ============================================================================
module fc_pe #(
    parameter DATA_WIDTH = 16,
    parameter WEIGHT_WIDTH = 16,
    parameter BIAS_WIDTH = 16,
    parameter OUTPUT_WIDTH = 16,
    parameter HIDDEN_SIZE = 94
)(
    input clk,
    input rst_n,
    input start,
    
    // Hidden state input (sequential, one per cycle)
    input [DATA_WIDTH-1:0] ht_in,
    
    // Weight input (sequential, one per cycle)
    input [WEIGHT_WIDTH-1:0] weight_in,
    
    // Bias input (constant)
    input [BIAS_WIDTH-1:0] bias_in,
    
    // Control
    output reg [6:0] addr,           // Address counter (0-93)
    output reg done,
    output reg [OUTPUT_WIDTH-1:0] fc_out
);

    // FSM States
    localparam IDLE       = 2'b00;
    localparam ACCUMULATE = 2'b01;
    localparam ADD_BIAS   = 2'b10;
    localparam DONE       = 2'b11;
    
    reg [1:0] state, next_state;
    
    // Accumulator
    reg [OUTPUT_WIDTH-1:0] accumulator;
    
    // Multiplier signals
    wire [DATA_WIDTH-1:0] mult_out;
    wire mult_overflow;
    
    // Adder signals
    wire [OUTPUT_WIDTH-1:0] add_out;
    wire add_overflow;
    
    // Instantiate multiplier
    multiplier #(
        .WIDTH(DATA_WIDTH),
        .FRAC_BITS(8),
        .INT_BITS(7)
    ) mult (
        .a(ht_in),
        .b(weight_in),
        .prod(mult_out),
        .overflow(mult_overflow)
    );
    
    // Instantiate adder for accumulation
    adder #(
        .WIDTH(OUTPUT_WIDTH),
        .FRAC_BITS(8),
        .INT_BITS(7)
    ) acc_adder (
        .a(accumulator),
        .b(mult_out),
        .sum(add_out),
        .overflow(add_overflow)
    );
    
    // Instantiate adder for bias
    wire [OUTPUT_WIDTH-1:0] bias_sum;
    wire bias_overflow;
    
    adder #(
        .WIDTH(OUTPUT_WIDTH),
        .FRAC_BITS(8),
        .INT_BITS(7)
    ) bias_adder (
        .a(accumulator),
        .b(bias_in),
        .sum(bias_sum),
        .overflow(bias_overflow)
    );
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = ACCUMULATE;
                else
                    next_state = IDLE;
            end
            
            ACCUMULATE: begin
                if (addr == HIDDEN_SIZE - 1)
                    next_state = ADD_BIAS;
                else
                    next_state = ACCUMULATE;
            end
            
            ADD_BIAS: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Address counter and accumulator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr <= 0;
            accumulator <= 0;
            fc_out <= 0;
            done <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    addr <= 0;
                    accumulator <= 0;
                    done <= 0;
                end
                
                ACCUMULATE: begin
                    accumulator <= add_out;  // accumulator + (ht * weight)
                    addr <= addr + 1;
                    done <= 0;
                end
                
                ADD_BIAS: begin
                    fc_out <= bias_sum;  // accumulator + bias
                    done <= 0;
                end
                
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule
