function [out,meta]=attack_image(im,c,seed)
stream=RandStream('mt19937ar','Seed',seed);out=im;area=0;side=0;
switch c.attack
    case 'control'
    case 'bitflip'
        idx=randperm(stream,numel(im)*8,c.level);pix=floor((idx-1)/8)+1;bit=mod(idx-1,8)+1;
        for q=1:numel(idx),out(pix(q))=bitxor(out(pix(q)),bitshift(uint8(1),bit(q)-1));end
    case 'gaussian'
        out=uint8(min(255,max(0,round(double(im)+c.level*randn(stream,size(im))))));
    case 'crop_zero'
        % Central square deletion on the original-size canvas. No resizing.
        side=round(sqrt(c.level*numel(im)));r=floor((size(im,1)-side)/2)+1;
        col=floor((size(im,2)-side)/2)+1;out(r:r+side-1,col:col+side-1)=0;
        area=side^2/numel(im);
    case 'translate'
        % Right shift; crop overflow and fill exposed columns with zero.
        d=c.level;out(:)=0;out(:,d+1:end)=im(:,1:end-d);area=d/size(im,2);
    otherwise,error('Unknown attack');
end
x=bitxor(out,im);changed_bits=0;
for b=1:8,changed_bits=changed_bits+nnz(bitget(x,b));end
meta=struct('changed_pixels',nnz(out~=im),'changed_bits',changed_bits, ...
    'affected_area_fraction',area,'crop_square_side',side,'noise_sigma_gray_levels',0);
if strcmp(c.attack,'gaussian'),meta.noise_sigma_gray_levels=c.level;end
end
