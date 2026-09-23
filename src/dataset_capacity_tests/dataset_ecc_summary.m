function s=dataset_ecc_summary(records,planned_count,dataset_file_count,dataset_name)
% records为按清单索引保存的cell；未处理项为[]，失败项不能进入均值和极值。
present=~cellfun(@isempty,records);
rows=[records{present}];
if isempty(rows),good=[];else,good=rows(strcmp({rows.status},'ok'));end
s=struct('dataset',dataset_name,'dataset_file_count',dataset_file_count, ...
    'planned_images',planned_count,'attempted_images',nnz(present), ...
    'successful_images',numel(good),'failed_images',nnz(present)-numel(good), ...
    'pending_images',planned_count-nnz(present),'all_attempted',nnz(present)==planned_count, ...
    'full_dataset_success',numel(good)==dataset_file_count && planned_count==dataset_file_count, ...
    'total_payload_bits',0,'mean_payload_bits_success',[], ...
    'mean_ecc_bpp_success',[],'weighted_ecc_bpp_success',[], ...
    'full_dataset_mean_ecc_bpp',[],'max_capacity',[],'min_capacity',[], ...
    'max_ecc',[],'min_ecc',[]);
if isempty(good),return;end
bits=[good.payload_bits];rates=[good.ecc_bpp];
assert(all(isfinite(bits) & bits>=0) && all(isfinite(rates)),'DatasetECC:InvalidRecord','Invalid successful capacity record.');
s.total_payload_bits=sum(bits);s.mean_payload_bits_success=mean(bits);
s.mean_ecc_bpp_success=mean(rates);
s.weighted_ecc_bpp_success=sum(bits)/sum([good.pixels]);
if s.full_dataset_success,s.full_dataset_mean_ecc_bpp=mean(rates);end
s.max_capacity=extreme(good,bits,max(bits));s.min_capacity=extreme(good,bits,min(bits));
s.max_ecc=extreme(good,rates,max(rates));s.min_ecc=extreme(good,rates,min(rates));
end

function e=extreme(rows,metric,value)
take=rows(metric==value);
e=struct('value',value,'tie_count',numel(take),'image_ids',{{take.image_id}}, ...
    'filenames',{{take.filename}},'payload_bits',[take.payload_bits],'ecc_bpp',[take.ecc_bpp]);
end
