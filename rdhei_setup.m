function root=rdhei_setup()
%RDHEI_SETUP Add only the main implementation and public utility directories.
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'src'),fullfile(root,'src','dataset_capacity_tests'), ...
    fullfile(root,'tests'),fullfile(root,'experiments'),fullfile(root,'experiments','paper'));
end
