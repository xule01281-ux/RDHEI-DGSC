function report=test_dataset_workflow(output_root)
%TEST_DATASET_WORKFLOW Two synthetic images: disjoint parts, resume and merge.
% Never reads or runs either real 10,000-image dataset.
rdhei_setup();
if nargin<1,output_root=tempname;end
assert(~isfolder(output_root),'rdhei:TestOutput','Choose a new test output directory.');
mkdir(output_root);input_dir=fullfile(output_root,'inputs');mkdir(input_dir);
I=repelem(rdhei_demo_input(),2,2);
imwrite(I,fullfile(input_dir,'1.pgm'));imwrite(uint8(min(255,double(I)+1)),fullfile(input_dir,'2.pgm'));
front=fullfile(output_root,'front');back=fullfile(output_root,'back');merged=fullfile(output_root,'merged');
captured=evalc('run_dataset_ecc(''BOSSBase'',''BossPath'',input_dir,''StartIndex'',1,''EndIndex'',1,''OutputRoot'',front);'); %#ok<NASGU>
captured=evalc('run_dataset_ecc(''BOSSBase'',''BossPath'',input_dir,''StartIndex'',2,''EndIndex'',2,''OutputRoot'',back);'); %#ok<NASGU>
before=fileread(fullfile(front,'BOSSBase','per_image.jsonl'));
captured=evalc('run_dataset_ecc(''BOSSBase'',''BossPath'',input_dir,''StartIndex'',1,''EndIndex'',1,''OutputRoot'',front);'); %#ok<NASGU>
assert(strcmp(before,fileread(fullfile(front,'BOSSBase','per_image.jsonl'))),'rdhei:Resume','Resume duplicated a record.');
captured=evalc('merge_dataset_ecc({front,back},merged,''BOSSBase'');'); %#ok<NASGU>
lines=splitlines(strtrim(fileread(fullfile(merged,'BOSSBase','per_image.jsonl'))));
assert(numel(lines)==2,'rdhei:Merge','Expected two merged rows.');
a=jsondecode(lines{1});b=jsondecode(lines{2});
assert(strcmp(a.status,'ok')&&strcmp(b.status,'ok')&&a.dataset_index==1&&b.dataset_index==2);
report=struct('synthetic_images',2,'resume_passed',true,'merge_passed',true, ...
    'real_dataset_images_processed',0,'payload_bits',[a.payload_bits,b.payload_bits]);
rdhei_write_json(fullfile(output_root,'validation.json'),report);
end
