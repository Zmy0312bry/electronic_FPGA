/**
 * FFT处理模块测试台
 * 
 * 功能描述：
 * 1. 生成60kHz正弦波信号作为ADC输入（q1.15定点小数格式）
 * 2. 测试FFT处理模块的完整功能
 * 3. 将输出的幅度、实部、虚部数据记录到CSV文件
 */

`timescale 1ns/1ps

module tb_fft_process();

    // ============================================
    // 测试参数定义
    // ============================================
    parameter CLK_PERIOD = 1000;            // 系统时钟周期：1000ns (1MHz)
    parameter SIN_FREQ = 60000;             // 正弦信号频率：60kHz
    parameter ADC_SAMPLE_FREQ = 500000;     // ADC采样频率：500kHz
    parameter SIMULATION_TIME = 50000000;   // 仿真时间：50ms
    
    // ============================================
    // 时钟和控制信号
    // ============================================
    reg clk;                                // 系统时钟
    reg rst_n;                              // 复位信号
    reg enable;                             // 模块使能信号
    
    // ============================================
    // ADC信号生成
    // ============================================
    reg [15:0] adc_input;                   // ADC输入信号 (q1.15格式)
    reg [31:0] time_counter;                // 时间计数器
    real sin_value;                         // 正弦波数值
    real time_ns;                           // 当前时间（纳秒）
    
    // 采样控制信号
    reg adc_valid;                          // ADC数据有效信号
    reg [7:0] sample_div_counter;           // 采样分频计数器
    wire ready_for_data;                    // FFT模块准备接收数据信号
    
    // ============================================
    // DUT输出信号
    // ============================================
    wire [27:0] magnitude;                  // FFT幅度输出
    wire [26:0] real_part;                  // FFT实部输出
    wire [26:0] imag_part;                  // FFT虚部输出
    wire [9:0] bin_index;                   // 频率点索引
    wire magnitude_valid;                   // 数据有效信号
    wire processing_done;                   // 处理完成信号
    
    // ============================================
    // 数据记录相关
    // ============================================
    integer csv_file;                       // CSV文件句柄
    reg csv_opened;                         // CSV文件打开标志
    reg [10:0] data_count;                  // 数据计数器
    real freq_hz;                           // 频率计算变量
    
    // ============================================
    // 时钟生成
    // ============================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // ============================================
    // 60kHz正弦波生成和采样控制
    // ============================================
    initial begin
        // 初始化关键信号，确保有正确的初始值
        time_counter = 32'd0;
        sin_value = 0.0;
        time_ns = 0.0;
        adc_input = 16'h0000;
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            time_counter <= 32'd0;
            adc_input <= 16'h0000;  // q1.15格式的0值
            sin_value <= 0.0;
            adc_valid <= 1'b0;
            sample_div_counter <= 8'd0;
        end else begin
            // 每个时钟周期都更新信号值（模拟连续的模拟信号）
            // 明确使用阻塞赋值计算中间值，确保即时更新
            time_ns = time_counter * CLK_PERIOD;
            sin_value = 1.0 * $sin(2.0 * 3.14159265 * SIN_FREQ * time_ns / 1000000000.0);
            
            // 调试输出，每1000个时钟周期显示一次
            if (time_counter % 1000 == 0) begin
                $display("DEBUG: time_counter=%d, time_ns=%f, sin_value=%f, adc_value=%d", 
                         time_counter, time_ns, sin_value, $rtoi(sin_value * 32767));
            end
            
            // 将正弦值转换为ADC值 (-32768 to 32767)
            adc_input <= $rtoi(sin_value * 32767);
            time_counter <= time_counter + 32'd1;  // 确保递增
            
            // 采样率控制：只在FFT模块准备接收数据时进行采样控制
            if (ready_for_data) begin
                // 1MHz / 500kHz = 2，所以每2个时钟周期标记一次有效数据
                if (sample_div_counter >= 8'd1) begin
                    sample_div_counter <= 8'd0;
                    adc_valid <= 1'b1;  // 标记数据有效
                    
                    // 打印采样信息，包括实际ADC值和sin值
                    $display("ADC Sample %d: time=%0t ns, adc_input=0x%h (%d), sin_value=%f", 
                             u_dut.sample_count + 1, $time, adc_input, $signed(adc_input), sin_value);
                             
                    // 检查采样值是否为零
                    if (adc_input == 16'h0000) begin
                        $display("WARNING: adc_input is zero at sample %d (time=%0t ns)", 
                                 u_dut.sample_count + 1, $time);
                    end
                end else begin
                    sample_div_counter <= sample_div_counter + 1'b1;
                    adc_valid <= 1'b0;  // 数据无效
                end
            end else begin
                adc_valid <= 1'b0;
                sample_div_counter <= 8'd0;  // 重置计数器
            end
        end
    end
    
    // ============================================
    // DUT实例化
    // ============================================
    fft_process u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .adc_input(adc_input),      // 16位Q1.15格式信号
        .adc_valid(adc_valid),      // ADC数据有效信号
        .enable(enable),
        .ready_for_data(ready_for_data),  // FFT模块准备接收数据信号
        .magnitude(magnitude),
        .real_part(real_part),
        .imag_part(imag_part),
        .bin_index(bin_index),
        .magnitude_valid(magnitude_valid),
        .processing_done(processing_done)
    );
    
    // ============================================
    // 测试激励控制
    // ============================================
    initial begin
        // 初始化信号
        rst_n = 0;
        enable = 0;
        csv_opened = 0;
        data_count = 0;
        
        // 复位序列
        #100;
        rst_n = 1;
        #100;
        
        // 测试ADC信号生成，确保正弦波生成正确
        #1000;  // 等待一段时间
        $display("\n=== Testing ADC Signal Generation ===");
        $display("Current ADC value: 0x%h (%d), sin_value=%f", 
                adc_input, $signed(adc_input), sin_value);
        
        #1000;  // 再等待一段时间
        $display("Next ADC value: 0x%h (%d), sin_value=%f", 
                adc_input, $signed(adc_input), sin_value);
                
        #1000;  // 再等待一段时间
        $display("Next ADC value: 0x%h (%d), sin_value=%f", 
                adc_input, $signed(adc_input), sin_value);
        $display("=======================================\n");
        
        $display("=== FFT Processing Start ===");
        $display("Input Signal: 60kHz sine wave (q1.15 fixed-point format)");
        $display("System Clock: 1MHz");
        $display("ADC Sample Rate: 500kHz (controlled by testbench)");
        $display("Total sampling: 1200 points, discard first 100 and last 76 points");
        $display("FFT Points: 1024 (middle 1024 points)");
        $display("Expected sampling time: 1200/500kHz = 2.4ms");
        
        // 启动FFT处理
        enable = 1;
        $display("FFT processing started...");
        $display("Waiting for FFT module to be ready for data...");
        
        // 等待FFT模块准备接收数据
        wait(ready_for_data == 1);
        $display("FFT module is ready, starting ADC sampling...");
        
        // 等待处理完成
        wait(processing_done == 1);
        $display("FFT processing done!");
        
        // 关闭文件
        if (csv_opened) begin
            $fclose(csv_file);
            $display("CSV has been saved at fft_results_60khz.csv");
        end
        
        // 显示测试结果统计
        $display("\n=== Test Result Statistics ===");
        $display("Total recorded frequency points: %d", data_count);
        $display("Expected peak index: %d (corresponding to 60kHz)", (60000 * 1024) / 500000);
        
        $display("\n=== Test Complete ===");
        $finish;
    end
    
    // ============================================
    // CSV文件创建和数据记录
    // ============================================
    always @(posedge clk) begin
        // 第一次检测到有效数据时打开CSV文件
        if (magnitude_valid && !csv_opened) begin
            csv_file = $fopen("D:/Work/23electronic/fft_results_60khz.csv", "w");
            if (csv_file == 0) begin
                $display("ERROR: failed to open CSV file!");
                $finish;
            end
            
            // 写入CSV文件头
            $fwrite(csv_file, "Index,Real_Part_Hex,Imag_Part_Hex,Magnitude_Hex\n");
            csv_opened = 1;
            $display("CSV file has been created, start recording data in hexadecimal format...");
        end
        
        // 记录有效数据到CSV
        if (magnitude_valid && csv_opened) begin
            // 写入CSV数据（以16进制格式导出）
            $fwrite(csv_file, "%d,%h,%h,%h\n",
                   bin_index,                    // 频率点索引（十进制序号）
                   real_part,                    // 实部（16进制格式）
                   imag_part,                    // 虚部（16进制格式）
                   magnitude);                   // 幅度（16进制格式）
            
            data_count = data_count + 1;         // 使用阻塞赋值，确保计数器立即更新
            
            // 每100个点显示一次进度
            if (bin_index % 100 == 0) begin
                $display("Processing: %d/1024 (%.1f%%) - index%d, magnitude=0x%h", 
                         bin_index + 1, (bin_index + 1) * 100.0 / 1024, 
                         bin_index, magnitude);
            end
            
            // 检测并显示峰值
            if (magnitude > 28'h1000000) begin  // 幅度阈值
                $display("** Detected peak: index%d, magnitude=0x%h, real=0x%h, imag=0x%h", 
                         bin_index, magnitude, real_part, imag_part);
            end
            
            // FFT完成后停止仿真（FFT只输出1024个频率点）
            if (data_count >= 1024) begin
                $display("\n=== FFT processing completed ===");
                if (csv_opened) begin
                    $fclose(csv_file);
                    $display("CSV has been saved at fft_results_60khz.csv");
                end
                $display("=== Test Complete ===");
                $finish;
            end
        end
    end
    
    // ============================================
    // 仿真监控和调试信息
    // ============================================
    initial begin
        // 监控DUT状态
        $monitor("Time:%0t ns, DUT Status: enable=%b, processing_done=%b, magnitude_valid=%b, bin_index=%d", 
                 $time, enable, processing_done, magnitude_valid, bin_index);
    end
    
    // 添加更多调试信息
    reg [3:0] prev_state;
    always @(posedge clk) begin
        if (u_dut.state != prev_state) begin
            case (u_dut.state)
                4'b0000: $display("FFT State changed to IDLE (%d) at time %t", u_dut.state, $time);
                4'b0001: $display("FFT State changed to SAMPLING (%d) at time %t", u_dut.state, $time);
                4'b0010: $display("FFT State changed to DATA_COPY (%d) at time %t", u_dut.state, $time);
                4'b0011: $display("FFT State changed to FFT_CONFIG (%d) at time %t", u_dut.state, $time);
                4'b0100: $display("FFT State changed to FFT_PREPARE (%d) at time %t", u_dut.state, $time);
                4'b0101: $display("FFT State changed to FFT_INPUT (%d) at time %t", u_dut.state, $time);
                4'b0110: $display("FFT State changed to FFT_WAIT (%d) at time %t", u_dut.state, $time);
                4'b0111: $display("FFT State changed to FFT_OUTPUT (%d) at time %t", u_dut.state, $time);
                4'b1000: $display("FFT State changed to MAG_CALC (%d) at time %t", u_dut.state, $time);
                4'b1001: $display("FFT State changed to DONE (%d) at time %t", u_dut.state, $time);
                default: $display("FFT State changed to UNKNOWN (%d) at time %t", u_dut.state, $time);
            endcase
            prev_state <= u_dut.state;
        end
        
        // 监控FFT输入过程
        if (u_dut.state == 4'b0101) begin  // FFT_INPUT状态
            if (u_dut.fft_data_valid && u_dut.fft_data_ready) begin
                $display("FFT Input: count=%d, data=0x%h, last=%b, input_done=%b", 
                         u_dut.fft_data_count, u_dut.fft_data_in, u_dut.fft_data_last, u_dut.fft_input_done);
            end
            if (!u_dut.fft_data_ready) begin
                $display("FFT IP not ready for data at count=%d", u_dut.fft_data_count);
            end
        end
        
        // 监控FFT输出过程
        if (u_dut.state == 4'b0111) begin  // FFT_OUTPUT状态
            if (u_dut.fft_out_valid) begin
                $display("FFT Output: count=%d, data=0x%h, last=%b", 
                         u_dut.fft_data_count, u_dut.fft_data_out, u_dut.fft_out_last);
            end
        end
        
        // 监控采样过程
        if (u_dut.state == 4'b0001) begin  // SAMPLING状态
            if (adc_valid && u_dut.sample_count % 100 == 0) begin
                $display("Sampling progress: %d/1200 total samples, %d/1024 valid samples stored", 
                         u_dut.sample_count, u_dut.buffer_index);
            end
        end
        
        // 监控配置过程
        if (u_dut.state == 4'b0011) begin  // FFT_CONFIG状态
            $display("FFT Config: valid=%b, ready=%b, data=0x%h", 
                     u_dut.fft_config_valid, u_dut.fft_config_ready, u_dut.fft_config_data);
        end
        
        // DATA_COPY状态已移除，不再需要监控
        /*if (u_dut.state == 4'b0010) begin  // DATA_COPY状态
            if (u_dut.copy_index % 256 == 0) begin
                $display("Data copy progress: %d/1024", u_dut.copy_index);
            end
        }*/
        
        if (magnitude_valid) begin
            $display("DEBUG: magnitude_valid detected! bin_index=%d, magnitude=0x%h, real=0x%h, imag=0x%h", 
                    bin_index, magnitude, real_part, imag_part);
        end
        
        // 显示采样状态
        if (ready_for_data && !prev_state[0]) begin  // ready_for_data刚变高
            $display("FFT module ready for data at time %t", $time);
        end
    end
    
    initial begin
        prev_state = 4'b0000;
    end
    
    // ============================================
    // 波形文件生成
    // ============================================
    initial begin
        $dumpfile("tb_fft_process.vcd");
        $dumpvars(0, tb_fft_process);
        
        // 只记录关键信号到波形文件中
        $dumpvars(1, clk, rst_n, enable);
        $dumpvars(1, adc_input, adc_valid, sample_div_counter, ready_for_data);  // 增加采样控制信号
        $dumpvars(1, magnitude, real_part, imag_part, bin_index);
        $dumpvars(1, magnitude_valid, processing_done);
    end
    
    // ============================================
    // 仿真超时保护
    // ============================================
    initial begin
        #SIMULATION_TIME;
        $display("ERROR: Out of simulation time!");
        if (csv_opened) $fclose(csv_file);
        $finish;
    end
    
    // ============================================
    // 信号完整性检查
    // ============================================
    always @(posedge clk) begin  
        // 检查频率点索引范围
        if (magnitude_valid && bin_index >= 1024) begin
            $display("ERROR: Index exceeds limit: %d", bin_index);
            $finish;
        end
    end

endmodule
