function f=security_features(I)
% Fixed before data collection; passive, inexpensive image-only detector.
I=double(I);v=I(:);hist=accumarray(v+1,1,[256 1])/numel(v);
means=mean(rem(floor(v./2.^(0:7)),2),1);
h=I(:,1:end-1);h2=I(:,2:end);q=I(1:end-1,:);q2=I(2:end,:);
f=[hist.',means,mean(v)/255,std(v)/128, ...
 mean(abs(h(:)-h2(:)))/255,mean(abs(q(:)-q2(:)))/255, ...
 mean((h(:)-127.5).*(h2(:)-127.5))/5461.25, ...
 mean((q(:)-127.5).*(q2(:)-127.5))/5461.25];
for a=1:4
 for b=1:4
  t=I((a-1)*128+(1:128),(b-1)*128+(1:128));
  f=[f,mean(t(:))/255,std(t(:))/128];
 end
end
% Public permutation is fixed by the current main (seed 123).
% This feature tests format distinguishability, not payload detection alone.
try
 [~,info]=scramble_blocks_within(zeros(size(I)),[16 16],123);
 U=unscramble_blocks_within(I,info);g=read_global_support(U,false);
 ok=g.h==16 && g.w==16 && g.layout.global_bits<numel(I)*8;
catch,ok=false;end
f=[f,double(ok)];
end
