# Clock signal
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset signal
set_property PACKAGE_PIN U18 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# ADC Data pins
set_property PACKAGE_PIN V17 [get_ports {adc_data[0]}]
set_property PACKAGE_PIN V16 [get_ports {adc_data[1]}]
set_property PACKAGE_PIN V15 [get_ports {adc_data[2]}]
set_property PACKAGE_PIN V14 [get_ports {adc_data[3]}]
set_property PACKAGE_PIN V13 [get_ports {adc_data[4]}]
set_property PACKAGE_PIN V12 [get_ports {adc_data[5]}]
set_property PACKAGE_PIN V11 [get_ports {adc_data[6]}]
set_property PACKAGE_PIN V10 [get_ports {adc_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_data[*]}]

# ADC Clock
set_property PACKAGE_PIN W4 [get_ports adc_clk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_clk]

# Rotary Encoder pins
set_property PACKAGE_PIN T1 [get_ports encoder_a]
set_property PACKAGE_PIN R2 [get_ports encoder_b] 
set_property IOSTANDARD LVCMOS33 [get_ports {encoder_*}]

# Output signal pins
set_property PACKAGE_PIN L1 [get_ports {signal1_out[0]}]
set_property PACKAGE_PIN L2 [get_ports {signal1_out[1]}]
set_property PACKAGE_PIN L3 [get_ports {signal1_out[2]}]
set_property PACKAGE_PIN L4 [get_ports {signal1_out[3]}]
set_property PACKAGE_PIN L5 [get_ports {signal1_out[4]}]
set_property PACKAGE_PIN L6 [get_ports {signal1_out[5]}]
set_property PACKAGE_PIN L7 [get_ports {signal1_out[6]}]
set_property PACKAGE_PIN L8 [get_ports {signal1_out[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {signal1_out[*]}]

set_property PACKAGE_PIN M1 [get_ports {signal2_out[0]}]
set_property PACKAGE_PIN M2 [get_ports {signal2_out[1]}]
set_property PACKAGE_PIN M3 [get_ports {signal2_out[2]}]
set_property PACKAGE_PIN M4 [get_ports {signal2_out[3]}]
set_property PACKAGE_PIN M5 [get_ports {signal2_out[4]}]
set_property PACKAGE_PIN M6 [get_ports {signal2_out[5]}]
set_property PACKAGE_PIN M7 [get_ports {signal2_out[6]}]
set_property PACKAGE_PIN M8 [get_ports {signal2_out[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {signal2_out[*]}]

# Timing constraints
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]
create_clock -period 20.000 -name adc_clk_pin -waveform {0.000 10.000} -add [get_ports adc_clk]
