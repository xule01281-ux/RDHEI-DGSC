function [FinalPredImg, FinalErrorImg, BlockInfo, NewErr1, BlockStats] = med_4dir_prediction(OriginalImg, split_row, split_col, ...
                                                             gH_global, gV_global, gD45_global, gD135_global,global_sigma ,GlobalPattern, R_zone, varargin)
    % MED_4DIR_PREDICTION (梯度导入版)
    % 仅保留 MED 预测器，并传入全局梯度供后续修改
    
    % 第 11 个参数：结构体为接收端重建状态，字符串为编码端选向方法。
    % 解码直接使用辅助信息中的方向；编码时才比较 entropy 或 sse 分数。
    % 两端共用 predict_core_optimized；极值干预已从所有 SCEC 分支移除。
    decode_state = [];
    prediction_mode = 'sse'; % 兼容旧的十参数调用
    BlockStats = zeros(4,5);
    if nargin >= 11
        if isstruct(varargin{1})
            decode_state = varargin{1};
        else
            prediction_mode = validatestring(varargin{1},{'entropy','sse'});
        end
    end

    Img = round(double(OriginalImg));
    [H, W] = size(Img);
    FinalPredImg = zeros(H, W);
    
    PadImg = padarray(Img, [2, 2], 'replicate');
    
    dir_labels = {'TL', 'TR', 'BL', 'BR'};
    
    % 定义四个块范围
    blocks = cell(4, 2);
    blocks{1, 1} = 1:split_row;      blocks{1, 2} = 1:split_col;
    blocks{2, 1} = 1:split_row;      blocks{2, 2} = (split_col+1):W;
    blocks{3, 1} = (split_row+1):H;  blocks{3, 2} = 1:split_col;
    blocks{4, 1} = (split_row+1):H;  blocks{4, 2} = (split_col+1):W;

    % 接收端模式：decode_state 中只包含误差、方向、统计量和因果
    % 参考像素。按编码端相同的块/扫描顺序逐块重建，不需要预测图像。
    if ~isempty(decode_state)
        [FinalPredImg, ~, BlockInfo] = ...
            decode_from_prediction_state(decode_state, split_row, split_col, ...
                                         gH_global, gV_global, gD45_global, ...
                                         gD135_global, global_sigma, ...
                                         GlobalPattern, R_zone, H, W);
        NewErr1 = -double(decode_state.error);
        FinalErrorImg = double(decode_state.error).^2;
        if isfield(decode_state,'block_stats')
            BlockStats = decode_state.block_stats;
        end
        return;
    end
    
    BlockInfo = struct('Dir', {}, 'Mode', {}, 'SSE', {});
    T = 4096;
    % --- 遍历 4 个扫描方向 ---
    for b = 1:4 
        best_cost = inf;
        r_range = blocks{b, 1};
        c_range = blocks{b, 2};
        if isempty(r_range) || isempty(c_range), continue; end
        H_block = numel(r_range);
        W_block = numel(c_range);
        N_block = H_block * W_block;

       % current_dir = dir_labels{b};
        TrueBlock = OriginalImg(r_range, c_range);

        if N_block >= T
            % 块足够大：用块内统计
            [gH_b, gV_b, gD45_b, gD135_b] = calc_global_gradients(TrueBlock);
            sigma_b = std(double(TrueBlock(:)));
        else
            % 块太小：退回全局统计
            gH_b    = gH_global;
            gV_b    = gV_global;
            gD45_b  = gD45_global;
            gD135_b = gD135_global;
            sigma_b = global_sigma;
        end
        % 保存预测核心所需统计量，接收端用同一组数值重建。
        BlockStats(b,:) = [gH_b,gV_b,gD45_b,gD135_b,sigma_b];
        
        
        % 【修改点】：不再循环模式，直接调用核心预测器，并传入全局梯度
        % 现在的模式固定为 'MED' (待修改版)
         for d = 1:numel(dir_labels)
                current_dir = dir_labels{d};
                TempPred = predict_core_optimized(PadImg, r_range, c_range, current_dir, gH_b, gV_b, gD45_b, gD135_b,sigma_b,split_row, split_col,GlobalPattern, R_zone);
                % 预估路径：折叠/符号映射后，累计八个位平面字节熵 N*H。
                % 复用这次方向预测，不运行候选 rANS，也不计算最终嵌入量。
                current_sse = sum(sum((TrueBlock - TempPred).^2));
                if strcmp(prediction_mode,'entropy')
                    current_cost = estimate_prediction_bits(TempPred-TrueBlock);
                else
                    current_cost = current_sse;
                end
                if current_cost < best_cost
                    best_cost = current_cost;
                    best_sse  = current_sse;
                    best_dir  = current_dir;
                    best_pred = TempPred;
                end
         end
       FinalPredImg(r_range, c_range) = best_pred;
    BlockInfo(b).Dir  = best_dir;
    BlockInfo(b).Mode = 'MED_GRAD'; % 梯度优化的 MED
    BlockInfo(b).SSE  = best_sse;
    BlockInfo(b).SelectionCost = best_cost;
    BlockInfo(b).SelectionMethod = prediction_mode;

    % fprintf('块 %d | 最优方向: %s | SSE: %d\n', b, best_dir, best_sse);


        % TempPred = predict_core_optimized(PadImg, r_range, c_range, current_dir, gH_b, gV_b, gD45_b, gD135_b,sigma_b,split_row, split_col,GlobalPattern, R_zone);
        % % 直接保存结果（因为没有竞争了）
        % current_sse = sum(sum((TrueBlock - TempPred).^2));
        % FinalPredImg(r_range, c_range) = TempPred;
        % BlockInfo(b).Dir = current_dir;
        % BlockInfo(b).Mode = 'MED_GRAD'; % 标记为梯度优化的MED
        % BlockInfo(b).SSE = current_sse;
        % 
        %  fprintf('块 %d | 方向: %s | SSE: %d\n', b, current_dir, current_sse);
    end

    FinalErrorImg = (Img - FinalPredImg).^2;
    NewErr1 = Img - FinalPredImg;
end

function PredBlock = predict_core_optimized(PadImg, r_idx, c_idx, dir_mode, gH, gV, gD45, gD135,global_sigma,split_row, split_col,GlobalPattern, R_zone, varargin)
    a=1.5;%%梯度把控系数
    b=2;
    H_block = length(r_idx);
    W_block = length(c_idx);
    PredBlock = zeros(H_block, W_block);
    % 解码模式：每算出一个像素，立即依据误差写回 PadImg，
    % 使后续像素可以读取已经恢复的因果邻域。编码调用没有这些参数。
    decode_err = [];
    decode_mode = false;
    if ~isempty(varargin)
        decode_err = varargin{1};
        decode_mode = true;
    end
    
    % 全局梯度权重计算 (保持不变)
    total_grad = gH + gV + gD45 + gD135 + 1e-5; 
    w_V = 1+(gV / total_grad)*2;   
    w_H =1+(gH / total_grad)*2 ;   
    w_md =1+(gD45 / total_grad)*2 ;   
    w_sd = 1+(gD135 / total_grad)*2 ;
    %  w_V = (gV / total_grad);   
    % w_H =(gH / total_grad);   
    % w_md =(gD45 / total_grad);   
    % w_sd =(gD135 / total_grad); 
    % w_V = gV  ;
    % w_H =gH  ;   
    % w_md =gD45 ;   
    % w_sd = gD135  ;  
    % 确定循环顺序
    switch dir_mode
        case 'TL', loop_r = 1:H_block;     loop_c = 1:W_block;
        case 'TR', loop_r = 1:H_block;     loop_c = W_block:-1:1;
        case 'BL', loop_r = H_block:-1:1;  loop_c = 1:W_block;
        case 'BR', loop_r = H_block:-1:1;  loop_c = W_block:-1:1;
    end
    
    for i = loop_r
        for j = loop_c
            % 坐标映射：因为 Padding 变成了 2，所以这里 +2
            pr = r_idx(i) + 2;
            pc = c_idx(j) + 2;
            


             abs_r = r_idx(i);
            abs_c = c_idx(j);
            % 判断当前像素属于内圈还是外圈
            
                a = 1.5;
                b = 2.0;

                

            % =========================================================
            % 1. 提取基础邻居 (xh, xv, xmd) 和 二阶邻居 (x1-x5)
            % =========================================================
            % 注意：方向不同，物理坐标的加减也不同
            
            switch dir_mode
                case 'TL' % 扫描：左上 -> 右下
                    % Row i
                    xh  = PadImg(pr,   pc-1); % Left
                    x1  = PadImg(pr,   pc-2); % Left-Left
                    % Row i-1
                    xv  = PadImg(pr-1, pc);   % Up
                    xmd = PadImg(pr-1, pc-1); % Up-Left
                    x2  = PadImg(pr-1, pc-2); % Up-Left-Left
                    % Row i-2
                    x5  = PadImg(pr-2, pc);   % Up-Up
                    x4  = PadImg(pr-2, pc-1); % Up-Up-Left
                    x3  = PadImg(pr-2, pc-2); % Up-Up-Left-Left
                    
                    % 检查"右侧"边界 (j+1)
                    
                        xsd = PadImg(pr-1, pc+1);
                        x6  = PadImg(pr-2, pc+1);
                    
                     
                case 'TR' % 扫描：右上 -> 左下 (水平镜像)
                    % "Left" 变成了物理上的 "Right" (+1)
                    % "Right" 变成了物理上的 "Left" (-1)
                    xh  = PadImg(pr,   pc+1);
                    x1  = PadImg(pr,   pc+2);
                    
                    xv  = PadImg(pr-1, pc);
                    xmd = PadImg(pr-1, pc+1);
                    x2  = PadImg(pr-1, pc+2);
                    
                    x5  = PadImg(pr-2, pc);
                    x4  = PadImg(pr-2, pc+1);
                    x3  = PadImg(pr-2, pc+2);
                    
                    % TR模式下，"右侧"是指物理上的左侧 (pc-1)
                    
                    
                    
                        xsd = PadImg(pr-1, pc-1);
                        x6  = PadImg(pr-2, pc-1);
                    
                   s=w_sd;
                     w_sd=w_md;   
                    w_md=s;
                    s=gD45;
                    gD45=gD135;
                    gD135=s;
                case 'BL' % 扫描：左下 -> 右上 (垂直镜像)
                    % "Up" 变成了物理上的 "Down" (+1)
                    xh  = PadImg(pr,   pc-1);
                    x1  = PadImg(pr,   pc-2);
                    
                    xv  = PadImg(pr+1, pc);
                    xmd = PadImg(pr+1, pc-1);
                    x2  = PadImg(pr+1, pc-2);
                    
                    x5  = PadImg(pr+2, pc);
                    x4  = PadImg(pr+2, pc-1);
                    x3  = PadImg(pr+2, pc-2);
                    
                    
                    
                   
                        xsd = PadImg(pr+1, pc+1);
                        x6  = PadImg(pr+2, pc+1);
                      s=w_sd;
                     w_sd=w_md;   
                    w_md=s;
                    s=gD45;
                    gD45=gD135;
                    gD135=s;
                   
                case 'BR' % 扫描：右下 -> 左上 (双重镜像)
                    xh  = PadImg(pr,   pc+1);
                    x1  = PadImg(pr,   pc+2);
                    
                    xv  = PadImg(pr+1, pc);
                    xmd = PadImg(pr+1, pc+1);
                    x2  = PadImg(pr+1, pc+2);
                    
                    x5  = PadImg(pr+2, pc);
                    x4  = PadImg(pr+2, pc+1);
                    x3  = PadImg(pr+2, pc+2);
                    
                    
                    
                    
                        xsd = PadImg(pr+1, pc-1);
                        x6  = PadImg(pr+2, pc-1);
                    
             end

             % 判断是否在重心辐射圈内
                dist_to_center = sqrt((abs_r - split_row)^2 + (abs_c - split_col)^2);
                is_center_zone = (dist_to_center <= R_zone);

                % 计算基础特征
                mx = max(xh, xv);
                mn = min(xh, xv);
                edge_span = mx - mn; % 局部跨度(对比度)


            switch dir_mode
                case 'TL'
                     
                case 'TR'
                    
                     s=w_sd;
                     w_sd=w_md;   
                    w_md=s;% 对角权互换
                case 'BL'
                     s=w_sd;
                     w_sd=w_md;   
                    w_md=s;
                    
                case 'BR'
                    
            end
            % =========================================================
            % 2. 预测计算 (利用提取出的所有变量)
            % =========================================================
            
            % 边界像素处理
            is_row_start = (i == loop_r(1));
            is_col_start = (j == loop_c(1));
            
            val = 0;
            
            if is_row_start && is_col_start
                val = xmd;
            elseif is_row_start
                val = xh;
            elseif is_col_start
                val = xv;
            else
                
                % 内部像素：使用 GAP (Gradient Adaptive Predictor) 风格的梯度计算
                % 既然我们有了 xsd, x6 等丰富的邻域，可以计算更精确的梯度
                % --- 【新增】A. 局部混乱度评估 (Local Chaos Activity) ---
                % 垂直梯度 (dh)
                dh = (2*abs(xh - xmd) + 2*abs(xv - x5) + abs(xsd - x6)+abs(xmd - x4)+abs(x1 - x2))/7; % 这里加入 xsd, x6
                % 水平梯度 (dv)
                dv = (2*abs(xh - x1) + 2*abs(xv - xmd) + abs(xsd - xv)+abs(x2 - xmd)+abs(x4 - x5))/7;
                dmd=(abs(x3 - xmd)+abs(x4 - xv)+abs(x5 - xsd)+abs(x2 - xh))/4;
                dsd=(abs(xmd - x1)+abs(x5 - xmd)+abs(xv- xh)+abs(x2 - x4))/4;
                % 在计算 score 前加几行：
                    grad_clip = 80;  % 可以试 30~80，看哪一档整体 MAE 更好
                    
                    dh   = min(dh,   grad_clip);
                    dv   = min(dv,   grad_clip);
                    dmd  = min(dmd,  grad_clip);
                    dsd  = min(dsd,  grad_clip);
                 % 边缘强度 (跨度)    
                % local_str = dh + dv + dmd + dsd;
                % global_avg_str=total_grad;
                % is_noisy_texture = (local_str > global_avg_str*13);
                % 结合全局权重
                % score_v = dv * w_V;
                % score_h = dh * w_H;
               
                % score_v = 1/(w_H^a*(dh+0.1)^b);
                % score_h = 1/(w_V^a*(dv+0.1)^b);
                % %gD45, gD135, 
                % score_md = 1/(sqrt(2)*w_md^a*(dmd+0.1)^b);
                % score_sd = 1/(sqrt(2)*w_sd^a*(dsd+0.1)^b);
                %  w_V = (gV / total_grad);   
    % w_H =(gH / total_grad);   
    % w_md =(gD45 / total_grad);   
    % w_sd =(gD135 / total_grad); 

                % score_v = 1/(( w_V / total_grad)^2*(dh+0.1)^2);
                % score_h = 1/((w_H / total_grad)^2*(dv+0.1)^2);
                % %gH, gV, gD45, gD135, 
                % score_md = 1/(sqrt(2)*(w_md / total_grad)^2*(dmd+0.1)^2);
                % score_sd = 1/(sqrt(2)*(w_sd / total_grad)^2*(dsd+0.1)^2);

                score_v = 1/((max(gV,1e-12))^2*(dh+0.1)^2);
                score_h = 1/((max(gH,1e-12))^2*(dv+0.1)^2);
                %gH, gV, gD45, gD135, 
                score_md = 1/(sqrt(2)*(max(gD45,1e-12))^2*(dmd+0.1)^2);
                score_sd = 1/(sqrt(2)*(max(gD135,1e-12))^2*(dsd+0.1)^2);

                % total_score=score_v*2+score_h*2+score_md+score_sd;
                % wight_v=2*score_v/total_score;
                % wight_h=2*score_h/total_score;
                % wight_md=score_md/total_score;
                % wight_sd=score_sd/total_score;
                % val= xv*wight_v+ xh*wight_h+xmd*wight_md+xsd*wight_sd;
                total_score=score_v+score_h+score_md+score_sd;
                wight_v=score_v/total_score;
                wight_h=score_h/total_score;
                wight_md=score_md/total_score;
                wight_sd=score_sd/total_score;
                val= xv*wight_v+ xh*wight_h+xmd*wight_md+xsd*wight_sd;
                 if GlobalPattern==1
                     flage=0;
                 elseif GlobalPattern==2
                     flage=2;
                 else  
                   flage=1;
                 end
                 
                if flage==1
                % SCEC 已取消极值干预：普通分支直接执行趋势反馈。
                % 编码和接收端共用此核心，无需新增辅助信息。
                edge_span = max(xh,xv)-min(xh,xv);
                     pred_val=val;
                    % --- 5. 趋势误差反馈 (Bias Cancellation) ---
                    % 这才是压低整体 MAE 的关键！
                    % 利用主方向的权重，推测当前的系统性偏差
                    slope_h = xh - x1; 
                    slope_v = xv - x5; 
                    bias = wight_h * slope_h + wight_v * slope_v;
                    

                         % 2. 计算当前像素真实的局部混乱度 (Local Chaos Activity)
                    % 无论它在图的哪里，只看它周围的情况
                    local_var = dh + dv + dmd + dsd;
                    
                    % 3. 利用高斯衰减函数(Gaussian Decay)动态计算 bias_w
                    % 核心思想：越平滑，bias_w 越大(最大0.6，全力消除渐变残差)；
                    % 越混乱，bias_w 平滑地滑向 0(关闭误差反馈，防止噪点雪崩)。
                    
                    % 这里引入 global_avg_str 作为标尺
                    % (如果你的代码里还没算 global_avg_str，可以用 global_sigma 代替，例如: base_scale = global_sigma * 1.5)
                    base_scale = total_grad / (H_block * W_block) + 1e-3; 
                    
                    % 归一化局部混乱度
                    norm_var = local_var / base_scale; 
                    
                    % 高斯平滑映射 (调节系数 2.0 可以微调衰减速度)
                    bias_w = 0.6 * exp(-(norm_var^2) / 2.0);
                    
                    % 加上底线保护 (0.4 ~ 0.6 之间动态浮动)
                    bias_w = max(0.4, min(0.6, bias_w));




                    % 限制 bias 的影响，防止被噪点带飞
                    % max_bias = max(3, edge_span / 4);
                    max_bias = max(0.4 * global_sigma, edge_span / 4);   % 用 global_sigma 替代 3
                    bias = sign(bias) * min(abs(bias), max_bias);
                    
                    % 施加偏置 (乘 0.5 削弱攻击性)
                    pred_val = pred_val + bias_w * bias;
                    
                    % % --- 6. 软约束 (Soft Clamping) ---
                    % % 确保预测值不会飞出局部邻域太多
                    % local_max = max([xh, xv, xmd, xsd]);
                    % local_min = min([xh, xv, xmd, xsd]);
                    % 
                    % % 允许超出 10 个灰度级
                    % pred_val = max(local_min - 10, min(local_max + 10, pred_val));

                    % --- 6. 软约束 (Soft Clamping) ---
                    local_max = max([xh, xv, xmd, xsd]);
                    local_min = min([xh, xv, xmd, xsd]);
                    
                    soft_margin = max(0.4 * global_sigma, 10);  % 原来的 ±10 改成跟 sigma 挂钩
                    pred_val = max(local_min - soft_margin, ...
                                   min(local_max + soft_margin, pred_val));
                                        val = round(pred_val);
                elseif flage==0
                    if is_center_zone
                        pred_val=val;
                    % --- 5. 趋势误差反馈 (Bias Cancellation) ---
                    % 这才是压低整体 MAE 的关键！
                    % 利用主方向的权重，推测当前的系统性偏差
                    slope_h = xh - x1; 
                    slope_v = xv - x5; 
                    bias = wight_h * slope_h + wight_v * slope_v;
                    

                     % 2. 计算当前像素真实的局部混乱度 (Local Chaos Activity)
                        % 无论它在图的哪里，只看它周围的情况
                        local_var = dh + dv + dmd + dsd;
                        
                        % 3. 利用高斯衰减函数(Gaussian Decay)动态计算 bias_w
                        % 核心思想：越平滑，bias_w 越大(最大0.6，全力消除渐变残差)；
                        % 越混乱，bias_w 平滑地滑向 0(关闭误差反馈，防止噪点雪崩)。
                        
                        % 这里引入 global_avg_str 作为标尺
                        % (如果你的代码里还没算 global_avg_str，可以用 global_sigma 代替，例如: base_scale = global_sigma * 1.5)
                        base_scale = total_grad / (H_block * W_block) + 1e-3; 
                        
                        % 归一化局部混乱度
                        norm_var = local_var / base_scale; 
                        
                        % 高斯平滑映射 (调节系数 2.0 可以微调衰减速度)
                        bias_w = 0.6 * exp(-(norm_var^2) / 2.0);
                        
                        % 加上底线保护 (0.4 ~ 0.6 之间动态浮动)
                        bias_w = max(0.4, min(0.6, bias_w));




                    % 限制 bias 的影响，防止被噪点带飞
                    % max_bias = max(3, edge_span / 4);
                    max_bias = max(0.4 * global_sigma, edge_span / 4);   % 用 global_sigma 替代 3
                    bias = sign(bias) * min(abs(bias), max_bias);
                    
                    % 施加偏置 (乘 0.5 削弱攻击性)
                    pred_val = pred_val + bias_w * bias;
                    
                    % % --- 6. 软约束 (Soft Clamping) ---
                    % % 确保预测值不会飞出局部邻域太多
                    % local_max = max([xh, xv, xmd, xsd]);
                    % local_min = min([xh, xv, xmd, xsd]);
                    % 
                    % % 允许超出 10 个灰度级
                    % pred_val = max(local_min - 10, min(local_max + 10, pred_val));

                    % --- 6. 软约束 (Soft Clamping) ---
                    local_max = max([xh, xv, xmd, xsd]);
                    local_min = min([xh, xv, xmd, xsd]);
                    
                    soft_margin = max(0.4 * global_sigma, 10);  % 原来的 ±10 改成跟 sigma 挂钩
                    pred_val = max(local_min - soft_margin, ...
                                   min(local_max + soft_margin, pred_val));
                                        val = round(pred_val);
                    else
                                mx = max(xh, xv);
                                mn = min(xh, xv);
                                edge_span = mx - mn;
                                
                                % 取消强边缘极值替换，保留原平滑区均值规则。
                                % 原条件 edge_span < (4*sigma)/4 等价于下式。
                                if edge_span < global_sigma
                                    val=(xh+xv)/2;
                                end
                    end
                else
                    if is_center_zone
                         mx = max(xh, xv);
                                mn = min(xh, xv);
                                edge_span = mx - mn;
                                
                                % 取消强边缘极值替换，保留原平滑区均值规则。
                                % 原条件 edge_span < (4*sigma)/4 等价于下式。
                                if edge_span < global_sigma
                                    val=(xh+xv)/2;
                                end
                    else
                        pred_val=val;
                        % --- 5. 趋势误差反馈 (Bias Cancellation) ---
                        % 这才是压低整体 MAE 的关键！
                        % 利用主方向的权重，推测当前的系统性偏差
                        slope_h = xh - x1; 
                        slope_v = xv - x5; 
                        bias = wight_h * slope_h + wight_v * slope_v;
                        
    
                         % 2. 计算当前像素真实的局部混乱度 (Local Chaos Activity)
                        % 无论它在图的哪里，只看它周围的情况
                        local_var = dh + dv + dmd + dsd;
                        
                        % 3. 利用高斯衰减函数(Gaussian Decay)动态计算 bias_w
                        % 核心思想：越平滑，bias_w 越大(最大0.6，全力消除渐变残差)；
                        % 越混乱，bias_w 平滑地滑向 0(关闭误差反馈，防止噪点雪崩)。
                        
                        % 这里引入 global_avg_str 作为标尺
                        % (如果你的代码里还没算 global_avg_str，可以用 global_sigma 代替，例如: base_scale = global_sigma * 1.5)
                        base_scale = total_grad / (H_block * W_block) + 1e-3; 
                        
                        % 归一化局部混乱度
                        norm_var = local_var / base_scale; 
                        
                        % 高斯平滑映射 (调节系数 2.0 可以微调衰减速度)
                        bias_w = 0.6 * exp(-(norm_var^2) / 2.0);
                        
                        % 加上底线保护 (0.4 ~ 0.6 之间动态浮动)
                        bias_w = max(0.4, min(0.6, bias_w));
    
    
    
    
                        % 限制 bias 的影响，防止被噪点带飞
                        % max_bias = max(3, edge_span / 4);
                        max_bias = max(0.4 * global_sigma, edge_span / 4);   % 用 global_sigma 替代 3
                        bias = sign(bias) * min(abs(bias), max_bias);
                        
                        % 施加偏置 (乘 0.5 削弱攻击性)
                        pred_val = pred_val + bias_w * bias;
                        
                        % % --- 6. 软约束 (Soft Clamping) ---
                        % % 确保预测值不会飞出局部邻域太多
                        % local_max = max([xh, xv, xmd, xsd]);
                        % local_min = min([xh, xv, xmd, xsd]);
                        % 
                        % % 允许超出 10 个灰度级
                        % pred_val = max(local_min - 10, min(local_max + 10, pred_val));
    
                        % --- 6. 软约束 (Soft Clamping) ---
                        local_max = max([xh, xv, xmd, xsd]);
                        local_min = min([xh, xv, xmd, xsd]);
                        
                        soft_margin = max(0.4 * global_sigma, 10);  % 原来的 ±10 改成跟 sigma 挂钩
                        pred_val = max(local_min - soft_margin, ...
                                       min(local_max + soft_margin, pred_val));
                                            val = round(pred_val);
                    end
                end
                
            end
            
            % Same finite 8-bit predictor at both ends.
            assert(isfinite(val),'prediction:Nonfinite','Nonfinite prediction.');
            PredBlock(i, j) = min(255,max(0,round(val)));
            if decode_mode
                recon_value = PredBlock(i,j) - double(decode_err(i,j));
                PadImg = write_reconstructed_pixel(PadImg, pr, pc, recon_value, ...
                    size(PadImg,1)-4, size(PadImg,2)-4);
            end
        end
    end
end

function PadImg = write_reconstructed_pixel(PadImg, pr, pc, value, H, W)
% padarray(...,'replicate') 的动态等价更新。首行/首列像素写入时，
% 同时更新两层复制边界，否则后续 x1/x5 会继续读到初始化值。
    ri = pr; ci = pc;
    if pr == 3, ri = 1:3; elseif pr == H+2, ri = H+2:H+4; end
    if pc == 3, ci = 1:3; elseif pc == W+2, ci = W+2:W+4; end
    PadImg(ri,ci) = value;
end

function [pred_img, recovered_img, BlockInfo] = decode_from_prediction_state(state, ...
        split_row, split_col, gH_global, gV_global, gD45_global, gD135_global, ...
        global_sigma, GlobalPattern, R_zone, H, W)
% 使用误差和最小因果参考集重建预测图及原图。
% state.refs.val 是编码端自动收集的必要参考像素值；参考位置可由
% 尺寸、分割点和方向重新推导。state.block_stats 每行是
% [gH gV gD45 gD135 sigma]。
    if ~isfield(state, 'error')
        error('med_4dir_prediction:MissingError', '重建状态缺少误差图。');
    end
    if ~isfield(state, 'dirs') || numel(state.dirs) < 4
        error('med_4dir_prediction:MissingDirections', '重建状态缺少四个块的扫描方向。');
    end

    work = nan(H, W);
    if isfield(state, 'refs')
        refs = state.refs;
    else
        refs = state;
    end
    if isfield(refs, 'val') && ~isempty(refs.val)
        if isfield(refs,'pos') && ~isempty(refs.pos)
            pos = double(refs.pos(:));
        else
            % 位置由尺寸、分割点和方向唯一确定，接收端无需保存索引。
            pos = prediction_reference_layout([H W], [split_row split_col], state.dirs);
        end
        val = double(refs.val(:));
        if numel(val) ~= numel(pos)
            error('med_4dir_prediction:ReferenceLengthMismatch', ...
                '参考像素值数量与可推导的位置数量不一致。');
        end
        good = pos >= 1 & pos <= H*W & isfinite(val);
        work(pos(good)) = val(good);
    end
    pred_img = nan(H, W);
    BlockInfo = struct('Dir', {}, 'Mode', {}, 'SSE', {});
    blocks = cell(4, 2);
    blocks{1, 1} = 1:split_row;      blocks{1, 2} = 1:split_col;
    blocks{2, 1} = 1:split_row;      blocks{2, 2} = (split_col+1):W;
    blocks{3, 1} = (split_row+1):H;  blocks{3, 2} = 1:split_col;
    blocks{4, 1} = (split_row+1):H;  blocks{4, 2} = (split_col+1):W;
    labels = {'TL','TR','BL','BR'};
    err_img = double(state.error);

    if isfield(state,'order') && numel(state.order) >= 4
        block_order = state.order;
    else
        block_order = 1:4;
    end
    for k = block_order
        rr = blocks{k,1}; cc = blocks{k,2};
        if isempty(rr) || isempty(cc), continue; end
        if iscell(state.dirs)
            dir_mode = state.dirs{k};
        else
            dir_mode = labels{double(state.dirs(k))+1};
        end
        if isstring(dir_mode), dir_mode = char(dir_mode); end
        if isfield(state, 'block_stats') && size(state.block_stats,1) >= k
            st = double(state.block_stats(k,:));
            gH = st(1); gV = st(2); gD45 = st(3); gD135 = st(4); sigma = st(5);
        else
            gH = gH_global; gV = gV_global; gD45 = gD45_global; gD135 = gD135_global; sigma = global_sigma;
        end
        PadWork = padarray(work, [2 2], 'replicate');
        % 核心预测器按原扫描顺序逐点写回已恢复像素，保持与编码端
        % 完全相同的邻域更新规则。
        pred_block = predict_core_optimized(PadWork, rr, cc, dir_mode, ...
            gH, gV, gD45, gD135, sigma, split_row, split_col, GlobalPattern, R_zone, err_img(rr,cc));
        if any(~isfinite(pred_block(:)))
            error('med_4dir_prediction:NaNPrediction', ...
                '第 %d 块方向 %s 的预测读取了未初始化参考像素。', k, dir_mode);
        end
        pred_img(rr,cc) = pred_block;
        rec_block = pred_block - err_img(rr,cc);
        % 误差定义为 prediction - original，因此 original = prediction - error。
        work(rr,cc) = rec_block;
        BlockInfo(k).Dir = dir_mode;
        BlockInfo(k).Mode = 'MED_GRAD';
        BlockInfo(k).SSE = NaN;
    end
    recovered_img = work;
    if any(~isfinite(recovered_img(:)))
        error('med_4dir_prediction:IncompleteReferences', ...
            '预测重建仍有未定义像素，请检查参考信息。');
    end
end
