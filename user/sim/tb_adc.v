`timescale 1ns/1ps

module tb_adc();

// Test signals
reg clk;
reg rst_n;
reg [7:0] adc_data;
reg adc_clk;
wire [7:0] data_out;
wire data_valid;

// Instance of ADC module
adc u_adc (
    .clk(clk),
    .rst_n(rst_n),
    .adc_data(adc_data),
    .adc_clk(adc_clk),
    .data_out(data_out),
    .data_valid(data_valid)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz clock
end

initial begin
    adc_clk = 0;
    forever #10 adc_clk = ~adc_clk;  // 50MHz ADC clock
end

// Test stimulus
initial begin
    // Initialize signals
    rst_n = 0;
    adc_data = 8'h00;
    
    // Wait for 100ns and release reset
    #100;
    rst_n = 1;
    
    // Test case 1: Basic data sampling
    repeat(32) begin
        adc_data = $random;  // Generate random test data
        @(posedge adc_clk);
        #2;  // Wait for data to be sampled
    end
    
    // Test case 2: Continuous wave pattern
    repeat(256) begin
        // Generate sine wave pattern
        adc_data = $rtoi(127 + 64*$sin(2*3.14159*$time/1000));
        @(posedge adc_clk);
        #2;
    end
    
    // Test case 3: Fast changing data
    repeat(32) begin
        adc_data = 8'hFF;
        @(posedge adc_clk);
        #2;
        adc_data = 8'h00;
        @(posedge adc_clk);
        #2;
    end
    
    // End simulation
    #1000;
    $finish;
end

// Monitor output
initial begin
    $monitor("Time=%0t rst_n=%b adc_data=%h data_out=%h valid=%b",
             $time, rst_n, adc_data, data_out, data_valid);
    $dumpfile("tb_adc.vcd");
    $dumpvars(0, tb_adc);
end

endmodule
