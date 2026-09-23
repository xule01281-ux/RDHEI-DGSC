function [PFA] = sum_PFA(select_blocked, h, w)
% 函数说明：计算累积概率分布表 (PFA) - 加速版
% 输入：select_blocked (数据矩阵), h (块高), w (块宽)
% 输出：PFA (Cell数组，每个单元包含截至当前块的累积 [Value, Count, Percent])

    [row, col] = size(select_blocked);
    row1 = row / h;
    col1 = col / w;
    total_blocks = row1 * col1;
    
    % 1. 预分配输出 Cell 数组
    PFA = cell(1, total_blocks);
    
    % 2. 初始化全局统计容器
    % 假设数据范围是 0-255 (常见的8位深度)
    % 如果数据范围不固定，可根据 max(select_blocked(:)) 动态调整
    global_counts = zeros(256, 1); 
    values_col = (0:255)'; % tabulate 的第一列 (Value)
    
    block_idx = 0;
    
    % 3. 循环处理块 (保持原来的 Row-Major 扫描顺序)
    for i = 1:row1
        for j = 1:col1
           
            block_idx = block_idx + 1;
            
            % --- 优化 1: 向量化提取块 (替代双重循环+动态扩容) ---
            r_idx = (i-1)*h + 1 : i*h;
            c_idx = (j-1)*w + 1 : j*w;
            current_block = select_blocked(r_idx, c_idx);
            
            % --- 优化 2: 快速直方图统计 ---
            % 将块展平，并统计当前块的频率
            % 使用 accumarray 或 histcounts 比 tabulate 快得多
            % 注意：accumarray 需要 1-based 索引，所以像素值+1
            block_data = current_block(:) + 1;
            
            % 统计当前块的分布 (256x1)
            % 这里的 [256, 1] 确保即使当前块没有某些值，也会生成占位 0
            current_hist = accumarray(block_data, 1, [256, 1]);
            
            % --- 优化 3: 累积更新 ---
            global_counts = global_counts + current_hist;
            
            % --- 优化 4: 格式化输出 ---
            % 构造 tabulate 格式: [Value, Count, Percent]
            total_sum = sum(global_counts);
            if total_sum > 0
                percent_col = (global_counts / total_sum) * 100;
            else
                percent_col = zeros(256, 1);
            end
            
             table_all = [values_col, global_counts, percent_col];
            nonzero_idx = global_counts > 0;
            if any(nonzero_idx)
                PFA{block_idx} = table_all(nonzero_idx, :);
            else
                PFA{block_idx} = zeros(0, 3); % 没有出现值时返回空矩阵（0x3）
            end
        end
    end
end