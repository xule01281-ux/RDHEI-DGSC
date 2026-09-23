function [pos, order, counts, boundary] = prediction_reference_layout(image_size, split, dirs)
% 根据几何关系选择 24 种整块恢复顺序中参考像素最少的一种。
% 不读取像素或误差；两端可自行推导 pos/order，无需发送位置表。
% 这里的最少限定于原有逐块扫描及完整预测邻域，不是任意解码算法的下界。
    H = image_size(1); W = image_size(2);
    sr = split(1); sc = split(2);
    labels = {'TL','TR','BL','BR'};
    if ~iscell(dirs), dirs = labels(double(dirs)+1); end
    ranges = {1:sr,1:sc; 1:sr,sc+1:W; sr+1:H,1:sc; sr+1:H,sc+1:W};
    owner = zeros(H,W);
    for k=1:4, owner(ranges{k,1},ranges{k,2})=k; end
    needed = cell(1,4);
    edge_src=[]; edge_dst=[];
    for k=1:4
        rr=ranges{k,1}; cc=ranges{k,2};
        dr=1; dc=1;
        if any(strcmp(dirs{k},{'BL','BR'})), rr=fliplr(rr); dr=-1; end
        if any(strcmp(dirs{k},{'TR','BR'})), cc=fliplr(cc); dc=-1; end
        [C,R]=meshgrid(cc,rr);
        [J,I]=meshgrid(1:numel(cc),1:numel(rr));
        rank=zeros(H,W);
        rank(sub2ind([H W],R,C))=(I-1)*numel(cc)+J;
        % 与核心邻域顺序一致: xh,x1,xv,xmd,x2,x5,x4,x3,xsd,x6。
        offsets=[0 -dc;0 -2*dc;-dr 0;-dr -dc;-dr -2*dc; ...
                 -2*dr 0;-2*dr -dc;-2*dr -2*dc;-dr dc;-2*dr dc];
        mask=false(H,W);
        for q=1:10
            use=I>1 & J>1;
            if q==4, use=use | (I==1 & J==1); end
            if q==1, use=use | (I==1 & J>1); end
            if q==3, use=use | (I>1 & J==1); end
            r=R(use); c=C(use); r=r(:); c=c(:);
            src=sub2ind([H W],r,c);
            dst=sub2ind([H W],min(H,max(1,r+offsets(q,1))), ...
                                   min(W,max(1,c+offsets(q,2))));
            % 起始行/列满足 E(target)=I(source)-I(target)。
            % 这些边形成的连通分量只需一个灰度锚点。
            linear_boundary=(I(use)==1 | J(use)==1);
            edge_src=[edge_src;dst(linear_boundary)]; %#ok<AGROW>
            edge_dst=[edge_dst;src(linear_boundary)]; %#ok<AGROW>
            % 块内前序像素必定已恢复；保留跨块及自身依赖。
            need=owner(dst)~=k | rank(dst)>=rank(src);
            mask(dst(need))=true;
        end
        needed{k}=find(mask);
    end
    [nodes,~,mapped]=unique([edge_src;edge_dst]);
    nedge=numel(edge_src);
    u=mapped(1:nedge); v=mapped(nedge+1:end);
    groups=conncomp(graph(u,v,[],numel(nodes))).';
    roots=accumarray(groups,nodes,[],@min);
    component=zeros(H*W,1); component(nodes)=groups;
    boundary=struct('nodes',nodes,'u',u,'v',v,'target',edge_dst, ...
        'groups',groups,'roots',roots);
    orders=sortrows(perms(1:4));
    counts=zeros(24,1); best_count=inf; pos=[]; order=1:4;
    for t=1:24
        done=false(1,4); seed=false(H,W);
        for k=orders(t,:)
            candidates=needed{k};
            seed(candidates(~done(owner(candidates))))=true;
            done(k)=true;
        end
        raw=find(seed); components=component(raw);
        % 等价边界像素用一个锚点替代；不属于这些边的依赖仍逐个保存。
        anchors=unique([raw(components==0);roots(unique(components(components>0)))]);
        counts(t)=numel(anchors);
        if counts(t)<best_count
            best_count=counts(t); pos=anchors; order=orders(t,:);
        end
    end
end
