/**
 * 信号分离模块 (Signal Separation Module)
 * 
 * 功能说明：
 * 1. 从ADC模块接收采样信号
 * 2. 使用Xilinx FFT IP核对信号进行频域变换
 * 3. 根据频率分量将信号分离为低频和高频输出
 * 4. 支持1024点FFT变换
 */
module signal_separation (
        input wire clk,                      // 系统时钟 (System clock)
        input wire rst_n,                    // 复位信号，低电平有效 (Active low reset)
        input wire [7:0] adc_data,           // ADC输入数据，8位 (ADC input data, 8-bit)
        input wire adc_clk,                  // ADC采样时钟 (ADC sampling clock)
        output wire [7:0] low_freq_out,      // 低频输出信号 (Low frequency output)
        output wire [7:0] high_freq_out      // 高频输出信号 (High frequency output)
    );

    // ===============================
    // 参数定义 (Parameter Definitions)
    // ===============================
    
    localparam FFT_POINTS = 1024;                    // FFT点数
    localparam FFT_POINT_WIDTH = 10;                 // FFT点数位宽
    localparam LOW_FREQ_THRESHOLD = 256;             // 低频阈值 (前256个频点为低频)
    localparam DATA_WIDTH = 8;                       // 数据位宽
    localparam FFT_DATA_WIDTH = 32;                  // FFT数据位宽 (16位实部 + 16位虚部)

    // ===============================
    // ADC接口信号 (ADC Interface Signals)
    // ===============================
    
    wire [DATA_WIDTH-1:0] adc_processed_data;        // ADC处理后的数据
    wire adc_data_valid;                             // ADC数据有效信号

    // ===============================
    // FFT输入控制信号 (FFT Input Control Signals)
    // ===============================
    
    reg [15:0] fft_config_data;                      // FFT配置数据
    reg fft_config_valid;                            // FFT配置有效信号
    wire fft_config_ready;                           // FFT配置就绪信号

    // ===============================
    // FFT输入数据信号 (FFT Input Data Signals)
    // ===============================
    
    reg [FFT_DATA_WIDTH-1:0] fft_input_data;         // FFT输入数据 (32位：16位实部+16位虚部)
    reg fft_input_valid;                             // FFT输入数据有效信号
    reg fft_input_last;                              // FFT输入数据最后一个样本标志
    wire fft_input_ready;                            // FFT输入数据就绪信号

    // ===============================
    // FFT输出数据信号 (FFT Output Data Signals)
    // ===============================
    
    wire [FFT_DATA_WIDTH-1:0] fft_output_data;       // FFT输出数据 (32位：16位实部+16位虚部)
    wire fft_output_valid;                           // FFT输出数据有效信号
    wire fft_output_last;                            // FFT输出数据最后一个样本标志
    reg fft_output_ready;                            // FFT输出数据就绪信号

    // ===============================
    // 数据处理寄存器 (Data Processing Registers)
    // ===============================
    
    reg [FFT_POINT_WIDTH-1:0] input_sample_counter;  // 输入样本计数器
    reg [FFT_POINT_WIDTH-1:0] output_sample_counter; // 输出样本计数器
    reg [15:0] fft_real_part;                        // FFT实部
    reg [15:0] fft_imag_part;                        // FFT虚部
    reg [DATA_WIDTH-1:0] frequency_magnitude;        // 频率分量幅度
    reg [DATA_WIDTH-1:0] low_freq_register;          // 低频输出寄存器
    reg [DATA_WIDTH-1:0] high_freq_register;         // 高频输出寄存器

    // ===============================
    // 状态机相关信号 (State Machine Signals)
    // ===============================
    
    localparam [2:0] IDLE_STATE      = 3'b000,    // 空闲状态
                     CONFIG_STATE    = 3'b001,    // 配置状态
                     INPUT_STATE     = 3'b010,    // 输入状态
                     PROCESSING_STATE = 3'b011,   // 处理状态
                     OUTPUT_STATE    = 3'b100;    // 输出状态
    
    reg [2:0] current_state, next_state;           // 当前状态和下一状态

    // ===============================
    // ADC模块实例化 (ADC Module Instantiation)
    // 作用：对输入的ADC数据进行缓存和处理
    // ===============================
    
    adc u_adc (
        .clk(clk),                               // 系统时钟
        .rst_n(rst_n),                           // 复位信号
        .adc_data(adc_data),                     // ADC输入数据
        .adc_clk(adc_clk),                       // ADC采样时钟
        .data_out(adc_processed_data),           // 处理后的数据输出
        .data_valid(adc_data_valid)              // 数据有效信号
    );

    // ===============================
    // FFT配置控制逻辑 (FFT Configuration Control Logic)
    // 作用：配置FFT IP核的工作模式和参数
    // ===============================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fft_config_data <= 16'h0001;        // 前向FFT配置
            fft_config_valid <= 1'b0;           // 配置无效
        end
        else begin
            case (current_state)
                CONFIG_STATE: begin
                    fft_config_data <= 16'h0001;    // 前向FFT，无缩放
                    fft_config_valid <= 1'b1;       // 配置有效
                end
                default: begin
                    fft_config_valid <= 1'b0;       // 其他状态下配置无效
                end
            endcase
        end
    end

    // ===============================
    // FFT输入数据控制逻辑 (FFT Input Data Control Logic)
    // 作用：将ADC数据打包成FFT格式并发送给FFT IP核
    // ===============================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_sample_counter <= 10'd0;
            fft_input_data <= 32'h0;
            fft_input_valid <= 1'b0;
            fft_input_last <= 1'b0;
        end
        else if (adc_data_valid && (current_state == INPUT_STATE)) begin
            // 将ADC数据打包：实部为ADC数据左移8位，虚部为0
            fft_input_data <= {adc_processed_data, 8'h0, 16'h0};
            fft_input_valid <= 1'b1;
            
            // 样本计数器管理
            if (input_sample_counter == (FFT_POINTS - 1)) begin
                input_sample_counter <= 10'd0;
                fft_input_last <= 1'b1;         // 最后一个样本
            end
            else begin
                input_sample_counter <= input_sample_counter + 1;
                fft_input_last <= 1'b0;
            end
        end
        else begin
            fft_input_valid <= 1'b0;
            fft_input_last <= 1'b0;
        end
    end

    // ===============================
    // FFT输出数据处理逻辑 (FFT Output Data Processing Logic)
    // 作用：处理FFT输出数据，提取幅度信息，分离低频和高频分量
    // ===============================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_sample_counter <= 10'd0;
            fft_real_part <= 16'h0;
            fft_imag_part <= 16'h0;
            frequency_magnitude <= 8'h0;
            low_freq_register <= 8'h0;
            high_freq_register <= 8'h0;
            fft_output_ready <= 1'b1;
        end
        else if (fft_output_valid && fft_output_ready) begin
            // 提取FFT输出的实部和虚部
            fft_real_part <= fft_output_data[31:16];    // 高16位为实部
            fft_imag_part <= fft_output_data[15:0];     // 低16位为虚部
            
            // 简化的幅度计算：使用实部的高8位作为幅度
            frequency_magnitude <= fft_real_part[15:8];
            
            // 根据频率分量位置进行分离
            if (output_sample_counter < LOW_FREQ_THRESHOLD) begin
                // 前256个频点为低频分量
                low_freq_register <= frequency_magnitude;
            end
            else begin
                // 后面的频点为高频分量
                high_freq_register <= frequency_magnitude;
            end
            
            // 输出样本计数器管理
            if (output_sample_counter == (FFT_POINTS - 1)) begin
                output_sample_counter <= 10'd0;
            end
            else begin
                output_sample_counter <= output_sample_counter + 1;
            end
        end
    end

    // ===============================
    // 状态机控制逻辑 (State Machine Control Logic)
    // 作用：控制FFT处理的整体流程
    // ===============================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE_STATE;
        end
        else begin
            current_state <= next_state;
        end
    end

    // 状态转移逻辑
    always @(*) begin
        case (current_state)
            IDLE_STATE: begin
                if (adc_data_valid) begin
                    next_state = CONFIG_STATE;
                end
                else begin
                    next_state = IDLE_STATE;
                end
            end
            
            CONFIG_STATE: begin
                if (fft_config_ready) begin
                    next_state = INPUT_STATE;
                end
                else begin
                    next_state = CONFIG_STATE;
                end
            end
            
            INPUT_STATE: begin
                if (fft_input_last && fft_input_ready) begin
                    next_state = PROCESSING_STATE;
                end
                else begin
                    next_state = INPUT_STATE;
                end
            end
            
            PROCESSING_STATE: begin
                if (fft_output_valid) begin
                    next_state = OUTPUT_STATE;
                end
                else begin
                    next_state = PROCESSING_STATE;
                end
            end
            
            OUTPUT_STATE: begin
                if (fft_output_last) begin
                    next_state = IDLE_STATE;
                end
                else begin
                    next_state = OUTPUT_STATE;
                end
            end
            
            default: begin
                next_state = IDLE_STATE;
            end
        endcase
    end

    // ===============================
    // Xilinx FFT IP核实例化 (Xilinx FFT IP Core Instantiation)
    // 作用：执行1024点FFT变换，将时域信号转换为频域信号
    // ===============================
    
    xfft_0 u_fft_core (
        // 时钟和复位
        .aclk(clk),                              // 系统时钟
        
        // 配置接口 - 用于设置FFT参数
        .s_axis_config_tdata(fft_config_data),   // 配置数据
        .s_axis_config_tvalid(fft_config_valid), // 配置数据有效
        .s_axis_config_tready(fft_config_ready), // 配置数据就绪
        
        // 输入数据接口 - 时域数据输入
        .s_axis_data_tdata(fft_input_data),      // 输入数据 (实部+虚部)
        .s_axis_data_tvalid(fft_input_valid),    // 输入数据有效
        .s_axis_data_tready(fft_input_ready),    // 输入数据就绪
        .s_axis_data_tlast(fft_input_last),      // 输入数据最后一个样本
        
        // 输出数据接口 - 频域数据输出
        .m_axis_data_tdata(fft_output_data),     // 输出数据 (实部+虚部)
        .m_axis_data_tvalid(fft_output_valid),   // 输出数据有效
        .m_axis_data_tready(fft_output_ready),   // 输出数据就绪
        .m_axis_data_tlast(fft_output_last)      // 输出数据最后一个样本
    );

    // ===============================
    // 输出连接 (Output Connections)
    // 作用：将处理后的低频和高频分量输出到模块端口
    // ===============================
    
    assign low_freq_out = low_freq_register;    // 低频分量输出
    assign high_freq_out = high_freq_register;  // 高频分量输出

endmodule
