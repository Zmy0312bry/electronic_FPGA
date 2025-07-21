// 信号分离模块，采集fft_process的magnitude数据，保存为2048维Q13.15数组，并实现频率分量提取与类型判别
module signal_separation (
    input wire clk,
    input wire rst,
    input wire task_done,
    input wire [15:0] magnitude_data, // Q13.15
    output reg done,
    output reg [10:0] count,
    output reg [10:0] main_freq1_idx,
    output reg [10:0] main_freq2_idx,
    output reg [10:0] h3_idx,
    output reg [10:0] h5_idx,
    output reg [1:0] type1, // 0:未知 1:正弦波 2:三角波
    output reg [1:0] type2
);

    reg [15:0] magnitude_array [0:2047];
    reg [10:0] counter;
    reg collecting;

    // 采集数据时序
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            collecting <= 0;
            done <= 0;
        end else begin
            if (task_done && !collecting) begin
                collecting <= 1;
                counter <= 0;
                done <= 0;
            end else if (collecting) begin
                magnitude_array[counter] <= magnitude_data;
                counter <= counter + 1;
                if (counter == 2047) begin
                    collecting <= 0;
                    done <= 1;
                end
            end
        end
    end

    always @(*) begin
        count = counter;
    end

    // 频率分量提取与类型判别
    integer i;
    reg [15:0] max1, max2, h3_val, h5_val;
    reg [10:0] idx1, idx2, idx2_h3, idx2_h5;
    reg [15:0] temp_mag [0:1023];

    always @(*) begin
        // 只在采集完成后处理
        if (done) begin
            // 1. 找最大幅值频点
            max1 = 0;
            idx1 = 0;
            for (i = 0; i < 1024; i = i + 1) begin
                temp_mag[i] = magnitude_array[i];
                if (temp_mag[i] > max1) begin
                    max1 = temp_mag[i];
                    idx1 = i[10:0];
                end
            end
            // 2. 去除最大频点正负5点
            for (i = (idx1 > 5 ? idx1-5 : 0); i <= (idx1+5 < 1024 ? idx1+5 : 1023); i = i + 1)
                temp_mag[i] = 0;
            // 3. 再找次大频点
            max2 = 0;
            idx2 = 0;
            for (i = 0; i < 1024; i = i + 1) begin
                if (temp_mag[i] > max2) begin
                    max2 = temp_mag[i];
                    idx2 = i[10:0];
                end
            end
            main_freq1_idx = idx1;
            main_freq2_idx = idx2;

            // 三次谐波
            idx2_h3 = idx2 * 3;
            h3_val = 0;
            h3_idx = 0;
            if (idx2_h3 < 1024) begin
                for (i = (idx2_h3 > 5 ? idx2_h3-5 : 0); i <= (idx2_h3+5 < 1024 ? idx2_h3+5 : 1023); i = i + 1) begin
                    if (magnitude_array[i] > h3_val) begin
                        h3_val = magnitude_array[i];
                        h3_idx = i[10:0];
                    end
                end
            end

            // 五次谐波
            idx2_h5 = idx2 * 5;
            h5_val = 0;
            h5_idx = 0;
            if (idx2_h5 < 1024) begin
                for (i = (idx2_h5 > 5 ? idx2_h5-5 : 0); i <= (idx2_h5+5 < 1024 ? idx2_h5+5 : 1023); i = i + 1) begin
                    if (magnitude_array[i] > h5_val) begin
                        h5_val = magnitude_array[i];
                        h5_idx = i[10:0];
                    end
                end
            end

            // 类型判别
            type1 = 1; // 第一主频默认正弦波
            type2 = 0; // 未知
            if (max2 != 0) begin
                // ratio/h3_val/max2/h5_val
                if (h3_val * 50 < max2) begin
                    type2 = 1; // 正弦波
                end else if (h3_val == 0) begin
                    type2 = 0; // 未知
                end else if ((h3_val * 8 < max2 && h3_val * 20 > max2) || h3_val > max2) begin
                    if (h3_val * 100 < max2 || (h5_val * 100 < max2 && h5_val != 0)) begin
                        type2 = 1; // 正弦波
                    end else if (h5_val * 20 < max2 && h5_val * 30 > max2 && h5_val != 0) begin
                        type2 = 2; // 三角波
                    end else begin
                        type2 = 1; // 正弦波
                    end
                end else begin
                    type2 = 2; // 三角波
                end
            end
        end else begin
            main_freq1_idx = 0;
            main_freq2_idx = 0;
            h3_idx = 0;
            h5_idx = 0;
            type1 = 0;
            type2 = 0;
        end
    end

endmodule
