function header = read_global_support(image,check_frequencies)
if nargin<2,check_frequencies=true;end
% 与 block_in_support2 对称的全局位流解析，供嵌入、提取及恢复共用。
% 同一位游标处理跨字节、跨行及 ecc 的稀疏位置/完整位图两种格式。
[H,W]=size(image);
bits=bytes_to_bits(image(H,W:-1:1)); cursor=1;
h=number(ceil(log2(H+1))); w=number(ceil(log2(W+1)));
assert(h>=1 && w>=1 && mod(H,h)==0 && mod(W,w)==0, ...
    'read_global_support:BlockSize','Invalid block dimensions.');
bits=bytes_to_bits(reshape(image(H:-h:1,W:-1:1).',1,[]));
rows=H/h; cols=W/w; count=rows*cols;
ecc=zeros(1,count); ecc_method='none';
if number(1)
    if number(1)
        ecc_method='sparse'; width=ceil(log2(count));
        skipped=number(width)+1;
        assert(skipped<=count,'read_global_support:Ecc','Invalid skipped block count.');
        indices=zeros(1,skipped);
        for k=1:skipped, indices(k)=number(width)+1; end
        assert(all(indices<=count) && all(diff(indices)>0), ...
            'read_global_support:Ecc','Invalid skipped block positions.');
        ecc(indices)=1;
    else
        ecc_method='bitmap'; ecc=take(count);
    end
end
max_l=number(4);
frequency_width=floor(log2(floor(log2(H*W+1))+1))+1;
bit_max=number(frequency_width);
assert(bit_max>=1,'read_global_support:Frequency','Invalid zero frequency width.');
protected_frequency=[];
frequencies=zeros(256,1); protected_frequency=[protected_frequency,cursor:cursor+bit_max-1]; frequencies(1)=number(bit_max);
other_width=number(frequency_width);
assert(other_width>=1,'read_global_support:Frequency','Invalid frequency width.');
for k=2:256, protected_frequency=[protected_frequency,cursor:cursor+other_width-1]; frequencies(k)=number(other_width); end
if check_frequencies,assert(sum(frequencies)==H*W,'read_global_support:Frequency','Frequency sum differs from image size.');end
field_width=ceil(log2(h*w/8+1));
tables=cell(1,3);
for t=1:3
    symbols=number(field_width);
    assert(symbols>0,'read_global_support:Huffman','Empty Huffman table.');
    lengths=zeros(1,symbols);
    for k=1:symbols, lengths(k)=number(field_width); end
    value_width=number(field_width);
    assert(all(lengths>0) && value_width>0, ...
        'read_global_support:Huffman','Invalid Huffman widths.');
    codes=cell(1,symbols); values=zeros(symbols,1);
    for k=1:symbols, codes{k}=char(take(lengths(k))+'0'); end
    for k=1:symbols, values(k)=number(value_width); end
    tables{t}=struct('codes',{codes},'values',values,'max_length',max(lengths),'count',symbols);
end
reference_length=number(14); reference_start=cursor; reference=take(reference_length);
layout=global_aux_layout(cursor-1,H,W,h);
header=struct('h',h,'w',w,'ecc',reshape(ecc,cols,rows).', ...
    'ecc_method',ecc_method,'max_l',max_l,'bit_max',bit_max, ...
    'frequencies',frequencies,'tables',{tables},'reference',reference,'layout',layout, ...
    'protected_frequency',protected_frequency,'reference_start',reference_start);

    function out=take(n)
        assert(cursor+n-1<=numel(bits),'read_global_support:Truncated','Truncated global section.');
        out=bits(cursor:cursor+n-1); cursor=cursor+n;
    end
    function value=number(n)
        value=take(n)*2.^(n-1:-1:0).';
    end
end

function bits=bytes_to_bits(bytes)
bits=reshape(rem(floor(double(bytes(:))./2.^(7:-1:0)),2).',1,[]);
end
