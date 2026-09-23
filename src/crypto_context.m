function ctx=crypto_context()
% Prototype out-of-band context. Keys are secret; IVs and version are public.
% Generate independent keys and fresh IVs per image. No authentication tag.
if ispc
    % Windows OS CSPRNG. Java generateSeed can repeatedly collect entropy
    % very slowly; do not replace it with MATLAB rand/randi.
    provider=System.Security.Cryptography.RandomNumberGenerator.Create();
    bytes=NET.createArray('System.Byte',144);provider.GetBytes(bytes);
    raw=uint8(bytes);provider.Dispose();
else
    provider=java.security.SecureRandom();
    raw=typecast(provider.generateSeed(144),'uint8');
end
ctx=struct('version',2,'image_key',raw(1:32),'image_iv',raw(33:48), ...
    'data_key',raw(49:80),'data_iv',raw(81:96), ...
    'aux_key',raw(97:128),'aux_iv',raw(129:144));
% aux_key belongs to the image-recovery credential, not the data credential.
end
