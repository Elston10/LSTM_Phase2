module tb_sigmoid_simple;

    reg [15:0] test_input;
    wire [15:0] sigmoid_result;
    wire overflow;

    // Instantiate sigmoid module
    sigmoid_s7_8 dut (
        .input_value(test_input),
        .sigmoid_out(sigmoid_result),
        .overflow(overflow)
    );

    initial begin
        $display("=== Simple Sigmoid Test ===");
        $display("Input(hex) | Input(dec) | Output(hex) | Output(dec) | Overflow");
        $display("---------- | ---------- | ----------- | ----------- | --------");
        
        // Test key values
        test_input = 16'h801F; #10; // 0.0
        $display("   %h    |   %6.3f   |    %h    |   %7.4f   |    %b", 
                 test_input, $signed(test_input)/256.0, sigmoid_result, 
                 $signed(sigmoid_result)/256.0, overflow);
        
        test_input = 16'h0100; #10; // 1.0
        $display("   %h    |   %6.3f   |    %h    |   %7.4f   |    %b", 
                 test_input, $signed(test_input)/256.0, sigmoid_result, 
                 $signed(sigmoid_result)/256.0, overflow);
        
        test_input = 16'hFF00; #10; // -1.0
        $display("   %h    |   %6.3f   |    %h    |   %7.4f   |    %b", 
                 test_input, $signed(test_input)/256.0, sigmoid_result, 
                 $signed(sigmoid_result)/256.0, overflow);
        
        test_input = 16'h0300; #10; // 3.0
        $display("   %h    |   %6.3f   |    %h    |   %7.4f   |    %b", 
                 test_input, $signed(test_input)/256.0, sigmoid_result, 
                 $signed(sigmoid_result)/256.0, overflow);
        
        test_input = 16'hFD00; #10; // -3.0
        $display("   %h    |   %6.3f   |    %h    |   %7.4f   |    %b", 
                 test_input, $signed(test_input)/256.0, sigmoid_result, 
                 $signed(sigmoid_result)/256.0, overflow);
        
        test_input = 16'h0600; #10; // 6.0 (max LUT)
        $display("   %h    |   %6.3f   |    %h    |   %7.4f   |    %b", 
                 test_input, $signed(test_input)/256.0, sigmoid_result, 
                 $signed(sigmoid_result)/256.0, overflow);
        
        test_input = 16'h0800; #10; // 8.0 (beyond LUT)
        $display("   %h    |   %6.3f   |    %h    |   %7.4f   |    %b", 
                 test_input, $signed(test_input)/256.0, sigmoid_result, 
                 $signed(sigmoid_result)/256.0, overflow);
        
        $display("\n=== Test Complete ===");
        $finish;
    end

endmodule