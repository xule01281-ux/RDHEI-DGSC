function [G_H, G_V, G_D45, G_D135] = calc_global_gradients(Img)
% CALC_GLOBAL_GRADIENTS 计算图像四个方向的全局梯度总和 (L1范数)
%
% 输入:
%   Img: 输入图像 (二维矩阵)
% 输出:
%   G_H    : 横向梯度总和 (Horizontal)
%   G_V    : 竖向梯度总和 (Vertical)
%   G_D45  : 主对角线梯度总和 (Diagonal, \ 方向)
%   G_D135 : 副对角线梯度总和 (Anti-Diagonal, / 方向)

    % 1. 预处理：转为 double 防止 uint8 溢出
    I = double(Img);
    
    %% --- 1. 横向梯度 (Horizontal, 0度) ---
    % 计算 I(i, j) - I(i, j-1)
    % 操作：所有行，从第2列到最后 - 所有行，从第1列到倒数第2列
    Diff_H = abs(I(:, 2:end) - I(:, 1:end-1));
    G_H = mean(Diff_H(:));
    
    %% --- 2. 竖向梯度 (Vertical, 90度) ---
    % 计算 I(i, j) - I(i-1, j)
    % 操作：从第2行到最后 - 从第1行到倒数第2行
    Diff_V = abs(I(2:end, :) - I(1:end-1, :));
    G_V = mean(Diff_V(:));
    
    %% --- 3. 主对角线梯度 (Diagonal, 45度, \) ---
    % 计算 I(i, j) - I(i-1, j-1)
    % 几何意义：左上角到右下角的差异
    % 操作：截取 (2:end, 2:end) 与 (1:end-1, 1:end-1)
    Diff_45 = abs(I(2:end, 2:end) - I(1:end-1, 1:end-1));
    G_D45 = mean(Diff_45(:));
    
    %% --- 4. 副对角线梯度 (Anti-Diagonal, 135度, /) ---
    % 计算 I(i, j) - I(i-1, j+1)
    % 几何意义：右上角到左下角的差异
    % 操作：
    %   当前点集: 行(2:end), 列(1:end-1)  -> (左下侧像素)
    %   参考点集: 行(1:end-1), 列(2:end)  -> (右上侧像素)
    Diff_135 = abs(I(2:end, 1:end-1) - I(1:end-1, 2:end));
    G_D135 = mean(Diff_135(:));
    
    %% (可选) 打印结果方便调试
    % fprintf('全局梯度统计:\n');
    % fprintf('  横向 (H): %.0f\n', G_H);
    % fprintf('  竖向 (V): %.0f\n', G_V);
    % fprintf('  对角 (45): %.0f\n', G_D45);
    % fprintf('  反角 (135): %.0f\n', G_D135);
end