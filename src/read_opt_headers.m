function [opt_map,opt_width,header_used]=read_opt_headers(image,header,active,h,w)
% 先按行优先从各块首部读出 opt 码字，再还原相邻块预测残差。
% 输出 opt_width 供后续定位 r/b0；图像恢复可在此预扫描后逆序处理各块。
method=header(1)*2+header(2);assert(method<=1);
header_used=2;k=0;
if method==1
    assert(numel(header)>=6);k=header(3:6)*[8;4;2;1];header_used=6;
end
width=ceil(log2(h*w));codes=cell(1,nnz(active));opt_width=zeros(size(active));idx=0;
for r=1:size(active,1)
    for c=1:size(active,2)
        if ~active(r,c),continue;end
        block=image((r-1)*h+(1:h),(c-1)*w+(1:w));
        vals=reshape(block.',[],1);
        bits=reshape(rem(floor(vals./2.^(7:-1:0)),2).',1,[]);
        if method==0,n=width;
        else
            stop=find(bits,1);
            assert(~isempty(stop),'read_opt_headers:Truncated','No Rice terminator.');
            n=stop+k;assert(n<=numel(bits));
        end
        idx=idx+1;codes{idx}=bits(1:n);opt_width(r,c)=n;
    end
end
[opt_map,used]=opt_header_codec('decode',[header(1:header_used),codes{:}],active,h*w);
assert(used==header_used+sum(opt_width,'all'));
end
