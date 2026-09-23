function result=dataset_capacity_only(origin_I,h,w,prediction_mode)
% 只做真实编码和容量核算，不加密、写入载荷、置乱、提取或还原图像。
% 与2026-09-20四图块尺寸实验采用相同的精确写入位置计数规则。
if nargin<2,h=16;end
if nargin<3,w=h;end
if nargin<4,prediction_mode='entropy';end
validateattributes(origin_I,{'numeric'},{'2d','real','finite','integer','>=',0,'<=',255});
[H,W]=size(origin_I);
assert(mod(H,h)==0 && mod(W,w)==0,'DatasetECC:BlockSize','Image dimensions must be divisible by block size.');
row1=H/h;col1=W/w;timer=tic;
[E,x,~,pred_ref]=deviate(double(origin_I),prediction_mode);
[mapped,~,~,fold]=Transform_E(E,h,w);
assert(all(mapped(:)>=-127 & mapped(:)<=128),'DatasetECC:FoldRange','Folded residual out of range.');
[selected,r,~,p0_f,p0,p1,l0,opt,b0,ns,l_0,l_d,l_d_best,max_l,xts,modes]=select_block(mapped,h,w);
PFA=sum_PFA(selected,h,w);
[LSIb,SIb,~,ns_b,ld_b,l0_b,ecc,~]=block_in_support(opt,p0,r,h,w,row1,col1,b0,ns,l_0,l_d,l_d_best,max_l,p1,l0,p0_f,xts,selected,modes);
[opt_header,opt_codes,opt_info]=encode_opt_headers(opt,ecc,LSIb,h,w);
old_width=ceil(log2(h*w));
for i=1:row1
    for j=1:col1
        if ecc(i,j)==0
            SIb{i,j}=[opt_codes{i,j},SIb{i,j}(old_width+1:end)];
            LSIb(i,j)=numel(SIb{i,j});
        end
    end
end
active=ecc==0;
block_bits=sum(LSIb(active));
raw_slots=sum(8*opt(active)-LSIb(active));
original_ref_bits=pred_ref.reference_bits;
pred_ref.opt_header=opt_header;
[SIt,LSIt,~,fold_info,skipped_info]=block_in_support2(opt,PFA{end},h,w,row1,col1,raw_slots,ns_b,ld_b,l0_b,x,max_l,ecc,block_bits,pred_ref,fold,r);
assert(numel(SIt)==LSIt && max_l<16,'DatasetECC:GlobalHeader','Global header length is inconsistent.');
layout=global_aux_layout(LSIt,H,W,h);
% 必须按实际全局覆盖位置排除写入槽，不能用 raw_slots-LSIt 近似。
slots=0;
for bi=1:row1
    for bj=1:col1
        if ~active(bi,bj),continue;end
        len=LSIb(bi,bj);
        assert(len<=8*opt(bi,bj),'DatasetECC:BlockHeader','Header exceeds selected block capacity.');
        bytes=floor(len/8)+1:opt(bi,bj);
        xx=(bi-1)*h+floor((bytes-1)/w)+1;
        yy=(bj-1)*w+mod(bytes-1,w)+1;
        weights=8*ones(size(bytes));
        if mod(len,8)~=0,weights(1)=8-mod(len,8);end
        use=xx<layout.last_row | mod(xx-layout.last_row,h)~=0 | ...
            (xx==layout.last_row & yy<layout.last_col);
        slots=slots+sum(weights(use));
    end
end
payload=slots-layout.displaced_bits;
% 不将无法容纳辅助信息的情况伪装成0容量；由批处理入口单独记为失败。
assert(payload>=0 && payload==fix(payload),'DatasetECC:InsufficientCapacity','Insufficient slots for required displaced data.');
result=struct('payload_bits',payload,'ecc_bpp',payload/numel(origin_I), ...
    'raw_slots_bits',raw_slots,'global_overlap_bits',raw_slots-slots, ...
    'displaced_bits',layout.displaced_bits,'global_auxiliary_bits',LSIt, ...
    'block_header_bits',block_bits,'auxiliary_bits',block_bits+LSIt, ...
    'prediction_reference_bits',original_ref_bits,'fold_map_bits',fold_info.total_bits, ...
    'fold_pixels',nnz(fold),'skipped_blocks',nnz(ecc),'skipped_r_bits',skipped_info.bits, ...
    'opt_bits',opt_info.bits,'opt_method',opt_info.method,'capacity_seconds',toc(timer));
end
