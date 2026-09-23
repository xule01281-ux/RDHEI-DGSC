function [prediction_bits,folded_mask,info,r_map,r_info] = unpack_fold_reference(bits,image_size,legacy_mask,ecc)
% 输入已去掉 opt 方法头的参考区。
% 11 格式：[11, 压缩折叠图, 不可编码块排列, 原预测器参考区]。
% 兼容此前 10 格式（只有折叠图）及原始 00/01 预测参考格式。
% 10/11 使用预测参考类型的保留值，旧 00/01 码流不会被误判为扩展格式。
% 旧格式仅为历史对照保留外传位置图；新格式完全忽略 legacy_mask。
if nargin<3, legacy_mask=[]; end
assert(isvector(bits) && numel(bits)>=2 && all(bits(:)==0 | bits(:)==1), ...
    'unpack_fold_reference:Bits','Invalid reference section.');
bits=double(bits(:).'); kind=bits(1)*2+bits(2);
r_map=[]; r_info=struct('from_stream',false,'count',0,'method','legacy_external','raw_bits',0,'bits',0);
if kind>=2
    if kind==3
        assert(nargin>=4,'unpack_fold_reference:Ecc','New reference format requires decoded ecc.');
    end
    [folded_mask,used,info]=fold_map_codec('decode',bits(3:end),image_size);
    prediction_bits=bits(used+3:end);
    info.from_stream=true; info.framing_bits=2;
    info.total_bits=used+2;
    if kind==3
        [r_map,r_used,r_info]=skipped_r_codec('decode',prediction_bits,ecc);
        prediction_bits=prediction_bits(r_used+1:end);
        r_info.from_stream=true;
    end
else
    assert(kind<=1,'unpack_fold_reference:Version','Unknown reference format.');
    assert(isequal(size(legacy_mask),image_size) && all(legacy_mask(:)==0 | legacy_mask(:)==1), ...
        'unpack_fold_reference:LegacyMask','Legacy format requires an external fold map.');
    folded_mask=logical(legacy_mask); prediction_bits=bits;
    info=struct('method','legacy_external','k',0,'ones',nnz(folded_mask), ...
        'raw_bits',prod(image_size),'bits',0,'from_stream',false, ...
        'framing_bits',0,'total_bits',0);
end
assert(numel(prediction_bits)>=10 && prediction_bits(1)*2+prediction_bits(2)<=1, ...
    'unpack_fold_reference:Prediction','Missing or invalid prediction reference after fold map.');
end
