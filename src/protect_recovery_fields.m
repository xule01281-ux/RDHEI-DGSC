function [I,layout]=protect_recovery_fields(I,ctx,layout)
% Symmetric protection; public location/length metadata remains readable.
if nargin<3,layout=packet_bit_layout(I);end
bits=image_bits('get',I,layout.protected);
I=image_bits('set',I,layout.protected,aes_ctr_bits(bits,ctx.aux_key,ctx.aux_iv));
end
