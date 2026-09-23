function [out,used,info] = fold_map_codec(action,data,image_size)
% 残差 +/-128 折叠位置图，按图像行优先展开，位序为 MSB first。
% 00: 全零；01: 全一；10: 原始 N 位；11: 少数值位置间隔的 Rice 码。
% 稀疏格式 = [11, 少数值(1), 个数(ceil(log2(N+1))), k, 间隔码]。
% k 位宽由 N 推导；间隔 = 当前位置 - 上一位置 - 1，首个上一位置为 0。
% 解码返回 used，允许后接预测器参考比特，不依赖发送端的索引或个数。
validateattributes(image_size,{'numeric'},{'vector','numel',2,'integer','positive','finite'});
image_size=double(image_size(:).'); N=prod(image_size);
count_width=ceil(log2(N+1)); max_k=ceil(log2(N));
k_width=max(1,ceil(log2(max_k+1)));
k=0;
if strcmp(action,'encode')
    assert(isequal(size(data),image_size) && all(data(:)==0 | data(:)==1), ...
        'fold_map_codec:Mask','Expected a binary image-sized fold map.');
    flat=reshape(logical(data).',1,[]); ones_count=nnz(flat);
    if ones_count==0
        out=[0 0]; method='all_zero';
    elseif ones_count==N
        out=[0 1]; method='all_one';
    else
        minority=ones_count<=N/2;
        positions=find(flat==minority);
        gaps=diff([0 positions])-1;
        costs=zeros(1,max_k+1);
        for candidate=0:max_k
            costs(candidate+1)=sum(floor(gaps/2^candidate)+1+candidate);
        end
        [payload_bits,best]=min(costs); k=best-1;
        prefix=[1 1 double(minority) bitget(numel(positions),count_width:-1:1) ...
            bitget(k,k_width:-1:1)];
        if numel(prefix)+payload_bits < N+2
            out=zeros(1,numel(prefix)+payload_bits); out(1:numel(prefix))=prefix;
            cursor=numel(prefix)+1;
            for gap=gaps
                cursor=cursor+floor(gap/2^k); out(cursor)=1; cursor=cursor+1;
                out(cursor:cursor+k-1)=bitget(mod(gap,2^k),k:-1:1);
                cursor=cursor+k;
            end
            assert(cursor==numel(out)+1,'fold_map_codec:Length','Encoded length mismatch.');
            method='sparse_rice';
        else
            out=[1 0 double(flat)]; method='raw'; k=0;
        end
    end
    used=numel(out);
elseif strcmp(action,'decode')
    assert(isvector(data) && all(data(:)==0 | data(:)==1), ...
        'fold_map_codec:Bits','Expected a binary stream.');
    bits=double(data(:).'); cursor=1;
    [mode,cursor]=take(bits,cursor,2);
    switch mode
        case 0
            flat=false(1,N); method='all_zero';
        case 1
            flat=true(1,N); method='all_one';
        case 2
            assert(cursor+N-1<=numel(bits),'fold_map_codec:Truncated','Truncated raw map.');
            flat=logical(bits(cursor:cursor+N-1)); cursor=cursor+N; method='raw';
        case 3
            [minority,cursor]=take(bits,cursor,1);
            [count,cursor]=take(bits,cursor,count_width);
            [k,cursor]=take(bits,cursor,k_width);
            assert(count>=1 && count<=floor(N/2) && k<=max_k, ...
                'fold_map_codec:Header','Invalid sparse-map count or Rice parameter.');
            flat=repmat(~logical(minority),1,N); position=0;
            for index=1:count
                q=0;
                while cursor<=numel(bits) && bits(cursor)==0
                    q=q+1; cursor=cursor+1;
                    assert(q*2^k < N-position,'fold_map_codec:Position','Rice gap exceeds image.');
                end
                assert(cursor<=numel(bits),'fold_map_codec:Truncated','Missing Rice terminator.');
                cursor=cursor+1;
                [remainder,cursor]=take(bits,cursor,k);
                position=position+q*2^k+remainder+1;
                assert(position<=N,'fold_map_codec:Position','Fold position exceeds image.');
                flat(position)=logical(minority);
            end
            method='sparse_rice';
    end
    out=reshape(flat,image_size(2),image_size(1)).';
    ones_count=nnz(out); used=cursor-1;
else
    error('fold_map_codec:Action','Unknown action.');
end
info=struct('method',method,'k',k,'ones',ones_count,'raw_bits',N,'bits',used);
end

function [value,cursor]=take(bits,cursor,width)
assert(cursor+width-1<=numel(bits),'fold_map_codec:Truncated','Truncated map field.');
value=bits(cursor:cursor+width-1)*2.^(width-1:-1:0).'; cursor=cursor+width;
end
