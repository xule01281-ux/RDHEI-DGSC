function [D,encrypted_reference,layout]=extract_payload_secure(I,data_key,data_iv,payload_bits)
% Input is after public inverse permutation. Only the data credential needed.
layout=packet_bit_layout(I);
D=aes_ctr_bits(image_bits('get',I,layout.payload),data_key,data_iv);
if nargin>=4
 assert(payload_bits>=0 && payload_bits<=layout.payload_bits && payload_bits==fix(payload_bits));
 D=D(1:payload_bits);
end
encrypted_reference=image_bits('get',I,layout.reference);
end
