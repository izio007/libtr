function unit_test_exception_result_mask
setup_test_paths;
P=zeros(3,2); a=zeros(2,1); v=ones(2,1);
m=test_model_init(@throws,P,a,a,v,v,zeros(3,1));
m=test_model_step(m); result=test_model_result(m);
assert(isnan(result.statuses) && result.contract_violations);
assert(~isempty(result.errors{1}) && result.metrics.successful==0);
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
file=[tempname(fullfile(root,'runtime')) '.mat'];
save(file,'result'); saved=load(file,'result');
assert(isequaln(saved.result,result));
assert(isequal(test_result_valid_mask(saved.result),false));
assert(isequaln(saved.result,result));
bad=result; bad.contract_violations=false; rejects(bad);
for status=[-1 3 Inf -Inf 0.5]
    bad=result; bad.statuses=status; rejects(bad);
end
fprintf('CLOUD-VALID-007 exception roundtrip PASS: %s\n',file);
end
function [s,x]=throws(varargin)
s=NaN; x=NaN(3,1);
error('libtr:test:Injected','Intentional operator exception');
end
function rejects(r)
caught=false;
try
    test_result_valid_mask(r);
catch e
    caught=strcmp(e.identifier,'libtr:result:Validity');
end
assert(caught,'Expected explicit validity rejection');
end