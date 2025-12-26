module weight_global_bram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,      // FIXED
    parameter MEM_SIZE   = 36864,
    parameter MEM_FILE   = "weights.mem"
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    input  wire [DATA_WIDTH-1:0] din,
    input  wire                 we,
    input  wire                 re,
    output reg  [DATA_WIDTH-1:0] dout,
    output reg done
);

    reg [DATA_WIDTH-1:0] bram [0:MEM_SIZE-1];

    // ------------------------------
    // SIMULATION LOAD
    // ------------------------------
    initial begin
        $readmemh(MEM_FILE, bram);
        done = 1'b1; // Always done since pre-loaded
    end

    // ------------------------------
    // WRITE (optional)
    // ------------------------------
    always @(posedge clk) begin
        if (we)
            bram[wr_addr] <= din;
    end

    // ------------------------------
    // READ
    // ------------------------------
    always @(posedge clk) begin
        if (re)
            dout <= bram[rd_addr];
    end

endmodule
