function rows=paper_table7(image_dir,output_dir)
if nargin<1,image_dir=[];end
if nargin<2,output_dir=[];end
[~,output_dir]=paper_setup('table7',output_dir);paper_inputs(image_dir);
rows=run_scec_ablation(image_dir,fullfile(output_dir,'ablation.json'));
end
