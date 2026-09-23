%%预测误差修改版：
function [origin_PV_I] = Copy_of_Predictor_Value2(origin_I,ref_x,ref_y,gH, gV, gD45, gD135,split_row, split_col,global_sigma, GlobalPattern, R_zone)  
% 函数说明：计算origin_I的预测值
% 输入：origin_I（原始图像）,ref_x,ref_y（参考像素的行列数）
% 输出：origin_PV_I（原始图像的预测值）
[row,col] = size(origin_I); %计算origin_I的行列值
 PadImg= padarray(origin_I, [2, 2], 'replicate');
 origin_PV_I=zeros(row,col);
X=origin_I;
  X = double(X);
    [H, W] = size(X);
H_block=H; W_block=W;
    % 横向 gh
    % i = 1:H, j = 2:W  ->  X(:,2:W) - X(:,1:W-1)
    diff_h = abs(X(:, 2:W) - X(:, 1:W-1));
    gH = sum(diff_h, 'all') / (H * (W - 1));

    % 竖�� gv
    % i = 2:H, j = 1:W  ->  X(2:H,:) - X(1:H-1,:)
    diff_v = abs(X(2:H, :) - X(1:H-1, :));
    gV = sum(diff_v, 'all') / ((H - 1) * W);

    % 主对角线 gmd (左上 -> 右下)
    % i = 2:H, j = 2:W -> X(2:H,2:W) - X(1:H-1,1:W-1)
    diff_md = abs(X(2:H, 2:W) - X(1:H-1, 1:W-1));
    gD45 = sum(diff_md, 'all') / ((H - 1) * (W - 1));

    % 副对角线 gsd (右上 -> 左下)
    % i = 2:H, j = 1:W-1 -> X(2:H,1:W-1) - X(1:H-1,2:W)
    diff_sd = abs(X(2:H, 1:W-1) - X(1:H-1, 2:W));
   gD135 = sum(diff_sd, 'all') / ((H - 1) * (W - 1));
origin_PV_I = origin_I;  %构建存储origin_I预测值的容器
x=origin_I(ref_x,ref_y);
 total_grad = gH + gV + gD45 + gD135 + 1e-5; 
%     w_V = 1+(gV / total_grad)*2;   
%     w_H =1+(gH / total_grad)*2 ;   
%     w_md =1+(gD45 / total_grad)*2 ;   
%     w_sd = 1+(gD135 / total_grad)*2 ; 
%     H_block=row ; W_block=col;
    % w_V = gV  ;
    % w_H =gH  ;   
    % w_md =gD45 ;   
    % w_sd = gD135  ; 
for i=1:row   
    for j=1:col  
        if i==1 && j==1
            origin_PV_I(i,j)=PadImg(i+2,j+2);
        elseif i==1 && j>1
             origin_PV_I(i,j)=PadImg(i+2,j-1+2);
        elseif j==1 && i>1
             origin_PV_I(i,j)=PadImg(i-1+2,j+2);
        else
            if j==col
                asa=1;
            end
            pr=i+2;
            pc=j+2;

             abs_r =i;
            abs_c = j;
             % 判断是否在重心辐射圈内
                % dist_to_center = sqrt((abs_r - split_row)^2 + (abs_c - split_col)^2);
                % is_center_zone = (dist_to_center <= R_zone);

            a=2;
            b=2;
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
             xsd = PadImg(pr-1, pc+1);
                        x6  = PadImg(pr-2, pc+1);
            % 垂直梯度 (dh)
                dh = (2*abs(xh - xmd) + 2*abs(xv - x5) + abs(xsd - x6)+abs(xmd - x4)+abs(x1 - x2))/7; % 这里加入 xsd, x6 
                % 水平梯度 (dv)
                dv = (2*abs(xh - x1) + 2*abs(xv - xmd) + abs(xsd - xv)+abs(x2 - xmd)+abs(x4 - x5))/7;
                dmd=(abs(x3 - xmd)+abs(x4 - xv)+abs(x5 - xsd)+abs(x2 - xh))/4;
                dsd=(abs(xmd - x1)+abs(x5 - xmd)+abs(xv- xh)+abs(x2 - x4))/4;
                % 结合全局权重
                % score_v = dv * w_V;
                % score_h = dh * w_H;
                % score_v = 1/(w_H^a*(dh+0.1)^b);
                % score_h = 1/(w_V^a*(dv+0.1)^b);
                % %gD45, gD135, 
                % score_md = 1/(sqrt(2)*w_md^a*(dmd+0.1)^b);
                % score_sd = 1/(sqrt(2)*w_sd^a*(dsd+0.1)^b);
                 score_v = 1/((max(gV,1e-12))^2*(dh+0.1)^2);
                score_h = 1/((max(gH,1e-12))^2*(dv+0.1)^2);
                %gH, gV, gD45, gD135, 
                score_md = 1/(sqrt(2)*(max(gD45,1e-12))^2*(dmd+0.1)^2);
                score_sd = 1/(sqrt(2)*(max(gD135,1e-12))^2*(dsd+0.1)^2);
                total_score=score_v+score_h+score_md+score_sd;
                wight_v=score_v/total_score;
                wight_h=score_h/total_score;
                wight_md=score_md/total_score;
                wight_sd=score_sd/total_score;
                val= xv*wight_v+ xh*wight_h+xmd*wight_md+xsd*wight_sd;
               flage=1;
               if  flage
                % 已取消极值干预：初始误差图统一使用趋势反馈。
                % 初始误差图决定 DGP 分区；不再将预测值直接替换为邻域极值。
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
               end
               assert(isfinite(val),'prediction:Nonfinite','Nonfinite initial prediction.');
               origin_PV_I(i,j)=min(255,max(0,round(val))); 
        end
    end
end
asa=1;

