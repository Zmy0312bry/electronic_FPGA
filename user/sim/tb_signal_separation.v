`timescale 1ns/1ps

module tb_signal_separation();

    // Test signals
    reg clk;
    reg rst_n;
    reg [7:0] adc_data;
    reg adc_clk;
    wire [7:0] low_freq_out;
    wire [7:0] high_freq_out;

    // Instance of signal separation module
    signal_separation u_signal_separation (
                          .clk(clk),
                          .rst_n(rst_n),
                          .adc_data(adc_data),
                          .adc_clk(adc_clk),
                          .low_freq_out(low_freq_out),
                          .high_freq_out(high_freq_out)
                      );

    // Clock generation
    initial begin
        clk = 0;
        forever
            #5 clk = ~clk;    // 100MHz system clock
    end

    initial begin
        adc_clk = 0;
        forever
            #10 adc_clk = ~adc_clk;  // 50MHz ADC clock
    end

    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        adc_data = 8'h00;

        // Wait for 100ns and release reset
        #100;
        rst_n = 1;

        // // Test case 1: Pure sine waves
        // // Low frequency sine wave
        // repeat(256) begin
        //     adc_data = $rtoi(127 + 64*$sin(2*3.14159*$time/2000));
        //     @(posedge adc_clk);
        //     #2;
        // end

        // // High frequency sine wave
        // repeat(256) begin
        //     adc_data = $rtoi(127 + 64*$sin(2*3.14159*$time/500));
        //     @(posedge adc_clk);
        //     #2;
        // end

        // Test case 2: Mixed sine waves (different amplitudes)
        repeat(1000000) begin
            // Low frequency with larger amplitude, high frequency with smaller amplitude
            adc_data = $rtoi(80+48*$sin(2*3.14159*$time/600) +
                             32*$sin(2*3.14159*$time/200));
            @(posedge adc_clk);
            #2;
        end

        // // Test case 3: Sine wave + Triangle wave
        // repeat(512) begin
        //     // Low frequency sine + high frequency triangle
        //     adc_data = $rtoi(127 + 48*$sin(2*3.14159*$time/2000) +
        //                      ($time%50 > 25 ? 50-$time%50 : $time%50));
        //     @(posedge adc_clk);
        //     #2;
        // end

        // // Test case 4: Triangle wave + Sine wave
        // repeat(512) begin
        //     // Low frequency triangle + high frequency sine
        //     adc_data = $rtoi(127 + ($time%200 > 100 ? 200-$time%200 : $time%200)/2 +
        //                      32*$sin(2*3.14159*$time/500));
        //     @(posedge adc_clk);
        //     #2;
        // end

        // End simulation
        #1000;
        $finish;
    end

    // Monitor results
    initial begin
        $monitor("Time=%0t adc_data=%h low_freq=%h high_freq=%h",
                 $time, adc_data, low_freq_out, high_freq_out);
        $dumpfile("tb_signal_separation.vcd");
        $dumpvars(0, tb_signal_separation);
    end

    // Signal verification
    reg [7:0] prev_low_freq, prev_high_freq;
    integer low_freq_changes, high_freq_changes;

    always @(posedge clk) begin
        if (rst_n) begin
            // Count rate of change for both outputs
            if (prev_low_freq != low_freq_out) begin
                low_freq_changes <= low_freq_changes + 1;
            end
            if (prev_high_freq != high_freq_out) begin
                high_freq_changes <= high_freq_changes + 1;
            end

            // Verify frequency separation
            if (high_freq_changes > low_freq_changes * 2) begin
                $display("Correct frequency separation at time %0t", $time);
            end

            prev_low_freq <= low_freq_out;
            prev_high_freq <= high_freq_out;
        end
    end

endmodule
