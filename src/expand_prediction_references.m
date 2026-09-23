function [positions, values] = expand_prediction_references(error_img, state)
% 用起始行/列中已有的误差关系传播锚点，生成核心扫描需要的参考值。
% 每条边: I(v)=I(u)-E(target)。正反两个方向都可精确传播。
    [~,~,~,b]=prediction_reference_layout(size(error_img),state.split,state.dirs);
    n=numel(b.nodes); adjacent=cell(n,1); changes=cell(n,1);
    for k=1:numel(b.u)
        u=b.u(k); v=b.v(k); e=double(error_img(b.target(k)));
        adjacent{u}(end+1)=v; changes{u}(end+1)=-e;
        adjacent{v}(end+1)=u; changes{v}(end+1)=e;
    end
    known=nan(n,1);
    [member,idx]=ismember(state.pos,b.nodes);
    known(idx(member))=state.val(member);
    queue=zeros(n,1); tail=nnz(member); head=1;
    queue(1:tail)=idx(member);
    while head<=tail
        u=queue(head); head=head+1;
        for k=1:numel(adjacent{u})
            v=adjacent{u}(k); value=known(u)+changes{u}(k);
            if isnan(known(v))
                known(v)=value; tail=tail+1; queue(tail)=v;
            else
                assert(known(v)==value,'prediction_reference:BoundaryConflict', ...
                    'Residuals disagree with the boundary references.');
            end
        end
    end
    positions=[state.pos(~member);b.nodes(isfinite(known))];
    values=[state.val(~member);known(isfinite(known))];
    assert(all(values>=0 & values<=255),'prediction_reference:BoundaryRange', ...
        'Boundary pixels are outside the 8-bit range.');
end
