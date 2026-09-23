function [header,codes,info]=encode_opt_headers(opt,ecc,LSIb,h,w)
% 编码完整 opt 网格后拆成全局方法头与每块码字，码字仍放在各自块头。
% 原块容量筛选 ecc 不变；任一变长码字导致块头超出 8*opt 时，整图回退定宽。
active=ecc==0;width=ceil(log2(h*w));
[stream,~,info]=opt_header_codec('encode',opt,active,h*w);
method=stream(1)*2+stream(2);count=2;if method==1,count=6;end
header=stream(1:count);codes=cell(size(opt));p=count+1;
for r=1:size(opt,1)
    for c=1:size(opt,2)
        if ~active(r,c),continue;end
        start=p;
        if method==0,p=p+width;
        else
            while stream(p)==0,p=p+1;end
            p=p+1+info.k;
        end
        codes{r,c}=stream(start:p-1);
    end
end
lens=cellfun(@numel,codes);
if any(LSIb(active)-width+lens(active)>8*opt(active))
    header=[0 0];info.method='raw';info.k=0;
    for r=1:size(opt,1)
        for c=1:size(opt,2)
            if active(r,c),codes{r,c}=bitget(opt(r,c)-1,width:-1:1);end
        end
    end
end
info.bits=numel(header)+sum(cellfun(@numel,codes),'all');
end
