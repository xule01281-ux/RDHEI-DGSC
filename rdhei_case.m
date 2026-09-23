function [summary,images,detail]=rdhei_case(I,options)
%RDHEI_CASE Complete embedding, extraction and pixel-exact reconstruction.
% Input must be an 8-bit grayscale image. Defaults match the current main chain.
% Sender arrays are retained solely for the production assertions.
if nargin<2,options=struct();end
defaults=struct('BlockSize',16,'PredictionMode','entropy','PayloadBits',Inf, ...
    'PayloadSeed',20260920,'Crypto',[],'Quiet',true);
assert(isstruct(options)&&isscalar(options),'rdhei:Options','Expected scalar options struct.');
fields=fieldnames(options);
for k=1:numel(fields)
    assert(isfield(defaults,fields{k}),'rdhei:Options','Unknown option: %s',fields{k});
    defaults.(fields{k})=options.(fields{k});
end
o=defaults;rdhei_setup();
validateattributes(I,{'numeric'},{'2d','nonempty','real','finite','integer','>=',0,'<=',255});
validateattributes(o.BlockSize,{'numeric'},{'scalar','integer','positive'});
assert(ismember(o.BlockSize,[8 16 32 64]),'rdhei:BlockSize','Supported square sizes: 8,16,32,64.');
assert(all(mod(size(I),o.BlockSize)==0),'rdhei:ImageSize','Dimensions must be divisible by block size.');
assert(isscalar(o.PayloadBits)&&o.PayloadBits>=0&&(isinf(o.PayloadBits)||o.PayloadBits==fix(o.PayloadBits)), ...
    'rdhei:PayloadBits','Invalid payload length.');
mode=validatestring(o.PredictionMode,{'entropy','sse'});
previous_rng=rng;cleanup=onCleanup(@()rng(previous_rng));
rng(o.PayloadSeed,'twister');
D=double(randi([0 1],1,min(o.PayloadBits,8*numel(I))));
wall=tic;
if o.Quiet
    log_text=evalc('[cipher,stego,embedded,~,extracted,validation,crypto,recovered]=Encrypt_Embed(double(I),D,1,2,1,1,o.BlockSize,o.BlockSize,mode,o.Crypto);');
else
    [cipher,stego,embedded,~,extracted,validation,crypto,recovered]=Encrypt_Embed(double(I),D,1,2,1,1,o.BlockSize,o.BlockSize,mode,o.Crypto);
    log_text='';
end
roundtrip_seconds=toc(wall);
assert(isequal(uint8(recovered),uint8(I))&&isequal(extracted,embedded),'rdhei:Roundtrip','Round trip differs.');
summary=struct('image_size',size(I),'block_size',o.BlockSize,'prediction_mode',mode, ...
    'payload_bits',numel(embedded),'ecc_bpp',numel(embedded)/numel(I), ...
    'maximum_payload_bits',validation.capacity.maximum_payload_bits, ...
    'maximum_ecc_bpp',validation.capacity.maximum_payload_bits/numel(I), ...
    'external_public_header_bytes',numel(crypto.public_header), ...
    'forward_seconds',validation.capacity.forward_seconds,'roundtrip_seconds',roundtrip_seconds, ...
    'payload_ok',validation.payload_ok,'auxiliary_ok',validation.auxiliary_ok, ...
    'image_recovery_ok',validation.image_recovery_ok,'scramble_ok',validation.scramble_ok, ...
    'image_pixel_mismatches',validation.image_pixel_mismatches, ...
    'image_max_pixel_error',validation.image_max_pixel_error, ...
    'fold_map_bits',validation.capacity.fold_map_bits,'skipped_blocks',validation.capacity.skipped_blocks, ...
    'global_auxiliary_bits',validation.capacity.global_auxiliary_bits,'padding_bits',validation.padding_bits);
images=struct('original',uint8(I),'cipher',uint8(cipher),'stego',uint8(stego),'recovered',uint8(recovered));
% Credentials are returned in memory for local experiments, never written by main.
detail=struct('validation',validation,'crypto',crypto,'embedded',embedded,'extracted',extracted,'log',log_text);
end
