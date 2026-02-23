`timescale 1ns/1ps

module tb_sync_fifo;

// ============================================================================
// Parameters
// ============================================================================
parameter CLK_PERIOD = 10; // 100 MHz clock
parameter DATA_WIDTH = 80;
parameter DEPTH = 20;
parameter ADDR_WIDTH = 5;

// ============================================================================
// DUT Signals
// ============================================================================
reg clk;
reg rst_n;
reg wr_en;
reg rd_en;
reg [DATA_WIDTH-1:0] wr_data;
wire [DATA_WIDTH-1:0] rd_data;
wire full;
wire empty;

// ============================================================================
// Test Variables
// ============================================================================
integer i;
integer error_count;
integer write_count;
integer read_count;
reg [DATA_WIDTH-1:0] expected_data;
reg [DATA_WIDTH-1:0] test_data_queue [0:DEPTH-1];

// ============================================================================
// Clock Generation
// ============================================================================
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ============================================================================
// DUT Instantiation
// ============================================================================
sync_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(0),
    .rd_en(0),
    .wr_data(wr_data),
    .rd_data(rd_data),
    .full(full),
    .empty(empty)
);

// ============================================================================
// Test Tasks
// ============================================================================

// Task to write data to FIFO
task write_fifo;
    input [DATA_WIDTH-1:0] data;
    begin
        @(posedge clk);
        wr_data = data;
        wr_en = 1;
        @(posedge clk);
        wr_en = 0;
        if (!full) begin
            $display("[%0t] WRITE: Data = %h, Count = %0d", $time, data, dut.count);
            write_count = write_count + 1;
        end else begin
            $display("[%0t] WRITE FAILED: FIFO Full", $time);
        end
    end
endtask

// Task to read data from FIFO
task read_fifo;
    output [DATA_WIDTH-1:0] data;
    begin
        @(posedge clk);
        rd_en = 1;
        @(posedge clk);
        rd_en = 0;
        @(posedge clk); // Wait for data to be valid
        data = rd_data;
        if (!empty) begin
            $display("[%0t] READ: Data = %h, Count = %0d", $time, data, dut.count);
            read_count = read_count + 1;
        end else begin
            $display("[%0t] READ FAILED: FIFO Empty", $time);
        end
    end
endtask

// Task to check if read data matches expected
task check_data;
    input [DATA_WIDTH-1:0] expected;
    input [DATA_WIDTH-1:0] actual;
    begin
        if (expected !== actual) begin
            $display("[%0t] ERROR: Data mismatch! Expected = %h, Got = %h", 
                     $time, expected, actual);
            error_count = error_count + 1;
        end else begin
            $display("[%0t] PASS: Data match! Data = %h", $time, actual);
        end
    end
endtask

// ============================================================================
// Test Scenarios
// ============================================================================
initial begin
    // Create VCD dump
    $dumpfile("sync_fifo.vcd");
    $dumpvars(0, tb_sync_fifo);
    
    // Initialize
    clk = 0;
    rst_n = 0;
    wr_en = 0;
    rd_en = 0;
    wr_data = 0;
    error_count = 0;
    write_count = 0;
    read_count = 0;
    
    // ========================================================================
    // Test 1: Reset Test
    // ========================================================================
    $display("\n========================================");
    $display("Test 1: Reset Test");
    $display("========================================");
    
    #(CLK_PERIOD * 5);
    rst_n = 1;
    #(CLK_PERIOD * 2);
    
    if (empty && !full && dut.count == 0) begin
        $display("[%0t] PASS: Reset successful - FIFO is empty", $time);
    end else begin
        $display("[%0t] ERROR: Reset failed - empty=%b, full=%b, count=%0d", 
                 $time, empty, full, dut.count);
        error_count = error_count + 1;
    end
    
    // ========================================================================
    // Test 2: Single Write and Read
    // ========================================================================
    $display("\n========================================");
    $display("Test 2: Single Write and Read");
    $display("========================================");
    
    write_fifo(80'hDEADBEEF_CAFEBABE_12345678_9ABCDEF0_FEDCBA98);
    #(CLK_PERIOD * 2);
    
    if (!empty && dut.count == 1) begin
        $display("[%0t] PASS: FIFO not empty after write, count = 1", $time);
    end else begin
        $display("[%0t] ERROR: FIFO state incorrect after write", $time);
        error_count = error_count + 1;
    end
    
    read_fifo(expected_data);
    check_data(80'hDEADBEEF_CAFEBABE_12345678_9ABCDEF0_FEDCBA98, expected_data);
    
    #(CLK_PERIOD * 2);
    if (empty && dut.count == 0) begin
        $display("[%0t] PASS: FIFO empty after read", $time);
    end else begin
        $display("[%0t] ERROR: FIFO should be empty", $time);
        error_count = error_count + 1;
    end
    
    // ========================================================================
    // Test 3: Fill FIFO Completely (Write 20 entries)
    // ========================================================================
    $display("\n========================================");
    $display("Test 3: Fill FIFO (20 writes)");
    $display("========================================");
    
    for (i = 0; i < DEPTH; i = i + 1) begin
        test_data_queue[i] = {16'hAAAA, 16'hBBBB, 16'hCCCC, 16'hDDDD, 16'h0000 + i};
        write_fifo(test_data_queue[i]);
    end
    
    #(CLK_PERIOD * 2);
    if (full && dut.count == DEPTH) begin
        $display("[%0t] PASS: FIFO full after %0d writes", $time, DEPTH);
    end else begin
        $display("[%0t] ERROR: FIFO should be full, count = %0d", $time, dut.count);
        error_count = error_count + 1;
    end
    
    // Test write to full FIFO
    $display("\n--- Attempting write to full FIFO ---");
    write_fifo(80'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF);
    if (dut.count == DEPTH) begin
        $display("[%0t] PASS: Write to full FIFO ignored", $time);
    end else begin
        $display("[%0t] ERROR: Write to full FIFO accepted", $time);
        error_count = error_count + 1;
    end
    
    // ========================================================================
    // Test 4: Empty FIFO Completely (Read 20 entries)
    // ========================================================================
    $display("\n========================================");
    $display("Test 4: Empty FIFO (20 reads)");
    $display("========================================");
    
    for (i = 0; i < DEPTH; i = i + 1) begin
        read_fifo(expected_data);
        check_data(test_data_queue[i], expected_data);
    end
    
    #(CLK_PERIOD * 2);
    if (empty && dut.count == 0) begin
        $display("[%0t] PASS: FIFO empty after %0d reads", $time, DEPTH);
    end else begin
        $display("[%0t] ERROR: FIFO should be empty, count = %0d", $time, dut.count);
        error_count = error_count + 1;
    end
    
    // Test read from empty FIFO
    $display("\n--- Attempting read from empty FIFO ---");
    read_fifo(expected_data);
    if (dut.count == 0) begin
        $display("[%0t] PASS: Read from empty FIFO ignored", $time);
    end else begin
        $display("[%0t] ERROR: Read from empty FIFO affected count", $time);
        error_count = error_count + 1;
    end
    
    // ========================================================================
    // Test 5: Simultaneous Read and Write
    // ========================================================================
    $display("\n========================================");
    $display("Test 5: Simultaneous Read and Write");
    $display("========================================");
    
    // First write some data
    for (i = 0; i < 10; i = i + 1) begin
        write_fifo(80'h1111111111111111_0000 + i);
    end
    
    #(CLK_PERIOD * 2);
    $display("[%0t] FIFO count before simultaneous ops: %0d", $time, dut.count);
    
    // Simultaneous write and read
    for (i = 0; i < 5; i = i + 1) begin
        @(posedge clk);
        wr_en = 1;
        rd_en = 1;
        wr_data = 80'h2222222222222222_0000 + i;
        @(posedge clk);
        wr_en = 0;
        rd_en = 0;
        @(posedge clk);
    end
    
    #(CLK_PERIOD * 2);
    if (dut.count == 10) begin
        $display("[%0t] PASS: Simultaneous R/W maintains count at 10", $time);
    end else begin
        $display("[%0t] ERROR: Count should be 10, got %0d", $time, dut.count);
        error_count = error_count + 1;
    end
    
    // ========================================================================
    // Test 6: Wrap-around Test
    // ========================================================================
    $display("\n========================================");
    $display("Test 6: Pointer Wrap-around");
    $display("========================================");
    
    // Reset FIFO
    rst_n = 0;
    #(CLK_PERIOD * 2);
    rst_n = 1;
    #(CLK_PERIOD * 2);
    
    // Write 25 items (more than DEPTH)
    for (i = 0; i < 25; i = i + 1) begin
        if (i < DEPTH) begin
            test_data_queue[i] = 80'h3333333333333333_0000 + i;
            write_fifo(test_data_queue[i]);
        end
    end
    
    // Read 15 items
    for (i = 0; i < 15; i = i + 1) begin
        read_fifo(expected_data);
        check_data(test_data_queue[i], expected_data);
    end
    
    // Write 10 more items (tests wrap-around)
    for (i = 0; i < 10; i = i + 1) begin
        write_fifo(80'h4444444444444444_0000 + i);
    end
    
    if (dut.count == 15) begin
        $display("[%0t] PASS: Wrap-around successful, count = 15", $time);
    end else begin
        $display("[%0t] ERROR: Wrap-around failed, count = %0d", $time, dut.count);
        error_count = error_count + 1;
    end
    
    // ========================================================================
    // Test 7: Random Operations
    // ========================================================================
    $display("\n========================================");
    $display("Test 7: Random Operations");
    $display("========================================");
    
    // Reset FIFO
    rst_n = 0;
    #(CLK_PERIOD * 2);
    rst_n = 1;
    #(CLK_PERIOD * 2);
    
    for (i = 0; i < 100; i = i + 1) begin
        if ($random % 2 && !full) begin
            write_fifo($random);
        end else if (!empty) begin
            read_fifo(expected_data);
        end
        #(CLK_PERIOD * 2);
    end
    
    $display("[%0t] Random operations completed, final count = %0d", 
             $time, dut.count);
    
    // ========================================================================
    // Test 8: Reset During Operation
    // ========================================================================
    $display("\n========================================");
    $display("Test 8: Reset During Operation");
    $display("========================================");
    
    write_fifo(80'hABCDEF0123456789_FEDCBA9876543210_1234567890ABCDEF);
    write_fifo(80'h1111111111111111_2222222222222222_3333333333333333);
    
    #(CLK_PERIOD);
    rst_n = 0;
    #(CLK_PERIOD * 3);
    rst_n = 1;
    #(CLK_PERIOD * 2);
    
    if (empty && !full && dut.count == 0) begin
        $display("[%0t] PASS: Reset during operation successful", $time);
    end else begin
        $display("[%0t] ERROR: Reset during operation failed", $time);
        error_count = error_count + 1;
    end
    
    // ========================================================================
    // Final Report
    // ========================================================================
    #(CLK_PERIOD * 10);
    
    $display("\n========================================");
    $display("Test Summary");
    $display("========================================");
    $display("Total Writes: %0d", write_count);
    $display("Total Reads:  %0d", read_count);
    $display("Total Errors: %0d", error_count);
    
    if (error_count == 0) begin
        $display("\n*** ALL TESTS PASSED ***");
    end else begin
        $display("\n*** TESTS FAILED ***");
    end
    
    $finish;
end

// ============================================================================
// Timeout Watchdog
// ============================================================================
initial begin
    #(CLK_PERIOD * 50000);
    $display("[%0t] ERROR: Test timeout!", $time);
    $finish;
end

// ============================================================================
// Monitor
// ============================================================================
initial begin
    $monitor("[%0t] empty=%b full=%b count=%0d wr_ptr=%0d rd_ptr=%0d", 
             $time, empty, full, dut.count, dut.wr_ptr, dut.rd_ptr);
end

endmodule