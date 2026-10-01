function model = test_model_step(model)
% One observation, no synthesis, metrics, presentation or file I/O.
o=model.observations;
j=model.cursor+1;
assert(j<=numel(model.result.statuses),'libtr:testmodel:Complete','Model already complete');
scalar=isfield(model,'mode') && strcmp(model.mode,'scalar');
if scalar
    P=[];
else
    P=o.P;
end
if isfield(model,'mode') && strcmp(model.mode,'trajectory')
    P=o.P(:,:,min(j,size(o.P,3)));
end
try
    stateful=isfield(model,'stateful') && model.stateful;
    if stateful
        if scalar
            frame=struct('index',j,'time',model.time(j), ...
                'measurement',o.measurement(j),'missing',o.missing(j));
        else
            frame=struct('index',j,'time',model.time(j),'P',P, ...
                'alpha',o.alpha(:,j),'beta',o.beta(:,j),'va',o.va,'vb',o.vb);
        end
        [status,x,next]=model.algorithm(model.algorithm_state,frame);
        test_state_validate(next);
    else
        [status,x]=model.algorithm(P,o.alpha(:,j),o.beta(:,j),o.va,o.vb);
    end
    assert(isscalar(status) && ismember(status,[0 1 2]));
    rows=3; if scalar, rows=1; end
    assert(isa(x,'double') && isreal(x) && isequal(size(x),[rows 1]));
    model.result.statuses(j)=status;
    model.result.samples(:,j)=x;
    if status==0
        model.result.contract_violations(j)=~all(isfinite(x));
    else
        model.result.contract_violations(j)=~all(isnan(x));
    end
    if stateful && ~model.result.contract_violations(j)
        model.algorithm_state=next;
    end
catch exception
    model.result.contract_violations(j)=true;
    model.result.errors{j}=getReport(exception,'extended','hyperlinks','off');
end
model.cursor=j;
if isfield(model,'time'), model.current_time=model.time(j); end
end