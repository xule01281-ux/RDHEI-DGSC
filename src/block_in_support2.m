%%进行全局支持信息生成
function [SIt,LSIt,bit_max,fold_info,skipped_r_info] = block_in_support2(opt,PFA_END,h,w,row1,col1,s_LSIb,ns_b,l_d_best_b,l_0_l_b,x,max_l, ecc, inforamtion_numn,pred_ref,fold_mask,r_map)
% 主链路参考区：[opt 方法头, 11, 压缩折叠图, 不可编码块排列, 预测器信息]。
% 位置图在这里压缩并计入 LSIt；省略 fold_mask 时保持历史码流格式。
fold_info=[]; skipped_r_info=struct('count',0,'method','legacy_external','raw_bits',0,'bits',0);
if nargin>=16
    [fold_bits,~,fold_info]=fold_map_codec('encode',fold_mask,[row1*h,col1*w]);
    prefix=[];
    if isfield(pred_ref,'opt_header'), prefix=pred_ref.opt_header; end
    if nargin>=17
        % 11 格式同时承载折叠图和不可编码块排列；块位置复用全局 ecc。
        [r_bits,~,skipped_r_info]=skipped_r_codec('encode',r_map,ecc);
        pred_ref.bits=[prefix,1 1,fold_bits,r_bits,pred_ref.bits];
    else
        pred_ref.bits=[prefix,1 0,fold_bits,pred_ref.bits];
    end
    pred_ref.reference_bits=numel(pred_ref.bits);
    fold_info.framing_bits=2;
    fold_info.total_bits=numel(fold_bits)+2;
    fold_info.reference_section_bits=pred_ref.reference_bits;
end
assert(pred_ref.reference_bits==numel(pred_ref.bits) && pred_ref.reference_bits<2^14, ...
    'block_in_support2:ReferenceSize', ...
    'Combined reference section must fit the 14-bit length field (at most 16383 bits).');
bs11=ceil(log2(row1*h+1));
bs21=ceil(log2(col1*w+1));
bs1=bitget(h,bs11:-1:1);
bs2=bitget(w,bs21:-1:1);
bs=[bs1,bs2];
lbs=bs11+bs21;
 
 ecc_t=ecc(:)';
ecc_s=sum(ecc_t);
if ecc_s~=0
    ecc1=ecc';
    ecc_t=ecc1(:)';
    ecc_n=0;
    n1=1;
    n=ceil(log2(row1*col1)); 
    if (ecc_s+1)*n<row1*col1
        ecc_bin=zeros(1,ecc_s*n);
        while ecc_n<ecc_s
            if ecc_t(n1)==1
              d = bitget(n1-1,n:-1:1);
              ecc_bin(ecc_n*n+1:(ecc_n+1)*n)=d;
              ecc_n=ecc_n+1;
            end
           
            n1=n1+1;
        end
             ecc_num=bitget(ecc_s-1,n:-1:1);
        ecc_bin=[1,ecc_num,ecc_bin];
    else
        ecc_bin=[0,ecc_t];
    end
end
    F= PFA_END(:,2);
    F3=PFA_END(:,1);
       %%F=z1{end}(:,2);
       bit_max1=0;
       for i2=2:length(F)
           if F(i2)>bit_max1
               bit_max1=F(i2);
           end
       end
       n=max(1,floor(log2(max(1,bit_max1)))+1);
       bit_max=max(1,floor(log2(max(1,F(1))))+1);%%零单独算数字太大
       n21=floor(log2(ceil(h*w*row1*col1+1)))+1;%%算出F最大值长度表示
       n2=floor(log2(n21))+1;%%转换成二进制长度
       f=bitget(bit_max,n2:-1:1);
       f=[f,bitget(F(1),bit_max:-1:1)];
       lbit_max1=n;
       f2=bitget(lbit_max1,n2:-1:1);
       f=[f,f2];
      
       if length(F3)~=256
            i2=2;
           for i=1:F3(length(F3))
               if F3(i2)==i
                   f1=bitget(F(i2),n:-1:1);
                   f=[f,f1];
                    i2=i2+1;
               else
                    f1=zeros(1,n);
                    f=[f,f1];
               end
           end
           if F3(length(F3))~=255
               for i=1:255-F3(length(F3))
                    f1=zeros(1,n);
                    f=[f,f1];
               end
           end
       else
             for i=2:256
                 f1=bitget(F(i),n:-1:1);
                   f=[f,f1];
             end
       end
        max_l2=bitget(max_l,max(4,floor(log2(max(1,max_l)))+1):-1:1);
      bits_l=bitget(pred_ref.reference_bits,14:-1:1);
      if ecc_s==0
       SIt=[bs,0,max_l2,f,ns_b,l_d_best_b,l_0_l_b,bits_l,pred_ref.bits];
       LSIt= n2*2+bit_max+n*255+length([ns_b,l_d_best_b,l_0_l_b])+lbs+0+4+1+pred_ref.reference_bits+14;
      else
         SIt=[bs,1,ecc_bin,max_l2,f,ns_b,l_d_best_b,l_0_l_b,bits_l,pred_ref.bits];
          LSIt= n2*2+bit_max+n*255+length([ns_b,l_d_best_b,l_0_l_b])+lbs+0+4+1+length(ecc_bin)+pred_ref.reference_bits+14;
      end
       if LSIt-length(SIt)~=0
             msg = 'Error 1 occurred.';
               error(msg)
       end
       sum1=s_LSIb;
 
 ecc1=(sum1-LSIt)/(h*w*row1*col1);
 inforamtion_numn=inforamtion_numn+ LSIt;
  fprintf('ecc: %.3f\n', ecc1);fprintf('ec: %.3f\n', sum1-LSIt);
 fprintf('辅助信息: %.3f\n',inforamtion_numn);
end
 
       
