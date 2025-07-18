/**
 * 信号分离模块测试文件 (Signal Separation Module Testbench)
 * 
 * 测试目标：
 * 1. 验证ADC数据输入处理
 * 2. 验证FFT变换功能
 * 3. 验证低频和高频分量分离
 * 4. 验证状态机工作流程
 * 
 * 频率设计说明：
 * - ADC采样频率：10MHz (100ns周期)
 * - 系统时钟：100MHz (10ns周期)
 * - 测试信号基频：1MHz (根据奈奎斯特定理，< 5MHz)
 * - 高频测试信号：4MHz (仍在奈奎斯特频率范围内)
 * - 频率计算：f_signal = f_sampling / N，其中N为采样点数每周期
 *   * 1MHz信号：N = 10MHz / 1MHz = 10个采样点/周期
 *   * 4MHz信号：N = 10MHz / 4MHz = 2.5个采样点/周期
 */

`timescale 1ns / 1ps

module tb_signal_separation_enhanced();

    // ===============================
    // 测试信号定义 (Test Signal Definitions)
    // ===============================
    reg clk;                        // 系统时钟
    reg rst_n;                      // 复位信号
    reg [7:0] adc_data;            // ADC输入数据
    reg adc_clk;                   // ADC采样时钟
    wire [7:0] low_freq_out;       // 低频输出
    wire [7:0] high_freq_out;      // 高频输出
    
    // 测试控制信号
    integer i;
    integer test_cycle;
    
    // 频率验证变量
    real expected_freq_1mhz;
    real expected_freq_4mhz;
    integer freq_bin_1mhz;
    integer freq_bin_4mhz;
    
    // 计算预期的频率分量位置
    initial begin
        expected_freq_1mhz = 1.0e6;  // 1MHz
        expected_freq_4mhz = 4.0e6;  // 4MHz
        freq_bin_1mhz = $rtoi(expected_freq_1mhz * 1024 / 10.0e6);  // ≈ 102
        freq_bin_4mhz = $rtoi(expected_freq_4mhz * 1024 / 10.0e6);  // ≈ 409
        
        $display("预期频率分量位置:");
        $display("1MHz信号 -> 频率分量 %d", freq_bin_1mhz);
        $display("4MHz信号 -> 频率分量 %d", freq_bin_4mhz);
        $display("低频/高频分离阈值: 256");
    end
    
    // ===============================
    // 时钟生成 (Clock Generation)
    // ===============================
    // 系统时钟：100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns周期 = 100MHz
    end
    
    // ADC采样时钟：10MHz
    initial begin
        adc_clk = 0;
        forever #50 adc_clk = ~adc_clk;  // 100ns周期 = 10MHz
    end
    
    // ===============================
    // 被测模块实例化 (DUT Instantiation)
    // ===============================
    signal_separation u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .adc_data(adc_data),
        .adc_clk(adc_clk),
        .low_freq_out(low_freq_out),
        .high_freq_out(high_freq_out)
    );
    
    // ===============================
    // 测试激励 (Test Stimulus)
    // ===============================
    initial begin
        // 初始化信号
        rst_n = 0;
        adc_data = 8'h0;
        test_cycle = 0;
        
        // 等待时钟稳定
        #100;
        
        // 释放复位
        rst_n = 1;
        #100;
        
        $display("=====================================");
        $display("开始信号分离模块测试");
        $display("=====================================");
        
        // 测试案例1：1MHz正弦波信号 (低频分量)
        $display("测试案例1：输入1MHz正弦波信号");
        for (i = 0; i < 2048; i = i + 1) begin
            @(posedge adc_clk);
            // 生成1MHz正弦波信号
            // ADC采样频率：10MHz，1MHz信号每10个采样点一个周期
            // 角频率：2π * 1MHz / 10MHz = 2π/10 = π/5
            adc_data = 8'd128 + (8'd100 * $sin(2 * 3.14159 * i / 10));
            test_cycle = test_cycle + 1;
            
            // 每隔一段时间显示输出
            if (test_cycle % 100 == 0) begin
                $display("时间: %0dns, 输入: %d, 低频输出: %d, 高频输出: %d", 
                         $time, adc_data, low_freq_out, high_freq_out);
            end
        end
        
        #1000;
        
        // 测试案例2：1MHz方波信号 (包含高频分量)
        $display("测试案例2：输入1MHz方波信号");
        for (i = 0; i < 2048; i = i + 1) begin
            @(posedge adc_clk);
            // 生成1MHz方波信号
            // 每10个采样点一个周期，前5个高电平，后5个低电平
            if ((i % 10) < 5) begin
                adc_data = 8'd200;  // 高电平
            end else begin
                adc_data = 8'd50;   // 低电平
            end
            test_cycle = test_cycle + 1;
            
            // 每隔一段时间显示输出
            if (test_cycle % 100 == 0) begin
                $display("时间: %0dns, 输入: %d, 低频输出: %d, 高频输出: %d", 
                         $time, adc_data, low_freq_out, high_freq_out);
            end
        end
        
        #1000;
        
        // 测试案例3：复合信号（低频1MHz + 高频4MHz）
        $display("测试案例3：输入复合信号（1MHz基频 + 4MHz高频）");
        for (i = 0; i < 2048; i = i + 1) begin
            @(posedge adc_clk);
            // 生成复合信号：1MHz基频 + 4MHz高频分量
            // 1MHz: 每10个采样点一个周期
            // 4MHz: 每2.5个采样点一个周期
            adc_data = 8'd128 + 
                       (8'd60 * $sin(2 * 3.14159 * i / 10)) +    // 1MHz基频分量
                       (8'd20 * $sin(2 * 3.14159 * i / 2.5));    // 4MHz高频分量
            test_cycle = test_cycle + 1;
            
            // 每隔一段时间显示输出
            if (test_cycle % 100 == 0) begin
                $display("时间: %0dns, 输入: %d, 低频输出: %d, 高频输出: %d", 
                         $time, adc_data, low_freq_out, high_freq_out);
            end
        end
        
        #2000;
        
        $display("=====================================");
        $display("信号分离模块测试完成");
        $display("=====================================");
        
        $finish;
    end
    
    // ===============================
    // 监控和调试 (Monitoring and Debug)
    // ===============================
    initial begin
        // 生成VCD文件用于波形查看
        $dumpfile("tb_signal_separation_enhanced.vcd");
        $dumpvars(0, tb_signal_separation_enhanced);
        
        // 显示状态机状态名称
        $display("状态机状态编码:");
        $display("IDLE_STATE = 0, CONFIG_STATE = 1, INPUT_STATE = 2");
        $display("PROCESSING_STATE = 3, OUTPUT_STATE = 4");
    end
    
    // 状态变化监控
    always @(posedge clk) begin
        if (u_dut.current_state != u_dut.next_state) begin
            case (u_dut.next_state)
                3'b000: $display("时间: %0dns, 状态转换: -> IDLE_STATE", $time);
                3'b001: $display("时间: %0dns, 状态转换: -> CONFIG_STATE", $time);
                3'b010: $display("时间: %0dns, 状态转换: -> INPUT_STATE", $time);
                3'b011: $display("时间: %0dns, 状态转换: -> PROCESSING_STATE", $time);
                3'b100: $display("时间: %0dns, 状态转换: -> OUTPUT_STATE", $time);
                default: $display("时间: %0dns, 状态转换: -> UNKNOWN_STATE(%d)", $time, u_dut.next_state);
            endcase
        end
    end
    
    // FFT处理进度监控
    always @(posedge clk) begin
        if (u_dut.fft_input_valid && u_dut.fft_input_ready) begin
            if (u_dut.input_sample_counter % 100 == 0) begin
                $display("FFT输入进度: %d/1024", u_dut.input_sample_counter);
            end
        end
        
        if (u_dut.fft_output_valid && u_dut.fft_output_ready) begin
            if (u_dut.output_sample_counter % 100 == 0) begin
                $display("FFT输出进度: %d/1024", u_dut.output_sample_counter);
            end
        end
    end
    
    // 超时保护
    initial begin
        #700000;  // 700us超时 (考虑3个测试案例的处理时间)
        $display("测试超时！");
        $finish;
    end

endmodule
