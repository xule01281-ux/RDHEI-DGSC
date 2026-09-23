function [out,used,info] = skipped_r_codec(action,data,ecc)
% 仅编码 ecc==1 块的排列，位置/数量复用全局 ecc，按块行优先。
% 无跳过块：0 bit；一个块：r-1 的两位；多个块：
% 0+原始两位值，或 1+两个压缩位平面，比较包含方法位的总长度。
inactive=reshape(logical(ecc).',1,[]); count=nnz(inactive);
method='none'; used=0;
if strcmp(action,'encode')
    assert(isequal(size(data),size(ecc)) && all(ismember(data(:),1:4)), ...
        'skipped_r_codec:Kinds','Expected one arrangement in 1..4 per block.');
    flat=reshape(double(data).',1,[]); values=flat(inactive)-1;
    raw=reshape([bitget(values,2);bitget(values,1)],1,[]); out=raw;
    if count>0, method='raw'; end
    if count>1
        upper=fold_map_codec('encode',logical(bitget(values,2)),[1 count]);
        lower=fold_map_codec('encode',logical(bitget(values,1)),[1 count]);
        if numel(upper)+numel(lower)<numel(raw)
            out=[1 upper lower]; method='bitplanes';
        else
            out=[0 raw];
        end
    end
    used=numel(out);
elseif strcmp(action,'decode')
    assert(isempty(data) || (isvector(data) && all(data(:)==0 | data(:)==1)), ...
        'skipped_r_codec:Bits','Expected a binary stream.');
    bits=double(data(:).'); values=[];
    if count>0
        method='raw';
        if count>1
            assert(~isempty(bits),'skipped_r_codec:Truncated','Missing arrangement method.');
            used=1;
        end
        if count>1 && bits(1)==1
            [upper,n]=fold_map_codec('decode',bits(2:end),[1 count]); used=used+n;
            [lower,n]=fold_map_codec('decode',bits(used+1:end),[1 count]); used=used+n;
            values=2*double(upper)+double(lower); method='bitplanes';
        else
            assert(numel(bits)>=used+2*count,'skipped_r_codec:Truncated','Truncated arrangements.');
            pairs=reshape(bits(used+(1:2*count)),2,[]);
            values=2*pairs(1,:)+pairs(2,:); used=used+2*count;
        end
    end
    flat=zeros(size(inactive)); flat(inactive)=values+1;
    out=reshape(flat,size(ecc,2),size(ecc,1)).';
else
    error('skipped_r_codec:Action','Unknown action.');
end
info=struct('count',count,'method',method,'raw_bits',2*count,'bits',used);
end
