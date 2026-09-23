function rows=run_scec_ablation(image_dir,output_file)
%RUN_SCEC_ABLATION Seven configurations, fixed DGP split, entropy reselection.
root=rdhei_setup();if nargin<1,image_dir=[];end
if nargin<2,output_file=fullfile(root,'results','generated','scec_ablation.json');end
old=path;cleanup=onCleanup(@()path(old));addpath(fullfile(root,'experiments','ablation'));
[paths,labels]=rdhei_four_inputs(image_dir);
groups={'full','no_scec','no_feedback','no_spatial','weight_05','no_bias_clamp','no_neighborhood_clamp'};
cfg=struct('all_off',false,'no_feedback',false,'fixed_weight',NaN,'no_bias_clamp',false, ...
    'no_soft_clamp',false,'no_spatial',false,'forced_dirs',[]);
rows=struct([]);
for k=1:4
    I=double(imread(paths{k}));
    captured=evalc('[Eprod,~,~,ref]=deviate(I,''entropy'');'); %#ok<NASGU>
    [~,~,meta]=ecc_prediction(I,cfg,.4,.1);
    for j=1:numel(groups)
        c=cfg;c.split=meta.split;
        switch groups{j}
            case 'no_scec',c.all_off=true;
            case 'no_feedback',c.no_feedback=true;
            case 'no_spatial',c.no_spatial=true;
            case 'weight_05',c.fixed_weight=.5;
            case 'no_bias_clamp',c.no_bias_clamp=true;
            case 'no_neighborhood_clamp',c.no_soft_clamp=true;
        end
        captured=evalc('[data,E,bits]=ecc_capacity(I,c,.4,.1);'); %#ok<NASGU>
        if j==1,assert(isequal(E,Eprod)&&isequal(bits,ref.bits),'rdhei:Ablation','Full configuration differs from production.');end
        row=struct('image',labels{k},'group',groups{j},'split',meta.split,'data',data);
        if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
        rdhei_write_json(output_file,rows);
        fprintf('%s / %s: %d bits\n',labels{k},groups{j},data.payload_bits);
    end
end
end
