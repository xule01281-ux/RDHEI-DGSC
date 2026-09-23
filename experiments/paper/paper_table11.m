function report=paper_table11(image_dir,output_dir,warmups,repetitions,image_indices)
% Defaults reproduce the paper protocol. Optional shorter runs are validation only.
if nargin<1,image_dir=[];end
if nargin<2,output_dir=[];end
if nargin<3,warmups=2;end
if nargin<4,repetitions=10;end
if nargin<5,image_indices=1:4;end
validateattributes(warmups,{'numeric'},{'scalar','integer','nonnegative'});
validateattributes(repetitions,{'numeric'},{'scalar','integer','positive'});
[package,output_dir]=paper_setup('table11',output_dir);
stage='timing';
% Current production functions; immutable snapshot with SHA-256 manifest.
% Capacity stops before encryption, insertion, scrambling and reception.
% Timing uses the unmodified production forward_seconds counter.
[paths,~]=paper_inputs(image_dir);
names={'11.png','Jetplane.tiff','Baboon.tiff','Tiffany.tiff'};
labels={'Man','Jetplane','Baboon','Tiffany'};
images=cell(1,4);
for k=image_indices
    images{k}=double(imread(paths{k}));
    assert(isequal(size(images{k}),[512 512]));
end
assert(strcmp(which('Encrypt_Embed'),fullfile(package,'src','Encrypt_Embed.m')));
base=struct('created',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    'matlab_version',version,'computer',computer,'stage',stage, ...
    'prediction_mode','entropy','scec_thresholds',[0.40 0.10], ...
    'extreme_intervention',false,'external_public_header_bytes',53);

assert(strcmp(stage,'timing'));
% Match main.m exactly: payload generation happens outside the timed region.
rand('seed',0); %#ok<RAND>
D=round(rand(1,8000000));
% warmups and repetitions were set by the public arguments.
forward=nan(repetitions,4);bits=nan(repetitions,4);entire=nan(repetitions,4);
warmup_seconds=nan(warmups,4);
for t=1:warmups
    for k=image_indices
        fprintf('WARMUP START trial=%d image=%s\n',t,names{k});
        [~,~,emD,~,exD,v]=Encrypt_Embed(images{k},D,1,2,1,1,16,16,'entropy');
        check_run(emD,exD,v);
        warmup_seconds(t,k)=v.capacity.forward_seconds;
        fprintf('WARMUP PASS trial=%d image=%s seconds=%.6f\n',t,names{k},v.capacity.forward_seconds);
    end
end
for t=1:repetitions
    order=circshift(image_indices,[0,-mod(t-1,numel(image_indices))]);
    for k=order
        fprintf('TIMING START trial=%d image=%s\n',t,names{k});
        outer=tic;
        [~,~,emD,~,exD,v]=Encrypt_Embed(images{k},D,1,2,1,1,16,16,'entropy');
        entire(t,k)=toc(outer);
        check_run(emD,exD,v);
        forward(t,k)=v.capacity.forward_seconds;bits(t,k)=numel(emD);
        report=base;report.labels=labels;report.filenames=names;
        report.block_size=[16 16];report.warmups_per_image=warmups;
        report.repetitions_per_image=repetitions;report.forward_seconds=forward;
        report.payload_bits=bits;report.whole_call_seconds_diagnostic_only=entire;
        report.warmup_forward_seconds=warmup_seconds;
        report.payload_input_bits=numel(D);
        report.timing_start='Immediately before deviate';
        report.timing_end='Immediately after scramble_blocks_within';
        report.recovery_in_timing=false;
        write_report(output_dir,'timing.json',report);
        fprintf('TIMING PASS trial=%d image=%s bits=%d seconds=%.6f checks=PASS\n',t,names{k},bits(t,k),forward(t,k));
    end
end
assert(all(all(bits(:,image_indices)==bits(1,image_indices))));
assert(all(all(isfinite(forward(:,image_indices)))));
cap=jsondecode(fileread(fullfile(package,'results','paper','table5','capacity.json')));
for k=image_indices
    found=false;
    for j=1:numel(cap.rows)
        if iscell(cap.rows),r=cap.rows{j};else,r=cap.rows(j);end
        if r.block_h==16 && strcmp(r.filename,names{k})
            assert(r.payload_bits==bits(1,k),'Capacity adapter differs from actual writer.');found=true;
        end
    end
    assert(found);
end
report.mean_seconds=mean(forward,1);report.std_seconds=std(forward,0,1);
report.total_seconds_each_repeat=sum(forward(:,image_indices),2).';
report.total_seconds_mean=mean(sum(forward(:,image_indices),2));
report.total_seconds_std=std(sum(forward(:,image_indices),2),0);
report.total_payload_bits=sum(bits(1,image_indices));
report.all_checks_passed=true;
report.paper_protocol=warmups==2 && repetitions==10 && isequal(image_indices,1:4);
report.image_indices=image_indices;
write_report(output_dir,'timing.json',report);
save(fullfile(output_dir,'timing_raw.mat'),'forward','bits','entire','warmup_seconds','report');
fprintf('ALL DONE total_bits=%d mean_four_image_seconds=%.6f sd=%.6f\n',report.total_payload_bits,report.total_seconds_mean,report.total_seconds_std);
end

function check_run(emD,exD,v)
assert(isequal(emD,exD) && numel(emD)==v.payload_bits);
assert(v.scramble_ok && v.payload_ok && v.auxiliary_ok && v.image_recovery_ok && v.fold_map_ok && v.r_ok);
assert(v.image_pixel_mismatches==0 && v.image_max_pixel_error==0);
end

function write_report(output_dir,name,report)
fid=fopen(fullfile(output_dir,name),'w','n','UTF-8');
assert(fid>=0);clean=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report));
end
