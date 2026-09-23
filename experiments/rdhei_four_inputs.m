function [paths,labels]=rdhei_four_inputs(image_dir)
%RDHEI_FOUR_INPUTS Natural-image inputs are supplied by the user.
if nargin<1||isempty(image_dir),root=rdhei_setup();image_dir=fullfile(root,'data');end
names={'11.png','Jetplane.tiff','Baboon.tiff','Tiffany.tiff'};
labels={'Man','Jetplane','Baboon','Tiffany'};
paths=cellfun(@(name)fullfile(image_dir,name),names,'UniformOutput',false);
for k=1:4,assert(isfile(paths{k}),'rdhei:InputMissing','Missing input: %s',paths{k});end
end
