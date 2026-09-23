function result=dataset_ecc_export(output,records,config)
% 批处理和分段合并共用输出口径；从逐图记录重算，不平均各段均值。
if nargin==1,result=write_combined(output);return;end
dest=fullfile(output,config.dataset);if ~isfolder(dest),mkdir(dest);end
s=dataset_ecc_summary(records,config.planned_images,config.dataset_file_count,config.dataset);
s.updated=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
s.block_size=config.block_size;s.prediction_mode=config.prediction_mode;
s.dataset_index_first=config.dataset_indices(1);s.dataset_index_last=config.dataset_indices(end);
write_json(fullfile(dest,'summary.json'),s);
rows=[records{~cellfun(@isempty,records)}];
if ~isempty(rows)
    template=dataset_ecc_empty_row();keys=fieldnames(template);
    for i=1:numel(rows)
        % JSON null解码为空数组，CSV中恢复为缺失值，绝不混入0容量。
        for k=1:numel(keys)
            if isnumeric(template.(keys{k})) && isempty(rows(i).(keys{k})),rows(i).(keys{k})=NaN;end
        end
    end
    tmp=fullfile(dest,'per_image.tmp.csv');
    writetable(struct2table(rows,'AsArray',true),tmp,'Encoding','UTF-8');movefile(tmp,fullfile(dest,'per_image.csv'),'f');
end
tmp=fullfile(dest,'checkpoint.tmp.mat');save(tmp,'records','config','s');
movefile(tmp,fullfile(dest,'checkpoint.mat'),'f');
fprintf('%s summary: ok=%d failed=%d pending=%d',s.dataset,s.successful_images,s.failed_images,s.pending_images);
if ~isempty(s.max_capacity)
    fprintf(' mean ECC=%.6f max=%d (%s) min=%d (%s)',s.mean_ecc_bpp_success, ...
        s.max_capacity.value,strjoin(s.max_capacity.image_ids,','),s.min_capacity.value,strjoin(s.min_capacity.image_ids,','));
end
fprintf('\n');result=s;
end

function all_s=write_combined(output)
labels={'BOSSBase','BOWS2'};all_s={};flat={};
for k=1:2
    f=fullfile(output,labels{k},'summary.json');if ~isfile(f),continue;end
    s=jsondecode(fileread(f));all_s{end+1}=s; %#ok<AGROW>
    r=struct('dataset',s.dataset,'planned_images',s.planned_images,'successful_images',s.successful_images, ...
        'failed_images',s.failed_images,'pending_images',s.pending_images,'full_dataset_success',s.full_dataset_success, ...
        'total_payload_bits',s.total_payload_bits,'mean_ecc_bpp_success',NaN, ...
        'full_dataset_mean_ecc_bpp',NaN,'max_payload_bits',NaN,'max_image_ids','', ...
        'min_payload_bits',NaN,'min_image_ids','','max_ecc_bpp',NaN, ...
        'max_ecc_image_ids','','min_ecc_bpp',NaN,'min_ecc_image_ids','');
    if ~isempty(s.max_capacity)
        r.mean_ecc_bpp_success=s.mean_ecc_bpp_success;
        r.max_payload_bits=s.max_capacity.value;r.min_payload_bits=s.min_capacity.value;
        r.max_image_ids=strjoin(cellstr(string(s.max_capacity.image_ids)),';');
        r.min_image_ids=strjoin(cellstr(string(s.min_capacity.image_ids)),';');
        r.max_ecc_bpp=s.max_ecc.value;r.min_ecc_bpp=s.min_ecc.value;
        r.max_ecc_image_ids=strjoin(cellstr(string(s.max_ecc.image_ids)),';');
        r.min_ecc_image_ids=strjoin(cellstr(string(s.min_ecc.image_ids)),';');
        if s.full_dataset_success,r.full_dataset_mean_ecc_bpp=s.full_dataset_mean_ecc_bpp;end
    end
    flat{end+1}=r; %#ok<AGROW>
end
write_json(fullfile(output,'datasets_summary.json'),all_s);
if ~isempty(flat)
    tmp=fullfile(output,'datasets_summary.tmp.csv');
    writetable(struct2table([flat{:}]),tmp,'Encoding','UTF-8');
    movefile(tmp,fullfile(output,'datasets_summary.csv'),'f');
end
end

function write_json(f,value)
tmp=[tempname(fileparts(f)),'.tmp'];fid=fopen(tmp,'w','n','UTF-8');
assert(fid>=0,'DatasetECC:Write','Cannot write %s',tmp);
c=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));clear c;
movefile(tmp,f,'f');
end
