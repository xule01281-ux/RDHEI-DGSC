function [recover_I,recovery_info] = Recover_Image2(image_encrypt_I,Image_key,ref_data,AI_sum_num,bit_max,image_test,LSIb,image_encrypt_I1,PFA_END,ecc,origin_D_I,PFA,asw,trandot,select_blocked1,r,origin_E_I,trandot1,key,iv,scrambleMap,has_opt_header)
% has_opt_header=true：参考区前含 opt 方法/k，各块 opt 是变长码字。
% false 保留旧格式解析；新主链路显式传 true。
if nargin<22, has_opt_header=false; end
opt_map=[]; opt_width=[];
image_encrypt_I2=image_encrypt_I;
%[Encrypt_D] = Encrypt_Data(D,Data_key);%%数据加密
% 全局字段统一从图像解析，发送端数组仅保留作断言。
global_header=read_global_support(image_encrypt_I2);
[H,W]=size(image_encrypt_I2);
h=global_header.h; w=global_header.w; sum2=h; sum3=w;
row1=H/h; col1=W/w;
ecc1=reshape(global_header.ecc.',[],1); eccflag=any(ecc1);
max_l=global_header.max_l; f3=global_header.frequencies;
expected_frequencies=zeros(256,1);
expected_frequencies(PFA_END(:,1)+1)=PFA_END(:,2);
assert(isequal(f3,expected_frequencies),'Global frequency check failed.');
assert(isequal(logical(global_header.ecc),logical(ecc)),'Skipped block map check failed.');
assert(global_header.bit_max==bit_max,'Frequency width check failed.');
ns_num=global_header.tables{1}.values;
ns_encode=global_header.tables{1}.codes;
ns_maxl=global_header.tables{1}.max_length;
ns_sum_b3=global_header.tables{1}.count;
l_d_best_num=global_header.tables{2}.values;
l_d_best_encode=global_header.tables{2}.codes;
l_d_best_maxl=global_header.tables{2}.max_length;
l_d_best_sum_b3=global_header.tables{2}.count;
l_0_l_num=global_header.tables{3}.values;
l_0_l_encode=global_header.tables{3}.codes;
l_0_l_maxl=global_header.tables{3}.max_length;
l_0_l_sum_b3=global_header.tables{3}.count;
max_b3=l_0_l_maxl;
b3=global_header.reference; sum_b3=numel(b3);
x_limt=global_header.layout.last_row; y_limt=global_header.layout.last_col;
% 参数位保留以兼容旧调用；实际长度只由码流及覆盖布局推导。
AI_sum_num=global_header.layout.displaced_bits;
% rANS 按块逆序恢复，而相邻块 opt 预测按行优先，因此必须先预扫描。
% 去掉方法/k 后，剩余比特才是 prediction_reference_codec 的原始输入。
if has_opt_header
    [opt_map,opt_width,opt_used]=read_opt_headers(image_encrypt_I2,b3, ...
        reshape(~ecc1,W/sum3,H/sum2).',sum2,sum3);
    prediction_reference_bits=double(b3(opt_used+1:end));
    sum_b3=sum_b3-opt_used;
else
    prediction_reference_bits=double(b3(:).');
end
if numel(prediction_reference_bits)~=sum_b3 || sum_b3<10
    error('Recover_Image2:InvalidPredictionReference', ...
        'Prediction reference length is invalid: expected %d bits, got %d.', ...
        sum_b3,numel(prediction_reference_bits));
end
% 新参考类型 11 内含压缩折叠图和不可编码块排列；主链路位置图参数为空。
% 只有旧 00/01 参考格式才使用外传位置图，以兼容历史测试。
[prediction_reference_bits,folded_mask,fold_info,stream_r,skipped_r_info]= ...
    unpack_fold_reference(prediction_reference_bits,[H W],trandot1,global_header.ecc);
if skipped_r_info.from_stream
    r=stream_r; % 编码块随后用块头覆盖；不可编码块已从 block_in_support2 解码。
end
% trandot（第14参数）已弃用，保留参数位，不再参与恢复运算。
assert(numel(ref_data)==AI_sum_num,'Recover_Image2:ReferenceLength', ...
    'Displaced byte count differs from the global stream layout.');
%%读取完毕
%%读取完毕
%%读取完毕
%%读取完毕
len4=floor(AI_sum_num/8);%%要用多少个数据%%按数据整个进行保存的 为8的倍数
len7=ceil(len4/W);%%用几行
n4=0;
n=0;
for i=H:-h:(H/h-len7+1)*h
    for j=W:-1:1
        n4=n4+1;
        if(n4<=len4)  
            %%fprintf('%d %d\n',i,j);
            sum1=0;
            for i1=1:8
                sum1=sum1*2+ref_data((n4-1)*8+i1);
                 n=n+1;
            end
            image_encrypt_I2(i,j)=sum1;
            if image_encrypt_I2(i,j)~=image_test(i,j)
              asa=1;
            end
        end
        if n4==len4
            break;
        end
    end
end%%回填全部完成
%[image_encrypt_I3] = Encrypt_Image(image_encrypt_I2,Image_key);%%回填后部分解码
% blockSize=[h,w];
% encryptedImage=uint8(image_encrypt_I2);
% encryptedImage1 = inverse_block_scramble_image(encryptedImage, blockSize, scrambleMap);
% image_encrypt_I2= double(encryptedImage1);
%encryptedImage1=encryptedImage1(:);
encryptedImage1=uint8(image_encrypt_I2(:));
image_encrypt_I3 = aesCtrImageDecrypt(encryptedImage1, ...
                                  H, W, 1, ...
                                   key, iv);
image_encrypt_I3=double(image_encrypt_I3);
max_b31=max_b3;
Encrypt_D_num=0;%%已经嵌入多少,前AI_sum_num个未辅助信息
lpot=ceil(log2(sum2*sum3*8/8));
lpot1=floor((lpot+3+3)/8);
lpot2=rem(lpot+3,8);
ecc3=zeros(row1*col1,1);
 for h2=H/sum2:-1:1
    for w2=W/sum3:-1:1
        if h2==4&&w2==2
           asa=1;
        end
     if ecc3((h2-1)*(W/sum3)+w2)==0
      if ecc1((h2-1)*(W/sum3)+w2)==0||eccflag==0%%加个标识
           t4_nflag=1;
        % opt 码长因块而异，r 与 b0 的起点必须随之移动。
        if ~isempty(opt_width)
            lpot=opt_width(h2,w2);
            lpot1=floor((lpot+3)/8);
            lpot2=rem(lpot+3,8);
        end
        h3=1;
        w3=0;
        i7=0; % 短 opt 可能使首个整字节循环为空
        for i7=1:lpot1
            w3=w3+1;
            if w3>sum3
                w3=1;
                h3=h3+1;
            end
           d1=zeros(1,8);
            for b = 1 : 8
                d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
            end
            if i7==1
                sum8=d1;
            elseif i7>1
                sum8=[sum8,d1];
            end
        end
        if h2==32&&w2==26
               asasx=1;
        end
        if lpot2~=0
            w3=w3+1;
            if w3>sum3
               w3=1;
               h3=h3+1;
            end
            d1=zeros(1,8);
            for b = 1 : 8
                d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
            end
            if i7~=0
                sum8=[sum8,d1(1:lpot2)];
            else
                sum8=d1(1:lpot2);
            end
            d2=d1(lpot2+1:8);
            p0=d2;
            lp0=8-lpot2;
        else
            lp0=0;
        end
        opt=0;
        for i8=1:lpot
            sum_i8=sum8(1,i8);
            opt=opt*2+sum_i8;
        end
        if isempty(opt_map)
            opt=opt+1; % 旧格式：定宽保存 opt-1
        else
            opt=opt_map(h2,w2); % 新格式：用预扫描解码出的真实 opt
        end
        %%opt完成
        block_kind=0;
        for i8=lpot+1:lpot+2
            sum_i8=sum8(1,i8);
            block_kind=block_kind*2+sum_i8;
        end
        r(h2,w2)=block_kind+1;
        b_x_l=lp0;
        if lp0~=0
            b_x=p0;
        else
            b_x=[];
        end
        %%r完成
        l_block=lpot+3;
        b0_flag=sum8(lpot+3);
        if b0_flag==1
            if lp0>=1
                 b0_r=p0(1);
                 b_x_l=lp0-1;
                 if b_x_l>0
                   b_x=p0(2:lp0);
                 else
                     b_x=[];
                 end
            else
                w3=w3+1;
                if w3>sum3
                   w3=1;
                   h3=h3+1;
                end
                d1=zeros(1,8);
                for b = 1 : 8
                    d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                end
                b0_r=d1(1);
                b_x_l=7;
                b_x=d1(2:8);
            end
            
            if b0_r==0
                b0_l=log2(w);
            else
                b0_l=log2(w)+max_l;
            end
            l_block=l_block+1+b0_l;
            if b_x_l>=b0_l
                b0_w=b_x(1:b0_l);
                if  b_x_l- b0_l>0
                     b_x=b_x(b0_l+1:b_x_l);
                     b_x_l=b_x_l-b0_l;
                else
                     b_x_l=0;
                     b_x=[];
                end
            else
                b0_l1=floor((b0_l-b_x_l)/8);
                b0_l2=rem(b0_l-b_x_l,8);
                if b_x_l==0
                        b_x1=[];
                else
                    b_x1=b_x;
                end
                for i7=1:b0_l1
                    w3=w3+1;
                    if w3>sum3
                        w3=1;
                        h3=h3+1;
                    end
                   d1=zeros(1,8);
                    for b = 1 : 8
                        d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                    end
                    if i7==1
                        sum8=d1;
                    elseif i7>1
                        sum8=[sum8,d1];
                    end
                end
                if b0_l2~=0
                    w3=w3+1;
                    if w3>sum3
                       w3=1;
                       h3=h3+1;
                    end
                    d1=zeros(1,8);
                    for b = 1 : 8
                        d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                    end
                    if i7~=0
                        sum8=[sum8,d1(1:b0_l2)];
                    else
                        sum8=d1(1:b0_l2);
                    end
                    d2=d1(b0_l2+1:8);
                    b_x=d2;
                    b_x_l=8-b0_l2;
                else
                    b_x_l=0;
                    b_x=[];
                end
                b0_w=[b_x1,sum8];
            end
            sum23=0;
            for n5=1:b0_l
                sum23=sum23*2+b0_w(n5);
            end
            b0_w_l=sum23+1;%%首段激活后连续零的长度
        end
% ns_num=num;
        % ns_encode=f16;
        % ns_maxl=max_b3;
        max_b3=ns_maxl;
        lp0=b_x_l;
        p0= b_x;
        sum_b3=ns_sum_b3;
        targetCellArray1=ns_encode;
        
        if lp0==0
            n_e1=ceil(max_b3/8);
            d1=zeros(1,ceil(max_b3/8)*8);
            for i3=1: n_e1
                w3=w3+1;
                if w3>sum3
                   w3=1;
                   h3=h3+1;
                end
                if i3==1
                    %d1=dec2bin(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3),8)-'0';
                    for b = 1 : 8
                        d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                    end
                else
                    for b = 1 : 8
                        d1((i3-1)*8+b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                    end
                end
            end
            index_n=0;
            index_i=0;
            for i=1:sum_b3
                if i==1
                 encode=d1(1);
                else
                 encode=[encode,d1(i)];
                end
                index = findArrayIndex(encode, targetCellArray1);
                if index~=0
                     index_i=i;
                    index_n=index;
                    encode2=encode;
                    break;
                end
            end
            num_lxf_len=8*n_e1-index_i;
            if num_lxf_len~=0
            num_lxf2=d1(index_i+1:8*n_e1);
            else
            num_lxf2=[];    
            end
        else
            if lp0-max_b3>=0
                index_n=0;
                index_i=0;
                for i=1:sum_b3
                    if i==1
                     encode=p0(1);
                    else
                     encode=[encode,p0(i)];
                    end
                    index = findArrayIndex(encode, targetCellArray1);
                    if index~=0
                         index_i=i;
                        index_n=index;
                        encode2=encode;
                        break
                    end
                end
                 num_lxf_len=lp0-index_i;
                    if num_lxf_len~=0
                      num_lxf2=p0(index_i+1:lp0);
                    else
                      num_lxf2=[];    
                    end
                 
            else
                n4=max_b3-lp0;
                n_e1=ceil(n4/8);
                d1=zeros(1,n_e1*8+lp0);
                d1(1:lp0)=p0;
                for i3=1: n_e1
                    w3=w3+1;
                    if w3>sum3
                       w3=1;
                       h3=h3+1;
                    end
                    if i3==1
                        for b = 1 : 8
                           d1(lp0+b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                        end
                    else
                        for b = 1 : 8
                           d1((i3-1)*8+lp0+b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                        end
                    end
                end
                d2=d1;
                for i=1:sum_b3
                    if i==1
                     encode=d2(1);
                    else
                     encode=[encode,d2(i)];
                    end
                    index = findArrayIndex(encode, targetCellArray1);
                    if index~=0
                         index_i=i;
                        index_n=index;
                        encode2=encode;
                        break;
                    end
                end
                 num_lxf_len=lp0-index_i+8*n_e1;
                if num_lxf_len~=0
                num_lxf2=d2(index_i+1:lp0+8*n_e1);
                else
                num_lxf2=[];    
                end
                 
            end
        end
        ns_b=ns_num(index_n);%%每一块内的段数
        ns_encode2=encode2;
         l_block=l_block+index_i;
         
%%结束
mode=[];
xts=[];
if ns_b==0
            %%结束了

        elseif ns_b>=1
         if num_lxf_len>=6
             xt_end_l_bin=num_lxf2(1:6);
             sum1=0;
             for xs=1:6
                 sum1=sum1*2+xt_end_l_bin(xs);
             end
             l_xt_end=sum1;
             if num_lxf_len>6
                 b_x_l=num_lxf_len-6;
                 b_x=num_lxf2(7:num_lxf_len);
             else
              b_x_l=0;
              b_x=[];
             end
         else
             
             xt_end_l1= floor((6-num_lxf_len)/8);
             xt_end_l2=rem((6-num_lxf_len),8);
             if num_lxf_len~=0
               sum8=num_lxf2(1:num_lxf_len);
             else
                sum8=[]; 
             end
             for xt_end_ln=1:xt_end_l1
                    w3=w3+1;
                    if w3>sum3
                       w3=1;
                       h3=h3+1;
                    end
                    d1=zeros(1,8);
                    for b = 1 : 8
                        d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                    end
                    sum8=[sum8,d1];
             end
             if xt_end_l2~=0
                  w3=w3+1;
                    if w3>sum3
                       w3=1;
                       h3=h3+1;
                    end
                    d1=zeros(1,8);
                    for b = 1 : 8
                        d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                    end
                    sum8=[sum8,d1(1:xt_end_l2)];
                    b_x=d1(xt_end_l2+1:8);
                    b_x_l=8-xt_end_l2;
             else
                 b_x_l=0;
                 b_x=[];
             end
             sum4=0;
             for sum4_i=1:6
                 sum4=sum4*2+sum8(sum4_i);
             end
             l_xt_end=sum4;
         end
         l_block=l_block+6+l_xt_end+ns_b;
         if ns_b>1
                % l_d_best_num=num;
                % l_d_best_encode=f16;
                % l_d_best_maxl=max_b3;
                % l_d_best_sum_b3=sum_b3;

                % l_0_l_num=num;
                % l_0_l_encode=f16;
                % l_0_l_maxl=max_b3;
                % l_0_l_sum_b3=sum_b3;
                
                       
                            max_b3=l_d_best_maxl;
                            lp0=b_x_l;
                            p0= b_x;
                            sum_b3=l_d_best_sum_b3;
                            targetCellArray1=l_d_best_encode;
                            n_num=l_d_best_num;
                       
                            
                        
                    if lp0==0
                        n_e1=ceil(max_b3/8);
                        d1=zeros(1,ceil(max_b3/8)*8);
                        for i3=1: n_e1
                            w3=w3+1;
                            if w3>sum3
                               w3=1;
                               h3=h3+1;
                            end
                            if i3==1
                                %d1=dec2bin(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3),8)-'0';
                                for b = 1 : 8
                                    d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                                end
                            else
                                for b = 1 : 8
                                    d1((i3-1)*8+b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                                end
                            end
                        end
                        index_n=0;
                        index_i=0;
                        for i=1:sum_b3
                            if i==1
                             encode=d1(1);
                            else
                             encode=[encode,d1(i)];
                            end
                            index = findArrayIndex(encode, targetCellArray1);
                            if index~=0
                                 index_i=i;
                                index_n=index;
                                encode2=encode;
                                break;
                            end
                        end
                        num_lxf_len=8*n_e1-index_i;
                        if num_lxf_len~=0
                        num_lxf2=d1(index_i+1:8*n_e1);
                        else
                        num_lxf2=[];    
                        end
                    else
                        if lp0-max_b3>=0
                            index_n=0;
                            index_i=0;
                            for i=1:sum_b3
                                if i==1
                                 encode=p0(1);
                                else
                                 encode=[encode,p0(i)];
                                end
                                index = findArrayIndex(encode, targetCellArray1);
                                if index~=0
                                     index_i=i;
                                    index_n=index;
                                    encode2=encode;
                                    break
                                end
                            end
                             num_lxf_len=lp0-index_i;
                                if num_lxf_len~=0
                                  num_lxf2=p0(index_i+1:lp0);
                                else
                                  num_lxf2=[];    
                                end
                             
                        else
                            n4=max_b3-lp0;
                            n_e1=ceil(n4/8);
                            d1=zeros(1,n_e1*8+lp0);
                            d1(1:lp0)=p0;
                            for i3=1: n_e1
                                w3=w3+1;
                                if w3>sum3
                                   w3=1;
                                   h3=h3+1;
                                end
                                if i3==1
                                    for b = 1 : 8
                                       d1(lp0+b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                                    end
                                else
                                    for b = 1 : 8
                                       d1((i3-1)*8+lp0+b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                                    end
                                end
                            end
                            d2=d1;
                            for i=1:sum_b3
                                if i==1
                                 encode=d2(1);
                                else
                                 encode=[encode,d2(i)];
                                end
                                index = findArrayIndex(encode, targetCellArray1);
                                if index~=0
                                     index_i=i;
                                    index_n=index;
                                    encode2=encode;
                                    break;
                                end
                            end
                             num_lxf_len=lp0-index_i+8*n_e1;
                            if num_lxf_len~=0
                            num_lxf2=d2(index_i+1:lp0+8*n_e1);
                            else
                            num_lxf2=[];    
                            end
                             
                        end
                    end
                    l_d_best_b=n_num(index_n);%%最佳段长
                    ns_encode2=encode2;
                     l_block=l_block+index_i;
                     b_x=num_lxf2;
                     b_x_l=num_lxf_len;
                     %%开始读取l_0,即段前连续零
                    max_b3=l_0_l_maxl;
                    sum_b3=l_0_l_sum_b3;
                    targetCellArray1=l_0_l_encode;
                    n_num=l_0_l_num;
                    l_0=zeros(1,ns_b-1);
                    for l_0_num=1:ns_b-1
                        lp0=b_x_l;
                        p0= b_x;
                         if lp0==0
                            n_e1=ceil(max_b3/8);
                            d1=zeros(1,ceil(max_b3/8)*8);
                            for i3=1: n_e1
                                w3=w3+1;
                                if w3>sum3
                                   w3=1;
                                   h3=h3+1;
                                end
                                if i3==1
                                    %d1=dec2bin(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3),8)-'0';
                                    for b = 1 : 8
                                        d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                                    end
                                else
                                    for b = 1 : 8
                                        d1((i3-1)*8+b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                                    end
                                end
                            end
                            index_n=0;
                            index_i=0;
                            for i=1:sum_b3
                                if i==1
                                 encode=d1(1);
                                else
                                 encode=[encode,d1(i)];
                                end
                                index = findArrayIndex(encode, targetCellArray1);
                                if index~=0
                                     index_i=i;
                                    index_n=index;
                                    encode2=encode;
                                    break;
                                end
                            end
                            num_lxf_len=8*n_e1-index_i;
                            if num_lxf_len~=0
                            num_lxf2=d1(index_i+1:8*n_e1);
                            else
                            num_lxf2=[];    
                            end
                        else
                            if lp0-max_b3>=0
                                index_n=0;
                                index_i=0;
                                for i=1:sum_b3
                                    if i==1
                                     encode=p0(1);
                                    else
                                     encode=[encode,p0(i)];
                                    end
                                    index = findArrayIndex(encode, targetCellArray1);
                                    if index~=0
                                         index_i=i;
                                        index_n=index;
                                        encode2=encode;
                                        break
                                    end
                                end
                                 num_lxf_len=lp0-index_i;
                                    if num_lxf_len~=0
                                      num_lxf2=p0(index_i+1:lp0);
                                    else
                                      num_lxf2=[];    
                                    end
                                 
                            else
                                n4=max_b3-lp0;
                                n_e1=ceil(n4/8);
                                d1=zeros(1,n_e1*8+lp0);
                                d1(1:lp0)=p0;
                                for i3=1: n_e1
                                    w3=w3+1;
                                    if w3>sum3
                                       w3=1;
                                       h3=h3+1;
                                    end
                                    if i3==1
                                        for b = 1 : 8
                                           d1(lp0+b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                                        end
                                    else
                                        for b = 1 : 8
                                           d1((i3-1)*8+lp0+b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                                        end
                                    end
                                end
                                d2=d1;
                                for i=1:sum_b3
                                    if i==1
                                     encode=d2(1);
                                    else
                                     encode=[encode,d2(i)];
                                    end
                                    index = findArrayIndex(encode, targetCellArray1);
                                    if index~=0
                                         index_i=i;
                                        index_n=index;
                                        encode2=encode;
                                        break;
                                    end
                                end
                                 num_lxf_len=lp0-index_i+8*n_e1;
                                if num_lxf_len~=0
                                num_lxf2=d2(index_i+1:lp0+8*n_e1);
                                else
                                num_lxf2=[];    
                                end
                                 
                            end
                         end
                         l_0(l_0_num)=n_num(index_n);%%段前零的长度
                         ns_encode2=encode2;
                         l_block=l_block+index_i;
                         b_x=num_lxf2;
                         b_x_l=num_lxf_len;
                    end
                    
                    if num_lxf_len>=ns_b-1
                         l_d_f=num_lxf2(1:ns_b-1);
                         if num_lxf_len>ns_b-1
                             b_x_l=num_lxf_len-(ns_b-1);
                             b_x=num_lxf2(ns_b:num_lxf_len);
                         else
                          b_x_l=0;
                          b_x=[];
                         end
                    else
                         l_d_f_l1= floor((ns_b-1-num_lxf_len)/8);
                         l_d_f_l2=rem((ns_b-1-num_lxf_len),8);
                         if num_lxf_len~=0
                             sum8=num_lxf2(1:num_lxf_len);
                         else
                             sum8=[];
                         end
                         for l_d_f_ln=1:l_d_f_l1
                                w3=w3+1;
                                if w3>sum3
                                   w3=1;
                                   h3=h3+1;
                                end
                                d1=zeros(1,8);
                                for b = 1 : 8
                                    d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                                end
                                sum8=[sum8,d1];
                         end
                         if l_d_f_l2~=0
                              w3=w3+1;
                                if w3>sum3
                                   w3=1;
                                   h3=h3+1;
                                end
                                d1=zeros(1,8);
                                for b = 1 : 8
                                    d1(b) = bitget(image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3), 9-b);
                                end
                                sum8=[sum8,d1(1:l_d_f_l2)];
                                b_x=d1(l_d_f_l2+1:8);
                                b_x_l=8-l_d_f_l2;
                         else
                             b_x_l=0;
                             b_x=[];
                         end
                         l_d_f=sum8;
                    end
                    l_block=l_block+ns_b-1;
                     l_block= l_block+sum(l_d_f)*l_d_best_b+(ns_b-1-sum(l_d_f))*53;
          end

            % Wire order: mode bits, last xt, then xt for segments 1..ns_b-1.
            xt_widths=zeros(1,ns_b);
            xt_widths(ns_b)=l_xt_end;
            if ns_b>1
                xt_widths(1:ns_b-1)=53;
                xt_widths(find(l_d_f==1))=l_d_best_b;
            end
            segment_bit_count=ns_b+sum(xt_widths);
            segment_bits=b_x(1:b_x_l);
            while numel(segment_bits)<segment_bit_count
                w3=w3+1;
                if w3>sum3
                    w3=1;
                    h3=h3+1;
                end
                if h3>sum2
                    error('Recover_Image2:TruncatedSegmentStates', ...
                        'Mode and xt bits exceed block (%d,%d).',h2,w2);
                end
                segment_pixel=image_encrypt_I2((h2-1)*sum2+h3,(w2-1)*sum3+w3);
                segment_bits=[segment_bits,bitget(segment_pixel,8:-1:1)];
            end

            mode=segment_bits(1:ns_b);
            xts=zeros(1,ns_b);
            segment_pos=ns_b;
            for segment_index=[ns_b,1:ns_b-1]
                segment_xt=0;
                for segment_bit=1:xt_widths(segment_index)
                    segment_xt=segment_xt*2+segment_bits(segment_pos+segment_bit);
                end
                xts(segment_index)=segment_xt;
                segment_pos=segment_pos+xt_widths(segment_index);
            end
            xt=xts(ns_b);
            b_x=segment_bits(segment_bit_count+1:end);
            b_x_l=numel(b_x);
            num_lxf2=b_x;
            num_lxf_len=b_x_l;
        end
% Segment metadata complete.
%%结束一部分
        l_sum= l_block;
        if l_sum~=LSIb(h2,w2)%%进行测试后期注释
            msg = 'Error rm1 occurred.';
               error(msg)
        end
        
        %%最终状态值求出
        % Rebuild the same ranked frequency tables as Copy_of_complete_bit.
        decode_freq=double(f3(:));
        nonzero_count=nnz(decode_freq);
        singleton_count=nnz(decode_freq==1);
        scale_values=decode_freq(decode_freq>1);
        if isempty(scale_values)
            frequency_scale=1000;
        else
            frequency_scale=min(scale_values);
        end
        if singleton_count*2<nonzero_count+1
            first_frequency=decode_freq(1);
            scaled_mask=decode_freq>=frequency_scale;
            positive_mask=decode_freq>0;
            decode_freq(scaled_mask)=floor(decode_freq(scaled_mask)/frequency_scale);
            decode_freq(~scaled_mask & positive_mask)=1;
            if first_frequency>=frequency_scale
                decode_freq(1)=ceil(first_frequency/frequency_scale);
            end
        end
        frequency_table=[(0:255)',decode_freq];
        frequency_table=frequency_table(decode_freq>0,:);
        [decode_symbols,base_frequencies]=sort_z(frequency_table);
        adjusted_frequencies=base_frequencies;
        if numel(base_frequencies)>1
            adjusted_frequencies(1)=base_frequencies(2)+1;
        end
        decode_tables={base_frequencies,adjusted_frequencies};
        decode_cumulative=cell(1,2);
        decode_totals=zeros(1,2);
        for table_index=1:2
            decode_cumulative{table_index}=[0,cumsum(decode_tables{table_index})];
            decode_totals(table_index)=sum(decode_tables{table_index});
        end

        if opt<0 || opt>sum2*sum3 || numel(xts)~=ns_b || numel(mode)~=ns_b
            error('Recover_Image2:InvalidBlockMetadata', ...
                'Invalid opt/ns/mode/xts in block (%d,%d).',h2,w2);
        end
        if ns_b>1 && numel(l_0)~=ns_b-1
            error('Recover_Image2:InvalidZeroRuns', ...
                'Expected %d inter-segment zero runs in block (%d,%d).', ...
                ns_b-1,h2,w2);
        end
        if b0_flag==1 && ns_b==0
            error('Recover_Image2:MissingPrefixState', ...
                ['Block (%d,%d) has a nonzero prefix but ns=0; ' ...
                 'the sender did not store its symbol state.'],h2,w2);
        end
        decode_segment=ns_b;
        decode_state=uint64(0);
        if decode_segment>0
            decode_state=uint64(xts(decode_segment));
        end
        pending_zeros=0;
        prefix_symbol_pending=false;
        prefix_symbol=0;
        decoded_elements=0;
        for element_index=opt:-1:1
            % Empty segments emit no symbol; their preceding zero runs do.
            while decode_segment>0 && decode_state==0 && pending_zeros==0
                if decode_segment>1
                    pending_zeros=l_0(decode_segment-1);
                    decode_segment=decode_segment-1;
                    decode_state=uint64(xts(decode_segment));
                else
                    decode_segment=0;
                end
            end
            state_before=decode_state;
            segment_before=decode_segment;
            if pending_zeros>0
                decoded_value=0;
                pending_zeros=pending_zeros-1;
            elseif prefix_symbol_pending
                decoded_value=prefix_symbol;
                prefix_symbol_pending=false;
            elseif decode_segment==0
                decoded_value=0;
            else
                table_index=mode(decode_segment)+1;
                if table_index~=1 && table_index~=2
                    error('Recover_Image2:InvalidMode', ...
                        'Invalid mode in block (%d,%d), segment %d.',h2,w2,decode_segment);
                end
                active_freq=decode_tables{table_index};
                active_cumulative=decode_cumulative{table_index};
                active_total=uint64(decode_totals(table_index));
                if decode_state<active_total
                    symbol_rank=double(decode_state);
                    if symbol_rank>=numel(decode_symbols)
                        error('Recover_Image2:InvalidInitialState', ...
                            'Invalid initial state %.0f in block (%d,%d), segment %d.', ...
                            double(decode_state),h2,w2,decode_segment);
                    end
                    decoded_value=decode_symbols(symbol_rank+1);
                    decode_state=uint64(0);
                    if decode_segment==1 && b0_flag==1
                        % Restore the skipped zeros before emitting the prefix seed.
                        prefix_symbol=decoded_value;
                        prefix_symbol_pending=true;
                        pending_zeros=b0_w_l-1;
                        decoded_value=0;
                        decode_segment=0;
                    end
                else
                    residue=double(rem(decode_state,active_total));
                    symbol_index=find(residue<active_cumulative(2:end),1);
                    symbol_frequency=uint64(active_freq(symbol_index));
                    previous_state=idivide(decode_state,active_total,'floor')* ...
                        symbol_frequency+uint64(residue-active_cumulative(symbol_index));
                    % Startup adds one modulus; ordinary encoded states exceed it.
                    if previous_state<=active_total
                        if previous_state<symbol_frequency
                            error('Recover_Image2:InvalidStateTransition', ...
                                'Invalid transition in block (%d,%d), segment %d.', ...
                                h2,w2,decode_segment);
                        end
                        previous_state=previous_state-symbol_frequency;
                    end
                    decoded_value=decode_symbols(symbol_index);
                    decode_state=previous_state;
                end
            end
            local_row=floor((element_index-1)/sum3)+1;
            local_col=mod(element_index-1,sum3)+1;
            pixel_row=(h2-1)*sum2+local_row;
            pixel_col=(w2-1)*sum3+local_col;
            image_encrypt_I3(pixel_row,pixel_col)=decoded_value;
            decoded_elements=decoded_elements+1;
            expected_value=image_encrypt_I1(pixel_row,pixel_col);
            if decoded_value~=expected_value
                error('Recover_Image2:ElementMismatch', ...
                    ['Block (%d,%d), element %d, local (%d,%d), image (%d,%d): ' ...
                     'expected %g, got %g; segment %d, state %.0f -> %.0f.'], ...
                    h2,w2,element_index,local_row,local_col,pixel_row,pixel_col, ...
                    expected_value,decoded_value,segment_before, ...
                    double(state_before),double(decode_state));
            end
        end
        if decoded_elements~=opt || pending_zeros~=0 || prefix_symbol_pending || ...
                decode_state~=0 || decode_segment>1
            error('Recover_Image2:UnconsumedState', ...
                'Unconsumed segment state or zero run in block (%d,%d).',h2,w2);
        end
      end % ecc==1 块保持 AES 解密后的完整符号，r 从全局参考区读取。
     end
      % Check the complete block, including the untouched tail.
      block_rows=(h2-1)*sum2+(1:sum2);
      block_cols=(w2-1)*sum3+(1:sum3);
      block_difference=image_encrypt_I3(block_rows,block_cols)~= ...
          image_encrypt_I1(block_rows,block_cols);
      if any(block_difference(:))
          [bad_row,bad_col]=find(block_difference,1);
          error('Recover_Image2:BlockMismatch', ...
              ['Block (%d,%d) has %d mismatched elements; first at (%d,%d): ' ...
               'expected %g, got %g.'],h2,w2,nnz(block_difference),bad_row,bad_col, ...
              image_encrypt_I1(block_rows(bad_row),block_cols(bad_col)), ...
              image_encrypt_I3(block_rows(bad_row),block_cols(bad_col)));
      end
      % Complete block check finished.
      %%减去频率
      %%得到新f3
      for ia=1:sum2
          for ib=1:sum3
              x1=image_encrypt_I3((h2-1)*h+ia,(w2-1)*w+ib);
              f3(x1+1)=f3(x1+1)-1;           
          end
      end
     
    end
     %fprintf('已经进行到%d块\n',h2);
end
%%解码完成
%%image_encrypt_I3=image_encrypt_I1;
for i=1:H
    for j=1:W
        if image_encrypt_I3(i,j)~=image_encrypt_I1(i,j)
            msg = 'Error 8 occurred.';
            error(msg)
        end
    end
end
image_encrypt_I4=zeros(H,W);
row1=H/h;
col1=W/w;
if ~isequal(size(r),[row1,col1]) || any(~ismember(r(:),1:4))
    error('Recover_Image2:InvalidBlockKinds','Expected one block kind (1..4) per block.');
end
plane_weights=reshape(2.^(7:-1:0),1,1,8);
for i=1:row1
    for j=1:col1
        block_rows=(i-1)*h+(1:h);
        block_cols=(j-1)*w+(1:w);
        block_data=image_encrypt_I3(block_rows,block_cols);
        restored_planes=reverse_block_processing(r(i,j),w,h,block_data);
        % select_block stores MSB first; odd mapped values represent positive errors.
        mapped_block=sum(restored_planes.*plane_weights,3);
        restored_block=-mapped_block/2;
        positive_mask=mod(mapped_block,2)==1;
        restored_block(positive_mask)=(mapped_block(positive_mask)+1)/2;
        image_encrypt_I4(block_rows,block_cols)=restored_block;

        expected_block=origin_D_I(block_rows,block_cols);
        block_difference=restored_block~=expected_block;
        if any(block_difference(:))
            [bad_row,bad_col]=find(block_difference,1);
            error('Recover_Image2:InverseBlockMismatch', ...
                ['Block (%d,%d), kind %d, local (%d,%d): ' ...
                 'expected signed value %g, got %g.'], ...
                i,j,r(i,j),bad_row,bad_col,expected_block(bad_row,bad_col), ...
                restored_block(bad_row,bad_col));
        end
    end
end

% Undo Transform_E's +/-128 folding before invoking the prediction decoder.
% folded_mask 已从全局辅助区解码，不能再使用发送端位置图。
positive_mask=image_encrypt_I4>0;
image_encrypt_I4(folded_mask & positive_mask)= ...
    image_encrypt_I4(folded_mask & positive_mask)+128;
image_encrypt_I4(folded_mask & ~positive_mask)= ...
    image_encrypt_I4(folded_mask & ~positive_mask)-128;
error_difference=image_encrypt_I4~=origin_E_I;
if any(error_difference(:))
    [bad_row,bad_col]=find(error_difference,1);
    error('Recover_Image2:PredictionErrorMismatch', ...
        'Prediction error at (%d,%d): expected %g, got %g.', ...
        bad_row,bad_col,origin_E_I(bad_row,bad_col),image_encrypt_I4(bad_row,bad_col));
end
recover_I=recover_from_prediction_error(image_encrypt_I4,prediction_reference_bits);
recovery_info=struct('fold_mask',folded_mask,'fold_info',fold_info, ...
    'r',r,'skipped_r',skipped_r_info,'layout',global_header.layout);



