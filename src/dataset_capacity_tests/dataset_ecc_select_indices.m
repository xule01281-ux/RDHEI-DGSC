function indices=dataset_ecc_select_indices(count,start_index,end_index,max_images)
% 区间含两端；显式超出清单范围时报错，避免把不足10000幅误当成完整数据集。
if isinf(end_index),end_index=count;end
assert(start_index<=end_index && end_index<=count,'DatasetECC:IndexRange', ...
    'Requested range %d:%d is invalid for a dataset of %d images.',start_index,end_index,count);
last=min(end_index,start_index+max_images-1);
indices=start_index:last;
end
