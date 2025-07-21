/**
 * FFT处理模块
 * 
 * 功能描述：
 * 1. 直接接收Q1.15格式的16位ADC数据
 * 2. 采样1024点数据送入FFT IP核进行变换
 * 3. 计算FFT输出的幅度值（实部和虚部绝对值相加）
 * 4. 输出28位Q13.15格式的幅度数据
 */


module fft_process (
    // 系统接口
    input wire clk,                     // 系统时钟
    input wire rst_n,                   // 复位信号（低电平有效）
    input wire [15:0] adc_input,        // ADC输入信号 (q1.15格式)
    input wire adc_valid,               // ADC数据有效信号
    input wire enable,                  // 模块使能信号
    
    // 输出接口
    output reg [27:0] magnitude,        // FFT幅度输出 Q13.15格式
    output reg [26:0] real_part,        // FFT实部输出 Q12.15格式
    output reg [26:0] imag_part,        // FFT虚部输出 Q12.15格式
    output reg [10:0] bin_index,        // 当前频率点索引 (0-2047)
    output reg magnitude_valid,         // 幅度数据有效信号
    output reg processing_done,         // 处理完成信号
    output reg ready_for_data           // 准备接收数据信号
);

    // ============================================
    // 参数定义
    // ============================================
    parameter FFT_SIZE = 2048;           // FFT点数
    parameter TOTAL_SAMPLES = 2400;      // 总采样点数
    parameter DISCARD_FRONT = 200;       // 丢弃前面的采样点数
    parameter SYS_CLK_FREQ = 1_000_000;  // 系统时钟频率 1MHz
    
    // ============================================
    // 内部信号定义
    // ============================================
    // 采样控制
    reg [11:0] sample_count;             // 总采样计数器 (0-2399)
    reg [10:0] buffer_index;             // 缓存索引计数器 (0-2047)
    reg [10:0] fft_data_count;           // FFT数据计数器 (0-2047)
    reg fft_input_done;                  // FFT输入完成标志
    
    // 数据缓存 - 仅使用一个缓存数组
    reg [15:0] sample_buffer [0:FFT_SIZE-1];  // 采样缓存 - 2048点
    
    // FFT接口信号
    reg [15:0] fft_config_data;          // FFT配置数据
    reg fft_config_valid;                // FFT配置有效信号
    wire fft_config_ready;               // FFT配置就绪信号
    
    reg [31:0] fft_data_in;              // FFT输入数据 32位
    reg fft_data_valid;                  // FFT输入数据有效
    reg fft_data_last;                   // FFT输入数据最后一个
    wire fft_data_ready;                 // FFT准备接收数据
    
    wire [58:0] fft_data_out;            // FFT输出数据 59位
    wire fft_out_valid;                  // FFT输出数据有效
    wire fft_out_last;                   // FFT输出数据最后一个
    reg fft_out_ready;                   // FFT输出数据准备接收
    
    // FFT结果存储
    reg [26:0] fft_real [0:FFT_SIZE-1];  // FFT实部 Q12.15 - 2048点
    reg [26:0] fft_imag [0:FFT_SIZE-1];  // FFT虚部 Q12.15 - 2048点
    
    // 幅度计算用的临时变量
    reg [26:0] abs_real, abs_imag;
    
    // 状态机
    reg [3:0] state;
    localparam 
        IDLE          = 4'b0000,
        SAMPLING      = 4'b0001,
        DATA_COPY     = 4'b0010,  // 保留定义但不使用此状态
        FFT_CONFIG    = 4'b0011,
        FFT_PREPARE   = 4'b0100,
        FFT_INPUT     = 4'b0101,
        FFT_WAIT      = 4'b0110,
        FFT_OUTPUT    = 4'b0111,
        MAG_CALC      = 4'b1000,
        DONE          = 4'b1001;
    
    // ============================================
    // FFT IP核实例化
    // ============================================
    xfft_0 u_fft (
        .aclk(clk),                          // 系统时钟
        
        // 配置接口
        .s_axis_config_tdata(fft_config_data),   // 配置数据
        .s_axis_config_tvalid(fft_config_valid), // 配置有效信号
        .s_axis_config_tready(fft_config_ready), // 配置就绪信号
        
        // 输入数据通道
        .s_axis_data_tdata(fft_data_in),     // 输入数据
        .s_axis_data_tvalid(fft_data_valid), // 输入数据有效
        .s_axis_data_tready(fft_data_ready), // 输入数据准备就绪
        .s_axis_data_tlast(fft_data_last),   // 输入数据最后一个
        
        // 输出数据通道
        .m_axis_data_tdata(fft_data_out),    // 输出数据
        .m_axis_data_tvalid(fft_out_valid),  // 输出数据有效
        .m_axis_data_tready(fft_out_ready),  // 输出数据准备接收
        .m_axis_data_tlast(fft_out_last)     // 输出数据最后一个
    );
    
    // ============================================
    // 主状态机控制
    // ============================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sample_count <= 12'd0;
            buffer_index <= 11'd0;
            fft_data_count <= 11'd0;
            fft_input_done <= 1'b0;
            bin_index <= 11'd0;
            magnitude <= 28'd0;
            real_part <= 27'd0;
            imag_part <= 27'd0;
            magnitude_valid <= 1'b0;
            processing_done <= 1'b0;
            ready_for_data <= 1'b0;
            fft_data_valid <= 1'b0;
            fft_data_last <= 1'b0;
            fft_out_ready <= 1'b0;
            fft_config_data <= 16'h0001;        // 前向FFT配置
            fft_config_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (enable) begin
                        state <= SAMPLING;
                        sample_count <= 12'd0;
                        buffer_index <= 11'd0;
                        fft_input_done <= 1'b0;
                        processing_done <= 1'b0;
                        ready_for_data <= 1'b1;  // 准备接收数据
                    end
                    magnitude_valid <= 1'b0;
                end
                
                SAMPLING: begin
                    // 等待外部提供有效数据
                    ready_for_data <= 1'b1;
                    
                    if (adc_valid) begin  // 当外部提供有效数据时采样
                        // 只保存第200到第2247个样本（即中间2048个样本）
                        if (sample_count >= DISCARD_FRONT && sample_count < (DISCARD_FRONT + FFT_SIZE)) begin
                            sample_buffer[buffer_index] <= adc_input;
                            
                            // 调试信息：检查存储的ADC数据
                            if (buffer_index % 200 == 0 || buffer_index < 10) begin
                                $display("Saving ADC data: buffer[%d] = 0x%h (%d)", 
                                        buffer_index, adc_input, $signed(adc_input));
                            end
                            
                            buffer_index <= buffer_index + 1'b1;
                        end
                        
                        // 采样2400个点后停止
                        if (sample_count >= TOTAL_SAMPLES - 1) begin
                            state <= FFT_CONFIG;  // 直接进入FFT配置阶段
                            ready_for_data <= 1'b0;  // 停止接收数据
                            $display("Sampling completed: Collected %d total samples, %d valid samples", 
                                    sample_count + 1, buffer_index);
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end
                
                DATA_COPY: begin
                    // 不再需要复制数据，直接进入FFT配置状态
                    state <= FFT_CONFIG;
                    fft_data_count <= 10'd0;
                end
                
                FFT_CONFIG: begin
                    fft_config_valid <= 1'b1;
                    if (fft_config_ready) begin
                        fft_config_valid <= 1'b0;
                        state <= FFT_PREPARE;
                    end
                end
                
                FFT_PREPARE: begin
                    state <= FFT_INPUT;
                    fft_data_count <= 11'd0;
                end
                
                FFT_INPUT: begin
                    // 防止循环传参：只有当前一次传输完成且未标记完成时才传输
                    if (!fft_input_done && fft_data_ready && fft_data_count < FFT_SIZE) begin
                        // 检查采样缓冲区中的数据并输出
                        if (fft_data_count % 200 == 0 || fft_data_count < 10) begin
                            $display("FFT Input Check: data[%d] = 0x%h (%d)", 
                                    fft_data_count, sample_buffer[fft_data_count], 
                                    $signed(sample_buffer[fft_data_count]));
                        end
                        
                        // 直接传入16位ADC数据
                        fft_data_in <= {16'h0000, sample_buffer[fft_data_count]};
                        fft_data_valid <= 1'b1;
                        
                        // 只有最后一个数据点(count=2047)才置last信号
                        if (fft_data_count == FFT_SIZE - 1) begin
                            fft_data_last <= 1'b1;
                            fft_input_done <= 1'b1;  // 标记输入完成
                        end else begin
                            fft_data_last <= 1'b0;
                        end
                        
                        fft_data_count <= fft_data_count + 1'b1;
                    end else begin
                        // 所有数据发送完成或FFT IP不准备接收数据时
                        fft_data_valid <= 1'b0;
                        fft_data_last <= 1'b0;
                        
                        // 所有数据发送完成，转到等待状态
                        if (fft_input_done) begin
                            state <= FFT_WAIT;
                        end
                    end
                end
                
                FFT_WAIT: begin
                    fft_data_valid <= 1'b0;
                    fft_data_last <= 1'b0;
                    // 告诉FFT IP核我们已准备好接收输出数据
                    fft_out_ready <= 1'b1;
                    
                    // 调试信息
                    $display("DEBUG: FFT_WAIT - waiting for output data, fft_out_valid=%b", fft_out_valid);
                    
                    // 检查FFT IP核是否有有效输出
                    if (fft_out_valid) begin
                        state <= FFT_OUTPUT;
                        fft_data_count <= 10'd0;
                        $display("DEBUG: FFT IP core has valid output data, moving to FFT_OUTPUT state");
                    end
                end
                
                FFT_OUTPUT: begin
                    if (fft_out_valid && fft_out_ready) begin
                        // 提取FFT输出：低27位实部，高27位虚部
                        // 确保从FFT IP核中正确提取数据
                        fft_real[fft_data_count] <= fft_data_out[26:0];
                        fft_imag[fft_data_count] <= fft_data_out[58:32];
                        
                        // 添加调试信息
                        $display("DEBUG: FFT Output at point %d: Real=0x%h, Imag=0x%h", 
                                fft_data_count, fft_data_out[26:0], fft_data_out[58:32]);
                        
                        // 接收到最后一个数据点或达到FFT_SIZE-1
                        if (fft_out_last || fft_data_count >= FFT_SIZE - 1) begin
                            state <= MAG_CALC;
                            bin_index <= 11'd0;
                            fft_out_ready <= 1'b0;  // 停止接收更多数据
                        end else begin
                            fft_data_count <= fft_data_count + 1'b1;
                        end
                    end
                end
                
                MAG_CALC: begin
                    // 计算幅度：|实部| + |虚部| 并同时输出原始实部和虚部
                    if (bin_index < FFT_SIZE) begin
                        // 输出原始实部和虚部 (Q12.15格式)
                        real_part <= fft_real[bin_index];
                        imag_part <= fft_imag[bin_index];
                        
                        // 计算绝对值
                        abs_real = fft_real[bin_index][26] ? 
                                  (~fft_real[bin_index] + 1'b1) : fft_real[bin_index];
                        abs_imag = fft_imag[bin_index][26] ? 
                                  (~fft_imag[bin_index] + 1'b1) : fft_imag[bin_index];
                        
                        // 计算幅度 Q13.15格式（28位）
                        magnitude <= {1'b0, abs_real} + {1'b0, abs_imag};
                        magnitude_valid <= 1'b1;
                        
                        // 添加调试信息
                        $display("DEBUG: MAG_CALC bin_index=%d, real=0x%h, imag=0x%h, magnitude=0x%h", 
                                bin_index, fft_real[bin_index], fft_imag[bin_index], 
                                {1'b0, abs_real} + {1'b0, abs_imag});
                        
                        bin_index <= bin_index + 1'b1;
                    end else begin
                        state <= DONE;
                        magnitude_valid <= 1'b0;
                    end
                end
                
                DONE: begin
                    processing_done <= 1'b1;
                    if (!enable) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
