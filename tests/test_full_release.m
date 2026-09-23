function report=test_full_release(image_dir,output_file)
%TEST_FULL_RELEASE Codec tests, full round trips, exact capacity and test vector.
root=rdhei_setup();if nargin<1,image_dir=[];end
if nargin<2,output_file=fullfile(root,'results','generated','validation.json');end
captured=evalc('test_fold_map_codec;test_opt_header_codec;test_huffman_singleton;'); %#ok<NASGU>
rows=struct([]);names={'synthetic','constant','short_payload'};
for k=1:3
    I=rdhei_demo_input();o=struct();
    if k==2,I=100*ones(256);end
    if k==3,o.PayloadBits=17;end
    [s,~,detail]=rdhei_case(I,o);
    captured=evalc('capacity=dataset_capacity_only(double(I),16,16,''entropy'');'); %#ok<NASGU>
    assert(s.maximum_payload_bits==capacity.payload_bits,'rdhei:Capacity','Count differs from actual embedding.');
    if k==3,assert(s.payload_bits==17&&numel(detail.extracted)==17);end
    s.image=names{k};rows=append(rows,s);
end
if ~isempty(image_dir)
    [paths,labels]=rdhei_four_inputs(image_dir);
    for k=1:4
        I=imread(paths{k});s=rdhei_case(I);
        captured=evalc('capacity=dataset_capacity_only(double(I),16,16,''entropy'');'); %#ok<NASGU>
        assert(s.payload_bits==capacity.payload_bits,'rdhei:Capacity','Capacity-only count differs.');
        s.image=labels{k};rows=append(rows,s);
        fprintf('PASS %s: %d bits, zero pixel errors\n',labels{k},s.payload_bits);
    end
end
vector_file=fullfile(root,'examples','synthetic_vector.mat');
if isfile(vector_file)
    v=load(vector_file);[s,images,d]=rdhei_case(v.original,struct('Crypto',v.public_test_context));
    assert(isequal(images.stego,v.stego)&&isequal(images.recovered,v.original)&& ...
        isequal(d.extracted,v.payload)&&isequal(d.crypto.public_header,v.public_header));
    vector_ok=true;
else,vector_ok=false;end
report=struct('version','1.0.0','matlab_version',version,'computer',computer, ...
    'codec_tests_passed',true,'cases',rows,'case_count',numel(rows), ...
    'all_roundtrips_passed',all([rows.image_recovery_ok]&[rows.payload_ok]&[rows.auxiliary_ok]), ...
    'capacity_matches_actual_embedding',true,'fixed_test_vector_passed',vector_ok, ...
    'validation_scope','Production element/block assertions retained; no separate-process receiver interface claim');
rdhei_write_json(output_file,report);
end
function rows=append(rows,row)
if isempty(rows),rows=row;else,rows(end+1)=row;end
end
