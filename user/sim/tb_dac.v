`timescale 1ns/1ps

module tb_dac();

// Test different data widths
localparam DATA_WIDTH_8 = 8;
localparam DATA_WIDTH_10 = 10;

// Test signals for 8-bit DAC
reg clk;
reg rst_n;
reg [DATA_WIDTH_8-1:0] data_in_8;
reg data_valid_8;
wire dac_out_8;
wire dac_clk_8;

// Test signals for 10-bit DAC
reg [DATA_WIDTH_10-1:0] data_in_10;
reg data_valid_10;
wire dac_out_10;
wire dac_clk_10;

// Instance of 8-bit DAC
dac #(
    .DATA_WIDTH(DATA_WIDTH_8)
) u_dac_8 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_in_8),
    .data_valid(data_valid_8),
    .dac_out(dac_out_8),
    .dac_clk(dac_clk_8)
);

// Instance of 10-bit DAC
dac #(
    .DATA_WIDTH(DATA_WIDTH_10)
) u_dac_10 (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_in_10),
    .data_valid(data_valid_10),
    .dac_out(dac_out_10),
    .dac_clk(dac_clk_10)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz clock
end

// Test stimulus
initial begin
    // Initialize signals
    rst_n = 0;
    data_in_8 = 0;
    data_in_10 = 0;
    data_valid_8 = 0;
    data_valid_10 = 0;
    
    // Wait for 100ns and release reset
    #100;
    rst_n = 1;
    data_valid_8 = 1;
    data_valid_10 = 1;
    
    // Test case 1: Ramp test for 8-bit DAC
    for (integer i = 0; i < 256; i = i + 1) begin
        data_in_8 = i;
        #100;  // Wait for PWM cycle
    end
    
    // Test case 2: Ramp test for 10-bit DAC
    for (integer i = 0; i < 1024; i = i + 4) begin
        data_in_10 = i;
        #100;  // Wait for PWM cycle
    end
    
    // Test case 3: Sine wave for 8-bit DAC
    repeat(256) begin
        data_in_8 = $rtoi(127 + 127*$sin(2*3.14159*$time/1000));
        #100;
    end
    
    // Test case 4: Sine wave for 10-bit DAC
    repeat(256) begin
        data_in_10 = $rtoi(511 + 511*$sin(2*3.14159*$time/1000));
        #100;
    end
    
    // Test case 5: Toggle data valid
    data_valid_8 = 0;
    data_valid_10 = 0;
    #1000;
    data_valid_8 = 1;
    data_valid_10 = 1;
    #1000;
    
    // End simulation
    #1000;
    $finish;
end

// Monitor PWM outputs
reg [7:0] pwm_count_8;
reg [9:0] pwm_count_10;

always @(posedge clk) begin
    if (dac_out_8)  pwm_count_8  <= pwm_count_8 + 1;
    if (dac_out_10) pwm_count_10 <= pwm_count_10 + 1;
end

// Display results
initial begin
    $monitor("Time=%0t 8bit_in=%h 8bit_pwm=%b 10bit_in=%h 10bit_pwm=%b",
             $time, data_in_8, dac_out_8, data_in_10, dac_out_10);
    $dumpfile("tb_dac.vcd");
    $dumpvars(0, tb_dac);
end

endmodule
