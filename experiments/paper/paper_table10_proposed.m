function rows=paper_table10_proposed(image_dir,output_dir)
if nargin<1,image_dir=[];end
if nargin<2,output_dir=[];end
[~,output_dir]=paper_setup('table10',output_dir);[paths,labels]=paper_inputs(image_dir);
rows=struct([]);
for k=1:4
    I=double(imread(paths{k}));
    captured=evalc('r=dataset_capacity_only(I,16,16,''entropy'');'); %#ok<NASGU>
    r.image=labels{k};r.external_header_bytes=53;r.image_pixels=numel(I);
    r.ecc_after_charging_external_header=(r.payload_bits-424)/numel(I);
    if isempty(rows),rows=r;else,rows(end+1)=r;end %#ok<AGROW>
    rdhei_write_json(fullfile(output_dir,'proposed_current.json'),rows);
end
end
