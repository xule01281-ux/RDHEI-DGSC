function output=image_bits(action,I,ids,values)
% Gather/scatter MSB-first bits; preserves all unrelated image bits.
if strcmp(action,'get')
 p=floor((ids-1)/8)+1;b=8-mod(ids-1,8);
 output=double(bitget(uint8(I(p)),b));return;
end
assert(strcmp(action,'set') && numel(ids)==numel(values));
bits=reshape(rem(floor(double(I(:))./2.^(7:-1:0)),2).',[],1);
bits(ids)=uint8(values);
output=reshape(double(reshape(bits,8,[]).')*2.^(7:-1:0).',size(I));
end
