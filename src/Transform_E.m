%%得到误差
%%大于127全部转化，减去128，进行标记。
function [origin_D_I,n,trandot1,trandot] = Transform_E(origin_E_I,h,w)
validateattributes(origin_E_I,{'numeric'},{'real','finite','integer','2d','>=',-255,'<=',255});
[row,col] = size(origin_E_I);
row1=row/h;%%块数
col1=col/w;
trandot=zeros(row,col);
origin_D_I=zeros(row,col);
trandot1=zeros(row1,col1);
n=0;
for i=1:row   
    for j=1:col   
        if origin_E_I(i,j)>128
            origin_D_I(i,j) = origin_E_I(i,j)-128;
            trandot(i,j)=1;
            n=n+1;
        elseif origin_E_I(i,j)<-127
            origin_D_I(i,j) = origin_E_I(i,j)+128;
            trandot(i,j)=1;
             n=n+1;
        else
            origin_D_I(i,j) = origin_E_I(i,j);
        end
    end
end
% for i=1:row1   %%不符合让rANS的编码会在高平面产生较大的值，尝试比较绝对值对其进行删减
%     for j=1:col1 
%         min_num=0;
%         max_num=0;
%         i_min=0;
%         j_min=0;
%         for x=(i-1)*h+1:i*h
%           for y=(j-1)*w+1:j*w
%               if  origin_D_I(x,y)>max_num
%                   max_num=origin_D_I(x,y);
%               end
%               if  origin_D_I(x,y)<min_num
%                   min_num=origin_D_I(x,y);
%                   i_min=x;
%                   j_min=y;
%               end
%           end
%         end
%               k=0;
%               for z=8:-1:1
%                    if max_num>=min_num&&max_num<=2^(z-1)&&min_num>=-(2^(z-1))
%                        k=z;%%确定范围
%                    end
%               end
%               if min_num==-(2^(k-1))&&max_num<=2^(k-1)-1&&min_num~=0
%                   trandot1(i,j)=1;
%                        for x=(i-1)*h+1:i*h
%                           for y=(j-1)*w+1:j*w
%                                  if origin_D_I(x,y)==-2^(k-1)
%                                      origin_D_I(x,y)=2^(k-1);
%                                  end
%                           end
%                        end
%               end
%     end
% end
asa=1;
