function unit_test_result_validity
setup_test_paths;
clear test_model_result;
P=zeros(3,2); a=zeros(2,2); v=ones(2,1);
models={test_model_init(@position,P,a,a,v,v,zeros(3,1)), ...
    test_trajectory_init(@position,[0 1],P,a,a,v,v,zeros(3,2)), ...
    test_filter_init(struct(),struct(),[0 1],[0 0],[false false],[0 0])};
for k=1:numel(models)
    m=models{k}; m.cursor=2;
    rows=size(m.result.samples,1);
    m.result.samples=[ones(rows,1) 100*ones(rows,1)];
    m.result.statuses=[0 0];
    m.result.contract_violations=[false true];
    m.result.errors{2}='Injected diagnostic';
    raw=m.result;
    rejects(rmfield(m,'truth'),'libtr:testmodel:Context');
    for value={NaN,zeros(2),single(m.truth),complex(m.truth,ones(size(m.truth)))}
        bad=m; bad.truth=value{1}; rejects(bad,'libtr:testmodel:Context');
    end
    for value={'unknown',42,{'trajectory'}}
        bad=m; bad.mode=value{1}; rejects(bad,'libtr:testmodel:Context');
    end
    if k>1
        bad=m; bad.truth=m.truth(:,1); rejects(bad,'libtr:testmodel:Context');
        rejects(rmfield(m,'time'),'libtr:testmodel:Context');
        bad=m; bad.parameter=[0 1]; rejects(bad,'libtr:testmodel:Context');
        for value={[0 0],[1 0],[0 NaN],[0;1],single([0 1])}
            bad=m; bad.time=value{1}; rejects(bad,'libtr:testmodel:Context');
        end
    else
        bad=m; bad.time=[0 1]; rejects(bad,'libtr:testmodel:Context');
    end
    rejects([], 'libtr:testmodel:Context');
    rejects([m m], 'libtr:testmodel:Context');
    for field={'cursor','result'}
        rejects(rmfield(m,field{1}),'libtr:testmodel:Context');
    end
    for field={'samples','statuses','contract_violations','errors'}
        bad=m; bad.result=rmfield(bad.result,field{1});
        rejects(bad,'libtr:testmodel:Context');
    end
    bad=m; bad.result=[m.result m.result]; rejects(bad,'libtr:testmodel:Context');
    for cursor={[],[2 2],NaN,Inf,-1,0.5,'2',complex(2,1)}
        bad=m; bad.cursor=cursor{1}; rejects(bad,'libtr:testmodel:Context');
    end
    for cursor=[0 1 3]
        bad=m; bad.cursor=cursor; rejects(bad,'libtr:testmodel:Incomplete');
    end
    bad=m; bad.result.contract_violations=bad.result.contract_violations.'; rejects(bad);
    bad=m; bad.result.contract_violations=double(bad.result.contract_violations); rejects(bad);
    bad=m; bad.result.statuses=bad.result.statuses.'; rejects(bad);
    bad=m; bad.result.statuses(1)=Inf; rejects(bad);
    bad=m; bad.result.statuses(1)=3; rejects(bad);
    bad=m; bad.result.samples=single(bad.result.samples); rejects(bad);
    bad=m; bad.result.samples=complex(bad.result.samples,ones(size(bad.result.samples))); rejects(bad);
    bad=m; bad.result.errors=bad.result.errors.'; rejects(bad);
    for value={42,zeros(0,2),struct(),{'nested'},string('text'),char('ab','cd'),repmat('a',0,2)}
        bad=m; bad.result.errors{1}=value{1}; rejects(bad);
    end
    diagnostic=m;
    diagnostic.result.errors={repmat('a',1,0),sprintf('Диагностика\nSecond line')};
    checked=test_model_result(diagnostic);
    assert(isequal(checked.errors,diagnostic.result.errors));
    assert(isequal(checked.valid,[true false]));
    for status=[0 1 2 NaN]
        bad=m; bad.result.statuses(1)=status;
        if status==0, bad.result.samples(1,1)=Inf; end
        rejects(bad,'libtr:testmodel:ResultConsistency');
        bad.result.contract_violations(1)=true;
        accepted=test_model_result(bad);
        assert(~accepted.valid(1) && isequaln(accepted.statuses,bad.result.statuses));
    end
    for status=[1 2]
        refusal=m; refusal.result.statuses(1)=status;
        refusal.result.samples(:,1)=NaN;
        accepted=test_model_result(refusal);
        assert(~accepted.valid(1) && ~accepted.contract_violations(1));
    end
    r=test_model_result(m);
    assert(isequal(r.valid,[true false]) && r.metrics.successful==1);
    assert(r.metrics.failure_fraction==0.5 && abs(r.metrics.rmse-sqrt(rows))<1e-14);
    assert(isequaln(r.samples,raw.samples) && isequaln(r.statuses,raw.statuses));
    assert(isequal(r.errors,raw.errors));
    m.result.contract_violations=[true true];
    r=test_model_result(m);
    assert(~any(r.valid) && r.metrics.successful==0 && isnan(r.metrics.rmse));
    assert(r.metrics.failure_fraction==1);
end
% Normal execution, not only injected result records.
m=models{1}; m=test_model_step(m); m=test_model_step(m);
r=test_model_result(m); assert(all(r.valid) && r.metrics.successful==2);
unit_test_path_model;
fprintf('Explicit validity mask, raw evidence preservation and lifecycle regressions PASS\n');
end
function rejects(model,id)
if nargin<2, id='libtr:testmodel:ResultShape'; end
caught=false;
try
    test_model_result(model);
catch e
    caught=strcmp(e.identifier,id);
end
assert(caught,'Expected explicit result shape rejection');
end
function [s,x]=position(varargin)
s=0; x=ones(3,1);
end