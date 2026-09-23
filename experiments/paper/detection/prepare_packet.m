
function packet=prepare_packet(origin_I,D,Image_key,Data_key,ref_x,ref_y,h,w,prediction_mode,crypto)
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
[image_encrypt_I,AI_sum_num,AI_sum,image_test,image_encrypt_I1,emD,scrambleMap,emD1] = Embed_Data_Encrypt_Data(select_blocked,Image_key,D,Data_key,h,w,row1,col1,LSIb,SIb,SIt,LSIt,ecc,bit_max,PFA{end},p0,r,key,iv,opt,opt_width);
%[image_encrypt_I,image_test] = Copy_of_Embed_Data_Encrypt_Data(select_blocked,Image_key,D,Data_key,h,w,row1,col1,LSIb,SIb,SIt,LSIt,ecc,bit_max,PFA{end},p0,r,key,iv);
fprintf('第一段操作用时: %.4f 秒\n', toc);
asa=1;
%% 块间 + 块内置乱（从 main.m 移至原第 48 行之后）
legacy_before_protection=image_encrypt_I;
[image_encrypt_I,protected_layout]=protect_recovery_fields(image_encrypt_I,crypto);
assert(isequal(protected_layout.header_lengths(ecc==0),LSIb(ecc==0)));
assert(protected_layout.payload_bits==numel(emD));
image_before_scramble = image_encrypt_I;
[image_encrypt_I, scrambleInfo] = scramble_blocks_within(image_before_scramble,[h,w],123);
forward_seconds=toc(forward_timer);
fprintf('第一段操作用时: %.4f 秒\n', toc);
ASA=1;
packet=struct('stego',image_encrypt_I,'before_scramble',image_before_scramble, ...
 'legacy',legacy_before_protection,'ordinary_cipher',image_test,'layout',protected_layout, ...
 'crypto',crypto,'scramble_info',scrambleInfo,'payload',emD,'LSIb',LSIb, ...
 'global_bits',LSIt,'prediction_reference',original_pred_ref, ...
 'forward_seconds',forward_seconds);
end
