function [select_blocked,r,select_blocked1,p0_f,p0,p1,l0,opt1,b0,ns,l_0,l_d,l_d_best,max_l,xts,mode_flag] = select_block(origin_D_I,h,w)
%%输出每一个快的类型，及最优图（两种，第二种方便给后续频率统计[row,col] = size(origin_D_I);
[row,col]=size(origin_D_I);
row1=row/h;
col1=col/w;
select_blocked=zeros(row,col);
r=zeros(row1,col1);
num0=0;
num_sum1=0;
num11=zeros(1,256);
max_l0=0;
bit_nums=0;
max_l1=0;
[row, col] = size(origin_D_I);
    row1 = row / h;
    col1 = col / w;
    num_blocks = row1 * col1;
p0_f=zeros(row1,col1);
p0=zeros(row1,col1);
p1=zeros(row1,col1);
l0=zeros(row1,col1);
opt1=zeros(row1,col1);
b0={};
ns=zeros(row1,col1);
l_0={};
l_d={};
l_d_best=zeros(row1,col1);
xts={};
ns=zeros(row1,col1);
    % 1. 提取位平面 (Row x Col x 8)
    % MSB First (Index 1) -> LSB Last (Index 8) 以匹配权重
    mapped_I = zeros(row, col);
    mask_pos = origin_D_I > 0;
    mask_neg = origin_D_I <= 0;
    mapped_I(mask_pos) = origin_D_I(mask_pos) * 2 - 1;
    mapped_I(mask_neg) = abs(origin_D_I(mask_neg)) * 2;
    
    s=mean(abs(mapped_I(:)));

    bit_planes = zeros(row, col, 8, 'uint8');
    for b = 1:8
        bit_planes(:, :, 9-b) = bitget(mapped_I, b); 
    end
    %%考虑通过全局梯度确定总体的方针
   %[gH, gV, gD45, gD135] = calc_global_gradients(mapped_I);

    % % 2. 切分块 (h, w, 8, K)
    % temp = reshape(double(bit_planes), h, row/h, w, col/w, 8);
    % temp = permute(temp, [1, 3, 5, 2, 4]); 
    % blocks_stack = reshape(temp, h, w, 8, []); 
    % 
    % % 细分原子块: (8, h/8, 8, w/8, 8_plane, K)
    % % Dims: 1:r8, 2:h_idx, 3:c8, 4:w_idx, 5:plane, 6:K
    % raw_splits = reshape(blocks_stack, 8, h/8, 8, w/8, 8, []);
    % 
    % weights = [128; 64; 32; 16; 8; 4; 2; 1]; 
    % max_zeros_per_block = zeros(num_blocks, 4);  
    select1=zeros(h*w,row1*col1);
    select2=zeros(h*w,row1*col1);
    select3_3=zeros(h*w,row1*col1);
    select4=zeros(h*w,row1*col1);
    select21=zeros(row,col);
    select22=zeros(row,col);
    select23=zeros(row,col);
    select24=zeros(row,col);
    max_zeros_per_block = zeros(num_blocks, 4);
    for N = 1:4
        if N==1%%1*8
            for i=1:row1
              for j=1:col1
                 
                  select3=zeros(h,w);
                  n2=0;
                  sum_num=0;
                  r_idx = (i-1)*h + 1 : i*h;
                 c_idx = (j-1)*w + 1 : j*w;
                 select_blocked1=bit_planes(r_idx, c_idx,end:-1:1);
                    n_h=floor(h/8); 
                  for n=1:8%%第几个位平面
                    for z=1:h  
                         for q=1:8:w 
                              sum=0;
                             for Q=0:7
                             sum=sum*2+select_blocked1(z,q+Q,9-n);
                             end
                             if q==1
                               sum_num=sum_num+1;
                             end
                             n2=n2+1;
                              %%为h*w/8+1时表示要换行
                         if sum_num == 9
                                 sum_num=1;
                         end
                             wn=floor(q/8);
                             hn=ceil(z/8);
                             select21((i-1)*h+(n-1)*n_h+hn,(j-1)*(w)+sum_num+wn*8)=sum;
                             select3((n-1)*n_h+hn,sum_num+wn*8)=sum;
                          if sum~=0
                              asa=1;
                          end
                         end
                    end
                  end
                  asa1=reshape(select3.',[],h*w);
                     select1(1:end,(i-1)*col1+j)=asa1(:);
                     
              end
            end
         end
         if N==2%%第二种2*4
             for i=1:row1
              for j=1:col1
                  select3=zeros(h,w);
                  n2=0;
                  sum_num=0;sum_num_h=1;
                  r_idx = (i-1)*h + 1 : i*h;
                 c_idx = (j-1)*w + 1 : j*w;
                 select_blocked1=bit_planes(r_idx, c_idx,end:-1:1);
                     n_h=floor(h/8);
                     n_w=floor(w/8);
                  for n=1:8%%第几个位平面
                      % for xx=1:n_h
                      %     for yy=1:n_w 
                      %       for z=1:2:8               
                      %           for R=0:8/4-1%%一行几个
                      %               sum=0;
                      %            for Z=0:1
                      %             for q=1:4
                      %               sum=sum*2+select_blocked1((xx-1)*8+z+Z,(yy-1)*8+q+R*4,9-n);
                      %             end
                      %            end
                      %            sum_num=sum_num+1;
                      %               if  sum_num==9
                      %                   sum_num=1;
                      %               end
                      %               n2=n2+1;
                      %            select22((i-1)*h+(n-1)*n_h+xx,(j-1)*(w)+sum_num+(yy-1)*8)=sum;
                      %            select3((n-1)*n_h+hn,sum_num+wn*8)=sum;
                      %           end
                      %       end
                      %     end
                      % end

                            for z=1:2:h              
                                for R=0:w/4-1%%一行几个
                                    sum=0;
                                 for Z=0:1
                                  for q=1:4
                                    sum=sum*2+select_blocked1(z+Z,q+R*4,9-n);
                                  end
                                 end
                                 sum_num=sum_num+1;
                                    if  sum_num==w+1
                                        sum_num=1;
                                        sum_num_h=sum_num_h+1;
                                        if sum_num_h==n_h+1
                                           sum_num_h=1;    
                                        end
                                    end
                                    n2=n2+1;
                                 select22((i-1)*h+(n-1)*n_h+sum_num_h,(j-1)*(w)+sum_num)=sum;
                                 select3((n-1)*n_h+sum_num_h,sum_num)=sum;
                                end
                            end
                  end
                  asa1=reshape(select3.',[],h*w);
                     select2(1:end,(i-1)*col1+j)=asa1(:);
                     
              end
             end
         end
         if N==3%%第二种4*2
             for i=1:row1
              for j=1:col1
                  select3=zeros(h,w);
                  n2=0;
                  sum_num=0;sum_num_h=1;
                  r_idx = (i-1)*h + 1 : i*h;
                 c_idx = (j-1)*w + 1 : j*w;
                 select_blocked1=bit_planes(r_idx, c_idx,end:-1:1);
                    
                     n_h=floor(h/8);
                     n_w=floor(w/8);
                      % for xx=1:n_h
                      %     for yy=1:n_w 
                      % 
                      %         for n=1:8%%第几个位平面
                      %           for z=1:4:8               
                      %               for R=0:8/2-1%%一行几个
                      %                   sum=0;
                      %                for Z=0:3
                      %                 for q=1:2
                      %                   sum=sum*2+select_blocked1((xx-1)*8+z+Z,(yy-1)*8+q+R*2,9-n);
                      %                 end
                      %                end
                      %                sum_num=sum_num+1;
                      %                   if  sum_num==9
                      %                       sum_num=1;
                      %                   end
                      %                select23((i-1)*h+(n-1)*n_h+xx,(j-1)*(w)+sum_num+(yy-1)*8)=sum;
                      %                 n2=n2+1;
                      %                 select3((n-1)*n_h+hn,sum_num+wn*8)=sum;
                      %               end
                      %           end
                      %         end
                      %     end
                      % end
                      for n=1:8%%第几个位平面
                            for z=1:4:h              
                                for R=0:w/2-1%%一行几个
                                    sum=0;
                                 for Z=0:3
                                  for q=1:2
                                    sum=sum*2+select_blocked1(z+Z,q+R*2,9-n);
                                  end
                                 end
                                 sum_num=sum_num+1;
                                    if  sum_num==w+1
                                        sum_num=1;
                                        sum_num_h=sum_num_h+1;
                                        if sum_num_h==n_h+1
                                           sum_num_h=1;    
                                        end
                                    end
                                    n2=n2+1;
                                 select23((i-1)*h+(n-1)*n_h+sum_num_h,(j-1)*(w)+sum_num)=sum;
                                 select3((n-1)*n_h+sum_num_h,sum_num)=sum;
                                end
                            end
                      end
                       asa1=reshape(select3.',[],h*w);
                     select3_3(1:end,(i-1)*col1+j)=asa1(:);
              end
             end
         end
         if N==4%%第四种8*1
              for i=1:row1
              for j=1:col1
                  select3=zeros(h,w);
                  n2=0;
                  sum_num=0;sum_num_h=1;
                  r_idx = (i-1)*h + 1 : i*h;
                 c_idx = (j-1)*w + 1 : j*w;
                 select_blocked1=bit_planes(r_idx, c_idx,end:-1:1);
                          n_h=floor(h/8);
                          n_w=floor(w/8);
                    for n=1:8%%第几个位平面
                            for z=1:8:h              
                                for R=0:w-1%%一行几个
                                    sum=0;
                                 for Z=0:7
                                  for q=1:1
                                    sum=sum*2+select_blocked1(z+Z,q+R*1,9-n);
                                  end
                                 end
                                 sum_num=sum_num+1;
                                    if  sum_num==w+1
                                        sum_num=1;
                                        sum_num_h=sum_num_h+1;
                                        if sum_num_h==n_h+1
                                           sum_num_h=1;    
                                        end
                                    end
                                    n2=n2+1;
                                 select24((i-1)*h+(n-1)*n_h+sum_num_h,(j-1)*(w)+sum_num)=sum;
                                 select3((n-1)*n_h+sum_num_h,sum_num)=sum;
                                end
                            end
                    end
                       asa1=reshape(select3.',[],h*w);
                     select4(1:end,(i-1)*col1+j)=asa1(:);
              end
              end
         end
        
        if N==1
           stream= select1;
        elseif N==2
            stream= select2;
        elseif N==3
            stream= select3_3;
        elseif N==4
            stream= select4;
        end
        % 统计 max_1_0
        % for k = 1:num_blocks
        %     col_data = stream(:, k);
        %     first_nz = find(col_data ~= 0, 1);
        %     if isempty(first_nz)
        %         max_zeros_per_block(k, N) = length(col_data);
        %     else
        %         max_zeros_per_block(k, N) = first_nz - 1;
        %     end
        % end
        for k = 1:num_blocks
            col_data = stream(:, k);
            
            % 1. 找到第一个非零值的位置
            first_nz_idx = find(col_data ~= 0, 1, 'first');
            
            if isempty(first_nz_idx)
                % 情况 A: 整个块全为 0
                % 根据原代码逻辑，flag_0 始终为 1，计数器从未启动
                max_zeros_per_block(k, N) = 0;
            else
                % 情况 B: 存在非零值
                % 截取从第一个非零值之后的部分
                if first_nz_idx < length(col_data)
                    remaining_data = col_data(first_nz_idx+1 : end);
                    
                    % 在剩余部分找第一个非零值（即第二个非零值）
                    second_nz_rel = find(remaining_data ~= 0, 1, 'first');
                    
                    if isempty(second_nz_rel)
                        % 后面全是 0
                        max_zeros_per_block(k, N) = length(remaining_data);
                    else
                        % 两个非零值之间的零个数
                        max_zeros_per_block(k, N) = second_nz_rel - 1;
                    end
                else
                    % 第一个非零值是最后一个元素，后面没有零
                    max_zeros_per_block(k, N) = 0;
                end
            end
        end
    end
    
   %max_l=1;
    % 计算结果
    max_l0 = 0;
    threshold = 2 + 2 + log2(w) + 1;
    valid_mask = max_zeros_per_block > threshold;
    if any(valid_mask(:))
        max_l0 = max(max_zeros_per_block(valid_mask));
    end
    
    if max_l0 > w
       if max_l0 == 0, max_l = 4; else, max_l = ceil(log2(max_l0)-log2(w)); end
    else
       max_l = 4;  
    end
% for i=1:row1   
%     for j=1:col1   %%对每个块进行处理
%      %%转换为位平面
%      % select_blocked1=zeros(h,w,8);%%切成位平面暂时存贮
%      % select_blocked2=reshape(,);%%当前块
%      r_idx = (i-1)*h + 1 : i*h;
%       c_idx = (j-1)*w + 1 : j*w;
% 
%      select_blocked3=zeros(h,w);%%最佳块
%      select_blocked3(1,1)=1;%%方便后续比较
%      bit_num=1;%%最大连续零位置
%      r_NUM=0;%%方便统计r
%           max_er=0;
%         for N=1:4  
%          if N==1%%1*8
%              select_blocked2=select21(r_idx, c_idx);
%              edges = -0.5 : 1 : 255.5;
%           num22 = histcounts(select_blocked2(:), edges);   % 1×256, 对应 0..255
% 
%          end
%          if N==2%%第二种2*4
%             select_blocked2=select22(r_idx, c_idx);
%              edges = -0.5 : 1 : 255.5;
%           num22 = histcounts(select_blocked2(:), edges);   % 1×256, 对应 0..255
%          end
%          if N==3%%第二种4*2
%              select_blocked2=select23(r_idx, c_idx);
%              edges = -0.5 : 1 : 255.5;
%           num22 = histcounts(select_blocked2(:), edges);   % 1×256, 对应 0..255
%          end
%          if N==4%%第四种8*1
%                select_blocked2=select24(r_idx, c_idx);
%              edges = -0.5 : 1 : 255.5;
%           num22 = histcounts(select_blocked2(:), edges);   % 1×256, 对应 0..255
%          end
%          % num0_2=num0_1+num0;
%          %  num_sum=((i-1)*col1+j)*w*h;
%          %  num_sum=0;
%          % if i==1&&j==1
%          %     num2=num1;
%          % else
%          %     num2=[num2,num1];
%          % end
% 
%          num22=num11+num22;
%          %[bit_num1] = complete_bit(select_blocked2,1,1,num22,max_l);
%          if i==4&&j==29
%              asa=1;
%          end
%          [bit_num1,p0_f1,p01,p11,l01,opt11,b01,ns1,l_0_1,l_d1,l_d_best1,xts1,max_er_f] = Copy_of_complete_bit(select_blocked2,num22,max_l, max_er);
%          if N==1
%              r_NUM=N;
%              bit_num=bit_num1;
%              select_blocked3=select_blocked2;
%              % num3=num2;
%             % num0_3=num0_1;
%              num33=num22;
%             p0_f2=p0_f1;
%             p02=p01;
%             p12=p11;
%             l02=l01;
%             opt12=opt11;
%             b02=b01;
%            ns2=ns1;
%            l_0_2=l_0_1;
%            l_d2=l_d1;
%            l_d_best2=l_d_best1;
%            xts2=xts1;
%            max_er=bit_num1;
%          else
%              if max_er_f==1
%                if bit_num<bit_num1
%                  r_NUM=N;
%                  bit_num=bit_num1;
%                  select_blocked3=select_blocked2;
%                  % num3=num2;
%                  % num0_3=num0_1;
%                  num33=num22;
%                  p0_f2=p0_f1;
%                 p02=p01;
%                 p12=p11;  
%                 l02=l01;
%                  opt12=opt11;
%                  b02=b01;
%                ns2=ns1;
%                l_0_2=l_0_1;
%                l_d2=l_d1;
%                l_d_best2=l_d_best1;
%                xts2=xts1;
%                max_er=bit_num1;
%                end
%             end
%          end
%         end
%             p0_f(i,j)=p0_f2;
%             p0(i,j)=p02;
%             p1(i,j)=p12; 
%             l0(i,j)= l02;
%              opt1(i,j)=opt12;
%              b0{end+1}=b02;
%              ns(i,j)=ns2;
%              l_0{end+1}=l_0_2;
%              l_d{end+1}=l_d2;
%               l_d_best(i,j)=l_d_best2;
%               xts{end+1}=xts2;
%         num11=num33;
%         % num0=num0+num0_3;
%         bit_nums=bit_nums+bit_num;
%         %%select_blocked3 在其基础上进行调整
% 
%         %%将最优块塞入和r_numd塞入r中
%         % num2=num3;
%         [select_blocked] = Join_big_block(select_blocked,select_blocked3,i,j);
%         [a,b]=size(select_blocked);
%         if b>512
%             asa=1;
%         end
%         r(i,j)=r_NUM;
%        % max_zeros_per_block
% 
%         if i==1&&j==1
%             r1=r_NUM;
% 
%         else
%             r1=[r1,r_NUM];
%         end
%         if max_l1< max_zeros_per_block((i-1)*col1+j,r_NUM)
%             max_l1=max_zeros_per_block((i-1)*col1+j,r_NUM);
%         end
%     end
% end
% --- 1. 预分配内存 (极其重要) ---
num_blocks = row1 * col1;
p0_f = zeros(row1, col1);
p0 = zeros(row1, col1);
p1 = zeros(row1, col1);
l0 = zeros(row1, col1);
opt1 = zeros(row1, col1);
ns = zeros(row1, col1);
l_d_best = zeros(row1, col1);
r = zeros(row1, col1);
r1 = zeros(1, num_blocks); % 替换原有的 r1 = [r1, r_NUM]

% Cell 数组预分配
b0 = cell(1, num_blocks);
l_0 = cell(1, num_blocks);
l_d = cell(1, num_blocks);
xts = cell(1, num_blocks);
mode_flag=cell(1, num_blocks);
% 常量提取
edges = -0.5 : 1 : 255.5;
max_l1 = 0; % 初始化全局最大值
block_count = 0; % 线性索引计数器

% --- 2. 开始主循环 ---
for i = 1:row1
    for j = 1:col1
        block_count = block_count + 1;
        r_idx = (i-1)*h + 1 : i*h;
        c_idx = (j-1)*w + 1 : j*w;
        
        % 存储当前块 4 种模式下最好的结果
        best_bit_num = -inf;
        best_res = struct(); 
        
        % 预取 4 种数据源的当前块切片，减少循环内索引开销
        current_blocks = {select21(r_idx, c_idx), ...
                          select22(r_idx, c_idx), ...
                          select23(r_idx, c_idx), ...
                          select24(r_idx, c_idx)};
        
        for N = 1:4
            sel_block = current_blocks{N};
            
            % 计算直方图
            num22_current = histcounts(sel_block(:), edges);
            num22_input = num11 + num22_current;
           
            % 调用核心函数
            [bit_num1, p0_f1, p01, p11, l01, opt11, b01, ns1, l_0_1, l_d1, l_d_best1, xts1, max_er_f,mode_flags] = ...
                Copy_of_complete_bit(sel_block, num22_input, max_l, (N > 1) * best_bit_num);
            
            % 更新逻辑：如果是第一种模式，或者当前模式更优且合法
            if N == 1 || (max_er_f == 1 && bit_num1 > best_bit_num)
                best_bit_num = bit_num1;
                best_r_NUM = N;
                best_num22 = num22_input;
                
                % 暂存最优数据
                best_res.p0_f = p0_f1;
                best_res.p0 = p01;
                best_res.p1 = p11;
                best_res.l0 = l01;
                best_res.opt1 = opt11;
                best_res.b0 = b01;
                best_res.ns = ns1;
                best_res.l_0 = l_0_1;
                best_res.l_d = l_d1;
                best_res.l_d_best = l_d_best1;
                best_res.xts = xts1;
                best_res.block = sel_block;
                best_res.mode =mode_flags;
            end
        end
        
        % --- 3. 将最优结果写入预分配的数组中 ---
        p0_f(i,j) = best_res.p0_f;
        p0(i,j) = best_res.p0;
        p1(i,j) = best_res.p1;
        l0(i,j) = best_res.l0;
        opt1(i,j) = best_res.opt1;
        b0{block_count} = best_res.b0;
        ns(i,j) = best_res.ns;
        l_0{block_count} = best_res.l_0;
        l_d{block_count} = best_res.l_d;
        l_d_best(i,j) = best_res.l_d_best;
        xts{block_count} = best_res.xts;
        r(i,j) = best_r_NUM;
        r1(block_count) = best_r_NUM;
        mode_flag{block_count}=best_res.mode;
        % 更新全局状态
        num11 = best_num22;
        bit_nums = bit_nums + best_bit_num;
        
        % 块拼接 (建议检查 Join_big_block 内部是否也使用了预分配)
        select_blocked(r_idx, c_idx) = best_res.block;
        
        % 更新最大零值统计
        current_max_z = max_zeros_per_block(block_count, best_r_NUM);
        if max_l1 < current_max_z
            max_l1 = current_max_z;
        end
    end
end
    if max_l1 > w
       if max_l1 == 0, max_l = 4; else, max_l = ceil(log2(max_l1)-log2(w)); end
    else
       max_l = 4;  
    end
% 
% %进行校准
% block_size=[h,w];
% image_trans=zeros(row,col,8);
% for i=1:row1   
%     for j=1:col1 
%         if i==2&&j==1
%           asa=1;
%         end
%         block_data = extract_image_block(select_blocked, i, j, block_size, row, col);
%         recovered_blocked1 = reverse_block_processing(r(i,j), w,h,block_data);
%         for n=1:8
%             for x=1:h
%                 for y=1:w
%                  image_trans((i-1)*h+x,(j-1)*w+y,n)=recovered_blocked1(x,y,n);
%                 end
%             end
%         end
%     end
% end
% H=row;
% W=col;
% for i=1:H
%     for j=1:W
%         for z=1:8
%             if z==1
%                 a=image_trans(i,j,z);
%             else
%                a=[a,image_trans(i,j,z)]; 
%             end
% 
%         end
%         sum=0;
%         for n=1:7
%             sum=sum*2+a(n);
%         end
%         if a(8)==0
%             sum=-sum;
%         elseif a(8)==1
%             sum=sum+1;
%         end
%       if origin_D_I(i,j)~=sum
%           asa=1;
%           msg = 'Error 7 occurred.';
%            error(msg)
%       end
%     end
% end     
asa=1;
