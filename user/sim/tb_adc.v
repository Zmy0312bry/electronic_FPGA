`timescale 1ns/1ps

module tb_adc();

// 测试信号
reg clk;                  // 系统时钟
reg rst_n;                // 复位信号，低电平有效
reg [7:0] adc_data;       // ADC输入数据 (8位)
reg adc_clk;              // ADC采样时钟
wire [15:0] data_out;     // 处理后的ADC数据 (16位Q1.15格式)
wire data_valid;          // 数据有效标志

// 添加中间变量用于监控
wire signed [15:0] signed_data_out = data_out;

// ADC模块实例化
adc u_adc (
    .clk(clk),
    .rst_n(rst_n),
    .adc_data(adc_data),
    .adc_clk(adc_clk),
    .data_out(data_out),
    .data_valid(data_valid)
);

// 时钟生成
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz系统时钟
end

initial begin
    adc_clk = 0;
    forever #10 adc_clk = ~adc_clk;  // 50MHz ADC采样时钟
end

// 正弦波参数
real amplitude = 64.0;    // 振幅
real offset = 128.0;      // 偏置
// 调整频率确保每个周期采样40个点
// 在50MHz ADC时钟(20ns周期)下，40个点的周期是40*20ns = 800ns
// 所以频率应设为1/(800ns) = 1.25MHz，参数约为1.25e-3
real frequency = 1.25e-3;   // 频率参数

// 保存输入ADC数据和处理后的输出数据到CSV文件
integer input_file, output_file;
integer sample_count = 0;  // 采样计数器
integer output_count = 0;  // 输出计数器
integer i;                 // 循环计数器

// 主测试流程 - 包含信号生成和数据采集
initial begin
    // 初始化CSV文件
    input_file = $fopen("adc_input.csv", "w");
    output_file = $fopen("adc_output.csv", "w");
    
    // 写入CSV文件的表头
    $fwrite(input_file, "Sample_Number,ADC_Input(hex)\n");
    $fwrite(output_file, "Sample_Number,Processed_Output(hex)\n");
    
    // 初始化信号
    rst_n = 0;
    adc_data = 8'h80;  // 设置为中间值128
    
    // 复位100ns后释放
    #100;
    rst_n = 1;
    
    // 生成正弦波并采样2048个点
    for (i = 0; i < 2048; i = i + 1) begin
        // 生成振幅为64的正弦波，中心为128
        adc_data = $rtoi(offset + amplitude*$sin(2*3.14159*frequency*$time));
        
        // 在ADC时钟上升沿记录输入数据
        @(posedge adc_clk);
        if (rst_n) begin
            // 保存输入数据
            $fwrite(input_file, "%d,%h\n", i, adc_data);
            sample_count = sample_count + 1;
        end
        
        // 等待2ns以确保稳定
        #2;
        
        // 检查是否有有效输出数据
        if (data_valid && rst_n) begin
            // 保存处理后的输出数据
            $fwrite(output_file, "%d,%h\n", output_count, signed_data_out);
            output_count = output_count + 1;
        end
    end
    
    // 等待一段时间让数据处理完成
    #1000;
    
    // 检查最后可能的有效输出
    repeat(100) begin
        @(posedge clk);
        if (data_valid && rst_n) begin
            $fwrite(output_file, "%d,%h\n", output_count, signed_data_out);
            output_count = output_count + 1;
        end
    end
    
    // 采样结束后关闭文件
    $fclose(input_file);
    $fclose(output_file);
    $display("CSV data collection completed. %d input samples and %d output samples saved.", sample_count, output_count);
    
    $display("Simulation completed.");
    $finish;
end

// 用于调试的监控信息
initial begin
    $monitor("Time=%0t, rst_n=%b, adc_data=%d, data_out=%d, valid=%b",
             $time, rst_n, adc_data, signed_data_out, data_valid);
    $dumpfile("tb_adc.vcd");
    $dumpvars(0, tb_adc);
end

endmodule