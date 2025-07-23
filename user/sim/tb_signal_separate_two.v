`timescale 1ns / 1ps

module tb_signal_separate_two;

    // 系统参数
    parameter CLK_PERIOD = 500;         // 系统时钟周期 2MHz
    parameter ADC_CLK_PERIOD = 2000;    // ADC时钟周期 500kHz
    parameter SIM_TIME = 5_000_000;     // 仿真时间 5ms
    parameter SAMPLE_COUNT = 2400;      // 需要采样的点数

    // 信号参数
    parameter SINE_FREQ = 30_000;       // 正弦波频率 30kHz
    parameter TRI_FREQ = 60_000;        // 三角波频率 60kHz
    parameter SAMPLE_FREQ = 500_000;    // 采样频率 500kHz

    // 仿真信号
    reg clk;                            // 系统时钟
    reg rst_n;                          // 复位信号
    reg adc_clk;                        // ADC采样时钟
    reg [7:0] adc_data;                 // ADC输入数据 (8位)
    reg enable;                         // FFT模块使能
    reg fft_ready_for_data_prev;        // FFT准备接收数据信号（前一状态）

    // ADC模块信号
    wire [15:0] adc_out;                // ADC输出数据
    reg adc_out_valid;                 // ADC输出有效
    wire adc_out_valid_display;         // ADC输出有效（显示用）

    // FFT处理模块信号
    wire [27:0] fft_magnitude;          // FFT幅度输出
    wire [26:0] fft_real_part;          // FFT实部输出
    wire [26:0] fft_imag_part;          // FFT虚部输出
    wire [10:0] fft_bin_index;          // 频率点索引 (修正位宽)
    wire fft_magnitude_valid;           // 幅度数据有效
    wire fft_processing_done;           // FFT处理完成
    wire fft_ready_for_data;            // FFT准备接收数据

    // 添加FFT内部状态监控信号
    wire [3:0] fft_state;               // FFT状态机状态
    wire [11:0] fft_sample_count;       // FFT采样计数
    wire [10:0] fft_buffer_index;       // FFT缓存索引
    wire [10:0] fft_data_count;         // FFT数据计数
    wire fft_input_done;                // FFT输入完成
    wire fft_config_valid;              // FFT配置有效
    wire fft_config_ready;              // FFT配置就绪
    wire fft_data_valid;                // FFT数据有效
    wire fft_data_ready;                // FFT数据就绪
    wire fft_out_valid;                 // FFT输出有效
    wire fft_out_ready;                 // FFT输出就绪

    // 仿真计数器
    integer sample_idx = 0;
    integer file_adc, file_fft;

    // 信号生成参数
    real time_counter = 0;
    real sine_value, triangle_value, combined_value;
    real sine_amp = 50.0;               // 正弦波幅度
    real triangle_amp = 30.0;           // 三角波幅度
    real time_step;                     // 时间步长
    real adc_temp_value;                // 添加中间实数变量
    real frequency;                     // 声明frequency变量
    real phase, tri_phase;              // 三角波计算用相位变量

    // 初始化
    initial begin
        // 打开输出文件
        file_adc = $fopen("adc_output.csv", "w");
        file_fft = $fopen("fft_output.csv", "w");

        // 写入文件头
        $fwrite(file_adc, "sample_idx,time_us,adc_input,adc_output_hex,adc_output_dec\n");
        $fwrite(file_fft, "bin_index,frequency_hz,magnitude_hex,magnitude_dec,real_part_hex,real_part_dec,imag_part_hex,imag_part_dec\n");

        // 初始化信号
        clk = 0;
        rst_n = 0;
        adc_clk = 0;
        adc_data = 8'h80; // 初始ADC值 = 中间值(128)
        enable = 1;
        adc_out_valid = 0; // 初始ADC输出无效

        // 复位序列
        #100;
        rst_n = 1;
        #100;

        // 计算时间步长 (ns)
        time_step = ADC_CLK_PERIOD;
        #500;

        // 等待处理完成信号
        wait(fft_processing_done);
        $display("FFT处理完成，等待一段时间以确保所有数据都被记录...");

        // 额外等待一段时间确保所有数据都被记录
        #10000;

        // 关闭文件
        $fclose(file_adc);
        $fclose(file_fft);

        $display("仿真完成。输出文件已生成。");
        $finish;
    end

    // 系统时钟生成
    always #(CLK_PERIOD/2) clk = ~clk;

    // ADC时钟生成
    always #(ADC_CLK_PERIOD/2) adc_clk = ~adc_clk;

    // 信号生成和ADC采样
    always @(posedge adc_clk) begin
        if (rst_n && sample_idx < SAMPLE_COUNT) begin
            adc_out_valid = 1; // 设置ADC输出有效
            // 计算当前时间(us)
            time_counter = sample_idx * (1.0/SAMPLE_FREQ) * 1_000_000;

            // 生成30kHz正弦波 (振幅±50)
            sine_value = sine_amp * $sin(2.0 * 3.14159 * SINE_FREQ * time_counter / 1_000_000);

            // 生成60kHz三角波 (振幅±30) - 使用分段函数实现
            phase = (TRI_FREQ * time_counter / 1_000_000) - $floor(TRI_FREQ * time_counter / 1_000_000); // 0到1的相位
            if (phase < 0.5)
                tri_phase = 4.0 * phase - 1.0;  // 上升段 -1到1
            else
                tri_phase = 3.0 - 4.0 * phase;  // 下降段 1到-1
            triangle_value = triangle_amp * tri_phase;

            // 加入偏置后的三角波 (确保为正)
            triangle_value = triangle_value + 30.0;  // 加入偏置确保为正值

            // 叠加信号 (范围大约在±80，再加上三角波偏置30)
            combined_value = sine_value + triangle_value;

            // 使用中间变量，确保值始终为正
            adc_temp_value = 128.0 + combined_value;

            // 确保ADC数据在0-255范围内
            if (adc_temp_value > 255)
                adc_temp_value = 255;
            if (adc_temp_value < 0)
                adc_temp_value = 0;

            adc_data = $rtoi(adc_temp_value);


            // 将ADC输入数据写入文件
            if (sample_idx % 10 == 0 || sample_idx < 10) begin
                $display("Sample %d: time=%f us, raw_value=%f, adc_data=%d",
                         sample_idx, time_counter, combined_value, adc_data);
            end

            sample_idx = sample_idx + 1;
        end
        if (rst_n && sample_idx >= SAMPLE_COUNT) begin
            adc_data = 0;
            adc_out_valid = 0;  // 停止ADC采样
        end
        if(!rst_n) begin
            adc_data = 0;
            enable = 0;  // 停止FFT处理
        end
    end


    // 添加调试信息 - 监控ADC输出和FFT输入信号
    always @(posedge clk) begin
        if (adc_out_valid) begin
            $display("DEBUG: ADC output valid at time %t - Data=%h (%d)",
                     $time, adc_out, $signed(adc_out));

            // 在ADC输出有效时将数据写入文件
            $fwrite(file_adc, "%d,%f,%d,%h,%d\n",
                    sample_idx, $time/1000.0, adc_data, adc_out, $signed(adc_out));
        end
    end

    // 监控FFT处理模块的状态
    reg [3:0] prev_fft_state;
    reg fft_config_valid_prev;
    reg fft_data_valid_prev;
    reg fft_out_valid_prev;
    reg fft_magnitude_valid_prev;

    // 初始化状态监控
    initial begin
        prev_fft_state = 4'b0000;
        fft_ready_for_data_prev = 0;
        fft_config_valid_prev = 0;
        fft_data_valid_prev = 0;
        fft_out_valid_prev = 0;
        fft_magnitude_valid_prev = 0;
    end

    // 监控FFT状态机变化
    always @(posedge clk) begin
        if (u_fft_process.state != prev_fft_state) begin
            case (u_fft_process.state)
                4'b0000:
                    $display("FFT State: IDLE at time %t", $time);
                4'b0001:
                    $display("FFT State: SAMPLING at time %t", $time);
                4'b0010:
                    $display("FFT State: DATA_COPY at time %t", $time);
                4'b0011:
                    $display("FFT State: FFT_CONFIG at time %t", $time);
                4'b0100:
                    $display("FFT State: FFT_PREPARE at time %t", $time);
                4'b0101:
                    $display("FFT State: FFT_INPUT at time %t", $time);
                4'b0110:
                    $display("FFT State: FFT_WAIT at time %t", $time);
                4'b0111:
                    $display("FFT State: FFT_OUTPUT at time %t", $time);
                4'b1000:
                    $display("FFT State: MAG_CALC at time %t", $time);
                4'b1001:
                    $display("FFT State: DONE at time %t", $time);
                default:
                    $display("FFT State: UNKNOWN (%d) at time %t", u_fft_process.state, $time);
            endcase
            prev_fft_state <= u_fft_process.state;
        end
    end

    // 监控FFT配置过程
    always @(posedge clk) begin
        if (u_fft_process.fft_config_valid && !fft_config_valid_prev) begin
            $display("FFT Config started: config_data=0x%h at time %t", u_fft_process.fft_config_data, $time);
        end
        if (!u_fft_process.fft_config_valid && fft_config_valid_prev) begin
            $display("FFT Config completed at time %t", $time);
        end
        fft_config_valid_prev <= u_fft_process.fft_config_valid;
    end

    // 监控FFT输入过程
    always @(posedge clk) begin
        if (u_fft_process.fft_data_valid && !fft_data_valid_prev) begin
            $display("FFT Input started: first data=0x%h at time %t", u_fft_process.fft_data_in, $time);
        end
        if (u_fft_process.fft_data_valid && u_fft_process.fft_data_ready) begin
            if (u_fft_process.fft_data_count % 256 == 0 || u_fft_process.fft_data_count < 5) begin
                $display("FFT Input progress: count=%d/%d, data=0x%h, last=%b",
                         u_fft_process.fft_data_count, 2048, u_fft_process.fft_data_in, u_fft_process.fft_data_last);
            end
        end
        if (!u_fft_process.fft_data_valid && fft_data_valid_prev) begin
            $display("FFT Input completed at time %t", $time);
        end
        fft_data_valid_prev <= u_fft_process.fft_data_valid;
    end

    // 监控FFT输出过程
    always @(posedge clk) begin
        if (u_fft_process.fft_out_valid && !fft_out_valid_prev) begin
            $display("FFT Output started at time %t", $time);
        end
        if (u_fft_process.fft_out_valid && u_fft_process.fft_out_ready) begin
            if (u_fft_process.fft_data_count % 256 == 0 || u_fft_process.fft_data_count < 5) begin
                $display("FFT Output progress: count=%d/%d, data=0x%h, last=%b",
                         u_fft_process.fft_data_count, 2048, u_fft_process.fft_data_out, u_fft_process.fft_out_last);
            end
        end
        if (!u_fft_process.fft_out_valid && fft_out_valid_prev) begin
            $display("FFT Output completed at time %t", $time);
        end
        fft_out_valid_prev <= u_fft_process.fft_out_valid;
    end

    // 监控采样过程
    always @(posedge clk) begin
        if (u_fft_process.state == 4'b0001) begin  // SAMPLING状态
            if (adc_out_valid && u_fft_process.sample_count % 100 == 0) begin
                $display("Sampling progress: total=%d/%d, valid=%d/%d, adc_data=0x%h",
                         u_fft_process.sample_count, 2400, u_fft_process.buffer_index, 2048, adc_out);
            end
        end
    end

    // 监控幅度计算过程
    always @(posedge clk) begin
        if (fft_magnitude_valid && !fft_magnitude_valid_prev) begin
            $display("Magnitude calculation started at time %t", $time);
        end
        if (fft_magnitude_valid) begin
            if (fft_bin_index % 256 == 0 || fft_bin_index < 5) begin
                $display("Magnitude calc progress: bin=%d/%d, magnitude=0x%h",
                         fft_bin_index, 2048, fft_magnitude);
            end
        end
        fft_magnitude_valid_prev <= fft_magnitude_valid;
    end

    // 监控处理完成信号
    always @(posedge clk) begin
        if (fft_processing_done) begin
            $display("FFT Processing completed at time %t", $time);
        end
        if (fft_ready_for_data && !fft_ready_for_data_prev) begin
            $display("FFT ready for data at time %t", $time);
        end
        fft_ready_for_data_prev <= fft_ready_for_data;
    end

    // 添加错误检查和深度调试
    always @(posedge clk) begin
        // 检查FFT模块是否卡在某个状态
        if (enable && u_fft_process.state == prev_fft_state) begin
            // 记录在同一状态停留的时间
            // 这里只是简单的检查，可以根据需要扩展
        end

        // 检查ADC数据是否正确传递到FFT模块
        if (adc_out_valid && fft_ready_for_data) begin
            if (sample_idx % 100 == 0) begin
                $display("DEBUG: ADC->FFT data transfer: sample_idx=%d, adc_out=0x%h, fft_state=%d",
                         sample_idx, adc_out, u_fft_process.state);
            end
        end

        // 检查FFT输入是否有问题
        if (u_fft_process.state == 4'b0101) begin  // FFT_INPUT状态
            if (!u_fft_process.fft_data_ready && u_fft_process.fft_data_valid) begin
                $display("WARNING: FFT IP not ready but trying to send data at time %t", $time);
            end
        end

        // 检查FFT输出是否有问题
        if (u_fft_process.state == 4'b0111) begin  // FFT_OUTPUT状态
            if (u_fft_process.fft_out_valid && !u_fft_process.fft_out_ready) begin
                $display("WARNING: FFT output valid but not ready to receive at time %t", $time);
            end
        end


    end

    // 添加FFT IP核状态监控
    always @(posedge clk) begin
        // 监控FFT IP核的握手信号
        if (u_fft_process.state == 4'b0011) begin  // FFT_CONFIG状态
            if (u_fft_process.fft_config_valid && u_fft_process.fft_config_ready) begin
                $display("DEBUG: FFT IP config handshake successful at time %t", $time);
            end
        end

        // 监控数据输入握手
        if (u_fft_process.state == 4'b0101) begin  // FFT_INPUT状态
            if (u_fft_process.fft_data_valid && u_fft_process.fft_data_ready) begin
                if (u_fft_process.fft_data_count == 0 || u_fft_process.fft_data_count == 2047) begin
                    $display("DEBUG: FFT data handshake: count=%d, data=0x%h, last=%b",
                             u_fft_process.fft_data_count, u_fft_process.fft_data_in, u_fft_process.fft_data_last);
                end
            end
        end

        // 监控数据输出握手
        if (u_fft_process.state == 4'b0111) begin  // FFT_OUTPUT状态
            if (u_fft_process.fft_out_valid && u_fft_process.fft_out_ready) begin
                if (u_fft_process.fft_data_count == 0 || u_fft_process.fft_data_count >= 2046) begin
                    $display("DEBUG: FFT output handshake: count=%d, data=0x%h, last=%b",
                             u_fft_process.fft_data_count, u_fft_process.fft_data_out, u_fft_process.fft_out_last);
                end
            end
        end
    end

    // 监控关键数据值
    always @(posedge clk) begin
        // 检查ADC输入是否为零
        if (adc_out_valid && adc_out == 16'h0000) begin
            $display("WARNING: ADC output is zero at sample %d, time %t", sample_idx, $time);
        end

        // 检查FFT结果是否为零
        if (fft_magnitude_valid && fft_magnitude == 28'h0000000) begin
            $display("WARNING: FFT magnitude is zero at bin %d", fft_bin_index);
        end

        // 报告非零的幅度值（前几个和大的值）
        if (fft_magnitude_valid && (fft_bin_index < 10 || fft_magnitude > 28'h1000000)) begin
            $display("INFO: Significant magnitude at bin %d: 0x%h (freq=%.2f kHz)",
                     fft_bin_index, fft_magnitude, fft_bin_index * (SAMPLE_FREQ * 1.0 / 2048) / 1000);
        end
    end

    // 实例化ADC模块
    adc u_adc (
            .clk(clk),                  // 系统时钟
            .rst_n(rst_n),              // 复位信号
            .adc_data(adc_data),        // ADC输入数据 (8位)
            .adc_clk(adc_clk),          // ADC采样时钟
            .data_out(adc_out),         // 处理后的ADC数据 (16位Q1.15格式)
            .data_valid(adc_out_valid_display)  // 数据有效信号
        );

    // 实例化FFT处理模块
    fft_process u_fft_process (
                    .clk(clk),                          // 系统时钟
                    .rst_n(rst_n),                      // 复位信号
                    .adc_input(adc_out),                // ADC输入信号 (Q1.15格式)
                    .adc_valid(adc_out_valid),          // ADC数据有效信号
                    .enable(enable),                    // 模块使能信号

                    .magnitude(fft_magnitude),          // FFT幅度输出
                    .real_part(fft_real_part),          // FFT实部输出
                    .imag_part(fft_imag_part),          // FFT虚部输出
                    .bin_index(fft_bin_index),          // 频率点索引
                    .magnitude_valid(fft_magnitude_valid),  // 幅度数据有效信号
                    .processing_done(fft_processing_done),  // 处理完成信号
                    .ready_for_data(fft_ready_for_data)     // 准备接收数据信号
                );

endmodule
