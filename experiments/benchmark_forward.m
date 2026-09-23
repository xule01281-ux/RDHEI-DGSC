function report=benchmark_forward(image_dir,repeats,output_file)
%BENCHMARK_FORWARD Warm-up then sequentially time prediction through scrambling.
% The full call validates extraction/reconstruction outside the reported interval.
root=rdhei_setup();if nargin<1,image_dir=[];end
if nargin<2,repeats=3;end
if nargin<3,output_file=fullfile(root,'results','generated','forward_timing.json');end
validateattributes(repeats,{'numeric'},{'scalar','integer','>=',2});
[paths,labels]=rdhei_four_inputs(image_dir);inputs=cellfun(@imread,paths,'UniformOutput',false);
for k=1:4,rdhei_case(inputs{k});end
times=zeros(repeats,4);bits=zeros(1,4);
for rep=1:repeats
    for k=1:4
        s=rdhei_case(inputs{k});times(rep,k)=s.forward_seconds;bits(k)=s.payload_bits;
        fprintf('Run %d %s: %.4f s\n',rep,labels{k},times(rep,k));
    end
end
report=struct('matlab_version',version,'computer',computer,'images',{labels}, ...
    'timing_scope','deviate entry through protected-image block/pixel scrambling; excludes receiver', ...
    'warmup_calls_per_image',1,'repeats',repeats,'seconds',times, ...
    'mean_seconds',mean(times,1),'std_seconds',std(times,0,1),'median_seconds',median(times,1), ...
    'payload_bits',bits,'total_payload_bits',sum(bits),'sum_mean_seconds',sum(mean(times,1)));
rdhei_write_json(output_file,report);
end
