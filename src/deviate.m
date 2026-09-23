%%得到误差
function [origin_E_I,x,recover_I,pred_ref] = deviate(origin_I,prediction_mode)
% 主链路显式传入 'entropy'：按估计码长选向；旧的单参数调用仍使用 SSE。
if nargin<2, prediction_mode='sse'; end
prediction_mode=validatestring(prediction_mode,{'entropy','sse'});
% 函数说明：计算origin_PV_I的误差值
% 输入：origin_I（原始图像）,origin_PV_I（预测图像）
% 输出：origin_E_I（预测图像-原始图像）；x（保持原接口）；
% recover_I（仅误差和参考比特流重建）；pred_ref.bits 为实际辅助比特流。
% [row,col] = size(origin_I); %计算origin_I的行列值
% for i=1:row   
%     for j=1:col 
%         origin_E_I1(i,j) = abs(origin_PV_I(i,j) - origin_I(i,j));
%         origin_E_I(i,j) = origin_PV_I(i,j) - origin_I(i,j);
%     end
% end

% ErrorMap=origin_E_I1;
% row_sums = sum(ErrorMap, 2);
% col_sums = sum(ErrorMap, 1);
% [~, best_r] = max(row_sums);
% [~, best_c] = max(col_sums);
% 
% % --- 3. 生成所有点的“行列叠加和”矩阵 (用于验证) ---
% % 利用 MATLAB 的广播机制 (Implicit Expansion)
% % 列向量 + 行向量 = 矩阵
% TotalSumMatrix = row_sums + col_sums; 
% 
% % 找出这个矩阵中的最大值
% [global_max, linear_idx] = max(TotalSumMatrix(:));
% [check_r, check_c] = ind2sub(size(TotalSumMatrix), linear_idx);
% 
% % --- 4. 结果对比 ---
% fprintf('快速方法得出的位置: (%d, %d)\n', best_r, best_c);
% fprintf('全矩阵搜索得出的位置: (%d, %d)\n', check_r, check_c);
% 
% % --- 5. 可视化 ---
% figure;
% imagesc(TotalSumMatrix);
% colorbar;
% hold on;
% plot(best_c, best_r, 'w+', 'MarkerSize', 20, 'LineWidth', 3);
% title('所有点的(行误差+列误差)分布图');
% xlabel('列索引'); ylabel('行索引');
validateattributes(origin_I,{'numeric'},{'2d','real','finite','integer','nonempty','>=',0,'<=',255});
% 纯色图必须保存灰度锚点，不能把零误差当作零辅助信息。
if all(origin_I(:)==origin_I(1))
    state=struct('mode',1,'value',double(origin_I(1)));
    [bits,pred_ref]=prediction_reference_codec('encode',state,size(origin_I));
    pred_ref.bits=bits;
    origin_E_I=zeros(size(origin_I)); x=0;
    recovered=recover_from_prediction_error(origin_E_I,bits);
    recover_I=cast(recovered,class(origin_I));
    assert(isequal(double(origin_I),recovered),'deviate:ReconstructionMismatch','Constant reconstruction failed.');
    fprintf('deviate 纯色重建通过：1 个参考像素，辅助信息 %d bit，像素差异 0。\n',numel(bits));
    return;
end
assert(all(size(origin_I)>=3),'deviate:ImageSize','Nonconstant images must be at least 3 by 3.');
global_sigma = std(double(origin_I(:)));
[origin_PV_I1] = Copy_of_Predictor_Value2(double(origin_I),1,1,1, 1, 1, 1,1, 1,global_sigma, 1, 1) ;

recover_I=0;%%站位
ErrorMap= (double(origin_PV_I1) - double(origin_I)).^2;   % MSE 模式 (推荐)

    [H, W] = size(ErrorMap);
    
    % 创建网格坐标矩阵
    [cols_grid, rows_grid] = meshgrid(1:W, 1:H);
    
    % 计算总误差质量
    total_mass = sum(ErrorMap(:));
    
    if ~isfinite(total_mass)
        error('deviate:NonfinitePredictor', ...
            '原预测器产生非有限值（例如某方向梯度为零）；保持预测公式不变时无法编码该图像。');
    end
    if total_mass == 0
        center_r = round(H/2);
        center_c = round(W/2);
    else
    % 计算行重心: Sum(r * Error(r,c)) / TotalMass
    weighted_r = sum(ErrorMap(:) .* rows_grid(:));
    center_r = round(weighted_r / total_mass);
    
    % 计算列重心: Sum(c * Error(r,c)) / TotalMass
    weighted_c = sum(ErrorMap(:) .* cols_grid(:));
    center_c = round(weighted_c / total_mass);
    end
    
    % 边界限制
    center_r = max(2, min(H-1, center_r));
    center_c = max(2, min(W-1, center_c));
    
    % fprintf('误差峰值位置可能受噪点干扰。\n');
    % fprintf('计算得到的误差重心位置: (%d, %d)\n', center_r, center_c);


    %% 误差重心已计算完毕：center_r, center_c 在这里可用
% % H, W, ErrorMap, rows_grid, cols_grid 也都已经有
% 
% % =========================
% % 1) 基于误差图的局部复杂度标识 RegionType
% % =========================
% % local_err 用平滑后的误差，表示“局部误差强度”
% local_err = imgaussfilt(ErrorMap, 1.0);   % sigma=1 可调
% 
% % 将局部误差强度拉直成向量
% v = local_err(:);
% 
% % 用分位数做三段分级（避免写死阈值）
% q1 = quantile(v, 0.33);   % 低 1/3
% q2 = quantile(v, 0.66);   % 中 1/3
% 
% % RegionType: 0=光滑区, 1=中等纹理区, 2=高误差/复杂区
% RegionType = zeros(H, W, 'uint8');
% RegionType(local_err <= q1)                  = 0;  % 光滑
% RegionType(local_err > q1  & local_err <= q2) = 1;  % 中等
% RegionType(local_err > q2)                   = 2;  % 复杂/高误差
% 
% % =========================
% % 2) 根据距离重心的远近，标识 CenterZone
% % =========================
% % 距离重心的欧氏距离
% dist2 = (rows_grid - center_r).^2 + (cols_grid - center_c).^2;
% 
% % 以图像短边的一定比例作为“重心附近半径”
% R = min(H, W) * 0.2;     % 20% 可调：0.15~0.3 试一试
% CenterZone = dist2 <= R^2;    % logical(H,W)，true 表示重心附近
% 
% % =========================
% % 3) （可选）整体误差模式 GlobalPattern
% % =========================
% mass_center = sum(ErrorMap(CenterZone));
% mass_total  = sum(ErrorMap(:));
% 
% ratio_center = mass_center / (mass_total + eps);
% 
% % GlobalPattern：0=中等型, 1=误差主要集中在重心附近, 2=误差较分散/整体混乱
% if ratio_center > 0.6
%     GlobalPattern = uint8(1);   % 中心复杂型
% elseif ratio_center < 0.3
%     GlobalPattern = uint8(2);   % 整体较分散/混乱
% else
%     GlobalPattern = uint8(0);   % 中间型
% end
% 
% % （暂时先不在后面用，只是算出来）
% fprintf('GlobalPattern = %d (0:中间型, 1:重心集中, 2:分散)\n', GlobalPattern);

 % ========================================================
    % 【修改】：误差空间分布模式判定 (仅特判极度集中)
    % ========================================================
    % 划定重心附近的判定半径 (例如短边的 25%)
    R_zone = min(H, W) * 0.25; 
    dist2 = (rows_grid - center_r).^2 + (cols_grid - center_c).^2;
    CenterZone = dist2 <= R_zone^2;
    
    mass_center = sum(ErrorMap(CenterZone));
    ratio_center = mass_center / (total_mass + eps);
    
    % GlobalPattern: 
    % 1 = 极度集中在中心 (重灾区特判)
    % 0 = 常规/分散情况 (通用处理)
    if ratio_center > 0.4  % 只有误差极其集中（50%以上）才触发
        GlobalPattern = 1; 
        pattern_str = '极度集中于中心 (外围平滑，中心复杂)';
    elseif ratio_center < 0.1
        GlobalPattern = 2; 
        pattern_str = '极度分散在外围 (中心平滑，外围复杂)';
    else
        GlobalPattern = 0; 
        pattern_str = '常规分散分布';
    end
    
    % fprintf('空间误差模式: %s (中心误差占比: %.1f%%)\n', pattern_str, ratio_center*100);
%%计算全局梯度
[gH, gV, gD45, gD135] = calc_global_gradients(origin_I);


%%得到最大点位处check_r, check_c
best_r=center_r;
best_c=center_c;
%%加个对比
% %peak_r, peak_c
% [origin_PV_I1] = Copy_of_Predictor_Value2(origin_I,1,1,gH, gV, gD45, gD135,best_r, best_c,global_sigma, GlobalPattern, R_zone) ;
% [origin_PV_I2] = Copy_2_of_Predictor_Value2(origin_I,1,1,gH, gV, gD45, gD135,best_r, best_c,global_sigma, GlobalPattern, R_zone) ;
% %%
% [NewPred, NewErr,BestDirs,NewErr1] =med_4dir_prediction(origin_I,best_r, best_c,gH, gV, gD45, gD135,global_sigma,GlobalPattern, R_zone);
% [FinalPredImg1, FinalErrorImg1, BlockInfo1, NewErr11] = Copy_of_med_4dir_prediction(origin_I, best_r, best_c, ...
%                                                              gH, gV, gD45, gD135,global_sigma ,GlobalPattern, R_zone);
%  % [NewPred, NewErr,NewErr1] = med_quadrant_prediction(origin_I, best_r, best_c);
% 
% % %% 4. 结果可视化
% % figure('Position', [100, 100, 1200, 400]);
% % 
% % subplot(1, 3, 1);
% % imagesc(origin_I); title('原始图像'); axis off; colormap gray;
% % 
% % subplot(1, 3, 2);
% % imagesc(origin_E_I1); title('MED预测误差图'); axis off; colorbar;clim([-255, 255]); 
% % 
% % subplot(1, 3, 3);
% % imagesc(NewPred); title(['四象限 MED 预测 (分割点: ', num2str(best_r), ',', num2str(best_c), ')']); 
% % axis off; hold on;
% % % 画分割线
% % line([1, size(origin_I, 2)], [best_r, best_r], 'Color', 'r', 'LineWidth', 2);
% % line([best_c, best_c], [1, size(origin_I, 1)], 'Color', 'r', 'LineWidth', 2);
% 
% % %% 4. 结果可视化 (严格匹配学术论文描述)
% % figure('Position', [100, 100, 1200, 400]);
% % [H, W] = size(origin_I);
% % 
% 1. 第一列：原始图像
% % subplot(1, 3, 1);
% % imagesc(origin_I); 
% % colormap(gca, 'gray'); % 独立设置当前子图的colormap
% % axis image off;        % 保持图像比例不变且去掉坐标轴
% % title('原始图像', 'FontSize', 12);
% % 
% % % 2. 第二列：平方误差能量图 E(i,j)
% % % 计算平方误差以体现"能量"，并限制极端异常值以保证热力图视觉效果
% % E_sq = double(origin_E_I1).^2; 
% % disp_max = prctile(E_sq(:), 98); % 取98%分位数作为显示上限，防止个别极值导致整体变暗
% % 
% % subplot(1, 3, 2);
% % imagesc(E_sq); 
% % colormap(gca, 'hot');  % 使用热力图(黑-红-黄-白)完美契合"能量聚集"的描述
% % clim(gca, [0, disp_max]); % 能量总是大于等于0
% % axis image off;
% % title('平方误差能量图', 'FontSize', 12);
% % 
% % % 3. 第三列：动态预测轴与判定邻域 \Omega
% % subplot(1, 3, 3);
% % % 背景使用原图，更能直观体现轴心与图像内容的关系
% % imagesc(origin_I); 
% % colormap(gca, 'gray'); 
% % axis image off; hold on;
% % title(['动态定位 (M_g 锚定点: ', num2str(best_r), ',', num2str(best_c), ')'], 'FontSize', 12); 
% % 
% % % 3.1 画动态预测轴 (十字线) - 使用高对比度的黄色或红色
% % line([1, W], [best_r, best_r], 'Color', '#FFD700', 'LineWidth', 2); % 水平轴
% % line([best_c, best_c], [1, H], 'Color', '#FFD700', 'LineWidth', 2); % 垂直轴
% % 
% % % 3.2 画判定邻域 \Omega (圆)
% % R_zone = 0.25 * min(H, W); % 按论文公式计算半径
% % theta = linspace(0, 2*pi, 100);
% % x_circle = best_c + R_zone * cos(theta);
% % y_circle = best_r + R_zone * sin(theta);
% % % 画一个青色虚线圆，学术感极强
% % plot(x_circle, y_circle, 'Color', '#00FFFF', 'LineWidth', 2, 'LineStyle', '--'); 
% % 
% % hold off;
% % 
% % %% 4. 结果可视化 (纯净版，无标题，适合直接插入论文)
% % figure('Color', 'w', 'Position', [100, 100, 1500, 450]); % 宽比例画布
% % [H, W] = size(origin_I);
% % 
% % % ==========================================
% % % 第一列：原始图像
% % % ==========================================
% % subplot(1, 3, 1);
% % imagesc(origin_I); 
% % colormap(gca, 'gray'); 
% % axis image off;
% % 
% % % ==========================================
% % % 第二列：平方误差能量图 (去底噪纯净版)
% % % ==========================================
% % subplot(1, 3, 2);
% % E_sq = double(origin_E_I1).^2;
% % 
% % % 过滤掉 85% 的平滑背景细微误差，强制设为 0 (纯黑)
% % noise_floor = prctile(E_sq(:), 85); 
% % E_sq(E_sq < noise_floor) = 0; 
% % 
% % % 高斯平滑，产生“能量发光”的视觉效果
% % E_vis = imgaussfilt(E_sq, 1.2); 
% % 
% % imagesc(E_vis); 
% % colormap(gca, 'hot'); % 黑->红->黄->白
% % clim(gca, [0, prctile(E_vis(:), 99.5)]); 
% % axis image off;
% % 
% % % ==========================================
% % % 第三列：动态定位与判定邻域 (高级学术配色)
% % % ==========================================
% % subplot(1, 3, 3);
% % imagesc(origin_I); 
% % colormap(gca, 'gray'); 
% % axis image off; hold on;
% % 
% % % 使用顶级期刊常用的学术对比色
% % color_axis = '#E63946';   % 砖红色 (十字轴)
% % color_circle = '#00B4D8'; % 亮湖蓝色 (判定圆)
% % 
% % % 画动态预测轴 (点划线)
% % line([1, W], [best_r, best_r], 'Color', color_axis, 'LineWidth', 1.5, 'LineStyle', '-.'); 
% % line([best_c, best_c], [1, H], 'Color', color_axis, 'LineWidth', 1.5, 'LineStyle', '-.'); 
% % 
% % % 画判定邻域 \Omega (圆)
% % R_zone = 0.25 * min(H, W); 
% % theta = linspace(0, 2*pi, 150); 
% % x_circle = best_c + R_zone * cos(theta);
% % y_circle = best_r + R_zone * sin(theta);
% % plot(x_circle, y_circle, 'Color', color_circle, 'LineWidth', 2.5, 'LineStyle', '--'); 
% % 
% % % 中心锚点标记 (黄橙色小圆点加白边)
% % plot(best_c, best_r, 'o', 'MarkerFaceColor', '#F4A261', 'MarkerEdgeColor', 'w', 'MarkerSize', 6);
% % 
% % hold off;
% % 
% % % 调整子图间距，让三张图紧凑排列，消除过多留白
% % set(gca, 'Position', [0.68, 0.05, 0.3, 0.9]);
% % subplot(1, 3, 2); set(gca, 'Position', [0.35, 0.05, 0.3, 0.9]);
% % subplot(1, 3, 1); set(gca, 'Position', [0.02, 0.05, 0.3, 0.9]);
% 
% % 显示误差统计
% original_mae = mean(origin_E_I1(:));
% new_mae = mean(abs(NewErr1(:)));
% new_mae1 = mean(abs(NewErr11(:)));
% s1=origin_PV_I1-origin_I;
% s=mean(abs(s1(:)));
% s2=origin_PV_I2-origin_I;
% s11=mean(abs(s2(:)));
% % fprintf('原预测 MAE: %.3f\n', original_mae^2);
% % fprintf('开 四象限 MED 预测 MAE: %.3f\n', new_mae);
% % fprintf('关 四象限 MED 预测 MAE: %.3f\n', new_mae1);
% % fprintf('开 多梯度预测 MAE: %.3f\n', s);
% % fprintf('关 多梯度预测 MAE: %.3f\n', s11);
% 
% % 显示误差统计 (标准差 Standard Deviation)
% 
% % 确保参与计算的误差矩阵为双精度浮点型，防止溢出或截断
% % 假设 origin_E_I1, NewErr1, NewErr11 已经是带符号的误差矩阵 (预测值 - 真实值)
% original_std = std(double(origin_E_I(:)));
% new_std = std(double(NewErr1(:)));
% new_std1 = std(double(NewErr11(:)));
% 
% % 计算开/关多梯度预测的真实误差矩阵 (带有正负号)
% s1 = double(origin_PV_I1) - double(origin_I);
% std_s = std(s1(:));
% 
% s2 = double(origin_PV_I2) - double(origin_I);
% std_s11 = std(s2(:));
% 
% % 打印输出标准差结果
% 
% fprintf('开 四象限 MED 预测 STD: %.3f\n', new_std);
% fprintf('关 四象限 MED 预测 STD: %.3f\n', new_std1);
% fprintf('开 多梯度预测 STD: %.3f\n', std_s);
% fprintf('关 多梯度预测 STD: %.3f\n', std_s11);
[NewPred, ~,BestDirs,~,BlockStats] =med_4dir_prediction(double(origin_I),best_r, best_c,gH, gV, gD45, gD135,global_sigma,GlobalPattern, R_zone,prediction_mode);
% med_4dir_prediction 内部的 NewErr1 是“原图 - 预测图”。
% 本工程的恢复方向采用“预测图 - 原图”，因此这里统一转换符号。
origin_E_I = double(NewPred) - double(origin_I);

% 接收端不保存 NewPred。只保存方向、分割参数、每块统计量和
% 尚未由扫描得到的因果参考像素，然后重新生成预测值。
labels={'TL','TR','BL','BR'};
dirs=zeros(1,4);
for k=1:4, dirs(k)=find(strcmp(BestDirs(k).Dir,labels))-1; end
state=struct('mode',0,'split',[best_r best_c],'dirs',dirs, ...
    'GlobalPattern',GlobalPattern,'block_stats',BlockStats);
[positions,~]=prediction_reference_layout(size(origin_I),state.split,dirs);
state.val=double(origin_I(positions));
[bits,pred_ref]=prediction_reference_codec('encode',state,size(origin_I));
pred_ref.bits=bits;
% % 验证实际传输比特流：接收端只有 E 与 bits，无原图/预测图输入。
% [recover_I_double,regen_pred]=recover_from_prediction_error(origin_E_I,bits);
% assert(isequal(regen_pred,NewPred),'deviate:PredictionMismatch','Regenerated predictions differ.');
% recovery_diff = recover_I_double - double(origin_I);
% recovery_ok = all(recovery_diff(:) == 0);
% if ~recovery_ok
%     error('deviate:ReconstructionMismatch', ...
%         '仅误差和辅助比特流未能逐像素恢复原图，最大误差为 %.g。', ...
%         max(abs(recovery_diff(:))));
% end
% 
% % 第三个输出用于外部测试；现有第二输出 x 保持原来的标量接口。
% recover_I = cast(round(recover_I_double), class(origin_I));
% fprintf('deviate 重建校验通过：像素差异 %d，最大误差 %.g。\n', ...
%     nnz(recovery_diff), max(abs(recovery_diff(:))));
% fprintf('预测参考信息：%d 个原始像素；完整辅助信息 %d bit（头部 %d，统计量 %d，参考值编码 %d）。\n', ...
%     pred_ref.reference_count,pred_ref.reference_bits,pred_ref.header_bits, ...
%     pred_ref.statistics_bits,pred_ref.reference_value_bits);
x=0;
% sx=max(max(origin_E_I));
% sd=min(min(origin_E_I));
 end
