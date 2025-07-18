module dac #(
    parameter DATA_WIDTH = 8    // Configurable data width
) (
    input wire clk,                            // System clock
    input wire rst_n,                          // Active low reset
    input wire [DATA_WIDTH-1:0] data_in,      // Input data with configurable width
    input wire data_valid,                     // Input data valid signal
    output reg dac_out,                       // DAC output (PWM)
    output reg dac_clk                        // DAC clock
);

// Parameters
parameter COUNTER_WIDTH = DATA_WIDTH;
parameter MAX_COUNT = (1 << DATA_WIDTH) - 1;

// Internal signals
reg [COUNTER_WIDTH-1:0] pwm_counter;
reg [DATA_WIDTH-1:0] current_data;
reg [3:0] clk_divider;        // For generating dac_clk

// PWM Counter for DAC output
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pwm_counter <= 0;
        dac_out <= 1'b0;
    end else begin
        pwm_counter <= (pwm_counter >= MAX_COUNT) ? 0 : pwm_counter + 1'b1;
        dac_out <= (pwm_counter < current_data);
    end
end

// Input data handling
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_data <= {DATA_WIDTH{1'b0}};
    end else if (data_valid) begin
        current_data <= data_in;
    end
end

// DAC clock generation (divided from system clock)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_divider <= 4'd0;
        dac_clk <= 1'b0;
    end else begin
        clk_divider <= clk_divider + 1'b1;
        if (clk_divider == 4'd0) begin
            dac_clk <= ~dac_clk;
        end
    end
end

endmodule
