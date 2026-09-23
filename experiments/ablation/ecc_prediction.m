function [E,pred_ref,meta]=ecc_prediction(I,cfg,upper,lower)
% Forward-only prediction and actual auxiliary bits. No receiver call.
[H,W]=size(I); sigma=std(I(:));
initial=Copy_of_Predictor_Value2(I,1,1,1,1,1,1,1,1,sigma,1,1);
mass=(initial-I).^2; [C,R]=meshgrid(1:W,1:H); total=sum(mass(:)); assert(isfinite(total));
if total==0, split=round([H W]/2);
else, split=round([sum(mass(:).*R(:)),sum(mass(:).*C(:))]/total); end
split=max([2 2],min([H-1 W-1],split)); if isfield(cfg,'split'),split=cfg.split;end
radius=min(H,W)*.25;
ratio=sum(mass((R-split(1)).^2+(C-split(2)).^2<=radius^2))/(total+eps);
if ratio>upper, pattern=1; elseif ratio<lower, pattern=2; else, pattern=0; end
[gh,gv,gd,gs]=calc_global_gradients(I);
[P,~,info,~,stats]=scec_no_extreme_predictor(I,split(1),split(2),gh,gv,gd,gs, ...
    sigma,pattern,radius,'entropy',cfg);
assert(all(isfinite(P(:))) && all(P(:)==round(P(:)))); E=P-I;
dirs=zeros(1,4); labels={'TL','TR','BL','BR'};
for k=1:4, dirs(k)=find(strcmp(info(k).Dir,labels))-1; end
state=struct('mode',0,'split',split,'dirs',dirs,'GlobalPattern',pattern,'block_stats',stats);
pos=prediction_reference_layout([H W],split,dirs); state.val=I(pos);
[bits,pred_ref]=prediction_reference_codec('encode',state,[H W]); pred_ref.bits=bits;
meta=struct('split',split,'pattern',pattern,'center_energy_ratio',ratio, ...
    'directions',dirs,'residual_std',std(E(:)),'residual_mae',mean(abs(E(:))), ...
    'residual_rmse',sqrt(mean(E(:).^2)),'residual_min',min(E(:)),'residual_max',max(E(:)), ...
    'diagnostics',sum(vertcat(info.Diagnostics),1));
end
