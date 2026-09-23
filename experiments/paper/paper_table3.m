function report=paper_table3(boss_dir,bows_dir,output_dir,stage,chunk,chunks,max_sources)
%PAPER_TABLE3 Original image IDs/split; 302 statistics plus format parser flag.
% Keys remain in memory. Fresh encryption changes features between new runs.
if nargin<3,output_dir=[];end
if nargin<4,stage='formal';end
if nargin<5,chunk=1;end
if nargin<6,chunks=2;end
if nargin<7,max_sources=Inf;end
validateattributes(chunks,{'numeric'},{'scalar','integer','positive'});
validateattributes(chunk,{'numeric'},{'scalar','integer','>=',1,'<=',chunks});
stage=validatestring(stage,{'pilot','formal'});
[root,output_dir]=paper_setup('table3',output_dir);
addpath(fullfile(root,'experiments','paper','detection'));
manifest=jsondecode(fileread(fullfile(root,'results','paper','table3','security_manifest.json')));
items=manifest.(stage);rows={};failures={};
dest=fullfile(output_dir,sprintf('security_%s_%d.json',stage,chunk));
if isfile(dest)
    previous=jsondecode(fileread(dest));
    assert(previous.chunks==chunks,'rdhei:ChunkSettings','Cannot resume using different partition settings.');
    if ~isempty(previous.rows),rows=num2cell(previous.rows);end
end
done=cellfun(@(r)r.id,rows,'UniformOutput',false);processed=0;
report=struct('stage',stage,'chunk',chunk,'chunks',chunks,'rows',{rows},'failures',{failures});
for j=chunk:chunks:numel(items)
    item=items(j);if any(strcmp(item.id,done)),continue;end
    if processed>=max_sources,break;end
    if strcmp(item.dataset,'BOSS'),folder=boss_dir;else,folder=bows_dir;end
    filename=fullfile(folder,item.filename);
    assert(isfile(filename),'rdhei:DatasetMissing','Missing %s',filename);
    fid=fopen(filename,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    assert(strcmp(paper_sha256(bytes),item.sha256),'rdhei:DatasetHash','Source file differs: %s',item.id);
    I=double(imread(filename));assert(isequal(size(I),[512 512]));
    D=zeros(1,8*numel(I));
    captured=evalc('p=prepare_packet(I,D,1,2,1,1,16,16,''entropy'');'); %#ok<NASGU>
    N=p.layout.payload_bits;features=security_features(p.ordinary_cipher);rates=[0 .25 .5 1];
    for r=1:4
        ctx=crypto_context();n=floor(rates(r)*N);plain=zeros(1,N);
        if n>0,plain(1:n)=aes_ctr_bits(zeros(1,n),ctx.image_key,ctx.image_iv);end
        bits=aes_ctr_bits(plain,ctx.data_key,ctx.data_iv);
        V=image_bits('set',p.before_scramble,p.layout.payload,bits);
        V=scramble_blocks_within(V,[16 16],123);
        features(r+1,:)=security_features(V);
    end
    rows{end+1}=struct('id',item.id,'dataset',item.dataset,'sha256',item.sha256, ...
        'split',item.split,'payload_bits',N,'protected_bits',numel(p.layout.protected), ...
        'global_bits',p.global_bits,'reference_count',p.prediction_reference.reference_count, ...
        'reference_bits',p.prediction_reference.reference_bits,'features',features); %#ok<AGROW>
    processed=processed+1;
    report=struct('stage',stage,'chunk',chunk,'chunks',chunks,'rows',{rows},'failures',{failures});
    rdhei_write_json(dest,report);
    fprintf('TABLE3 %s chunk %d/%d %s\n',stage,chunk,chunks,item.id);
end
end
