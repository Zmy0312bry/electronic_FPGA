module adc (
    input wire clk,              // System clock
    input wire rst_n,            // Active low reset
    input wire [7:0] adc_data,   // ADC input data (8-bit)
    input wire adc_clk,          // ADC sampling clock
    output reg [7:0] data_out,   // Processed ADC data
    output reg data_valid        // Data valid signal
);

// Parameters for sampling
parameter BUFFER_DEPTH = 256;

// Internal signals
reg [7:0] sample_buffer [0:BUFFER_DEPTH-1];
reg [$clog2(BUFFER_DEPTH)-1:0] write_ptr;
integer i;

// Sample buffer management
always @(posedge adc_clk or negedge rst_n) begin
    if (!rst_n) begin
        write_ptr <= 0;
        data_valid <= 1'b0;
        for (i = 0; i < BUFFER_DEPTH; i = i + 1) begin
            sample_buffer[i] <= 8'd0;
        end
    end else begin
        sample_buffer[write_ptr] <= adc_data;
        write_ptr <= (write_ptr + 1) % BUFFER_DEPTH;
        data_valid <= 1'b1;  // Set valid after first sample
    end
end

// Data output
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out <= 8'd0;
    end else if (data_valid) begin
        data_out <= sample_buffer[write_ptr];
    end
end

endmodule
