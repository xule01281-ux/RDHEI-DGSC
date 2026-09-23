 %%选择连续零最多的方法，返回连续零最大位置
function [bit_num,p0_f,p0,p1,l0,opt,b0,ns,l_0_1,l_d,l_d_best1,xts,max_er_f,mode_flags] = Copy_of_complete_bit(select_blocked2,num22,max_l,max_er)
%%最后根据最新rans编码方式重写。
%%需要输出三个值：
%p0_f标识
%%p0
%%p1标识
 xt = 0; 
 xts={};
 xts_n=zeros(200,1);
 sum_record1=zeros(1,257);
 sum_record1_n=1;
[row,col] = size(select_blocked2);
xti=zeros(row*col,1);
  min1=1000;
  z21=num22;
  f_n1=0;
  f_n0=0;
  max_er_f=1;
  mode_flags=[];
       %% 1. 向量化统计与频率缩放
% 替换原有的 for i=1:length(z21) 循环
f_n0 = sum(z21 ~= 0);
f_n1 = sum(z21 == 1);

% 寻找大于 1 的最小值
valid_vals = z21(z21 > 1);
if ~isempty(valid_vals)
    min1 = min(valid_vals);
else
    min1 = 1000; % 保持你原来的默认值
end

% 向量化频率缩放逻辑
if f_n1 * 2 < f_n0 + 1
    % 逻辑：n1 >= min1 的进行除法，其余非零的设为 1
    idx_ge_min = (z21 >= min1);
    idx_nonzero = (z21 ~= 0);
    
    % 先备份 i=1 的情况，因为它有特殊的 ceil 逻辑
    first_val = z21(1);
    
    % 统一处理 floor 和 1 的赋值
    z21(idx_ge_min) = floor(z21(idx_ge_min) / min1);
    z21(~idx_ge_min & idx_nonzero) = 1;
    
    % 特殊修正 i=1 (如果它满足条件)
    if first_val >= min1
        z21(1) = ceil(first_val / min1);
    end
end

%% 2. 还原 F1 与 m
m = sum(z21);
F1 = [(0:255)', z21(:)];
F1 = F1(z21 ~= 0, :);
values1 = F1(:, 1);

%% 3. 优化 sort_z 后的映射逻辑 (核心加速点)
% 调用你原有的函数
[sorted_data, sorted_frequency, max_val] = sort_z(F1);

% --- 替换原有的 z_tale 循环 (消除 find) ---
% 原代码在循环里用 find，复杂度是 O(N^2)，现在降为 O(N)
z_tale = zeros(max_val + 1, 1);
% 直接利用索引映射：sorted_data 的值 + 1 作为索引，存储其在序列中的位置
z_tale(sorted_data + 1) = (0:length(sorted_data)-1)';

%% 4. 向量化生成 z 矩阵
% 替换原有的 for n=1:length(sorted_data) 循环
z = [(0:length(sorted_data)-1)', sorted_frequency(:)];
%% 铺平
% 1. 按光栅顺序 (Raster Scan) 将数据块转换为一维数列
seq = reshape(select_blocked2.', 1,[]); 
total_len = length(seq);
 
% 2. 寻找第一个非零符号的位置
first_nz_idx = find(seq ~= 0, 1, 'first');

% --- 初始化所有输出变量，防止后续报错 ---
bit_num = 0;   % 序列前端收益/消耗比特数初始化
p0_f = 0;      % 默认不开启特殊截断
p0 = 0;        % 默认截断位置为0
p1 = 0;        % p1 标识
opt = 1;       % 对应你代码中的 flag2，默认设为 1 (不生效状态)
l_0=zeros(1,200);%段前0的长度
l_0_n=0;         %几个
l_d=zeros(1,200);          %段长
l_d_n=0;
l_d_best=zeros(1,200);     %标准段长
width_cost=zeros(1,53);
minimum_width=53;
total_state_width=0;
if isempty(first_nz_idx)
    % 情况 A: 整个块全为 0，全是光滑带
    l0 = total_len;
    p0_f = 1;
    p0 = total_len;
    p1 = 0;
    opt = total_len; % 整个块全零，触发特殊标志
    sum_benefit= total_len*8;
    end0_id=total_len;
     b0=0;
     % for sum_n0=1:total_len
     %    if sum_record1_n==1 
     %       sum_record1(1)=8;
     %    else
     %         sum_record1(sum_record1_n)=sum_record1(sum_record1_n-1)+8;
     %    end
     %    sum_record1_n=sum_record1_n+1;
     % end
     % 预计算增益序列
        increments = 8:8:(total_len * 8);
        
        if sum_record1_n == 1
            % 如果从第一个位置开始，直接赋值
            sum_record1(1:total_len) = increments;
        else
            % 如果是从中间某个位置开始，加上前一个位置的基数
            sum_record1(sum_record1_n : sum_record1_n + total_len - 1) = sum_record1(sum_record1_n - 1) + increments;
        end
        
        % 一次性更新索引指针
        sum_record1_n = sum_record1_n + total_len;
else
    opt =first_nz_idx-1;
     % for sum_n0=1:opt
     %    if sum_record1_n==1 
     %       sum_record1(1)=8;
     %    else
     %         sum_record1(sum_record1_n)=sum_record1(sum_record1_n-1)+8;
     %    end
     %    sum_record1_n=sum_record1_n+1;
     % end

    % 1. 预计算需要增加的序列 [8, 16, 24, ..., 8*opt]
    increments = 8 * (1:opt);
    
    % 2. 一次性填充
    if sum_record1_n == 1
        sum_record1(1:opt) = increments;
    else
        % 基于上一个位置的值进行累加填充
        sum_record1(sum_record1_n : sum_record1_n + opt - 1) = sum_record1(sum_record1_n - 1) + increments;
    end
    
    % 3. 一次性更新指针
    sum_record1_n = sum_record1_n + opt;
    p0=opt ;
    sum_benefit=opt*8;
    % 情况 B: 存在非零符号
    l0 = first_nz_idx - 1; % 第一个非零符号前面的 0 的个数
    end0_id=l0 ;
    % --- 【新策略：检测第一个非零符号后的连续零的数量】 ---
    
    % 1. 提取第一个非零符号之后的序列
    after_nz_seq = seq(first_nz_idx + 1 : end);
    
    % 2. 计算连续零的数量 num1
    if isempty(after_nz_seq)
        num1 = 0;
    else
        next_nz_idx = find(after_nz_seq ~= 0, 1, 'first');
        if isempty(next_nz_idx)
            num1 = length(after_nz_seq); % 后面一直到结尾全都是 0  
        else
            num1 = next_nz_idx - 1;      % 遇到下一个非零符号前的 0 的个数
        end
    end 

    % % 3. 提取第一个非零符号的值，并映射到你的变量
    first_nz_symbol = z_tale(seq(first_nz_idx) + 1);
    % col = total_len; % 用总长 total_len 代替你代码中的 col
    % 
    % % 4. 计算需要的位数 n_sum
    % n_sum1 = ceil(log2(z_tale(first_nz_symbol + 1) + 1)); %% 需要几位+第二个非零符号的频率即可

    % 5. 核心判断逻辑 (应用你的判断条件)
    if num1-1 < col * 1
        if num1 > (2 + ceil(log2(col)))
            % 如果带来的收益(或连续零)大到满足阈值，则计算 bit_num
            bit_num = 8*(num1+1) - (2 + log2(col));
            p0_f = 1;
            p0 = first_nz_idx + num1; % 记录截断点：第一个非零符号 + 连续0的末尾
            opt=p0;
            xt =first_nz_symbol;
            xti(first_nz_idx+num1)=xt;
            sum_benefit=sum_benefit+bit_num-ceil(log2(xt));
            end0_id=p0;
           % b1=dec2bin(num1-1,log2(col))-'0';
            b1=bitget(num1-1,log2(col):-1:1);
            b0=[1,0,b1];
            if sum_record1_n~=1
               sum_record1(sum_record1_n)=sum_record1(sum_record1_n-1)+8-(2 + log2(col))-ceil(log2(xt));
            else
                  sum_record1(sum_record1_n)=8-(2 + log2(col))-ceil(log2(xt));
            end
            sum_record1_n=sum_record1_n+1;
            for sum_n0=1:num1
                if sum_record1_n==1 
                   sum_record1(1)=8;
                else
                     sum_record1(sum_record1_n)=sum_record1(sum_record1_n-1)+8;
                end
                sum_record1_n=sum_record1_n+1;
             end
        else
            b0=0;
        end 
    elseif num1-1 < col * 2^max_l
        if num1 > (2+  ceil(log2(col))   + max_l )
            bit_num =  8*(num1+1) - (2  + log2(col) + max_l );
            p0_f = 1;
            p0 = first_nz_idx + num1;
            opt=p0;
            xt =first_nz_symbol;
             sum_benefit=sum_benefit+bit_num-ceil(log2(xt));
            end0_id=p0;
           % b1=dec2bin(num1-1,log2(col)+ max_l)-'0';
            b1=bitget(num1-1,log2(col)+max_l:-1:1);
            b0=[1,1,b1];
            xti(first_nz_idx+num1)=xt;
             if sum_record1_n~=1
               sum_record1(sum_record1_n)=sum_record1(sum_record1_n-1)+8-(2 + log2(col) + max_l )-ceil(log2(xt));
            else
                  sum_record1(sum_record1_n)=8-(2 + log2(col) + max_l )-ceil(log2(xt));
            end
            sum_record1_n=sum_record1_n+1;
             for sum_n0=1:num1
                if sum_record1_n==1 
                   sum_record1(1)=8;
                else
                     sum_record1(sum_record1_n)=sum_record1(sum_record1_n-1)+8;
                end
                sum_record1_n=sum_record1_n+1;
             end
        else
            b0=0;
        end
    else
        msg = 'Error rANS occurred.';
        error(msg); 
    end
end
% 因为我们通过数学预测锁定了最高点，这里的 sumx2(end) 就是最大增幅
%%筛选出增益最大的点
%% ========================================================
%% 后续序列处理：判断是否需要使用 z3 (0的频率减半，m1 = m - 0.5*z(1,2))
%% ========================================================
% 溢出标识
x53=0;
%段类型标记
r_xc={};
%段末标识
r_id={};


          xts1={};
          l_d=-1;
          l_d_best1=0;
          ns=0;%%有几有效段
          l_0_1=[];
% 1. 获取后续尚未编码的剩余序列
remain_seq = seq(end0_id + 1 : end);

% 用于存储后续序列产生的真实 bit 消耗
sum3_real = 0; 

    z3 = z;
    f0_old = z(1,2);
    % rANS 要求频率必须是整数且 >= 1，所以这里用 ceil 并且设置保底为 1
    if size(z,1)>1
        f0_new = z(2,2)+1;
    else
        f0_new = f0_old;
    end
    z3(1,2) = f0_new;
    
    % 新的总分母 m1
    m1 = m - f0_old + f0_new; 
   

% 假设 z 已经按符号排序，或者按照你需要的顺序排列
            symbols =z3(:,1); % 符号列
            counts = z3(:,2);  % 频率列
            
            % 初始化查找表 (针对 0-255 的像素值)
            LUT_f = zeros(1, 256);
            LUT_c = zeros(1, 256);
            
            % 计算累加频率
            % cumsum 计算 [f1, f1+f2, f1+f2+f3...]
            % 这里的 c 需要的是“小于当前符号的频率之和”，所以我们要偏移一位
            cum_counts = [0; cumsum(counts(:))];
            
            % 填充查找表 (注意 MATLAB 索引从 1 开始，符号从 0 开始，所以用 s+1)
            LUT_f1(symbols + 1) = counts;
            LUT_c1(symbols + 1) = cum_counts(1:end-1);

             symbols =z(:,1); % 符号列
            counts = z(:,2);  % 频率列
            
            % 初始化查找表 (针对 0-255 的像素值)
            LUT_f = zeros(1, 256);
            LUT_c = zeros(1, 256);
            
            % 计算累加频率
            % cumsum 计算 [f1, f1+f2, f1+f2+f3...]
            % 这里的 c 需要的是“小于当前符号的频率之和”，所以我们要偏移一位
            cum_counts = [0; cumsum(counts(:))];
            
            % 填充查找表 (注意 MATLAB 索引从 1 开始，符号从 0 开始，所以用 s+1)
            LUT_f0(symbols + 1) = counts;
            LUT_c0(symbols + 1) = cum_counts(1:end-1);

if ~isempty(remain_seq)
   
    %% --- 0. 全局参数设置 ---
    N_total = length(remain_seq);
    
   
    
    % 初始化状态 (假设 xt 等在外部已经初始化)
    sum2 = 0; 
    sum2_record = zeros(N_total, 1); 
    
    % 提前算好两种表的单步理论收益
    gain_per_step = log2(m / m1);           
    penalty_per_zero = log2(f0_new / f0_old); 
    
    %% --- 1. 动态探路与延展编码 ---
    i = 1;
    sum3_real1=0;
    while i <= N_total
        
        % =========================================================
        % 【第一步：探路 (Preview)】 
        % 使用正常频率集合 z 提前模拟，找出达到 2^53 界限的预测段长 L
        % =========================================================
        L = 0; 
        xt_sim = xt; 
        sim_i = i; % 模拟指针
        bit_num1=sum_benefit+sum3_real1+8*(N_total-i+1);
         if bit_num1<max_er
             max_er_f=0;
            return;
         end
        while sim_i <= N_total
            sym_sim = remain_seq(sim_i);
            num3_sim = z_tale(sym_sim + 1);
            f_sim = LUT_f0(num3_sim + 1);
            c_sim = LUT_c0(num3_sim + 1);
            
            % 模拟起步逻辑
            if  xt_sim ==0
                
                 xt_sim_next = num3_sim;
            else
                if xt_sim<m
                    xt_sim_next = floor(xt_sim / f_sim) * m + rem(xt_sim, f_sim) + c_sim+m;
                else
                    xt_sim_next = floor(xt_sim / f_sim) * m + rem(xt_sim, f_sim) + c_sim;
                end
            end
            
            L = L + 1; % 模拟吃进一个符号
            
            % 一旦碰到天花板，探路结束
            if xt_sim_next >= 2^53
                break; 
            end
            
            xt_sim = xt_sim_next;
            sim_i = sim_i + 1;
        end
        
        % =========================================================
        % 【第二步：裁决 (Evaluate & Decide)】 
        % 针对探路得到的段长 L，评价并筛选出最佳的频率集合
        % =========================================================
        current_probe_size = max(1, L);
        chunk_seq = remain_seq(i : i + current_probe_size - 1);
        N0_chunk = sum(chunk_seq == 0);
        N_other_chunk = current_probe_size - N0_chunk;
        
        chunk_gain = N_other_chunk * gain_per_step + N0_chunk * penalty_per_zero;
        
        if chunk_gain > 0
            best_z = z3;
            best_m = m1;
            r_id{end+1}=1;
             LUT_f=LUT_f1;
            LUT_c=LUT_c1;
        else
            best_z = z;
            best_m = m;
             r_id{end+1}=0;
             LUT_f=LUT_f0;
            LUT_c=LUT_c0;
        end
        
        i_x=i;%%r_id中转
        % =========================================================
        % 【第三步：真实编码与延展 (Actual Encode & Extend)】 
        % 用选出的频率集合一直算，不到 2^53 绝不停下来！
        % =========================================================
        while i <= N_total
            sym = remain_seq(i);
            num3 = z_tale(sym + 1);
            %[c, f] = rANS_C(best_z, num3); 
            % 假设当前处理的符号是 num
            f = LUT_f(num3 + 1);
            c = LUT_c(num3 + 1);
            xt_prev = xt;
            
            % 【试探性计算】
            if xt == 0
                xt_next = num3;
            else
                if xt<best_m
                    xt_next = floor(xt / f) * best_m + rem(xt, f) + c+best_m;
                else
                xt_next = floor(xt / f) * best_m + rem(xt, f) + c;
                end
            end
           
            % 【界限判定：决定是延展，还是归一化并结束当前段】
            if xt_next >= 2^53 
                
                % ---------------------------------------------------
                % 碰触 2^53！执行回退、输出比特并重新计算
                % ---------------------------------------------------
                x53=1;
                xt = xt_prev;
                xts{end+1}=xt;
                r_xc{end+1}=i_x+i;
                ld1=ceil(log2(xt+1));
                l_d_n=l_d_n+1;
                     if l_d_n <= length(l_d)
                        l_d(l_d_n) = ld1;
                    else
                        l_d = [l_d, ld1]; % 动态扩容保护
                     end
                     xts_n(l_d_n)=end0_id+i;
               % ===============================================================
                    % 【核心业务】：寻找最优段长，并计算当前 ld1 的增益减少(惩罚)
                    % ===============================================================
                  
                    % Each completed state contributes padding to all 53 widths.
                    % min preserves the original smallest-width tie break.
                    width_padding=repmat(53-ld1,1,53);
                    width_padding(ld1:53)=0:53-ld1;
                    width_cost=width_cost+width_padding;
                    minimum_width=min(minimum_width,ld1);
                    total_state_width=total_state_width+ld1;
                    [min_cost,width_offset]=min(width_cost(minimum_width:53));
                    best_L=minimum_width+width_offset-1;
                    penalty=total_state_width+min_cost;
                    l_d_best(1,l_d_n)=best_L;
                    base_val=(i-1)*8-penalty-l_d_n;
                 % ===============================================================
                % 【新增】：在 break 之前，计算当前位置的连续0或非0的增益/惩罚
                % ===============================================================
                if remain_seq(i) == 0
                    % --- 1. 当当前元素为0时：检索连续零的长度 ---
                    zero_len = 0;
                    temp_i = i;
                    % 向后检索连续0，防止数组越界
                    while temp_i <= length(remain_seq) && remain_seq(temp_i) == 0
                        zero_len = zero_len + 1;
                        temp_i = temp_i + 1;
                    end
                    
                    % 存储进 l_0
                    l_0_n = l_0_n + 1;
                    if l_0_n <= length(l_0)
                        l_0(l_0_n) = zero_len;
                    else
                        l_0 = [l_0, zero_len]; % 动态扩容保护
                    end
                    
                    % --- 2. 记录段长并动态重置 sum2_record ---
                    % 根据段长动态计算：首个减4，后续每个比前一个加8
                    for k = 1 : zero_len
                        curr_idx = i + k - 1;
                        
                        if curr_idx == 1
                            base_val = 0;
                        end
                         %sum2=sum2-1-3*l_0_n;%%段种类标记,段前0的huffman
                        if k == 1
                            sum2_record(curr_idx) = base_val+8-1-3*l_0_n; % 首个单独减 4
                        else
                            sum2_record(curr_idx) =sum2_record(curr_idx-1) + 8; % 后续加 8
                        end
                        xti(end0_id+curr_idx)=0;
                    end
                   xt=0; 
                   i=i+zero_len;
                else
                    zero_len=0;
                    l_0_n = l_0_n + 1;
                     if l_0_n <= length(l_0)
                        l_0(l_0_n) = zero_len;
                    else
                        l_0 = [l_0, zero_len]; % 动态扩容保护
                    end
                    % --- 1. 当当前元素不为0时：模拟计算 rANS ---
                    sym_sim = remain_seq(i);
                    num3_sim = z_tale(sym_sim + 1);
                    xt_gain = ceil(log2(num3_sim));
                    xt=num3_sim;
                    xti(end0_id+i)=xt;
                    % --- 2. 记录段长并加上计算出的 xt 增益 ---
                    % 非零元素段长视为 1
                    if i == 1
                        base_val = 0;
                    end
                    
                    % 在 sum2_record(i) 上加上增益
                    sum2_record(i) = base_val + xt_gain-1-3*l_0_n; 
                    i=i+1;
                end
                % ===============================================================
                 
                %sum2_record(i)
                break; % 【关键】：跳出内层 while 延展循环，回到第一步重新探路！
                
            else
                % ---------------------------------------------------
                % 没有大于 2^53！完美，继续延展！
                % ---------------------------------------------------
                xt = xt_next;
                 xti(end0_id+i)=xt;
                % 记录追踪理论信息量
                if i == 1
                    sum2 = 8 - ceil(log2(xt + 1));
                else
                    sum2 = 8 - ceil(log2(xt + 1)) + ceil(log2(xt_prev + 1));
                end
                 if x53==1
                     x53=0;
                 end
                 if i>1
                sum2_record(i) =sum2_record(i-1)+sum2;
                 else
                     sum2_record(i)=sum2;
                 end
               
                i = i + 1; % 指针前移，保持在内层 while 循环中继续吃下一个符号
            end
            sum3_real1=max(sum2_record);
        end % 结束内层延展循环
        
    end % 结束最外层数据流
    if max_er_f==1
        %% --- 3. 结尾收尾处理 ---
        % 将机内剩余的最终状态 xt 强制转换为比特流保存
        % 转化标准
        % final_bits = floor(log2(max(1, xt))) + 1;
        % final_bin_array = zeros(1, final_bits);
        % for b = 1 : final_bits
        %     final_bin_array(b) = bitget(xt, b);
        % end
        xts{end+1}= xt;
       % disp(['自适应探路并延展编码完成，生成二进制流总长: ', num2str(length(bitstream)), ' bits']);
    %sum_record1_n
                if sum_record1_n==1
                     sum_record1=sum2_record;
                else
                    sum_record1(sum_record1_n:sum_record1_n-1+N_total)=sum_record1(sum_record1_n-1)+sum2_record;
                end
                sum_record1_n=sum_record1_n+N_total-1;
         % 找出 sum2_record 中的最大值以及它所在的索引位置
        [max_sum2, max_idx] = max(sum2_record);
        
        % 打印结果查看
        %disp(['sum2_record 的最大值为: ', num2str(max_sum2), '，出现在第 ', num2str(max_idx), ' 个符号处。']);
        if max_sum2>8
           sum3_real=max_sum2;
           opt=end0_id+max_idx;
           p1=1;
        else
          sum3_real=0;
          p1=0;
    
        end
    end
end
% l_0=zeros(1,200);%段前0的长度
% l_0_n=0;         %几个
% l_d=zeros(1,200);          %段长
% l_d_n=0;
% l_d_best=zeros(1,200);     %标准段长
%首先存贮xts,再处理段长问题
xts1={};
mode_flags1=[];
mode_flags=[0,0];
xts_n=xts_n(1:l_d_n);
l_0_1=[];
    if max_er_f==1
        bit_num=sum_benefit+sum3_real;
        if sum3_real~=0
            if l_d_n~=0
                if opt<min(xts_n)
                   %??????????
                   if opt>p0
                      xts1{end+1}=xti(opt);
                      if ~isempty(r_id)
                          mode_flags1 = r_id{1};
                      end
                     l_d=-1;
                    l_d_best1=0;
                    ns=1;%%?????
                   else
                       xts1={};
                       l_d=-1;
                       l_d_best1=0;
                       ns=0;%%?????
                   end
                elseif opt==256
                     xts1=xts;
                     mode_flags1 = cell2mat(r_id(1:numel(r_id)));
                    l_d=l_d(1:l_d_n);
                    l_d_best1=l_d_best(l_d_n);
                     l_0_1=l_0(1:l_d_n);%%?????
                    ns=l_d_n+1;%%?????
                   
                else
                    ns=0;%%?????
                    xt_flag=1;
                    for xis=1:length(xts_n)
                        if xts_n(xis)<=opt
                             xts1{end+1}=xts{xis};
                             if xis <= numel(r_id)
                                 mode_flags1(end+1) = r_id{xis}; %#ok<AGROW>
                             end
                            ns=ns+1;
                        else
                             xts1{end+1}=xti(opt);
                             next_mode = min(numel(r_id),numel(mode_flags1)+1);
                             if next_mode > 0
                                 mode_flags1(end+1) = r_id{next_mode}; %#ok<AGROW>
                             end
                            xt_flag=0;
                            break
                        end
                    end
                    if xt_flag==1
                         xts1{end+1}=xti(opt);
                         next_mode = min(numel(r_id),numel(mode_flags1)+1);
                         if next_mode > 0
                         mode_flags1(end+1) = r_id{next_mode}; %#ok<AGROW>
                         end
                    end
                    l_d=l_d(1:ns);
                    l_d_best1=l_d_best(ns);
                    l_0_1=l_0(1:ns);
                    ns=ns+1;
                end
            else
                  if opt>p0
                      xts1{end+1}=xti(opt);
                      if ~isempty(r_id)
                          mode_flags1 = r_id{1};
                      end
                     l_d=-1;
                     l_d_best1=0;
                     ns=1;%%?????
                   else
                       xts1={};
                       l_d=-1;
                       l_d_best1=0;
                       ns=0;%%?????
                   end
            end
         xts=xts1;
         mode_flags=mode_flags1;
        else
          xts1={};
          l_d=-1;
          l_d_best1=0;
          ns=0;%%?????
          mode_flags=[];
        end
    else
          xts1={};
          l_d=-1;
          l_d_best1=0;
          ns=0;%%?????
          mode_flags=[];
    end
    % A prefix-only block still needs its nonzero seed on the wire.
    if max_er_f==1 && b0(1)==1 && opt==p0
        xts={xti(p0)};
        ns=1;
        mode_flags=0;
        l_0_1=[];
        l_d=-1;
        l_d_best1=0;
    elseif ns==0
        xts={};
    end
    asa=1;
