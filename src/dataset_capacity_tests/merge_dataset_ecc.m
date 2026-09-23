function summaries=merge_dataset_ecc(input_roots,output,which_dataset)
% 合并独立分段的逐图净ECC结果；不读图、不调用预测或编码函数。
% merge_dataset_ecc   % 默认合并run_dataset_ecc_part(1/2)生成的两个数据集结果
% merge_dataset_ecc({part1_root,part2_root},merged_root,'BOSSBase')
% 要求分段完整覆盖数据集且每张均有记录；失败项保留，不能充当0容量。
if nargin<1 || isempty(input_roots)
    input_roots={fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'results','dataset_part1'), ...
        fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'results','dataset_part2')};
end
if nargin<2 || isempty(output),output=fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'results','dataset_merged');end
if nargin<3,which_dataset='both';end
which_dataset=validatestring(which_dataset,{'both','BOSSBase','BOWS2'});
input_roots=cellstr(string(input_roots));
assert(numel(input_roots)>=2,'DatasetECC:MergeInputs','Provide at least two segment directories.');
input_roots=cellfun(@absolute_path,input_roots,'UniformOutput',false);output=absolute_path(output);
assert(numel(unique(lower(string(input_roots))))==numel(input_roots),'DatasetECC:DuplicateRoot','Duplicate input directory.');
assert(~any(strcmpi(output,input_roots)),'DatasetECC:MergeOutput','Merged output must differ from source directories.');
% 与批处理使用同一个原子锁，合并时不读取正在写入的记录。
locks=cell(1,numel(input_roots));source=cell(size(input_roots));
for p=1:numel(input_roots)
    root=input_roots{p};assert(isfolder(root),'DatasetECC:MergeInput','Missing directory: %s',root);
    lockdir=fullfile(root,'.running_lock');lock=java.io.File(lockdir);
    assert(lock.mkdir(),'DatasetECC:Locked','Segment is running or has a stale lock: %s',root);
    locks{p}=onCleanup(@()release_lock(lockdir));
    source{p}=verify_source(root);
    if p>1
        assert(isequaln(source{1},source{p}),'DatasetECC:SourceMismatch', ...
            'Source snapshot, runner or MATLAB environment differs between segments.');
    end
end
labels={'BOSSBase','BOWS2'};if ~strcmp(which_dataset,'both'),labels={which_dataset};end
configs=cell(size(labels));merged=cell(size(labels));
% 先完成全部校验，再产生合并输出。索引与文件编号独立核对，拒绝交叠和遗漏。
for d=1:numel(labels)
    label=labels{d};coverage=[];records={};reference=[];
    for p=1:numel(input_roots)
        dest=fullfile(input_roots{p},label);file=fullfile(dest,'manifest.mat');
        assert(isfile(file),'DatasetECC:MergeManifest','Missing segment manifest: %s',file);
        saved=load(file,'config');c=saved.config;validate_config(c,label);
        if p==1
            reference=c;coverage=false(1,c.dataset_file_count);records=cell(size(coverage));
        else
            compare_config(reference,c);
        end
        idx=c.dataset_indices;
        assert(~any(coverage(idx)),'DatasetECC:Overlap','Overlapping ranges for %s.',label);
        coverage(idx)=true;
        local=dataset_ecc_load_journal(fullfile(dest,'per_image.jsonl'),c.filenames);
        for j=1:numel(local)
            if isempty(local{j}),continue;end
            row=local{j};[~,id]=fileparts(c.filenames{j});
            assert(row.dataset_index==idx(j) && strcmp(row.dataset,label) && strcmp(row.image_id,id), ...
                'DatasetECC:RecordMismatch','Image identity mismatch in %s, local index %d.',dest,j);
            if strcmp(row.status,'ok')
                assert(isscalar(row.payload_bits) && isfinite(row.payload_bits) && row.payload_bits>=0 && ...
                    row.payload_bits==fix(row.payload_bits) && row.pixels==prod(c.expected_image_size) && ...
                    isscalar(row.ecc_bpp) && abs(row.ecc_bpp-row.payload_bits/row.pixels)<1e-12, ...
                    'DatasetECC:InvalidRecord','Invalid successful capacity record: %s',row.filename);
                assert(~isempty(regexp(row.sha256,'^[0-9a-f]{64}$','once')), ...
                    'DatasetECC:InvalidRecord','Successful record has no valid image SHA-256: %s',row.filename);
            end
            row.index=idx(j);records{idx(j)}=row;
        end
    end
    assert(all(coverage),'DatasetECC:Gap','%s: %d images are not covered by the supplied segments.',label,nnz(~coverage));
    pending=cellfun(@isempty,records);
    assert(~any(pending),'DatasetECC:Pending','%s: %d images have no completed record. Resume segments before merging.',label,nnz(pending));
    c=reference;c.folder=''; % 原始路径在逐图path中保留，避免误称所有图来自同一机器目录。
    c.planned_images=c.dataset_file_count;c.dataset_indices=1:c.dataset_file_count;
    c.filenames=c.catalog_filenames;c.bytes=c.catalog_bytes;c.modified_datenum=c.catalog_modified_datenum;
    c.merged_from=input_roots;configs{d}=c;merged{d}=records;
end
provenance=struct('input_roots',{input_roots},'datasets',{labels},'source_signature',source{1});
% 允许同一组分段重试失败后再次合并，不允许覆盖普通批处理目录或其他实验。
if isfolder(output)
    existing=fullfile(output,'merge_manifest.json');
    assert(isfile(existing),'DatasetECC:MergeOutput','Existing output is not a merge directory; use a new destination.');
    prior=jsondecode(fileread(existing));
    assert(isequal(string(prior.input_roots(:)),string(input_roots(:))) && ...
        isequal(string(prior.datasets(:)),string(labels(:))) && isequaln(prior.source_signature,source{1}), ...
        'DatasetECC:MergeOutput','Output belongs to a different merge; use a new destination.');
else
    mkdir(output);
end
lockdir=fullfile(output,'.running_lock');lock=java.io.File(lockdir);
assert(lock.mkdir(),'DatasetECC:Locked','Merged output is already in use: %s',output);
output_lock=onCleanup(@()release_lock(lockdir));
provenance.updated=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
write_json(fullfile(output,'merge_manifest.json'),provenance);
for d=1:numel(labels)
    config=configs{d};records=merged{d};dest=fullfile(output,labels{d});if ~isfolder(dest),mkdir(dest);end
    save(fullfile(dest,'manifest.mat'),'config');write_json(fullfile(dest,'manifest.json'),config);
    tmp=fullfile(dest,'per_image.tmp.jsonl');fid=fopen(tmp,'w','n','UTF-8');
    assert(fid>=0,'DatasetECC:Write','Cannot write %s',tmp);
    journal_cleanup=onCleanup(@()fclose(fid));
    for j=1:numel(records),fprintf(fid,'%s\n',jsonencode(records{j}));end
    clear journal_cleanup;movefile(tmp,fullfile(dest,'per_image.jsonl'),'f');
    s=dataset_ecc_export(output,records,config);
    if s.failed_images>0
        warning('DatasetECC:FailedImages','%s: %d failed images retained; full-dataset mean is unavailable. Retry failed images in the original segment(s) and merge again.',labels{d},s.failed_images);
    end
end
summaries=dataset_ecc_export(output);
fprintf('Merge complete (no image encoding executed): %s\n',output);
end

function validate_config(c,label)
assert(isfield(c,'format_version') && c.format_version==2,'DatasetECC:MergeFormat','Segment does not contain a version 2 range manifest.');
n=c.dataset_file_count;idx=c.dataset_indices;
assert(strcmp(c.dataset,label) && n>=1 && n==fix(n) && numel(c.catalog_filenames)==n && ...
    numel(c.catalog_bytes)==n && numel(c.catalog_modified_datenum)==n && ...
    numel(unique(string(c.catalog_filenames)))==n,'DatasetECC:MergeManifest','Invalid dataset catalog.');
assert(numel(idx)==c.planned_images && ~isempty(idx) && all(idx>=1 & idx<=n & idx==fix(idx)) && ...
    all(diff(idx)>0),'DatasetECC:MergeManifest','Invalid range indices.');
assert(isequal(c.filenames,c.catalog_filenames(idx)) && isequal(c.bytes,c.catalog_bytes(idx)) && ...
    isequal(c.modified_datenum,c.catalog_modified_datenum(idx)), ...
    'DatasetECC:MergeManifest','Segment does not match its full catalog.');
end

function compare_config(a,b)
fields={'format_version','dataset','dataset_file_count','catalog_filenames','catalog_bytes', ...
    'catalog_modified_datenum','block_size','prediction_mode','expected_image_size', ...
    'capacity_definition','external_public_header_bytes','encryption_embedding_scrambling_recovery'};
for k=1:numel(fields)
    assert(isequaln(a.(fields{k}),b.(fields{k})),'DatasetECC:ConfigMismatch', ...
        'Incompatible segment configuration: %s.',fields{k});
end
end

function signature=verify_source(root)
f=fullfile(root,'source_manifest.json');assert(isfile(f),'DatasetECC:SourceMissing','Missing source manifest: %s',f);
m=jsondecode(fileread(f));
assert(strcmp(file_sha256(fullfile(root,'run_dataset_ecc_saved.m')),m.runner_sha256), ...
    'DatasetECC:SnapshotChanged','Saved runner was modified: %s',root);
[~,ord]=sort(string({m.files.name}));entries=m.files(ord);
for k=1:numel(entries)
    assert(strcmp(file_sha256(fullfile(root,'source_snapshot',entries(k).name)),entries(k).sha256), ...
        'DatasetECC:SnapshotChanged','Source snapshot modified: %s.',entries(k).name);
end
signature=struct('runner_sha256',m.runner_sha256,'matlab_version',m.matlab_version,'computer',m.computer,'files',entries);
end
function h=file_sha256(f)
fid=fopen(f,'rb');assert(fid>=0,'DatasetECC:SourceMissing','Cannot read %s',f);
c=onCleanup(@()fclose(fid));bytes=fread(fid,Inf,'*uint8');md=java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(bytes(:),'int8'));digest=typecast(md.digest(),'uint8');h=lower(reshape(dec2hex(digest,2).',1,[]));
end
function write_json(f,value)
tmp=[tempname(fileparts(f)),'.tmp'];fid=fopen(tmp,'w','n','UTF-8');
assert(fid>=0,'DatasetECC:Write','Cannot write %s',tmp);
c=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));clear c;movefile(tmp,f,'f');
end
function p=absolute_path(p)
p=char(java.io.File(char(p)).getCanonicalPath());
end
function release_lock(p)
if isfolder(p),rmdir(p);end
end
