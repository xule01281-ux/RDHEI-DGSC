function Encrypt_D=Encrypt_Data(D,Data_key)
% Data_key is a credential struct, never a MATLAB RNG seed.
assert(isstruct(Data_key) && isfield(Data_key,'key') && isfield(Data_key,'iv'), ...
 'Encrypt_Data:Credential','Provide a 32-byte AES key and 16-byte IV.');
Encrypt_D=aes_ctr_bits(D,Data_key.key,Data_key.iv);
end
