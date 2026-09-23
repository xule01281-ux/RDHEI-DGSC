function out=crypto_public_header(action,in)
% External 53-byte public header, not stored inside image pixels.
% 1 version + 3*16 IV bytes + 4 big-endian net payload length bytes.
if strcmp(action,'encode')
 n=double(in.payload_bits);assert(n>=0 && n<2^32 && n==fix(n));
 out=uint8([2,reshape(typecast(in.image_iv(:),'uint8'),1,[]), ...
  reshape(typecast(in.data_iv(:),'uint8'),1,[]), ...
  reshape(typecast(in.aux_iv(:),'uint8'),1,[]), ...
  mod(floor(n./2.^(24:-8:0)),256)]);
else
 assert(strcmp(action,'decode') && numel(in)==53 && in(1)==2);
 in=uint8(in(:).');
 out=struct('version',2,'image_iv',in(2:17),'data_iv',in(18:33), ...
  'aux_iv',in(34:49),'payload_bits',double(in(50:53))*2.^(24:-8:0).');
end
end
