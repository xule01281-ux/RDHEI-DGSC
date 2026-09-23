function [out,used,info]=opt_header_codec(action,input,active,block_size)
% opt 编解码：00=定宽 opt-1；01=Paeth 预测残差 + Rice，随后保存 4 位 k。
% 相邻块按行优先解码；缺失/不可用邻居取 1。预测残差 d 映射为
% z=2*abs(d)-(d<0)，Rice 码由 floor(z/2^k) 个 0、一个 1 和 k 位余数组成。
% 总块数及可用块掩码来自原有全局头，无须保存本序列长度。
width=ceil(log2(block_size)); active=logical(active);
if strcmp(action,'encode')
    values=double(input); assert(isequal(size(values),size(active)));
    assert(all(values(active)>=1 & values(active)<=block_size & values(active)==fix(values(active))));
    residual=zeros(1,nnz(active)); raw=zeros(1,nnz(active)*width); q=0;
    for r=1:size(active,1)
        for c=1:size(active,2)
            if ~active(r,c),continue;end
            q=q+1; pred=predict(values,active,r,c);
            d=values(r,c)-pred; residual(q)=2*abs(d)-(d<0);
            raw((q-1)*width+(1:width))=bitget(values(r,c)-1,width:-1:1);
        end
    end
    costs=zeros(1,16);
    for k=0:15,costs(k+1)=sum(floor(residual/2^k)+1+k);end
    [payload,idx]=min(costs); k=idx-1;
    if payload+6<numel(raw)+2
        out=zeros(1,payload+6);out(1:6)=[0 1 bitget(k,4:-1:1)];p=7;
        for v=residual
            n=floor(v/2^k);p=p+n;out(p)=1;p=p+1;
            out(p:p+k-1)=bitget(rem(v,2^k),k:-1:1);p=p+k;
        end
        method='paeth_rice';
    else
        out=[0 0 raw];method='raw';k=0;
    end
    used=numel(out);info=struct('method',method,'k',k,'bits',used);
elseif strcmp(action,'decode')
    bits=double(input(:).');p=1;[method,p]=take(bits,p,2);
    assert(method<=1,'opt_header_codec:Method','Invalid method.');
    k=0;if method==1,[k,p]=take(bits,p,4);end
    out=zeros(size(active));
    for r=1:size(active,1)
        for c=1:size(active,2)
            if ~active(r,c),continue;end
            if method==0
                [v,p]=take(bits,p,width);out(r,c)=v+1;
            else
                q=0;
                while p<=numel(bits) && bits(p)==0,q=q+1;p=p+1;end
                assert(p<=numel(bits),'opt_header_codec:Truncated','Missing Rice terminator.');
                p=p+1;[rem_value,p]=take(bits,p,k);z=q*2^k+rem_value;
                d=ceil(z/2)*(1-2*mod(z,2));out(r,c)=predict(out,active,r,c)+d;
            end
            assert(out(r,c)>=1 && out(r,c)<=block_size,'opt_header_codec:Range','Invalid opt.');
        end
    end
    used=p-1;info=struct('method',method,'k',k,'bits',used);
else,error('opt_header_codec:Action','Unknown action.');end
end
function value=predict(v,mask,r,c)
a=1;b=1;cc=1;
if c>1 && mask(r,c-1),a=v(r,c-1);end
if r>1 && mask(r-1,c),b=v(r-1,c);end
if r>1 && c>1 && mask(r-1,c-1),cc=v(r-1,c-1);end
p=a+b-cc;delta=abs(p-[a b cc]);[~,i]=min(delta);neighbors=[a b cc];value=neighbors(i);
end
function [v,p]=take(bits,p,n)
assert(p+n-1<=numel(bits),'opt_header_codec:Truncated','Truncated field.');
v=bits(p:p+n-1)*2.^(n-1:-1:0).';p=p+n;
end
