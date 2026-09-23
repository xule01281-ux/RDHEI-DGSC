function test_opt_header_codec()
rng(3,'twister');
for mode=1:6
    dims=[5 7];active=true(dims);
    switch mode
        case 1,values=ones(dims);
        case 2,values=256*ones(dims);
        case 3,values=randi(256,dims);
        case 4,values=repmat([1 256 1 256 1 256 1],5,1);
        case 5,values=randi(256,dims);active=rand(dims)>.4;
        case 6,values=ones(dims);active(:)=false;
    end
    [bits,~,~]=opt_header_codec('encode',values,active,256);
    [decoded,used]=opt_header_codec('decode',[bits 1 0 1],active,256);
    assert(used==numel(bits) && isequal(decoded(active),values(active)));
    [header,codes,info]=encode_opt_headers(values,~active,8*ones(dims),16,16);
    fake=zeros(dims.*16);
    for r=1:dims(1)
        for c=1:dims(2)
            if ~active(r,c),continue;end
            code=codes{r,c};padded=[code,zeros(1,8*ceil(numel(code)/8)-numel(code))];
            bytes=reshape(padded,8,[]).'*2.^(7:-1:0).';
            idx=(r-1)*16+1+(c-1)*16*size(fake,1)+(0:numel(bytes)-1)*size(fake,1);
            % Local code is at most 12 bits with these chosen test cases.
            assert(numel(bytes)<=16);fake(idx)=bytes;
        end
    end
    [decoded,widths,used]=read_opt_headers(fake,[header 1 1],active,16,16);
    assert(used==numel(header) && isequal(decoded(active),values(active)));
    assert(isequal(widths,cellfun(@numel,codes)));
    assert(info.bits==numel(header)+sum(widths,'all'));
    fprintf('OPT_CODEC case=%d method=%s bits=%d exact=1\n',mode,info.method,info.bits);
end
try
    opt_header_codec('decode',[0 1 0],true(1),256);
    error('test:MissingTruncation','Truncated stream accepted.');
catch ME
    assert(strcmp(ME.identifier,'opt_header_codec:Truncated'));
end
end
