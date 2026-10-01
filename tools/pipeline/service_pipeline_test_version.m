function hash = service_pipeline_test_version(request,root)
% Identity of the selected test source, not its transitive dependency closure.
name=service_pipeline_select_test(request,root);
assert(~isempty(name),'libtr:pipeline:Version','Version requires one unit test');
file=fullfile(root,'matlab','tests',[name '.m']);
fid=fopen(file,'rb'); assert(fid~=-1); cleanup=onCleanup(@() fclose(fid));
bytes=fread(fid,Inf,'*uint8');
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
hash=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
if isfield(request,'test_sha256')
    assert(ischar(request.test_sha256) && strcmp(request.test_sha256,hash), ...
        'libtr:pipeline:Version','Selected test bytes differ from requested SHA-256');
end
end