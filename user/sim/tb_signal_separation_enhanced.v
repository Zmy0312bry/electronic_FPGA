/**
 * 增强型信号分离仿真测试台
 * Enhanced Signal Separation Testbench
 * 
 * 功能：
 * 1. 生成10kHz正弦信号，使用100kHz ADC采样
 * 2. 采样100个点后补零至1024点
 * 3. 执行1024点FFT变换
 * 4. 输出ADC采样数据、原始信号、FFT实部/虚部和幅度值
 */

`timescale 1ns/1ps

module tb_signal_separation_enhanced();

    // ============================================
    // 测试参数定义 (Test Parameters)
    // ============================================
    parameter CLK_PERIOD = 10;              // 系统时钟周期：10ns (100MHz)
    parameter ADC_CLK_PERIOD = 5000;        // ADC时钟周期：5000ns = 5μs (200kHz采样率，每周期20个采样点)
    parameter SAMPLE_POINTS = 200;          // 采样点数
    parameter FFT_POINTS = 1024;            // FFT点数
    parameter SIN_FREQ = 10000;             // 正弦信号频率：10kHz
    
    // ============================================
    // 时钟和复位信号 (Clock and Reset Signals)
    // ============================================
    reg clk;                                // 系统时钟
    reg rst_n;                              // 复位信号
    reg adc_clk;                            // ADC时钟
    
    // ============================================
    // 信号生成相关 (Signal Generation)
    // ============================================
    reg [15:0] adc_data;                    // ADC输入数据 - 16位定点数 (1位符号+15位小数)
    reg [31:0] time_counter;                // 时间计数器
    real sin_value;                         // 正弦值
    
    // ============================================
    // 测试控制信号 (Test Control Signals)
    // ============================================
    reg start_sampling;                     // 开始采样控制信号
    reg [10:0] sample_counter;              // 采样计数器
    reg [10:0] fft_input_counter;           // FFT输入计数器
    reg [10:0] fft_output_counter;          // FFT输出计数器
    reg sampling_done;                      // 采样完成标志
    reg fft_processing;                     // FFT处理中标志
    reg fft_done;                           // FFT处理完成标志
    
    // ============================================
    // 数据存储寄存器 (Data Storage Registers)
    // ============================================
    reg [15:0] adc_samples [0:FFT_POINTS-1];     // ADC采样数据存储 - 16位定点数 (1位符号+15位小数)
    reg [15:0] original_signal [0:SAMPLE_POINTS-1]; // 原始信号存储 - 16位定点数
    reg [26:0] fft_real_out [0:FFT_POINTS-1];   // FFT实部输出 - 27位定点数 Q12.15格式
    reg [26:0] fft_imag_out [0:FFT_POINTS-1];   // FFT虚部输出 - 27位定点数 Q12.15格式
    
    // ============================================
    // FFT相关信号 (FFT Related Signals)  
    // ============================================
    reg [15:0] fft_config_data;             // FFT配置数据
    reg fft_config_valid;                   // FFT配置有效信号
    wire fft_config_ready;                  // FFT配置就绪信号
    
    reg [31:0] fft_input_data;              // FFT输入数据 (16位实部 + 16位虚部)
    reg fft_input_valid;                    // FFT输入有效信号
    reg fft_input_last;                     // FFT输入最后信号
    wire fft_input_ready;                   // FFT输入就绪信号
    
    wire [58:0] fft_output_data;            // FFT输出数据 - 59位总线
    wire fft_output_valid;                  // FFT输出有效信号
    wire fft_output_last;                   // FFT输出最后信号
    reg fft_output_ready;                   // FFT输出就绪信号
    
    // ============================================
    // FFT进度指示信号 (FFT Progress Indicators)
    // ============================================
    reg [7:0] fft_progress_percent;         // FFT进度百分比
    reg [10:0] fft_progress_counter;        // FFT进度计数器
    
    // ============================================
    // 状态机定义 (State Machine Definition)
    // ============================================
    localparam [3:0] 
        IDLE = 4'b0000,                     // 空闲状态
        INIT = 4'b0001,                     // 初始化状态
        SAMPLING = 4'b0010,                 // 采样状态
        FFT_CONFIG = 4'b0011,               // FFT配置状态
        FFT_INPUT = 4'b0100,                // FFT输入状态
        FFT_PROCESS = 4'b0101,              // FFT处理状态
        FFT_OUTPUT = 4'b0110,               // FFT输出状态
        COMPLETE = 4'b0111;                 // 完成状态
    
    reg [3:0] current_state, next_state;
    
    integer i, j; // 循环变量
    
    // ============================================
    // 仿真波形显示控制 (Simulation Waveform Display Control)
    // ============================================
    initial begin
        // 创建VCD文件，只记录需要的信号
        $dumpfile("tb_signal_separation_enhanced.vcd");
        $dumpvars(0, tb_signal_separation_enhanced);
        
        // 只显示关键信号的变化
        $display("=== Key Signals for Waveform Display ===");
        $display("- adc_data: ADC input signal");
        $display("- current_state: State machine status");
        $display("- adc_samples[]: ADC sampled data array");
        $display("- original_signal[]: Original signal array"); 
        $display("- fft_real_out[]: FFT real part array");
        $display("- fft_imag_out[]: FFT imaginary part array");
        $display("- fft_magnitude[]: FFT magnitude array");
        $display("- fft_progress_percent: FFT processing progress");
        $display("==========================================");
    end
    
    // ============================================
    // 时钟生成 (Clock Generation)
    // ============================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        adc_clk = 0;
        forever #(ADC_CLK_PERIOD/2) adc_clk = ~adc_clk;
    end
    
    // ============================================
    // 复位和初始化 (Reset and Initialization)
    // ============================================
    initial begin
        // 初始化所有信号
        rst_n = 0;
        time_counter = 0;
        sample_counter = 0;
        fft_input_counter = 0;
        fft_output_counter = 0;
        sampling_done = 0;
        fft_processing = 0;
        fft_done = 0;
        start_sampling = 0;
        fft_progress_percent = 0;
        fft_progress_counter = 0;
        
        // 初始化FFT信号
        fft_config_data = 16'h0001;         // 前向FFT配置
        fft_config_valid = 0;
        fft_input_data = 32'h0;
        fft_input_valid = 0;
        fft_input_last = 0;
        fft_output_ready = 1;
        
        // 清零所有数据寄存器
        $display("Initializing data arrays to zero...");
        for (i = 0; i < FFT_POINTS; i = i + 1) begin
            adc_samples[i] = 16'h0;
            fft_real_out[i] = 27'h0;
            fft_imag_out[i] = 27'h0;
        end
        
        for (i = 0; i < SAMPLE_POINTS; i = i + 1) begin
            original_signal[i] = 16'h0;
        end
        
        // 复位序列
        #100;
        rst_n = 1;
        #100;
        start_sampling = 1;
        $display("System reset completed, starting simulation...");
    end
    
    // ============================================
    // 10kHz正弦信号生成 (10kHz Sine Wave Generation)
    // ============================================
    always @(posedge adc_clk or negedge rst_n) begin
        if (!rst_n) begin
            time_counter <= 0;
            adc_data <= 16'h0; // 零点值
            sin_value <= 0.0;
        end else begin
            // 计算正弦信号：幅度1，无偏移，16位定点数格式(1位符号+15位小数)
            sin_value = 1.0 * $sin(2.0 * 3.14159265 * SIN_FREQ * time_counter * ADC_CLK_PERIOD / 1000000000.0);
            // 转换为16位定点数：1位符号+15位小数
            adc_data <= $rtoi(sin_value * 32768.0); // 左移15位表示小数部分
            time_counter <= time_counter + 1; // 每个ADC时钟递增1
        end
    end
    
    // ============================================
    // 状态机控制逻辑 (State Machine Control Logic)
    // ============================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // 状态转移逻辑
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start_sampling) 
                    next_state = INIT;
            end
            
            INIT: begin
                next_state = SAMPLING;
            end
            
            SAMPLING: begin
                if (sampling_done)
                    next_state = FFT_CONFIG;
            end
            
            FFT_CONFIG: begin
                if (fft_config_ready)
                    next_state = FFT_INPUT;
            end
            
            FFT_INPUT: begin
                if (fft_input_counter >= FFT_POINTS && fft_input_ready)
                    next_state = FFT_PROCESS;
            end
            
            FFT_PROCESS: begin
                if (fft_output_valid)
                    next_state = FFT_OUTPUT;
            end
            
            FFT_OUTPUT: begin
                if (fft_output_counter >= FFT_POINTS && fft_output_last)
                    next_state = COMPLETE;
            end
            
            COMPLETE: begin
                next_state = COMPLETE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // ============================================
    // 采样控制逻辑 (Sampling Control Logic)
    // ============================================
    always @(posedge adc_clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_counter <= 0;
            sampling_done <= 0;
        end else if (current_state == SAMPLING && !sampling_done) begin
            if (sample_counter < SAMPLE_POINTS) begin
                // 存储ADC采样数据和原始信号
                adc_samples[sample_counter] <= adc_data;
                original_signal[sample_counter] <= adc_data;
                sample_counter <= sample_counter + 1;
                
                // 每10个采样点显示一次进度和采样值
                if (sample_counter % 10 == 0) begin
                    $display("Sampling progress: %d/200 points completed, Current ADC value: %h", 
                             sample_counter, adc_data);
                end
                
                // 显示前几个采样点的详细信息
                if (sample_counter < 20) begin
                    $display("Sample[%d] = %h (Time: %d * 5us = %0.1f us)", 
                             sample_counter, adc_data, sample_counter, sample_counter * 5.0);
                end
            end else begin
                sampling_done <= 1;
                $display("Sampling completed! 200 points sampled, remaining 824 points set to zero");
                $display("Expected: 10 complete cycles of 10kHz signal (each cycle = 20 samples)");
            end
        end
    end
    
    // ============================================
    // FFT配置控制 (FFT Configuration Control)
    // ============================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fft_config_valid <= 0;
        end else if (current_state == FFT_CONFIG) begin
            fft_config_valid <= 1;
            if (fft_config_ready) begin
                $display("FFT configuration completed, starting FFT input phase...");
                fft_config_valid <= 0;
            end
        end else begin
            fft_config_valid <= 0;
        end
    end
    
    // ============================================
    // FFT输入控制逻辑 (FFT Input Control Logic)
    // ============================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fft_input_counter <= 0;
            fft_input_valid <= 0;
            fft_input_last <= 0;
            fft_processing <= 0;
        end else if (current_state == FFT_INPUT) begin
            if (!fft_processing) begin
                fft_processing <= 1;
                $display("Starting 1024-point FFT processing...");
            end
            
            if (fft_input_ready && fft_input_counter < FFT_POINTS) begin
                // 组装FFT输入数据：实部为ADC定点数据，虚部为0
                fft_input_data <= {adc_samples[fft_input_counter], 16'h0};
                fft_input_valid <= 1;
                
                // 最后一个数据点
                if (fft_input_counter == FFT_POINTS - 1) begin
                    fft_input_last <= 1;
                end
                
                fft_input_counter <= fft_input_counter + 1;
                
                // 更新FFT输入进度
                fft_progress_percent <= (fft_input_counter * 50) / FFT_POINTS; // 输入阶段占50%
                if (fft_input_counter % 102 == 0) begin // 每10%显示一次
                    $display("FFT input progress: %d%% (%d/1024 points)", 
                             fft_progress_percent, fft_input_counter);
                end
            end else begin
                fft_input_valid <= 0;
                fft_input_last <= 0;
            end
        end else begin
            fft_input_valid <= 0;
            fft_input_last <= 0;
        end
    end
    
    // ============================================
    // FFT输出处理逻辑 (FFT Output Processing Logic)
    // ============================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fft_output_counter <= 0;
            fft_output_ready <= 1;
            fft_done <= 0;
        end else if (current_state == FFT_OUTPUT) begin
            if (fft_output_valid && fft_output_ready) begin
                // 提取FFT输出的实部和虚部 - 从59位数据总线中提取
                fft_real_out[fft_output_counter] <= fft_output_data[26:0];   // Q12.15格式实部 (27位)
                fft_imag_out[fft_output_counter] <= fft_output_data[58:32];  // Q12.15格式虚部 (27位)
                
                fft_output_counter <= fft_output_counter + 1;
                
                // 更新FFT输出进度 (50%-100%)
                fft_progress_percent <= 50 + (fft_output_counter * 50) / FFT_POINTS;
                if (fft_output_counter % 102 == 0) begin // 每10%显示一次
                    $display("FFT output progress: %d%% (%d/1024 points processed)", 
                             fft_progress_percent, fft_output_counter);
                end
                
                if (fft_output_last) begin
                    fft_done <= 1;
                    $display("FFT processing completed successfully!");
                    $display("Real and imaginary parts extracted for all %d points", FFT_POINTS);
                    $display("Ready to export data and terminate simulation...");
                end
            end
        end
    end
    
    // ============================================
    // Xilinx FFT IP核实例化 (Xilinx FFT IP Core)
    // ============================================
    xfft_0 u_fft_core (
        .aclk(clk),                              // 系统时钟
        
        // 配置接口
        .s_axis_config_tdata(fft_config_data),   // 配置数据
        .s_axis_config_tvalid(fft_config_valid), // 配置有效信号
        .s_axis_config_tready(fft_config_ready), // 配置就绪信号
        
        // 输入数据接口
        .s_axis_data_tdata(fft_input_data),      // 输入数据
        .s_axis_data_tvalid(fft_input_valid),    // 输入有效信号
        .s_axis_data_tready(fft_input_ready),    // 输入就绪信号
        .s_axis_data_tlast(fft_input_last),      // 输入最后信号
        
        // 输出数据接口
        .m_axis_data_tdata(fft_output_data),     // 输出数据
        .m_axis_data_tvalid(fft_output_valid),   // 输出有效信号
        .m_axis_data_tready(fft_output_ready),   // 输出就绪信号
        .m_axis_data_tlast(fft_output_last)      // 输出最后信号
    );
    
    // ============================================
    // 数据导出和仿真结束控制 (Data Export and Simulation End Control)
    // ============================================
    integer csv_file;  // CSV文件句柄
    
    initial begin
        // 等待FFT处理完成
        wait(fft_done == 1);
        #100;
        
        // 创建并写入CSV文件
        $display("Exporting FFT results to CSV file...");
        csv_file = $fopen("D:/Work/23electronic/fft_results.csv", "w");
        
        if (csv_file == 0) begin
            $display("ERROR: Cannot create CSV file!");
            $finish;
        end
        
        // 写入CSV文件头
        $fwrite(csv_file, "Index,ADC_Sample,Original_Signal,FFT_Real,FFT_Imag\n");
        
        // 写入所有FFT数据点(16进制格式)
        for (i = 0; i < FFT_POINTS; i = i + 1) begin
            if (i < SAMPLE_POINTS) begin
                // 前200个点有原始信号数据
                $fwrite(csv_file, "%d,%04x,%04x,%07x,%07x\n", 
                       i, adc_samples[i], original_signal[i], 
                       fft_real_out[i], fft_imag_out[i]);
            end else begin
                // 后824个点原始信号为0
                $fwrite(csv_file, "%d,%04x,0000,%07x,%07x\n", 
                       i, adc_samples[i], 
                       fft_real_out[i], fft_imag_out[i]);
            end
        end
        
        $fclose(csv_file);
        $display("CSV file 'fft_results.csv' created successfully!");
        
        // 显示关键结果数据
        $display("\n=== Final Results Summary ===");
        $display("- Total ADC samples: %d points", SAMPLE_POINTS);
        $display("- FFT points processed: %d points", FFT_POINTS);
        $display("- CSV file generated with all results");
        $display("First 5 sample results:");
        for (i = 0; i < 5; i = i + 1) begin
            $display("Point[%d]: ADC=%04x, Real=%07x, Imag=%07x", 
                     i, adc_samples[i], fft_real_out[i], fft_imag_out[i]);
        end
        
        $display("\n=== Simulation Completed Successfully ===");
        $finish;
    end
    
    // ============================================
    // 仿真超时保护 (Simulation Timeout Protection)
    // ============================================
    initial begin
        #10000000; // 10ms 超时 (减少超时时间，因为仿真会更快结束)
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule