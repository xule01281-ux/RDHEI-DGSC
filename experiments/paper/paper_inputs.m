function [paths,labels]=paper_inputs(image_dir)
%PAPER_INPUTS Refuse silently substituted or resized standard images.
root=rdhei_setup();if nargin<1,image_dir=[];end
[paths,labels]=rdhei_four_inputs(image_dir);
manifest=jsondecode(fileread(fullfile(root,'results','reference','input_manifest.json')));
for k=1:4
    I=imread(paths{k});r=manifest.images(k);
    assert(isa(I,'uint8')&&isequal(size(I),[r.height r.width]),'rdhei:PaperInput','Expected original 512x512 uint8 grayscale image.');
    assert(strcmp(paper_sha256(I(:)),r.decoded_pixels_sha256),'rdhei:PaperInput','Decoded pixels do not match paper input %s.',labels{k});
end
end
