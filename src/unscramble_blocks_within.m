function restored = unscramble_blocks_within(scrambled, info)
% 逆序恢复：先块内像素，再块间顺序。info 由 scramble_blocks_within 返回。
assert(isequal(size(scrambled),info.image_size), ...
    'unscramble_blocks_within:ImageSize', '图像尺寸与置乱参数不一致。');
h = info.block_size(1); w = info.block_size(2);
nr = size(scrambled,1)/h; nc = size(scrambled,2)/w;
assert(isequal(sort(info.key_inter(:).'),1:nr*nc) && ...
       isequal(sort(info.key_intra(:).'),1:h*w), ...
    'unscramble_blocks_within:Permutation', '置乱映射不是有效排列。');
blocks = mat2cell(scrambled,repmat(h,1,nr),repmat(w,1,nc));
blocks = blocks(:);
for k = 1:numel(blocks)
    values = blocks{k}(:);
    original = zeros(size(values),'like',values);
    original(info.key_intra) = values;
    blocks{k} = reshape(original,h,w);
end
originalBlocks = cell(size(blocks));
originalBlocks(info.key_inter) = blocks;
restored = cell2mat(reshape(originalBlocks,nr,nc));
end
