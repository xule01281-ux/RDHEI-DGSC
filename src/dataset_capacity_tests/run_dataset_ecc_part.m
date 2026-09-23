function summaries=run_dataset_ecc_part(part,which_dataset,varargin)
% 便捷分段入口；默认每次处理两个数据集的同一半，可分开时段/进程运行。
% run_dataset_ecc_part(1)              % 两个数据集分别第1~5000幅
% run_dataset_ecc_part(2)              % 两个数据集分别第5001~10000幅
% run_dataset_ecc_part(1,'BOSSBase')   % 仅BOSSBase前5000幅
% 两段完成后：merge_dataset_ecc
if nargin<2,which_dataset='both';end
validateattributes(part,{'numeric'},{'scalar','integer','>=',1,'<=',2});
roots={fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'results','dataset_part1'), ...
    fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'results','dataset_part2')};
summaries=run_dataset_ecc(which_dataset,'StartIndex',(part-1)*5000+1, ...
    'EndIndex',part*5000,'OutputRoot',roots{part},varargin{:});
end
