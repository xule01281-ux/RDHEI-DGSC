function cost=estimate_prediction_bits(E)
% 估计候选预测误差的压缩位数，不执行 rANS 或实际嵌入。
% E 的符号为“预测值-原值”，先与 Transform_E/select_block 做相同的映射。
% 每个位平面横向 8 位组字节，累计 -sum(count*log2(count/N))。
% 仅是压缩成本代理，不包含最终分段、截断位置、码表及参考像素开销。
E(E>128)=E(E>128)-128; E(E<-127)=E(E<-127)+128;
v=2*abs(E)-(E>0);
cost=0;
for plane=8:-1:1
    bits=double(bitget(v,plane));
    % Pack adjacent horizontal bits. Tail pixels use binary entropy.
    n=8*floor(size(bits,2)/8);
    groups=reshape(bits(:,1:n).',8,[]);
    bytes=(2.^(7:-1:0))*groups;
    counts=histcounts(bytes,-0.5:1:255.5);
    counts=counts(counts>0);
    cost=cost-sum(counts.*log2(counts/sum(counts)));
    tail=bits(:,n+1:end);
    if ~isempty(tail)
        counts=[nnz(tail),numel(tail)-nnz(tail)];counts=counts(counts>0);
        cost=cost-sum(counts.*log2(counts/sum(counts)));
    end
end
end
