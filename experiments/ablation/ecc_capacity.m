function [result,E,pred_bits]=ecc_capacity(I,cfg,upper,lower)
% Encode real block/global headers, then count the exact existing write slots.
% No encryption, payload insertion, permutation, extraction or recovery.
timer=tic; h=16; w=16; [H,W]=size(I); row1=H/h; col1=W/w;
pt=tic; [E,pred_ref,meta]=ecc_prediction(I,cfg,upper,lower); prediction_seconds=toc(pt);
[mapped,~,~,fold]=Transform_E(E,h,w);
assert(all(mapped(:)>=-127 & mapped(:)<=128),'Ablation:ResidualRange','Eight-bit folded residual range exceeded.');
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
active=ecc==0; block_bits=sum(LSIb(active));
raw_slots=sum(8*opt(active)-LSIb(active));
original_ref_bits=pred_ref.reference_bits; pred_bits=pred_ref.bits;
pred_ref.opt_header=opt_header;
[SIt,LSIt,~,fold_info,skipped_info]=block_in_support2(opt,PFA{end},h,w,row1,col1,raw_slots,ns_b,ld_b,l0_b,0,max_l,ecc,block_bits,pred_ref,fold,r);
assert(numel(SIt)==LSIt && max_l<16);
layout=global_aux_layout(LSIt,H,W,h);
% Reproduce the physical exclusion predicate in Embed_Data_Encrypt_Data.
slots=0;
for bi=1:row1
    for bj=1:col1
        if ~active(bi,bj), continue; end
        len=LSIb(bi,bj); assert(len<=8*opt(bi,bj));
        bytes=floor(len/8)+1:opt(bi,bj);
        x=(bi-1)*h+floor((bytes-1)/w)+1;
        y=(bj-1)*w+mod(bytes-1,w)+1;
        weights=8*ones(size(bytes));
        if mod(len,8)~=0, weights(1)=8-mod(len,8); end
        use=x<layout.last_row | mod(x-layout.last_row,h)~=0 | ...
            (x==layout.last_row & y<layout.last_col);
        slots=slots+sum(weights(use));
    end
end
payload=slots-layout.displaced_bits;
assert(payload>=0 && payload==fix(payload));
result=struct('payload_bits',payload,'ecc_bpp',payload/numel(I), ...
    'raw_slots_bits',raw_slots,'global_overlap_bits',raw_slots-slots, ...
    'displaced_bits',layout.displaced_bits,'global_auxiliary_bits',LSIt, ...
    'block_header_bits',block_bits,'prediction_reference_bits',original_ref_bits, ...
    'fold_map_bits',fold_info.total_bits,'fold_pixels',nnz(fold), ...
    'skipped_blocks',nnz(ecc),'skipped_r_bits',skipped_info.bits, ...
    'opt_bits',opt_info.bits,'opt_method',opt_info.method, ...
    'prediction_seconds',prediction_seconds,'capacity_seconds',toc(timer), ...
    'prediction',meta);
end
