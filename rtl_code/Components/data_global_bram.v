`timescale 1ns/1ps
module data_global_bram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 6,    // 64 locations
    parameter MEM_SIZE=100
)(
    input  wire                 clk,
    input  wire                 rst_n,reset_done,
    input  wire [ADDR_WIDTH-1:0] wr_addr, // Renamed for Write Address
    input  wire [ADDR_WIDTH-1:0] rd_addr, // <--- NEW: Dedicated Read Address
    input  wire [DATA_WIDTH-1:0] din,
    input  wire                 we,
    input  wire                 re,
    output reg  [DATA_WIDTH-1:0] dout,
    output reg                   done
);

    localparam MAX_COUNT = MEM_SIZE; 
    
    // ------------------------------
    // BRAM and counter
    // ------------------------------
    reg [DATA_WIDTH-1:0] bram [0:MEM_SIZE-1]; 
    reg [ADDR_WIDTH-1:0]   write_count; 

    // ------------------------------
    // Write + Done Logic (Uses wr_addr)
    // ------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_count <= 0;
            done        <= 1'b0;
        end 
        if(reset_done) begin
            write_count <= 0;
            done        <= 1'b0;
        end
        // Reset done/count when a new write sequence starts after completion
        else if (we && (write_count == MAX_COUNT)) begin
             write_count <= 0;
             done        <= 1'b0;
        end
        // Allow writes as long as 'we' is high AND we haven't reached MAX_COUNT
        else if (we && (write_count < MAX_COUNT)) begin
            
            // Execute the write using the dedicated write address
            bram[wr_addr] <= din;

            // Increment counter 
            write_count <= write_count + 1;
            
            // Assert 'done' on the cycle the final element (MEM_SIZE-1) is written
            if (write_count == (MEM_SIZE - 1)) 
                done <= 1'b1;
        end
        // Keep done high once completed, unless reset or new write starts
        else if (!we && done) begin
        
        end
        else begin
             done <= 1'b0; // Reset done when write is inactive and not yet finished
        end
    end

    // ------------------------------
    // Read logic (Uses rd_addr)
    // ------------------------------
    always @(posedge clk) begin
        // Read happens only when 're' is high, using the dedicated read address
        if (re)
            dout <= bram[rd_addr]; 
    end

endmodule
