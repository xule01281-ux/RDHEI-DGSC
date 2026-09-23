function [records,valid_text]=dataset_ecc_load_journal(filename,image_names)
% 单图完成立即追加JSONL；断电留下的最后一条不完整记录可丢弃后重算。
records=cell(1,numel(image_names));valid_text='';
if ~isfile(filename),return;end
txt=fileread(filename);lines=regexp(txt,'\r?\n','split');
nonempty=find(~cellfun(@isempty,lines));
for j=nonempty
    try
        row=jsondecode(lines{j});
    catch err
        if j==nonempty(end)
            warning('DatasetECC:PartialJournal','Ignoring interrupted final journal line: %s',err.message);
            break;
        end
        rethrow(err);
    end
    i=row.index;
    assert(i>=1 && i<=numel(image_names) && i==fix(i) && strcmp(row.filename,image_names{i}), ...
        'DatasetECC:JournalMismatch','Journal does not match image manifest.');
    assert(any(strcmp(row.status,{'ok','failed'})),'DatasetECC:JournalStatus','Unknown record status.');
    records{i}=row; % RetryFailed时同一图像可能有多次记录，最后一次为准。
    valid_text=[valid_text,lines{j},newline]; %#ok<AGROW>
end
end
