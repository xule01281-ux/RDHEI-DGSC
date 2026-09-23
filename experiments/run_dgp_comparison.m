function rows=run_dgp_comparison(image_dir,output_file)
%RUN_DGP_COMPARISON Axis-location heuristics under the same current SCEC coder.
% New reproducible comparison; not a claim of global capacity optimality.
root=rdhei_setup();if nargin<1,image_dir=[];end
if nargin<2,output_file=fullfile(root,'results','generated','dgp_comparison.json');end
old=path;cleanup=onCleanup(@()path(old));addpath(fullfile(root,'experiments','ablation'));
[paths,labels]=rdhei_four_inputs(image_dir);rows=struct([]);
cfg=struct('all_off',false,'no_feedback',false,'fixed_weight',NaN,'no_bias_clamp',false, ...
    'no_soft_clamp',false,'no_spatial',false,'forced_dirs',[]);
groups={'dgp','geometric_center','maximum_error','max_row_column_energy'};
for k=1:4
    I=double(imread(paths{k}));[H,W]=size(I);
    P=Copy_of_Predictor_Value2(I,1,1,1,1,1,1,1,1,std(I(:)),1,1);
    energy=(P-I).^2;
    [~,~,meta]=ecc_prediction(I,cfg,.4,.1);
    [~,q]=max(energy(:));[pr,pc]=ind2sub([H W],q);
    [~,rr]=max(sum(energy,2));[~,cc]=max(sum(energy,1));
    splits=[meta.split;round([H W]/2);pr pc;rr cc];
    splits=max([2 2],min([H-1 W-1],splits));
    for j=1:numel(groups)
        c=cfg;c.split=splits(j,:);
        captured=evalc('data=ecc_capacity(I,c,.4,.1);'); %#ok<NASGU>
        if j==1
            captured=evalc('reference=dataset_capacity_only(I,16,16,''entropy'');'); %#ok<NASGU>
            assert(data.payload_bits==reference.payload_bits,'rdhei:DGP','DGP control differs from main chain.');
        end
        row=struct('image',labels{k},'configuration',groups{j},'split',splits(j,:),'data',data);
        if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
        rdhei_write_json(output_file,rows);
    end
end
end
