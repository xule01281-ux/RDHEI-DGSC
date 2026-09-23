function [out, report] = prediction_reference_codec(action, data, image_size)
% 实际比特流格式（尺寸来自误差图，无需重复发送）：
% 2 bit 类型；普通模式: 分割点、4*2 bit 方向、2 bit GlobalPattern、
% 统计量、参考值。纯色模式: 2 bit 类型 + 8 bit 灰度。
% 梯度均值精确表示为整数差值总和/已知样本数；sigma 按 IEEE64 保存。
% 小块共用全局统计量只记录一次。参考值比较原样和差分 Rice 总长度。
    encoding=strcmp(action,'encode');
    assert(encoding || strcmp(action,'decode'),'prediction_reference:Action','Unknown action.');
    H=image_size(1); W=image_size(2); cursor=1;
    if encoding
        state=data; bits=false(1,0); put(state.mode,2);
    else
        assert(isvector(data) && all(data(:)==0 | data(:)==1), ...
            'prediction_reference:InvalidBits','Reference stream must contain bits.');
        bits=logical(data(:).'); state=struct('mode',take(2));
    end
    if state.mode==1
        if encoding, put(state.value,8); else, state.value=take(8); end
        report=struct('header_bits',2,'statistics_bits',0,'reference_value_bits',8, ...
            'reference_count',1,'reference_bits',10,'order',[]);
    else
        assert(state.mode==0,'prediction_reference:Version','Unsupported reference format.');
        widths=ceil(log2([H W]));
        if encoding
            put(state.split(1)-1,widths(1)); put(state.split(2)-1,widths(2));
            for k=1:4, put(state.dirs(k),2); end
            put(state.GlobalPattern,2);
        else
            state.split=[take(widths(1))+1,take(widths(2))+1];
            state.dirs=zeros(1,4);
            for k=1:4, state.dirs(k)=take(2); end
            state.GlobalPattern=take(2);
        end
        assert(all(state.split>=1 & state.split<[H W]) && state.GlobalPattern<=2, ...
            'prediction_reference:Geometry','Invalid split or pattern.');
        header_bits=12+sum(widths);
        sr=state.split(1); sc=state.split(2);
        block_sizes=[sr sc;sr W-sc;H-sr sc;H-sr W-sc];
        shared=[];
        if ~encoding, state.block_stats=zeros(4,5); end
        stat_start=cursor;
        if encoding, stat_start=numel(bits)+1; end
        for k=1:4
            dims=block_sizes(k,:);
            small=prod(dims)<4096;
            if small && ~isempty(shared)
                if ~encoding, state.block_stats(k,:)=shared; end
                continue;
            end
            if small, dims=[H W]; end
            counts=[dims(1)*(dims(2)-1),(dims(1)-1)*dims(2), ...
                    (dims(1)-1)*(dims(2)-1),(dims(1)-1)*(dims(2)-1)];
            row=zeros(1,5);
            for q=1:4
                width=ceil(log2(255*counts(q)+1));
                if encoding
                    gradient=state.block_stats(k,q);
                    numerator=round(gradient*counts(q));
                    assert(numerator/counts(q)==gradient, ...
                        'prediction_reference:GradientPrecision', ...
                        'Gradient cannot be represented exactly as an integer sum.');
                    put(numerator,width);
                else
                    row(q)=take(width)/counts(q);
                end
            end
            if encoding
                put(typecast(double(state.block_stats(k,5)),'uint64'),64);
                row=state.block_stats(k,:);
            else
                row(5)=typecast(take64(64),'double');
                assert(all(isfinite(row)) && all(row>=0), ...
                    'prediction_reference:Stats','Invalid prediction statistics.');
                state.block_stats(k,:)=row;
            end
            if small, shared=row; end
        end
        if encoding, statistics_bits=numel(bits)+1-stat_start;
        else, statistics_bits=cursor-stat_start; end
        [state.pos,state.order]=prediction_reference_layout([H W],state.split,state.dirs);
        count=numel(state.pos);
        value_start=cursor;
        if encoding
            values=double(state.val(:).');
            assert(numel(values)==count,'prediction_reference:Count','Invalid reference count.');
            value_start=numel(bits)+1;
            delta=diff(values); z=2*abs(delta)-(delta<0);
            lengths=zeros(1,8);
            for k=0:7, lengths(k+1)=12+sum(floor(z/2^k)+1+k); end
            [compressed,kidx]=min(lengths); rice_k=kidx-1;
            if count>0 && compressed<1+8*count
                put(1,1); put(rice_k,3); put(values(1),8);
                for zval=z
                    q=floor(zval/2^rice_k);
                    bits=[bits,false(1,q),true]; %#ok<AGROW>
                    put(mod(zval,2^rice_k),rice_k);
                end
            else
                put(0,1);
                for v=values, put(v,8); end
            end
        else
            state.val=zeros(count,1);
            compressed=take(1);
            if compressed
                assert(count>0,'prediction_reference:Count','Missing Rice samples.');
                rice_k=take(3); state.val(1)=take(8);
                for k=2:count
                    q=0;
                    while take(1)==0
                        q=q+1;
                        assert(q<=510,'prediction_reference:Rice','Invalid Rice quotient.');
                    end
                    z=q*2^rice_k+take(rice_k);
                    delta=ceil(z/2)*(1-2*mod(z,2));
                    state.val(k)=state.val(k-1)+delta;
                end
            else
                for k=1:count, state.val(k)=take(8); end
            end
            assert(all(state.val>=0 & state.val<=255), ...
                'prediction_reference:Value','Invalid reference pixel.');
        end
        if encoding, value_bits=numel(bits)+1-value_start;
        else, value_bits=cursor-value_start; end
        report=struct('header_bits',header_bits,'statistics_bits',statistics_bits, ...
            'reference_value_bits',value_bits,'reference_count',count, ...
            'reference_bits',header_bits+statistics_bits+value_bits,'order',state.order);
    end
    if encoding
        assert(report.reference_bits==numel(bits),'prediction_reference:Length','Incorrect bit count.');
        out=bits;
    else
        assert(cursor==numel(bits)+1,'prediction_reference:TrailingBits', ...
            'Reference stream has trailing bits.');
        out=state;
    end

    function put(value,width)
        assert(all(double(value)>=0) && (width==64 || double(value)<2^width), ...
            'prediction_reference:Overflow','Value exceeds allocated width.');
        if width>0, bits=[bits,logical(bitget(uint64(value),width:-1:1))]; end
    end
    function value=take(width)
        value=double(take64(width));
    end
    function value=take64(width)
        assert(cursor+width-1<=numel(bits),'prediction_reference:Truncated', ...
            'Reference stream is truncated.');
        value=uint64(0);
        for bit=bits(cursor:cursor+width-1)
            value=bitor(bitshift(value,1),uint64(bit));
        end
        cursor=cursor+width;
    end
end
