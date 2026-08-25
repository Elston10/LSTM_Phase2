`timescale 1ns / 1ps

module tb_fifo_input_system;

    // -----------------------------------------------------------------------
    // Parameters: 125 MHz clock, 115200 baud with M=68, 16x oversampling
    // -----------------------------------------------------------------------
    localparam CLK_PERIOD = 8;                      // 8 ns = 125 MHz
    localparam BIT_PERIOD = 68 * 16 * CLK_PERIOD;  // 8704 ns per UART bit

    // -----------------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------------
    reg         clk, rst_n, rx;
    wire     fifo_full;
    wire match;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    fifo_input_system #(
        .DATA_SIZE        (8),
        .ADDR_SPACE_EXP   (4),
        .OUTPUT_DATA_WIDTH(80),
        .ADDR_WIDTH       (5)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx         (rx),
        .fifo_full  (fifo_full),
        .match       (match)
    );

    // -----------------------------------------------------------------------
    // Clock: 125 MHz
    // -----------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -----------------------------------------------------------------------
    // Task: transmit one 8N1 UART byte (LSB first)
    // -----------------------------------------------------------------------
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            rx = 0; #(BIT_PERIOD);             // start bit
            for (i = 0; i < 8; i = i + 1)
                begin rx = data[i]; #(BIT_PERIOD); end
            rx = 1; #(BIT_PERIOD);             // stop bit
        end
    endtask

    // -----------------------------------------------------------------------
    // Task: send 10 bytes and wait for done (edge-triggered, never misses)
    // -----------------------------------------------------------------------
    integer j;
    task send_batch;
        input [79:0] bytes; // bytes[7:0]=byte0 … bytes[79:72]=byte9
        begin
            fork
                begin : tx
                    for (j = 0; j < 10; j = j + 1)
                        send_byte(bytes[j*8 +: 8]);
                end
                begin : wait_done
                    @(posedge clk);
                end
            join
        end
    endtask

    // -----------------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_fifo_input_system.vcd");
        $dumpvars(0, tb_fifo_input_system);

        rx    = 1;  // UART idle HIGH
        rst_n = 0;

        // Active-low reset: hold for 20 cycles
        @(negedge clk);
        rst_n = 1;
        repeat (20) @(posedge clk);
        rst_n = 0;
        repeat (5)  @(posedge clk);

        $display("=== UART FIFO System Testbench ===");

        // ------------------------------------------------------------------
        // Batch 1: bytes A1 B2 C3 D4 E5 F6 07 18 29 3A
        //          packed LSB-first: [7:0]=A1, [15:8]=B2, ...
        // ------------------------------------------------------------------
        $display("[%0t ns] Batch 1: sending 10 bytes", $time);
        send_batch(80'h3A_29_18_07_F6_E5_D4_C3_B2_A1);
        $display("[%0t ns] DONE (Batch 1)  output_data = 0x%020X", $time, dut.output_data);
        if (dut.output_data === 80'h3A_29_18_07_F6_E5_D4_C3_B2_A1)
            $display("[%0t ns] PASS Batch 1", $time);
        else
            $display("[%0t ns] FAIL Batch 1 – expected 0x3A291807F6E5D4C3B2A1, got 0x%020X", $time, dut.output_data);

        // Wait for controller to return to IDLE
        wait (dut.done == 0);
        repeat (20) @(posedge clk);

        // ------------------------------------------------------------------
        // Batch 2: bytes 11 22 33 44 55 66 77 88 99 AA
        // ------------------------------------------------------------------
        $display("[%0t ns] Batch 2: sending 10 bytes", $time);
        send_batch(80'hAA_99_88_77_66_55_44_33_22_11);
        $display("[%0t ns] DONE (Batch 2)  output_data = 0x%020X", $time, dut.output_data);
        if (dut.output_data === 80'hAA_99_88_77_66_55_44_33_22_11)
            $display("[%0t ns] PASS Batch 2", $time);
        else
            $display("[%0t ns] FAIL Batch 2 – expected 0xAA998877665544332211, got 0x%020X", $time, dut.output_data);

        repeat (100) @(posedge clk);
        $display("=== Simulation complete ===");
        $finish;
    end

    // Watchdog: 200 ms timeout
    initial begin
        #200_000_000;
        $display("[%0t ns] WATCHDOG timeout", $time);
        $finish;
    end

endmodule
