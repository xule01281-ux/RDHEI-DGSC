function report=paper_table12(image_dir,output_dir,scope,image_indices)
if nargin<1,image_dir=[];end
if nargin<2,output_dir=[];end
if nargin<3,scope='full';end
if nargin<4,image_indices=1:4;end
scope=validatestring(scope,{'full','smoke'});
[package,output_dir]=paper_setup('table12',output_dir);
addpath(fullfile(package,'experiments','damage'));
[paths,~]=paper_inputs(image_dir);
names={'11.png','Jetplane.tiff','Baboon.tiff','Tiffany.tiff'};
labels={'Man','Jetplane','Baboon','Tiffany'};
rng(20260919,'twister');D=double(randi([0 1],1,8*512*512));
cases=struct('attack','control','level',0,'repeat',1);
ids={'bitflip','gaussian','crop_zero','translate'};
levels={[1 10 100],[.5 1 2],[.01 .05 .10],[1 2 4]};
for a=1:4
 repeats=1;if a<=2,repeats=5;end
 for level=levels{a}
  for rep=1:repeats,cases(end+1)=struct('attack',ids{a},'level',level,'repeat',rep);end
 end
end
if strcmp(scope,'smoke'),cases=cases([1 2]);end
rows=struct([]);baselines=struct([]);
for k=image_indices
 I=double(imread(paths{k}));
 captured=evalc('packet=retest_prepare(I,D,1,2,1,1,16,16,''entropy'');'); %#ok<NASGU>
 assert(packet.baseline_validation.image_recovery_ok&&packet.baseline_validation.payload_ok);
 baselines=[baselines struct('image',labels{k},'payload_bits',numel(packet.payload), ...
  'ecc_bpp',numel(packet.payload)/numel(packet.original),'public_bytes',numel(packet.crypto.public_header))];
 for j=1:numel(cases)
  c=cases(j);seed=20260919+10000*k+100*j;
  [received,meta]=attack_image(packet.stego,c,seed);
  captured=evalc('result=decode_received(received,packet);');
  row=struct('image',labels{k},'attack',c.attack,'level',c.level,'repeat',c.repeat,'seed',seed, ...
   'payload_bits',numel(packet.payload),'metadata',meta,'result',result);
  rows=[rows row];
  report=struct('created',char(datetime('now')),'code_version','current protected auxiliary v2', ...
   'baseline',baselines,'rows',rows,'public_header_intact',true,'production_assertions_retained',true, ...
   'image_success_definition','All retained production checks pass and every original pixel matches.');
  report.scope=scope;report.image_indices=image_indices;report.recovery_timeout_seconds=30;
  rdhei_write_json(fullfile(output_dir,'damage.json'),report);
  fprintf('DAMAGE %s %s %g rep%d extract%d payload%d image%d joint%d stage=%s\n', ...
   labels{k},c.attack,c.level,c.repeat,result.extraction_completed,result.payload_exact,result.image_exact,result.joint_exact,result.failure_stage);
  if strcmp(c.attack,'control'),assert(result.joint_exact,'Control failed');end
 end
end
save(fullfile(output_dir,'damage.mat'),'report');fprintf('DAMAGE DONE %d cases\n',numel(rows));
end

function result=decode_received(received,p)
global RETEST_TIMER
RETEST_TIMER=tic;timer=tic;
result=struct('extraction_completed',false,'payload_length_match',false,'payload_exact',false, ...
 'payload_bit_errors',NaN,'payload_ber',NaN,'recovery_attempted',false,'recovery_completed',false, ...
 'image_exact',false,'pixel_mismatches',NaN,'image_psnr_db',NaN,'joint_exact',false, ...
 'failure_stage','','extraction_error','','recovery_error','','error_message','', ...
 'reference_exact',false);
try
 image=unscramble_blocks_within(double(received),p.scramble_info);
 public=crypto_public_header('decode',p.crypto.public_header);
 [decoded,~,layout]=extract_payload_secure(image,p.crypto.data_key,public.data_iv,public.payload_bits);
 result.extraction_completed=true;result.payload_length_match=numel(decoded)==numel(p.payload);
 if result.payload_length_match
  result.payload_bit_errors=nnz(decoded(:)~=p.payload(:));result.payload_ber=result.payload_bit_errors/numel(p.payload);
  result.payload_exact=result.payload_bit_errors==0;
 end
catch ME
 result.failure_stage='payload_parse';result.extraction_error=ME.identifier;result.error_message=ME.message;
end
% Recovery is attempted even when plaintext payload differs. No truth replaces
% received values. Original sender-truth assertions are retained in recovery.
try
 result.recovery_attempted=true;
 if ~exist('image','var'),error('Retest:Unscramble','No inverse permutation output');end
 if ~exist('layout','var'),layout=packet_bit_layout(image);end
 image=protect_recovery_fields(image,p.crypto,layout);
 ref_data=image_bits('get',image,layout.reference);
 result.reference_exact=isequal(ref_data(:),p.AI_sum(:));
 restored=retest_recover(image,1,ref_data,[],p.bit_max,p.image_test,p.LSIb,p.image_encrypt_I1, ...
  p.PFA_END,p.ecc,p.origin_D_I,p.PFA,0,[],p.select_blocked1,[],p.origin_E_I,[], ...
  p.crypto.image_key,p.crypto.image_iv,p.scrambleMap,true);
 result.recovery_completed=true;
 delta=double(restored)-double(p.original);result.pixel_mismatches=nnz(delta);result.image_exact=~any(delta(:));
 mse=mean(delta(:).^2);if mse==0,result.image_psnr_db=Inf;else,result.image_psnr_db=10*log10(255^2/mse);end
catch ME
 if isempty(result.failure_stage),result.failure_stage='image_decode';end
 result.recovery_error=ME.identifier;result.error_message=[result.error_message ' | ' ME.message];
end
result.joint_exact=result.payload_exact&&result.image_exact;
result.seconds=toc(timer);RETEST_TIMER=[];
end
