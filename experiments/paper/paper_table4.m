function report=paper_table4(image_dir,output_dir,N,image_indices)
if nargin<1,image_dir=[];end
if nargin<2,output_dir=[];end
if nargin<3,N=5;end
if nargin<4,image_indices=1:4;end
validateattributes(N,{'numeric'},{'scalar','integer','positive'});
% Table 4: actual full-chain images, independent OS-random credentials.
% This runner does not alter the prediction, coding or recovery implementation.
[release,out]=paper_setup('table4',output_dir);
[paths,~]=paper_inputs(image_dir);
paths=paths([3 2 4 1]);
assert(strcmp(which('Encrypt_Embed'),fullfile(release,'src','Encrypt_Embed.m')));

labels={'Baboon','Jetplane','Tiffany','Man'};
files={'Baboon.tiff','Jetplane.tiff','Tiffany.tiff','11.png'};
rows=struct([]);
meta=struct('started',datestr(now,31),'matlab_version',version,'release','RDHEI-DGSC v1.1.0 paper archive', ...
    'repetitions',N,'block_size',16,'prediction_mode','entropy','payload','full capacity', ...
    'payload_seed',20260920,'crypto','fresh independent OS CSPRNG keys and IVs each run', ...
    'cipher_stage','AES encryption of transformed carrier, before auxiliary/payload insertion and scrambling', ...
    'stego_stage','final marked image after auxiliary protection and scrambling', ...
    'reference','original uint8 input at the same image coordinates', ...
    'ssim','MATLAB ssim(uint8_image,uint8_original), DynamicRange=255, default Gaussian local window', ...
    'psnr','10*log10(255^2 / mean((image-original).^2))', ...
    'mae','mean(abs(double(image)-double(original)))', ...
    'entropy','256-bin empirical Shannon entropy, log base 2, bit/pixel');
for k=image_indices
    I=imread(paths{k});
    assert(isa(I,'uint8')&&ismatrix(I)&&isequal(size(I),[512 512]));
    for rep=1:N
        fprintf('START %s repetition=%d/%d\n',labels{k},rep,N);
        [s,images,detail]=rdhei_case(I,struct('PayloadSeed',20260920));
        assert(s.image_recovery_ok&&s.payload_ok&&s.auxiliary_ok&&s.scramble_ok);
        assert(isequal(images.recovered,I)&&isequal(detail.embedded,detail.extracted));
        row=struct('image',labels{k},'filename',files{k},'repetition',rep, ...
            'original_entropy',H(I),'cipher',measure(images.cipher,I), ...
            'marked',measure(images.stego,I),'recovered',measure(images.recovered,I), ...
            'summary',s,'image_sha256',hash_bytes(I(:)), ...
            'cipher_sha256',hash_bytes(images.cipher(:)), ...
            'marked_sha256',hash_bytes(images.stego(:)), ...
            'credentials_sha256',hash_bytes([detail.crypto.image_key,detail.crypto.image_iv, ...
                detail.crypto.data_key,detail.crypto.data_iv,detail.crypto.aux_key,detail.crypto.aux_iv]));
        rows=append(rows,row);
        save(fullfile(out,'table4_raw.mat'),'meta','rows');
        rdhei_write_json(fullfile(out,'table4_raw.json'),struct('meta',meta,'rows',rows));
        fprintf('PASS %s rep=%d bits=%d cipher PSNR=%.6f marked PSNR=%.6f recovery errors=%d\n', ...
            labels{k},rep,s.payload_bits,row.cipher.psnr_db,row.marked.psnr_db,s.image_pixel_mismatches);
    end
end
assert(numel(unique({rows.credentials_sha256}))==numel(rows));
meta.finished=datestr(now,31);meta.all_20_roundtrips_passed=numel(rows)==20 && N==5;meta.all_roundtrips_passed=true;meta.image_indices=image_indices;
save(fullfile(out,'table4_raw.mat'),'meta','rows');
rdhei_write_json(fullfile(out,'table4_raw.json'),struct('meta',meta,'rows',rows));
report=struct('meta',meta,'rows',rows);
fprintf('TABLE4 COMPLETE: %d runs, all payload and original-image checks passed.\n',numel(rows));
end
function r=measure(A,I)
d=double(A)-double(I);mse=mean(d(:).^2);
if mse==0,psnr_db=Inf;else,psnr_db=10*log10(255^2/mse);end
r=struct('psnr_db',psnr_db,'psnr_is_infinite',isinf(psnr_db), ...
    'ssim',ssim(A,I,'DynamicRange',255),'entropy',H(A),'mae',mean(abs(d(:))), ...
    'mse',mse,'pixel_mismatches',nnz(A~=I));
end
function h=H(A)
c=accumarray(double(A(:))+1,1,[256 1]);p=c(c>0)/numel(A);h=-sum(p.*log2(p));
end
function h=hash_bytes(data)
digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(typecast(uint8(data(:)),'int8'));
bytes=typecast(digest.digest(),'uint8');h=lower(reshape(dec2hex(bytes,2).',1,[]));
end
function a=append(a,r)
if isempty(a),a=r;else,a(end+1)=r;end
end
