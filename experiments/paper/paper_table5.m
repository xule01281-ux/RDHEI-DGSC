function report=paper_table5(image_dir,output_dir,block_sizes)
if nargin<1,image_dir=[];end
if nargin<2,output_dir=[];end
if nargin<3,block_sizes=[8 16 32 64];end
[~,output_dir]=paper_setup('table5',output_dir);paper_inputs(image_dir);
rows=run_capacity_suite(image_dir,block_sizes,fullfile(output_dir,'capacity_rows.json'));
names={'11.png','Jetplane.tiff','Baboon.tiff','Tiffany.tiff'};
labels={'Man','Jetplane','Baboon','Tiffany'};
for k=1:numel(rows)
    rows(k).block_h=rows(k).block_size;rows(k).block_w=rows(k).block_size;
    rows(k).filename=names{strcmp(labels,rows(k).image)};rows(k).status='pass';
end
report=struct('stage','capacity','rows',rows,'paper_protocol',isequal(block_sizes,[8 16 32 64]));
rdhei_write_json(fullfile(output_dir,'capacity.json'),report);
end
