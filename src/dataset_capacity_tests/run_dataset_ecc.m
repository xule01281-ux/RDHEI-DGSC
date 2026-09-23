function summaries=run_dataset_ecc(which_dataset,varargin)
% 数据集净ECC批处理。只有用户显式调用本函数才运行；不调用完整Encrypt_Embed。
% run_dataset_ecc                 % BOSSBase和BOWS2，默认各10000幅
% run_dataset_ecc('BOSSBase')     % 仅BOSSBase
% run_dataset_ecc('BOWS2')        % 仅BOWS2
% run_dataset_ecc('both','RetryFailed',true)
% 分段推荐使用run_dataset_ecc_part(1)、run_dataset_ecc_part(2)，最后merge_dataset_ecc。
% 同一OutputRoot重复调用自动续跑；首次运行时冻结代码快照。
if nargin<1,which_dataset='both';end
which_dataset=validatestring(which_dataset,{'both','BOSSBase','BOWS2'});
script_dir=fileparts(mfilename('fullpath'));project=fileparts(script_dir);
p=inputParser;
addParameter(p,'BossPath',fullfile(fileparts(project),'data','BOSSBase'),@(x)ischar(x)||isstring(x));
addParameter(p,'BowsPath',fullfile(fileparts(project),'data','BOWS2'),@(x)ischar(x)||isstring(x));
addParameter(p,'OutputRoot',fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'results','dataset_ecc'),@(x)ischar(x)||isstring(x));
addParameter(p,'BlockSize',16,@(x)isscalar(x)&&any(x==[8 16 32 64]));
addParameter(p,'PredictionMode','entropy',@(x)any(strcmp(x,{'entropy','sse'})));
addParameter(p,'MaxImages',Inf,@(x)isscalar(x)&&x>0&&(isinf(x)||x==fix(x)));
addParameter(p,'StartIndex',1,@(x)isscalar(x)&&isfinite(x)&&x>=1&&x==fix(x));
addParameter(p,'EndIndex',Inf,@(x)isscalar(x)&&x>=1&&(isinf(x)||x==fix(x)));
addParameter(p,'SaveEvery',100,@(x)isscalar(x)&&x>=1&&x==fix(x));
addParameter(p,'RetryFailed',false,@(x)islogical(x)&&isscalar(x));
parse(p,varargin{:});o=p.Results;
output=absolute_path(char(o.OutputRoot));
if ~isfolder(output),mkdir(output);end
% Java目录的原子创建防止两个进程同时写同一结果目录。
lockdir=fullfile(output,'.running_lock');lock=java.io.File(lockdir);
assert(lock.mkdir(),'DatasetECC:Locked','Output directory is in use. If an earlier process crashed, confirm it has stopped before removing %s.',lockdir);
lock_cleanup=onCleanup(@()release_lock(lockdir));
snapshot=prepare_snapshot(project,script_dir,output);
old_path=path;old_dir=pwd;
path_cleanup=onCleanup(@()restore_environment(old_path,old_dir));
addpath(script_dir);addpath(snapshot,'-begin');cd(snapshot);
assert(strcmp(which('dataset_capacity_only'),fullfile(snapshot,'dataset_capacity_only.m')));
assert(strcmp(which('deviate'),fullfile(snapshot,'deviate.m')));
dataset_names={'BOSSBase','BOWS2'};dataset_paths={char(o.BossPath),char(o.BowsPath)};
stop_path=fullfile(output,'STOP');
for d=1:2
    if ~strcmp(which_dataset,'both') && ~strcmp(which_dataset,dataset_names{d}),continue;end
    label=dataset_names{d};folder=absolute_path(dataset_paths{d});
    assert(isfolder(folder),'DatasetECC:Folder','Dataset folder does not exist: %s',folder);
    files=dir(fullfile(folder,'*.pgm'));
    assert(~isempty(files),'DatasetECC:Empty','No PGM files in %s',folder);
    [~,ord]=sort(lower(string({files.name})));files=files(ord);
    ids=cellfun(@(n)str2double(n(1:end-4)),{files.name});
    if all(isfinite(ids)),[~,ord]=sort(ids);files=files(ord);end
    all_count=numel(files);
    if all_count~=10000,warning('DatasetECC:Count','%s contains %d PGM files (expected 10000). Counts will be reported explicitly.',label,all_count);end
    % 索引基于完整数据集的数字排序；MaxImages仅限制所选区间的张数。
    catalog_names={files.name};catalog_bytes=[files.bytes];catalog_dates=[files.datenum];
    dataset_indices=dataset_ecc_select_indices(all_count,o.StartIndex,o.EndIndex,o.MaxImages);
    files=files(dataset_indices);N=numel(files);
    dest=fullfile(output,label);if ~isfolder(dest),mkdir(dest);end
    config=struct('format_version',2,'dataset',label,'folder',folder,'dataset_file_count',all_count, ...
        'planned_images',N,'filenames',{{files.name}},'bytes',[files.bytes], ...
        'modified_datenum',[files.datenum],'dataset_indices',dataset_indices, ...
        'catalog_filenames',{catalog_names},'catalog_bytes',catalog_bytes, ...
        'catalog_modified_datenum',catalog_dates,'block_size',[o.BlockSize o.BlockSize], ...
        'prediction_mode',char(o.PredictionMode),'expected_image_size',[512 512], ...
        'capacity_definition','Net in-image secret bits / original pixel count', ...
        'external_public_header_bytes',53,'encryption_embedding_scrambling_recovery',false);
    config_file=fullfile(dest,'manifest.mat');
    if isfile(config_file)
        saved=load(config_file,'config');
        assert(isequaln(config,saved.config),'DatasetECC:ResumeConfig', ...
            'Image list, file size/time or parameters changed. Use a different OutputRoot for a new experiment.');
    else
        save(config_file,'config');write_json(fullfile(dest,'manifest.json'),config);
    end
    journal=fullfile(dest,'per_image.jsonl');
    [records,valid_text]=dataset_ecc_load_journal(journal,{files.name});
    if isfile(journal),write_text_atomic(journal,valid_text);end
    dataset_ecc_export(output,records,config);
    fprintf('\n%s: %d/%d images already recorded. Output: %s\n',label,nnz(~cellfun(@isempty,records)),N,dest);
    started=tic;new_count=0;
    for i=1:N
        if isfile(stop_path),fprintf('STOP file found. Progress saved; remove STOP before continuing.\n');break;end
        if ~isempty(records{i}) && (strcmp(records{i}.status,'ok') || ~o.RetryFailed),continue;end
        f=files(i);[~,image_id]=fileparts(f.name);full=fullfile(folder,f.name);
        row=dataset_ecc_empty_row();row.index=i;row.dataset_index=dataset_indices(i);
        row.dataset=label;row.image_id=image_id;row.filename=f.name;
        row.path=full;row.timestamp=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
        timer=tic;
        try
            st=dir(full);
            assert(st.bytes==f.bytes && st.datenum==f.datenum,'DatasetECC:ImageChanged','Image changed during this run.');
            row.sha256=sha256(full);
            I=imread(full);
            assert(isa(I,'uint8') && ismatrix(I) && isequal(size(I),[512 512]), ...
                'DatasetECC:InputFormat','Expected a 512x512 uint8 grayscale image; no automatic conversion or resizing is applied.');
            row.pixels=numel(I);
            % 捕获原函数打印，日志只保留逐图摘要；没有生成秘密载荷或调用加密器。
            captured=evalc('result=dataset_capacity_only(double(I),o.BlockSize,o.BlockSize,o.PredictionMode);'); %#ok<NASGU>
            keys=fieldnames(result);
            for k=1:numel(keys),row.(keys{k})=result.(keys{k});end
            row.status='ok';
        catch err
            row.status='failed';row.error_id=err.identifier;row.error_message=err.message;
            error_dir=fullfile(dest,'errors');if ~isfolder(error_dir),mkdir(error_dir);end
            write_text_atomic(fullfile(error_dir,sprintf('%05d.txt',i)),getReport(err,'extended','hyperlinks','off'));
        end
        row.attempt_seconds=toc(timer);
        append_record(journal,row); % 先落盘，再更新内存；Ctrl+C后也能从上一张续跑。
        records{i}=row;new_count=new_count+1;
        if strcmp(row.status,'ok')
            fprintf('%s [%d/%d; dataset index=%d] id=%s bits=%d ECC=%.6f seconds=%.3f\n',label,i,N,row.dataset_index,image_id,row.payload_bits,row.ecc_bpp,row.capacity_seconds);
        else
            fprintf('%s [%d/%d] id=%s FAILED: %s\n',label,i,N,image_id,row.error_id);
        end
        if mod(new_count,o.SaveEvery)==0
            dataset_ecc_export(output,records,config);
            fprintf('Saved %d new records; wall time %.1f min.\n',new_count,toc(started)/60);
        end
    end
    dataset_ecc_export(output,records,config);
    if isfile(stop_path),break;end
end
summaries=dataset_ecc_export(output);
fprintf('Results saved to %s\n',output);
end

function snapshot=prepare_snapshot(project,script_dir,output)
snapshot=fullfile(output,'source_snapshot');manifest=fullfile(output,'source_manifest.json');
runner_digest=sha256(fullfile(script_dir,'run_dataset_ecc.m'));
if isfile(manifest)
    m=jsondecode(fileread(manifest));
    assert(strcmp(m.runner_sha256,runner_digest),'DatasetECC:RunnerChanged','Runner changed; use a new OutputRoot.');
    for k=1:numel(m.files)
        assert(strcmp(sha256(fullfile(snapshot,m.files(k).name)),m.files(k).sha256), ...
            'DatasetECC:SnapshotChanged','Snapshot was modified: %s',m.files(k).name);
    end
    return;
end
assert(~isfolder(snapshot),'DatasetECC:IncompleteSnapshot','Incomplete snapshot exists; choose a new OutputRoot.');
mkdir(snapshot);
files=dir(fullfile(project,'*.m'));
helpers={'dataset_capacity_only.m','dataset_ecc_summary.m','dataset_ecc_load_journal.m', ...
    'dataset_ecc_select_indices.m','dataset_ecc_empty_row.m','dataset_ecc_export.m'};
entries=struct('name',{},'sha256',{});
for k=1:numel(files)
    copyfile(fullfile(project,files(k).name),fullfile(snapshot,files(k).name));
    entries(end+1)=struct('name',files(k).name,'sha256',sha256(fullfile(snapshot,files(k).name))); %#ok<AGROW>
end
for k=1:numel(helpers)
    copyfile(fullfile(script_dir,helpers{k}),fullfile(snapshot,helpers{k}));
    entries(end+1)=struct('name',helpers{k},'sha256',sha256(fullfile(snapshot,helpers{k}))); %#ok<AGROW>
end
copyfile(fullfile(script_dir,'run_dataset_ecc.m'),fullfile(output,'run_dataset_ecc_saved.m'));
m=struct('created',char(datetime('now')),'project',project,'runner_sha256',runner_digest, ...
    'matlab_version',version,'computer',computer,'files',entries);
write_json(manifest,m);
end

function append_record(f,row)
fid=fopen(f,'a','n','UTF-8');assert(fid>=0,'DatasetECC:Write','Cannot open %s',f);
c=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(row));
end
function write_json(f,value)
write_text_atomic(f,jsonencode(value,PrettyPrint=true));
end
function write_text_atomic(f,value)
temp=[tempname(fileparts(f)),'.tmp'];
fid=fopen(temp,'w','n','UTF-8');assert(fid>=0,'DatasetECC:Write','Cannot open %s',temp);
try
    fprintf(fid,'%s',value);fclose(fid);
catch err
    fclose(fid);rethrow(err);
end
movefile(temp,f,'f');
end
function h=sha256(f)
fid=fopen(f,'rb');assert(fid>=0,'DatasetECC:Read','Cannot read %s',f);
c=onCleanup(@()fclose(fid));
bytes=fread(fid,Inf,'*uint8');md=java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(bytes(:),'int8'));digest=typecast(md.digest(),'uint8');
h=lower(reshape(dec2hex(digest,2).',1,[]));
end
function p=absolute_path(p)
p=char(java.io.File(p).getCanonicalPath());
end
function release_lock(p)
if isfolder(p),rmdir(p);end
end
function restore_environment(p,d)
cd(d);path(p);
end
