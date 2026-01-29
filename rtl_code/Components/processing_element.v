module processing_element #(
    parameter DATA_WIDTH = 16,
    parameter OUTPUT_WIDTH = 16
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire [DATA_WIDTH-1:0] weight_in,
    input  wire wr_en,
    input  wire done_in,                           // Done signal from previous PE
    input  wire [OUTPUT_WIDTH-1:0] partial_in,
    output reg  [OUTPUT_WIDTH-1:0] partial_out,
    output reg  done_out,                          // Done signal to next PE
    output reg  [DATA_WIDTH-1:0] fwd_data,         // Registered data forwarding controlled by done
    output wire computing                          // High when add_res is being computed (combinational)
);

    wire [DATA_WIDTH-1:0] mul_res;      // Multiplier result
    wire [OUTPUT_WIDTH-1:0] add_res;    // Adder result
    // Internal computation done flag
    reg computation_done;
    multiplier #() multiply_inst   (
     .a(data_in),
     .b(weight_in),
     .prod(mul_res),
     .overflow()
);

    // Systolic array with interdependence: compute only when dependencies are met
    // For first PE in row (done_in acts as start signal), or when previous PE completes
    wire start_compute = wr_en && done_in;
    
    // Computing signal indicates add_res is valid (before it's registered to partial_out)
    assign computing = start_compute;
    adder #() add_inst
  (  .a(partial_in),
     .b(mul_res),
     .sum(add_res),
     .overflow());
    // Standard MAC operation with interdependence control
   // Standard MAC operation with interdependence control
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        partial_out <= {OUTPUT_WIDTH{1'b0}};
        done_out <= 1'b0;
        computation_done <= 1'b0;
        fwd_data <= {DATA_WIDTH{1'b0}};
    end else begin
        // Reset done signals when wr_en goes low (computation reset)
        if (!wr_en && !done_in) begin
            done_out <= 1'b0;
            computation_done <= 1'b0;
        end
        else if (start_compute && !computation_done) begin  // Only compute once
            // Perform MAC: multiply and accumulate only when dependencies are met (done_in is high)
            partial_out <= add_res;
            computation_done <= 1'b1;
            done_out <= 1'b1;  // Signal completion to next PE
            fwd_data <= data_in;  // Forward data when computation is done
        end 
        else if (computation_done && done_out) begin
            // Clear done_out one cycle after setting it, then keep it at 0
            done_out <= 1'b0;
        end
        else if (done_in && !wr_en) begin
            // Pass through when previous is done but no local computation
            partial_out <= partial_in;
            fwd_data <= data_in;  // Continue forwarding data
        end else begin
            // Hold state - done_out stays at 0 once cleared
            partial_out <= partial_out;
            fwd_data <= fwd_data;  // Hold previous data
        end
    end
end

endmodule