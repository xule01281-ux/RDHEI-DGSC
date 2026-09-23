function output=aes_ctr_bits(bits,key,iv)
% Length-preserving AES-CTR: MSB-first bit packing, discard unused tail bits.
% Each key/IV pair must be unique for a new message. XOR is its own inverse.
if isempty(bits),output=double(bits);return;end
validateattributes(bits,{'numeric','logical'},{'vector','binary'});
assert(isa(key,'uint8')||isa(key,'int8')); assert(numel(key)==32);
assert(isa(iv,'uint8')||isa(iv,'int8')); assert(numel(iv)==16);
n=numel(bits); z=zeros(ceil(n/8),1,'int8');
c=javax.crypto.Cipher.getInstance('AES/CTR/NoPadding');
c.init(javax.crypto.Cipher.ENCRYPT_MODE, ...
    javax.crypto.spec.SecretKeySpec(typecast(key(:),'int8'),'AES'), ...
    javax.crypto.spec.IvParameterSpec(typecast(iv(:),'int8')));
stream=typecast(c.doFinal(z),'uint8');
stream=reshape(rem(floor(double(stream(:))./2.^(7:-1:0)),2).',1,[]);
output=reshape(double(xor(logical(bits(:).'),logical(stream(1:n)))),size(bits));
end
