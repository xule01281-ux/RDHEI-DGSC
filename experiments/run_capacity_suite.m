function rows=run_capacity_suite(image_dir,block_sizes,output_file)
%RUN_CAPACITY_SUITE True net capacity only: no embedding, encryption or recovery.
root=rdhei_setup();if nargin<1,image_dir=[];end
if nargin<2,block_sizes=[8 16 32 64];end
if nargin<3,output_file=fullfile(root,'results','generated','capacity_suite.json');end
[paths,labels]=rdhei_four_inputs(image_dir);rows=struct([]);
for h=block_sizes
    assert(ismember(h,[8 16 32 64]));
    for k=1:4
        I=double(imread(paths{k}));
        captured=evalc('row=dataset_capacity_only(I,h,h,''entropy'');'); %#ok<NASGU>
        row.image=labels{k};row.block_size=h;row.external_public_header_bytes=53;
        if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
        rdhei_write_json(output_file,rows);
        fprintf('%s / %d: %d bits, %.6f bpp\n',labels{k},h,row.payload_bits,row.ecc_bpp);
    end
end
end
