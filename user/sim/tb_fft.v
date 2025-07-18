`timescale 1ns/1ps

module tb_fft();

// Test signals
reg clk;
reg rst_n;
reg [15:0] s_axis_config_tdata;
reg s_axis_config_tvalid;
wire s_axis_config_tready;
reg [31:0] s_axis_data_tdata;
reg s_axis_data_tvalid;
reg s_axis_data_tlast;
wire s_axis_data_tready;
wire [31:0] m_axis_data_tdata;
wire m_axis_data_tvalid;
wire m_axis_data_tlast;
reg m_axis_data_tready;

// Test variables
integer i;
integer re_int, im_int;
real re_real, im_real;
real mag_real;
real prev_max_freq;
integer max_freq_bin;
integer sample_count;

// Instance of FFT module
xfft_0 u_fft (
    .aclk(clk),
    .s_axis_config_tdata(s_axis_config_tdata),
    .s_axis_config_tvalid(s_axis_config_tvalid),
    .s_axis_config_tready(s_axis_config_tready),
    .s_axis_data_tdata(s_axis_data_tdata),
    .s_axis_data_tvalid(s_axis_data_tvalid),
    .s_axis_data_tready(s_axis_data_tready),
    .s_axis_data_tlast(s_axis_data_tlast),
    .m_axis_data_tdata(m_axis_data_tdata),
    .m_axis_data_tvalid(m_axis_data_tvalid),
    .m_axis_data_tready(m_axis_data_tready),
    .m_axis_data_tlast(m_axis_data_tlast)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz clock
end

// Test stimulus
initial begin
    // Initialize signals
    s_axis_config_tdata = 16'h0;
    s_axis_config_tvalid = 0;
    s_axis_data_tdata = 32'h0;
    s_axis_data_tvalid = 0;
    s_axis_data_tlast = 0;
    m_axis_data_tready = 1;

    // Initialize test variables
    sample_count = 0;
    prev_max_freq = 0;
    max_freq_bin = 0;
    
    // Wait for 100ns and start configuration
    #100;
    
    // Configure FFT - forward transform
    s_axis_config_tdata = 16'h0; // Forward FFT
    s_axis_config_tvalid = 1;
    @(posedge clk);
    while (!s_axis_config_tready) @(posedge clk);
    s_axis_config_tvalid = 0;
    
    // Test case 1: Mixed frequency sine waves
    $display("Test Case 1: Mixed Frequency Sine Waves");
    s_axis_data_tvalid = 1;
    
    for (i = 0; i < 1024; i = i + 1) begin
        // Generate real and imaginary parts using real math
        re_real = 32767.0 * ($sin(2.0*3.14159*i/1024.0) +  // Low freq
                          0.5*$sin(2.0*3.14159*i*4.0/1024.0)); // High freq
        im_real = 0.0; // No imaginary component for input
        
        // Convert to integers
        re_int = $rtoi(re_real);
        im_int = $rtoi(im_real);
        
        // Pack into 32-bit data (16-bit real + 16-bit imaginary)
        s_axis_data_tdata = {re_int[15:0], im_int[15:0]};
        s_axis_data_tlast = (i == 1023);
        
        @(posedge clk);
        while (!s_axis_data_tready) @(posedge clk);
    end
    
    s_axis_data_tvalid = 0;
    
    // Wait for processing
    while (!m_axis_data_tlast) @(posedge clk);
    repeat(100) @(posedge clk);
    
    // Test case 2: Different amplitudes
    $display("Test Case 2: Different Amplitude Sine Waves");
    s_axis_data_tvalid = 1;
    
    for (i = 0; i < 1024; i = i + 1) begin
        // Generate real and imaginary parts using real math
        re_real = 32767.0 * (0.8*$sin(2.0*3.14159*i/1024.0) +  // Low freq (larger)
                          0.2*$sin(2.0*3.14159*i*4.0/1024.0));  // High freq (smaller)
        im_real = 0.0; // No imaginary component for input
        
        // Convert to integers
        re_int = $rtoi(re_real);
        im_int = $rtoi(im_real);
        
        // Pack into 32-bit data
        s_axis_data_tdata = {re_int[15:0], im_int[15:0]};
        s_axis_data_tlast = (i == 1023);
        
        @(posedge clk);
        while (!s_axis_data_tready) @(posedge clk);
    end
    
    s_axis_data_tvalid = 0;
    
    // Wait for final processing
    while (!m_axis_data_tlast) @(posedge clk);
    repeat(100) @(posedge clk);
    
    // End simulation
    $finish;
end

// Monitor outputs and verify frequency separation
initial begin
    $monitor("Time=%0t data=%h fft_out=%h",
             $time, s_axis_data_tdata, m_axis_data_tdata);
    $dumpfile("tb_fft.vcd");
    $dumpvars(0, tb_fft);
end

// Monitor FFT outputs
always @(posedge clk) begin
    if (m_axis_data_tvalid && m_axis_data_tready) begin
        // Extract real and imaginary parts as integers
        re_int = $signed(m_axis_data_tdata[31:16]);
        im_int = $signed(m_axis_data_tdata[15:0]);
        
        // Convert to real for magnitude calculation
        re_real = $itor(re_int);
        im_real = $itor(im_int);
        
        // Calculate magnitude using real math
        mag_real = $sqrt(re_real*re_real + im_real*im_real);
        
        // Track maximum frequency component
        if (mag_real > prev_max_freq) begin
            prev_max_freq = mag_real;
            max_freq_bin = sample_count;
        end
        
        // Increment sample counter and wrap around at 1024
        sample_count = (sample_count + 1) % 1024;
        
        // Reset on last sample and display results
        if (m_axis_data_tlast) begin
            $display("Time %0t: Maximum frequency component at bin %0d, magnitude %f",
                    $time, max_freq_bin, prev_max_freq);
            if (max_freq_bin < 256) begin
                $display("Low frequency component is dominant");
            end else begin
                $display("High frequency component is dominant");
            end
            // Reset for next frame
            prev_max_freq = 0;
            sample_count = 0;
        end
    end
end

endmodule
