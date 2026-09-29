function unit_test_document_profile()
setup_test_paths;
% Verify the approved profile and the gate without production documents.
root=fileparts(fileparts(mfilename('fullpath')));
for file={'service_parse_document_profile.m','service_validate_documents.m'}
    issues=checkcode(fullfile(root,'tools','docs',file{1}),'-id');
    assert(isempty(issues),'Document gate Code Analyzer findings');
end
fid=fopen(fullfile(root,'PlainTextPrincipe.md'),'r','n','UTF-8');
assert(fid~=-1); standard=fscanf(fid,'%c'); fclose(fid);
[allowed,version]=service_parse_document_profile(standard);
assert(strcmp(version,'5.23') && all(ismember({'sum','prod','alpha','begin','quad'},allowed)));
for ending={newline,sprintf('\r\n'),sprintf('\r')}
    normalized=regexprep(standard,'\r\n|\n|\r',ending{1});
    [actual,v]=service_parse_document_profile([normalized ending{1} '   * Outside: `\unknown`']);
    assert(isequal(actual,allowed) && strcmp(v,version));
end
bad={strrep(standard,'Акценты и многоточия','Неизвестная категория'), ...
    strrep(standard,'Акценты и многоточия','Функции и операторы'), ...
    regexprep(standard,'[^\r\n]*Акценты и многоточия[^\r\n]*','')};
for k=1:numel(bad)
    rejected=false;
    try
        service_parse_document_profile(bad{k});
    catch exception
        assert(strcmp(exception.identifier,'libtr:docs:Standard'));
        rejected=true;
    end
    assert(rejected,'Invalid profile must be rejected');
end
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