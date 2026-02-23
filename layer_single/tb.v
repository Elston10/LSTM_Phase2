`timescale 1ns / 1ps

module sequence_top_tb_simple;

    reg clk, rst_n, start;
    wire done;
    
    top uut (.clk(clk), .rst_n(rst_n), .start(start), .done(done));
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        rst_n = 0;
        start = 0;
        
        #20 rst_n = 1;           // Release reset
        #10 start = 1;           // Start
        #10 start = 0;           // Stop start signal
        
        wait(done);              // Wait for done
        #100 $finish;
    end
    
    initial begin
        $monitor("Time=%0t | done=%b", $time, done);
    end

endmodule