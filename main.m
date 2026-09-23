function summary=main(image_path,output_dir)
%MAIN Run the complete reference implementation with pixel and payload checks.
% main                         % freely redistributable synthetic demo
% main(fullfile('data','11.png'))
root=rdhei_setup();
if nargin<1||isempty(image_path),I=rdhei_demo_input();label='synthetic';
else,I=imread(image_path);[~,label]=fileparts(image_path);end
if nargin<2||isempty(output_dir),output_dir=fullfile(root,'results','generated',label);end
[summary,images,detail]=rdhei_case(I);
if ~isfolder(output_dir),mkdir(output_dir);end
names=fieldnames(images);
for k=1:numel(names),imwrite(images.(names{k}),fullfile(output_dir,[names{k} '.png']));end
embedded=detail.embedded;extracted=detail.extracted;public_header=detail.crypto.public_header;
save(fullfile(output_dir,'roundtrip.mat'),'summary','images','embedded','extracted','public_header');
rdhei_write_json(fullfile(output_dir,'metrics.json'),summary);
fprintf('%s: %d net bits, %.6f bpp, prediction-to-scrambling %.4f s; pixel errors %d.\n', ...
    label,summary.payload_bits,summary.ecc_bpp,summary.forward_seconds,summary.image_pixel_mismatches);
end
