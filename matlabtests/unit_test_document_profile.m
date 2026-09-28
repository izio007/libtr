function unit_test_document_profile()
% Verify the approved profile and the gate without production documents.
root=fileparts(fileparts(mfilename('fullpath')));
folder=tempname(fullfile(root,'runtime')); mkdir(folder);
cleanup=onCleanup(@() rmdir(folder,'s'));
copyfile(fullfile(root,'PlainTextPrincipe.md'),folder);
mkdir(fullfile(folder,'docs','html'));
mkdir(fullfile(folder,'docs','liveeditor'));
source=fullfile(folder,'docs','probe_theory.txt');
writeText(source,'$\lambda \in A \times B$');
writeText(fullfile(folder,'docs','html','probe.html'),'<span class="math"></span>');
writeText(fullfile(folder,'docs','liveeditor','probe_theory.m'), ...
    '%[text] $\\lambda \\in A \\times B$');
metrics=service_validate_documents(folder,folder);
assert(metrics.failures==0 && strcmp(metrics.standard,'PlainTextPrincipe 5.23'));
writeText(source,'$\unknowncommand A$');
metrics=service_validate_documents(folder,folder);
assert(metrics.failures==1);
fprintf('Document profile regression: PASS\n');
end

function writeText(file,text)
fid=fopen(file,'w','n','UTF-8');
assert(fid~=-1);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',text);
end