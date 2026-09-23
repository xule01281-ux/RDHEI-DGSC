function test_fold_map_codec()
% 验证位置顺序、稀疏/稠密回退、尾随参考区、旧格式及损坏输入。
rng(19,'twister');
masks={false(1),true(1),false(17,31),true(17,31)};
sparse=false(16,32); sparse(1,1)=true; sparse(8,32)=true; sparse(16,32)=true;
masks=[masks,{sparse,~sparse,mod(reshape(1:512,16,32),2)==0,rand(129,131)<.003}];
last=false(7,13); last(end,end)=true; masks{end+1}=last;
adjacent=false(16,32); adjacent(1,1:8)=true; masks{end+1}=adjacent;
prediction_bits=[0 1 bitget(100,8:-1:1)];
for index=1:numel(masks)
    mask=masks{index};
    [bits,used,info]=fold_map_codec('encode',mask,size(mask));
    [decoded,consumed,decoded_info]=fold_map_codec('decode',[bits prediction_bits],size(mask));
    assert(isequal(mask,decoded) && consumed==used && used==numel(bits));
    assert(info.ones==nnz(mask) && isequal(info,decoded_info));
    assert(used<=numel(mask)+2);
    % 故意给错 legacy_mask：新格式必须只使用码流中的图。
    [ref,map,report]=unpack_fold_reference([1 0 bits prediction_bits],size(mask),~mask);
    assert(isequal(ref,prediction_bits) && isequal(map,mask) && report.from_stream);
    assert(report.total_bits==used+2);
    must_fail(@() fold_map_codec('decode',bits(1:end-1),size(mask)), ...
        {'fold_map_codec:Truncated','fold_map_codec:Bits'});
    fprintf('FOLD_CODEC case=%d ones=%d method=%s bits=%d exact=1\n', ...
        index,info.ones,info.method,used);
end
% 固定向量：行优先位置 1、256、512，间隔 0、254、255，Rice k=7。
[bits,~,info]=fold_map_codec('encode',sparse,size(sparse));
expected=[1 1 1 bitget(3,10:-1:1) bitget(7,4:-1:1), ...
    1 zeros(1,7),0 1 bitget(126,7:-1:1),0 1 ones(1,7)];
assert(strcmp(info.method,'sparse_rice') && info.k==7 && isequal(bits,expected));
[~,~,info]=fold_map_codec('encode',masks{7},size(masks{7}));
assert(strcmp(info.method,'raw'));
[~,~,info]=fold_map_codec('encode',adjacent,size(adjacent));
assert(strcmp(info.method,'sparse_rice') && info.k==0);
[ref,map,report]=unpack_fold_reference(prediction_bits,size(sparse),sparse);
assert(isequal(ref,prediction_bits) && isequal(map,sparse) && ~report.from_stream);
must_fail(@() unpack_fold_reference(prediction_bits,size(sparse),[]), ...
    {'unpack_fold_reference:LegacyMask'});
must_fail(@() unpack_fold_reference([1 1],size(sparse),[]), ...
    {'unpack_fold_reference:Ecc'});
must_fail(@() unpack_fold_reference([1 0 0 0],size(sparse),[]), ...
    {'unpack_fold_reference:Prediction'});
must_fail(@() fold_map_codec('decode',[1 1 1 zeros(1,10) zeros(1,4)],size(sparse)), ...
    {'fold_map_codec:Header'});
must_fail(@() fold_map_codec('decode',[1 1 1 bitget(1,10:-1:1) ones(1,4)],size(sparse)), ...
    {'fold_map_codec:Header'});
% k=9、q=1、rem=0 给出越界位置 513，应在解码时拒绝。
must_fail(@() fold_map_codec('decode',[1 1 1 bitget(1,10:-1:1) ...
    bitget(9,4:-1:1) 0 1 zeros(1,9)],size(sparse)),{'fold_map_codec:Position'});

% 用真实 block_in_support2 核对整段长度和新增开销，旧格式仍可生成。
pred_ref=struct('bits',prediction_bits,'reference_bits',numel(prediction_bits), ...
    'opt_header',[0 0]);
legacy_ref=pred_ref; legacy_ref.bits=[pred_ref.opt_header,prediction_bits];
legacy_ref.reference_bits=numel(legacy_ref.bits);
freq=[(0:255).',2*ones(256,1)];
[old_stream,old_length]=block_in_support2(256,freq,16,16,1,2,4096, ...
    [0 0],[0 0],[0 0],0,1,[0 0],0,legacy_ref);
[stream,len,~,info]=block_in_support2(256,freq,16,16,1,2,4096, ...
    [0 0],[0 0],[0 0],0,1,[0 0],0,pred_ref,sparse);
assert(old_length==numel(old_stream) && len==numel(stream));
assert(len-old_length==info.total_bits && info.total_bits==numel(expected)+2);
section=[pred_ref.opt_header,1 0,expected,prediction_bits];
assert(isequal(stream(end-numel(section)+1:end),section));
fprintf('PASS: fold-map codec, malformed input, old format and global bit accounting.\n');
end

function must_fail(action,identifiers)
try
    action();
catch ME
    assert(any(strcmp(ME.identifier,identifiers)), ...
        'test_fold_map_codec:UnexpectedError','Unexpected error: %s',ME.identifier);
    return;
end
error('test_fold_map_codec:AcceptedInvalidInput','Invalid or truncated stream was accepted.');
end
