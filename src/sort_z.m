%%转化评率及数字
function [sorted_data,sorted_frequency,max_val] = sort_z(z)
     
    data = z(:,1);
    frequency = z(:,2);
% 将数据组合成一个矩阵，第一列是frequency，第二列是data
combined = [frequency(:), data(:)];

% 使用sortrows先按第一列（frequency）升序，再按第二列（data）升序
sorted = sortrows(combined, [1, 2],{'descend', 'ascend'});

% 提取排序后的data和frequency
sorted_frequency = sorted(:, 1)';
sorted_data = sorted(:, 2)';
[max_val, max_idx] = max(data);
