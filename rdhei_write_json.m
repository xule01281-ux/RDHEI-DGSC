function rdhei_write_json(filename,value)
%RDHEI_WRITE_JSON Write a UTF-8 result record.
folder=fileparts(filename);if ~isfolder(folder),mkdir(folder);end
fid=fopen(filename,'w','n','UTF-8');assert(fid>=0,'rdhei:Output','Cannot open result file.');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
