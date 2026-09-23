function [root,out]=paper_setup(table_id,out)
%PAPER_SETUP Separate immutable paper records from generated experiment files.
root=rdhei_setup();
addpath(fullfile(root,'experiments','ablation'));
if nargin<2||isempty(out),out=fullfile(root,'results','generated','paper',table_id);end
out=char(java.io.File(out).getCanonicalPath());
reference=char(java.io.File(fullfile(root,'results','paper')).getCanonicalPath());
assert(~strcmpi(out,reference)&&~startsWith(lower(out),[lower(reference) filesep]), ...
    'rdhei:ReadOnlyReference','Choose an output directory outside results/paper.');
if ~isfolder(out),mkdir(out);end
end
