
function packet = retest_prepare(origin_I,D,Image_key,Data_key,ref_x,ref_y,h,w,prediction_mode,crypto)
% 主链路默认用估计编码位数选预测方向，完成选向后只执行一次 rANS/嵌入。原图像的加密和嵌入：
% 可选 'sse' 仅用于预测器对照；两种选择都使用下面的新 opt 辅助信息格式。
if nargin<9, prediction_mode='entropy'; end
prediction_mode=validatestring(prediction_mode,{'entropy','sse'});
% 函数说明：将原始图像origin_I加密并嵌入数据
% 输入：origin_I（原始图像）,D（要嵌入的数据）,Image_key,Data_key（密钥）,ref_x,ref_y（参考像素的行列数）
% 输出：encrypt_I（加密图像）,stego_I（加密标记图像）,emD（嵌入的数据）
% 生成密钥和IV (密钥和IV应该在加密和解密之间保持一致)
% Version 2: actual credentials are returned explicitly. Historical numeric
% Image_key/Data_key arguments are compatibility placeholders, not AES keys.
if nargin<10 || isempty(crypto),crypto=crypto_context();end
key=crypto.image_key;iv=crypto.image_iv;
Data_key=struct('key',crypto.data_key,'iv',crypto.data_iv);

tic
%% 计算origin_I的预测值
%%[origin_PV_I1] = Predictor_Value(origin_I,ref_x,ref_y); 
%[origin_PV_I2,x] = Predictor_Value2(origin_I,ref_x,ref_y); %%x参考像素
[row,col]=size(origin_I);
row1=row/h;
col1=col/w;
emD=0;
emD1=0;
tic
%% 计算origin_PV_I的预测误差
%%[origin_E_I1] = deviate(origin_I,origin_PV_I1);
forward_timer=tic;
[origin_E_I,x,prediction_recovered,pred_ref] = deviate(origin_I,prediction_mode);
fprintf('第一段操作用时: %.4f 秒\n', toc);
%%[test_value1] = test_perdictor(origin_I,origin_E_I1) ;比较而已
%%[test_value2] = test_perdictor(origin_I,origin_E_I2) ;
%%对origin_PV_I的预测误差符号进行处理
[origin_D_I,n,~,trandot1] = Transform_E(origin_E_I,h,w);
% trandot1 是逐像素折叠位置图；第三输出是已弃用的块符号标记，直接忽略。
[select_blocked,r,select_blocked1,p0_f,p0,p1,l0,opt,b0,ns,l_0,l_d,l_d_best,max_l,xts,mode_flag] = select_block(origin_D_I,h,w);%%可嵌入图像select_blocked，快类型r
%%PFA进行统计，并进行编码
[PFA] = sum_PFA(select_blocked,h,w);
%%进行一个实研
[z1]=test_PFA(PFA);
fprintf('第一段操作用时: %.4f 秒\n', toc);
%%
%%进行rANS编码
   %fprintf('运行时间为: %.4f 秒\n',toc);
   %[opt,lxf,xf,row1,col1,xtf] = rANS_encode(PFA,select_blocked,h,w,z1,p0_f,p0,p1,l0,opt1);
%%进行块内辅助信息编码support
    [LSIb,SIb,s_LSIb,ns_b,l_d_best_b,l_0_l_b, ecc,inforamtion_numn] = block_in_support(opt,p0,r,h,w,row1,col1,b0,ns,l_0,l_d,l_d_best,max_l,p1,l0,p0_f,xts,select_blocked,mode_flag);  
    % block_in_support 先生成定宽 opt，随后只替换块头的 opt 部分：
    % SIb = [opt 码字, r, b0, ns/各段辅助信息与状态]。
    % Rice 参数按整幅图选择；若无净节省或任一块放不下，则回退到定宽。
    [opt_header,opt_codes,opt_info]=encode_opt_headers(opt,ecc,LSIb,h,w);
    opt_width=cellfun(@numel,opt_codes);
    old_opt_width=ceil(log2(h*w));
    for oi=1:row1
        for oj=1:col1
            if ecc(oi,oj)==0
                SIb{oi,oj}=[opt_codes{oi,oj},SIb{oi,oj}(old_opt_width+1:end)];
                LSIb(oi,oj)=numel(SIb{oi,oj});
            end
        end
    end
    % 重新计算块内开销，后续容量必须使用实际码字长度。
    s_LSIb=sum(8*opt(ecc==0)-LSIb(ecc==0));
    inforamtion_numn=sum(LSIb(ecc==0));
    % block_in_support2 压缩并加入逐像素折叠图；所有新增比特计入 LSIt。
    % 全局参考区 = [opt 方法头, 11, 折叠图, 不可编码块排列, 原预测器辅助信息]。
    % 外层仍用 14 位长度字段；各块 opt 码字留在块头。
    original_pred_ref=pred_ref;
    pred_ref.opt_header=opt_header;
    [SIt,LSIt,bit_max,fold_info,skipped_r_info] = block_in_support2(opt,PFA{end},h,w,row1,col1,s_LSIb,ns_b,l_d_best_b,l_0_l_b,x,max_l, ecc,inforamtion_numn,pred_ref,trandot1,r);
   %fprintf('运行时间为: %.4f 秒\n',toc);
     fprintf('第一段操作用时: %.4f 秒\n', toc);
%%[row1,col1] = rANS_encode1(PFA,select_blocked,h,w,z1,origin_D_I,r);
%%图像进行修改并嵌入信息后加密
% Fill unused capacity with encrypted zero padding; keep the true payload
% length in the external public header. Historical full-capacity calls are
% unchanged, and sender-side assertions compare the complete padded stream.
requested_payload_bits=numel(D);
D=reshape(D,1,[]);
if numel(D)<8*numel(origin_I),D=[D,zeros(1,8*numel(origin_I)-numel(D))];end
[image_encrypt_I,AI_sum_num,AI_sum,image_test,image_encrypt_I1,emD,scrambleMap,emD1] = Embed_Data_Encrypt_Data(select_blocked,Image_key,D,Data_key,h,w,row1,col1,LSIb,SIb,SIt,LSIt,ecc,bit_max,PFA{end},p0,r,key,iv,opt,opt_width);
%[image_encrypt_I,image_test] = Copy_of_Embed_Data_Encrypt_Data(select_blocked,Image_key,D,Data_key,h,w,row1,col1,LSIb,SIb,SIt,LSIt,ecc,bit_max,PFA{end},p0,r,key,iv);
fprintf('第一段操作用时: %.4f 秒\n', toc);
asa=1;
%% 块间 + 块内置乱（从 main.m 移至原第 48 行之后）
legacy_before_protection=image_encrypt_I;
[image_encrypt_I,protected_layout]=protect_recovery_fields(image_encrypt_I,crypto);
assert(isequal(protected_layout.header_lengths(ecc==0),LSIb(ecc==0)));
assert(protected_layout.payload_bits==numel(emD));
crypto.payload_bits=min(requested_payload_bits,protected_layout.payload_bits);
crypto.public_header=crypto_public_header('encode',crypto);
assert(numel(crypto.public_header)==53);
image_before_scramble = image_encrypt_I;
[image_encrypt_I, scrambleInfo] = scramble_blocks_within(image_before_scramble,[h,w],123);
forward_seconds=toc(forward_timer);
fprintf('第一段操作用时: %.4f 秒\n', toc);
ASA=1;
%% 接收端先解置乱，再按新 opt 格式提取载荷并逐元素/逐块还原图像
% 保留 image_encrypt_I 为置乱后的输出；恢复结果用于校验。
image_for_extract = unscramble_blocks_within(image_encrypt_I,scrambleInfo);
scramble_check_image=image_for_extract;
secure_payload=extract_payload_secure(image_for_extract,crypto.data_key,crypto.data_iv);
assert(isequal(secure_payload(:),emD(:)),'Secure payload extraction failed.');
image_for_extract=protect_recovery_fields(image_for_extract,crypto);
assert(isequal(image_for_extract,legacy_before_protection),'Auxiliary protection failed.');
% validation = struct('scramble_ok',isequal(image_for_extract,image_before_scramble), ...
%     'pixel_mismatches',nnz(image_for_extract~=image_before_scramble), ...
%     'max_pixel_error',max(abs(double(image_for_extract(:))-double(image_before_scramble(:)))), ...
%     'payload_ok',[],'auxiliary_ok',[],'payload_bits',numel(emD), ...
%     'prediction_reference',original_pred_ref, ...
%     'prediction_reconstruction_ok',all(prediction_diff(:)==0), ...
%     'prediction_pixel_mismatches',nnz(prediction_diff), ...
%     'prediction_max_pixel_error',max(abs(prediction_diff(:))), ...
%     'prediction_reference_count',pred_ref.reference_count, ...
%     'prediction_reference_bits',pred_ref.reference_bits, ...
%     'prediction_reference_embedded',false, ...
%     'scramble_info',scrambleInfo);
% assert(validation.scramble_ok,'Encrypt_Embed:ScrambleMismatch', ...
%     '解置乱结果与置乱前载密图像不一致。');
% exD = [];
% fprintf('置乱/解置乱校验通过：像素差异 %d；最大像素误差 %.g。\n', ...
%     validation.pixel_mismatches,validation.max_pixel_error);
%%开始进行提取
% true 表示参考区含 opt 方法头；接收端从图像自行读取 opt 及码字长度，
% 不把发送端 opt/opt_width 作为解码输入。原有校验参数继续保留。
a=0;
[D1,ref_data,extraction_info]=Extract_Data2(image_for_extract,Data_key,ecc,bit_max,LSIb,[],D,PFA{end},AI_sum,true);
% AI_sum_num、r、旧 trandot、逐像素折叠图均传 []，由码流恢复实际必需信息。
[recover_I,recovery_info] = Recover_Image2(image_for_extract,Image_key,ref_data,[],bit_max,image_test,LSIb,image_encrypt_I1,PFA{end},ecc,origin_D_I,PFA,a,[],select_blocked1,[],origin_E_I,[],key,iv,scrambleMap,true);
% 这些发送端真值只用于外层校验，不再作为恢复输入。
assert(extraction_info.layout.global_bits==LSIt && ...
    extraction_info.layout.displaced_bits==AI_sum_num && ...
    isequal(extraction_info.layout,recovery_info.layout),'Derived auxiliary length check failed.');
assert(recovery_info.skipped_r.from_stream && isequal(recovery_info.r,r) && ...
    recovery_info.skipped_r.bits==skipped_r_info.bits,'Embedded block arrangement check failed.');
fold_map_ok=recovery_info.fold_info.from_stream && ...
    isequal(recovery_info.fold_mask,logical(trandot1)) && ...
    recovery_info.fold_info.total_bits==fold_info.total_bits;
assert(fold_map_ok,'Encrypt_Embed:FoldMapMismatch','Embedded fold map failed to round-trip.');
exD=D1;
recovery_delta=double(recover_I)-double(origin_I);
scramble_delta=double(scramble_check_image)-double(image_before_scramble);
validation=struct('scramble_ok',~any(scramble_delta(:)), ...
    'pixel_mismatches',nnz(scramble_delta), ...
    'max_pixel_error',max(abs(scramble_delta(:))), ...
    'image_recovery_ok',~any(recovery_delta(:)), ...
    'image_pixel_mismatches',nnz(recovery_delta), ...
    'image_max_pixel_error',max(abs(recovery_delta(:))), ...
    'payload_ok',isequal(D1(:),reshape(D(1:numel(D1)),[],1)), ...
    'auxiliary_ok',isequal(ref_data(:),AI_sum(:)), ...
    'payload_bits',numel(D1),'crypto_version',2, ...
    'protected_bits',numel(protected_layout.protected),'external_public_bytes',53, ...
    'prediction_reference',original_pred_ref, ...
    'prediction_reference_embedded',true, ...
    'fold_map_ok',fold_map_ok,'fold_map_embedded',recovery_info.fold_info.from_stream, ...
    'fold_map',fold_info,'skipped_r',skipped_r_info, ...
    'r_from_stream',recovery_info.skipped_r.from_stream,'r_ok',isequal(recovery_info.r,r), ...
    'aux_length_from_stream',true,'aux_layout',recovery_info.layout, ...
    'ecc_method',extraction_info.ecc_method, ...
    'scramble_info',scrambleInfo);
assert(validation.image_recovery_ok,'Encrypt_Embed:ImageRecoveryMismatch', ...
    'Image recovery failed: %d differing pixels, maximum error %g.', ...
    validation.image_pixel_mismatches,validation.image_max_pixel_error);
fprintf('Image recovery: %d differing pixels, maximum error %g.\n', ...
    validation.image_pixel_mismatches,validation.image_max_pixel_error);
% 报告实际 opt 压缩开销与前向耗时，pred_ref 对外仍表示纯预测器辅助信息。
validation.capacity=struct('prediction_mode',prediction_mode, ...
    'opt_method',opt_info.method,'opt_bits',opt_info.bits, ...
    'opt_saving',nnz(ecc==0)*old_opt_width-opt_info.bits, ...
    'forward_seconds',forward_seconds, ...
    'fold_map_bits',fold_info.total_bits,'skipped_r_bits',skipped_r_info.bits, ...
    'skipped_blocks',nnz(ecc),'global_auxiliary_bits',LSIt);
assert(validation.payload_ok && validation.auxiliary_ok,'Encrypt_Embed:PayloadMismatch', ...
    'Payload or displaced auxiliary bits failed to round-trip.');
validation.capacity.maximum_payload_bits=protected_layout.payload_bits;
validation.payload_bits=crypto.payload_bits;
validation.padding_bits=protected_layout.payload_bits-crypto.payload_bits;
exD=exD(1:crypto.payload_bits);emD=emD(1:crypto.payload_bits);
packet=struct('stego',uint8(image_encrypt_I),'crypto',crypto,'scramble_info',scrambleInfo, ...
 'original',uint8(origin_I),'payload',emD,'baseline_validation',validation, ...
 'image_test',image_test,'LSIb',LSIb,'image_encrypt_I1',image_encrypt_I1, ...
 'PFA_END',PFA{end},'ecc',ecc,'origin_D_I',origin_D_I,'PFA',{PFA}, ...
 'select_blocked1',select_blocked1,'origin_E_I',origin_E_I,'bit_max',bit_max, ...
 'scrambleMap',scrambleMap,'AI_sum',AI_sum);

end


