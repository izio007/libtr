function unit_test_filter2win_candidate
% Schema-2 replacement of the supplied schema-1 contract suite.
% Independent transition expectations live in filter2win_cases.json.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
c=filter2win_config;
p=jsondecode(fileread(fullfile(root,'matlab','tests','configs','filter2win_cases.json')));
codes=[]; records={};
for j=1:numel(p.scenarios)
    spec=p.scenarios(j); cfg=policy(c,p.policies,spec.policy);
    [ok,reason]=filter2win_validate(cfg); assert(ok,reason);
    state=struct(); shifted=struct();
    if spec.baseline
        for k=1:numel(p.baseline_time)
            [state,~]=step(cfg,state,p.baseline_time(k),p.baseline_value(k),false);
            [shifted,~]=step(cfg,shifted,p.baseline_time(k)+p.translation_time, ...
                p.baseline_value(k)+p.translation_value,false);
        end
        assert(state.FILTER_STATUS==2 && state.FILTER_VALID);
    end
    for k=1:numel(spec.time)
        before=state;
        [state,d]=step(cfg,state,spec.time(k),spec.value(k),spec.missing(k));
        assert(d.status==spec.status(k),'libtr:f2w:Transition', ...
            '%s step %d: expected %d, actual %d',spec.id,k,spec.status(k),d.status);
        [shifted,translated]=step(cfg,shifted,spec.time(k)+p.translation_time, ...
            spec.value(k)+p.translation_value,spec.missing(k));
        assert(translated.status==d.status && translated.valid==d.valid);
        if d.valid
            assert(abs(translated.output-d.output-p.translation_value)<=p.tolerance);
        end
        if ismember(d.status,[0 1 8 9 11 12]), assert(~d.valid); end
        if d.status==6 || d.status==13
            assert(state.REACQUIRED && abs(d.output-p.target)<=p.tolerance);
        end
        if d.status==16
            assert(isequaln(state.FILTER_STATE.primary,before.FILTER_STATE.primary));
            assert(state.FILTER_STATE.main.count==before.FILTER_STATE.main.count+1);
        end
        if d.status==10
            assert(strcmp(d.guards.incompatible_action,'ignore'));
            assert(isequaln(state.FILTER_STATE.alt,before.FILTER_STATE.alt));
        end
        if d.status==5
            assert(state.FILTER_STATE.alt.count==cfg.alt.min_samples);
            assert(d.guards.candidate_model.mad>cfg.alt.band.max_mad);
        end
        if strcmp(spec.policy,'instant') && d.status~=6, assert(~d.valid); end
        if strcmp(spec.policy,'partial') && d.status==6, assert(d.guards.partial); end
        if d.status==14
            assert(d.blend_weight>=0 && d.blend_weight<1);
            assert(d.output>=p.baseline_value(end)-p.tolerance && d.output<=p.target+p.tolerance);
        end
        codes(end+1)=d.status; records{end+1}=d; %#ok<AGROW>
    end
end
assert(isequal(unique(codes),p.required_statuses(:).'),'libtr:f2w:Coverage','Missing operating modes');
save('filter2win_candidate_contract.mat','records','codes','p');
end

function cfg=policy(cfg,p,name)
switch name
    case 'default'
    case 'quality'
        cfg.alt.band.max_mad=p.quality_max_mad;
    case 'disabled'
        for k=1:numel(cfg.rules), cfg.rules(k).enabled=p.disabled_enabled; end
    case 'instant'
        cfg.flow.outlier_hold_seconds=p.instant_hold;
        cfg.handover.duration_seconds=p.instant_duration;
    case 'partial'
        cfg.alt.allow_partial=p.partial_enabled;
        cfg.alt.partial_confirm_seconds=p.partial_confirm_seconds;
        cfg.handover.duration_seconds=p.instant_duration;
    otherwise
        error('libtr:f2w:Policy','Unknown test policy');
end
end

function [state,d]=step(cfg,state,t,x,missing)
[rc,state,d]=filter2win(cfg,state,t,x,missing);
assert(rc==0,'libtr:f2w:Refusal','%s',d.reason);
assert(state.FILTER_STATUS==state.FILTER_STATE.status);
assert(state.FILTER_VALID==isfinite(state.X_FILTERED_OUTPUT));
end