module tb_sigmoid_addr_calculator;

reg [15:0] test_input;
wire [10:0] lut_addr;
wire addr_valid;
wire use_symmetry;
wire saturate_high;
wire [15:0] sigmoid_result;

// Instantiate address calculator

initial begin
    $display("Testing Sigmoid Address Calculator");
    $display("Time\tInput\t\tAddr\tValid\tSymm\tSat\tSigmoid");
    $display("----\t-----\t\t----\t-----\t----\t---\t-------");
    
    // Test positive values
    test_input = 16'h0000; #10; // 0.0
    $display("%0t\t%h (%.3f)\t%d\t%b\t%b\t%b\t%h", $time, test_input, $signed(test_input)/256.0, lut_addr, addr_valid, use_symmetry, saturate_high, sigmoid_result);
    
    test_input = 16'h0100; #10; // 1.0
    $display("%0t\t%h (%.3f)\t%d\t%b\t%b\t%b\t%h", $time, test_input, $signed(test_input)/256.0, lut_addr, addr_valid, use_symmetry, saturate_high, sigmoid_result);
    
    test_input = 16'h0300; #10; // 3.0
    $display("%0t\t%h (%.3f)\t%d\t%b\t%b\t%b\t%h", $time, test_input, $signed(test_input)/256.0, lut_addr, addr_valid, use_symmetry, saturate_high, sigmoid_result);
    
    test_input = 16'h0600; #10; // 6.0 (max)
    $display("%0t\t%h (%.3f)\t%d\t%b\t%b\t%b\t%h", $time, test_input, $signed(test_input)/256.0, lut_addr, addr_valid, use_symmetry, saturate_high, sigmoid_result);
    
    test_input = 16'h0800; #10; // 8.0 (overflow)
    $display("%0t\t%h (%.3f)\t%d\t%b\t%b\t%b\t%h", $time, test_input, $signed(test_input)/256.0, lut_addr, addr_valid, use_symmetry, saturate_high, sigmoid_result);
    
    // Test negative values
    test_input = 16'hFF00; #10; // -1.0
    $display("%0t\t%h (%.3f)\t%d\t%b\t%b\t%b\t%h", $time, test_input, $signed(test_input)/256.0, lut_addr, addr_valid, use_symmetry, saturate_high, sigmoid_result);
    
    test_input = 16'hFD00; #10; // -3.0
    $display("%0t\t%h (%.3f)\t%d\t%b\t%b\t%b\t%h", $time, test_input, $signed(test_input)/256.0, lut_addr, addr_valid, use_symmetry, saturate_high, sigmoid_result);
    
    test_input = 16'hFA00; #10; // -6.0
    $display("%0t\t%h (%.3f)\t%d\t%b\t%b\t%b\t%h", $time, test_input, $signed(test_input)/256.0, lut_addr, addr_valid, use_symmetry, saturate_high, sigmoid_result);
    
    // Test boundary cases
    test_input = 16'h0080; #10; // 0.5
    $display("%0t\t%h (%.3f)\t%d\t%b\t%b\t%b\t%h", $time, test_input, $signed(test_input)/256.0, lut_addr, addr_valid, use_symmetry, saturate_high, sigmoid_result);
    
    test_input = 16'hFF80; #10; // -0.5
    $display("%0t\t%h (%.3f)\t%d\t%b\t%b\t%b\t%h", $time, test_input, $signed(test_input)/256.0, lut_addr, addr_valid, use_symmetry, saturate_high, sigmoid_result);
    
    $finish;
end

endmodule