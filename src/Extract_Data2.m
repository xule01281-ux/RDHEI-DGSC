function [D1,ref_data,extraction_info]=Extract_Data2(image_encrypt_I,Data_key,ecc,bit_max,LSIb,AI_sum_num,D,PFA_END,AI_sum,has_opt_header)
% has_opt_header=true：参考区前含 opt 方法/k，各块 opt 是变长码字。
% false 保留旧格式解析；新主链路显式传 true。
if nargin<10, has_opt_header=false; end
opt_map=[]; opt_width=[];
image_encrypt_I2=image_encrypt_I;
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
% 全局参考区已读取到 b3；先按行优先扫描块头恢复 opt。
% 随后的载荷提取只使用图像中的码字，不依赖发送端的 opt 数组。
if has_opt_header
    [opt_map,opt_width,~]=read_opt_headers(image_encrypt_I2,b3, ...
        reshape(~ecc1,W/sum3,H/sum2).',sum2,sum3);
end
%%读取完毕
%%读取完毕
% max_b31=max_b3;
% targetCellArray1=f16;
% targetCellArray3=f18;
% targetCellArray2=f19;
Encrypt_D_num=0;%%已经嵌入多少,前AI_sum_num个未辅助信息
lpot=ceil(log2(sum2*sum3*8/8));
lpot1=floor((lpot+3)/8);
lpot2=rem(lpot+3,8);
ecc3=zeros(row1*col1,1);
 for h2=1:H/sum2
    for w2=1:W/sum3
        if h2==31&&w2==32
           asa=1;
        end
     if ecc3((h2-1)*(W/sum3)+w2)==0
      if ecc1((h2-1)*(W/sum3)+w2)==0||eccflag==0%%加个标识
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
        r=0;
        for i8=lpot+1:lpot+2
            sum_i8=sum8(1,i8);
            r=r*2+sum_i8;
        end
        r=r+1;
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
            b0_w_l=sum23+1;
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
        ns_b=ns_num(index_n);
        ns_encode2=encode2;
         l_block=l_block+index_i;
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
                         if num_lxf_len>6
                             b_x_l=num_lxf_len-6;
                             b_x=num_lxf2(7:num_lxf_len);
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
        end

        l_sum=l_block;
%%结束
        %%开算可以嵌入位置和可以嵌入多少
        %l_sum=lpot+length(encode1)+2+num_lxf+length(encode2)+lxf_num;
        if l_sum~=LSIb(h2,w2)%%进行测试后期注释
             msg = 'Error EE-qianru1 occurred.';
               error(msg)
        end
        if h2==14&&w2==30
            asa=1;
        end
        %%%长度确定开始提取秘密数据
        l_sum1=floor(l_sum/8);%%要用多少位
        l_sum2=rem(l_sum,8);
        if h2==32&&w2==1
            asa=1;
        end
        if l_sum2==0
            %%打上ceil((l_sum1)/sum3)=0的补丁
            rem_n=rem((l_sum1),sum3);
            ceil_n=ceil((l_sum1)/sum3);
            if rem_n==0
                %%rem_n=1;%%不用进行调整下面有加1
                ceil_n=ceil_n+1; %%长度加1就行
            end
            data_x=(h2-1)*sum2+ceil_n;%%x
            data_y=(w2-1)*sum3+rem_n;%%y
            num_data=l_sum1;%%开始长度
        else
            %%打上ceil((l_sum1+1)/sum3)=0的补丁
            rem_n=rem((l_sum1+1),sum3);
            ceil_n=ceil((l_sum1+1)/sum3);
            if rem_n==0
                 rem_n=sum3; 
                %%ceil_n=ceil_n;
            end
            data_x=(h2-1)*sum2+ceil_n;%%x
            data_y=(w2-1)*sum3+rem_n;%%y
            num_data=l_sum1+1;%%开始长度
        end
        opt1=opt;
        %%opt2=rem(opt,2);
        opt2=0;
        opt=opt1;
        end_data=opt;%%结束位置
        if l_sum2~=0
          if  data_x<x_limt||rem(data_x-x_limt,sum2)~=0||(data_x==x_limt&&data_y<y_limt)
          d4=dec2bin(image_encrypt_I2(data_x,data_y),8)-'0';%%提取辅助信息
          d41=d4(1:l_sum2);
          if Encrypt_D_num==0
              D2=d4(l_sum2+1:8);
          else
              D2=[D2,d4(l_sum2+1:8)];
          end
          Encrypt_D_num=Encrypt_D_num+8-l_sum2;
           if  Encrypt_D_num>=1466269
               asa=1;
           end
          if Encrypt_D_num>AI_sum_num
              asa=1;
          end
           %%fprintf('%d %d\n',h2,w2);
           %%fprintf('%d %d\n',data_x,data_y);
          %% disp('---------------');
          end
        end
        for i13=1:end_data-num_data
            if i13==76
                asa=1;
            end
            data_y=data_y+1;
            if data_y>sum3*w2%%检查换行
                data_x=data_x+1;
                data_y=(w2-1)*sum3+1;
            end
             if data_x==499&&data_y==32
                   asa=1;
             end
           if  data_x<x_limt||rem(data_x-x_limt,sum2)~=0||(data_x==x_limt&&data_y<y_limt)
            d4=dec2bin(image_encrypt_I2(data_x,data_y),8)-'0'; 
             if Encrypt_D_num==0
                D2=d4;
             else
                D2=[D2,d4];
             end
            Encrypt_D_num=Encrypt_D_num+8; 
            if  Encrypt_D_num>=1466269
               asa=1;
           end
            if Encrypt_D_num>AI_sum_num
              asa=1;
            end
           end
        end
        if data_x>h2*sum3
            saa=1;
        end
        if opt2==1
            data_y=data_y+1;
            if data_y>sum3*w2%%检查换行
                data_x=data_x+1;
                data_y=(w2-1)*sum3+1;
            end
            if  data_x<x_limt||rem(data_x-x_limt,sum2)~=0||(data_x==x_limt&&data_y<y_limt)
                d4=dec2bin(image_encrypt_I2(data_x,data_y),8)-'0';
                if Encrypt_D_num==0
                    D2=d4(1:4);
                 else
                    D2=[D2,d4(1:4)];
                end
                Encrypt_D_num=Encrypt_D_num+4;
            end
        end
      end % ecc==1 的块不嵌入秘密载荷，直接跳过。
     end
    end
end
%%提取完毕
[Encrypt_D] = Encrypt_Data(D,Data_key);
ref_data=D2(1,1:AI_sum_num);
D3=D2(1,AI_sum_num+1:length(D2));
[D1] = Encrypt_Data(D3,Data_key);
for i=1:AI_sum_num
    if D2(1,i)~=AI_sum(1,i)
        disp(i);
        msg = 'Error data1 occurred.';
               error(msg)
    end
end
for i=1:length(D3)
    if D3(1,i)~=Encrypt_D(1,i)
        disp(i);
        msg = 'Error data2 occurred.';
               error(msg)
    end
end
for i=1:length(D1)
    if D1(1,i)~=D(1,i)
        disp(i);
        msg = 'Error data3 occurred.';
               error(msg)
    end
end
asa=1;

extraction_info=struct('layout',global_header.layout,'ecc_method',global_header.ecc_method);
