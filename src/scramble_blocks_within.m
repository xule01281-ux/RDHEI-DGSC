function [scrambled, info] = scramble_blocks_within(img, blockSize, seed)
% 块间置乱后，再对每块的像素置乱；保持像素值和数据类型不变。
% 与原 main.m 的 rng(123) + 两次 randperm 使用相同的排列规则。
validateattributes(img, {'numeric','logical'}, {'2d','nonempty'}, mfilename, 'img');
validateattributes(blockSize, {'numeric'}, {'vector','numel',2,'integer','positive'});
validateattributes(seed, {'numeric'}, {'scalar','integer','nonnegative','<=',2^32-1});
[H,W] = size(img);
h = blockSize(1); w = blockSize(2);
assert(mod(H,h)==0 && mod(W,w)==0, ...
    'scramble_blocks_within:BlockSize', '图像尺寸必须能被块尺寸整除。');
nr = H/h; nc = W/w;
stream = RandStream('mt19937ar','Seed',seed);
key_inter = randperm(stream,nr*nc);
key_intra = randperm(stream,h*w);
blocks = mat2cell(img,repmat(h,1,nr),repmat(w,1,nc));
blocks = blocks(:);
blocks = blocks(key_inter);
for k = 1:numel(blocks)
    values = blocks{k}(:);
    blocks{k} = reshape(values(key_intra),h,w);
end
scrambled = cell2mat(reshape(blocks,nr,nc));
info = struct('block_size',[h,w], 'image_size',[H,W], ...
    'seed',seed, 'key_inter',key_inter, 'key_intra',key_intra);
end
