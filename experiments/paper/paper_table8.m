function rows=paper_table8(image_dir,output_dir,image_indices)
% Paper Table 8: 11 measured axes, 10 candidates in the finite search.
if nargin<1,image_dir=[];end
if nargin<2,output_dir=[];end
[~,output_dir]=paper_setup('table8',output_dir);
if nargin<3,image_indices=1:4;end
[paths,~]=paper_inputs(image_dir);
names={'11.png','Jetplane.tiff','Baboon.tiff','Tiffany.tiff'};
cfg=struct('all_off',false,'no_feedback',false,'fixed_weight',NaN, ...
 'no_bias_clamp',false,'no_soft_clamp',false,'no_spatial',false,'forced_dirs',[]);
rows={};
for j=image_indices
 I=double(imread(paths{j}));
 [Eprod,~,~,ref]=deviate(I,'entropy');
 [~,~,meta]=ecc_prediction(I,cfg,.4,.1);centroid=meta.split;
 candidates=[1 1;256 256;centroid;128 128;128 256;128 384;256 128;256 384;384 128;384 256;384 384];
 for k=1:size(candidates,1)
  c=cfg;c.split=candidates(k,:);tag='axis';
  captured=evalc('[data,E,bits]=ecc_capacity(I,c,.4,.1);');
  if k==3,assert(isequal(E,Eprod)&&isequal(bits,ref.bits),'Current main prediction mismatch.');end
  rows{end+1}=struct('image',names{j},'group',tag,'split',c.split,'data',data);
  rdhei_write_json(fullfile(output_dir,'capacity.json'),rows);
  fprintf('CAPACITY %s %s (%d,%d) bits=%d ECC=%.6f\n',names{j},tag,c.split,data.payload_bits,data.ecc_bpp);
 end
end
end
