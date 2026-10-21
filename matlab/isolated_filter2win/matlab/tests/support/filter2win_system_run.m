function result=filter2win_system_run(root,output_dir)
% Independent system acceptance. All experiment parameters come from JSON.
% Plateau levels/events are generated before invoking the filter. The false
% plateau is a persistent measurement error that MUST be captured autonomously.
% Existing fixed-seed consumer regression and 17-mode unit suite are separate.
cfg=filter2win_config(fullfile(root,'matlab','tests','configs','filter2win_schema2_config.json'));
p=jsondecode(fileread(fullfile(root,'matlab','tests','configs','filter2win_system.json')));
checks=struct('requirement',{},'case_id',{},'status',{},'expected',{},'actual',{});
traces={}; oldrng=rng; cleanup=onCleanup(@() rng(oldrng));
verify=@check;
for j=1:numel(p.seeds)
    rng(p.seeds(j),p.rng_algorithm); rng_before=rng;
    data=observations(cfg,p,p.noise_profiles{j}); rng_after=rng;
    name=sprintf('random_%d_%s',p.seeds(j),p.noise_profiles{j});
    tr=execute(cfg,data.time,data.measured,data.missing,name,verify);
    tr.data=data; tr.seed=p.seeds(j); tr.rng_before=rng_before; tr.rng_after=rng_after;
    verify(isequaln(rng,rng_after),'F2W-SYS-001','Filter does not consume RNG',rng,tr);
    verify(all(diff(tr.time)>0) && numel(unique(diff(tr.time)))>1, ...
        'F2W-SYS-001','Strictly increasing irregular timestamps',diff(tr.time),tr);
    verify(isequal(unique(data.phase),1:5),'F2W-SYS-001', ...
        'Initial plateau, persistent error, return, gap, and renewal are present',unique(data.phase),tr);
    verify(data.origin>=p.time_origin_range(1) && data.origin<=p.time_origin_range(2), ...
        'F2W-SYS-001',p.time_origin_range,data.origin,tr);
    nominal=data.levels([1 5]);
    verify(all(nominal>=p.level_range(1) & nominal<=p.level_range(2)) && ...
        abs(data.jump)>=p.jump_range(1) && abs(data.jump)<=p.jump_range(2), ...
        'F2W-SYS-001','Realized nominal levels and jump follow declared ranges', ...
        [nominal data.jump],tr);
    durations=data.requested_durations([1 2 3 5]);
    verify(all(durations>=p.phase_duration_range(1) & durations<=p.phase_duration_range(2)), ...
        'F2W-SYS-001',p.phase_duration_range,durations,tr);
    intervals=tr.time-[data.origin tr.time(1:end-1)]; intervals=intervals(data.phase~=4);
    verify(all(intervals>=p.dt_range(1)-p.tolerance & intervals<=p.dt_range(2)+p.tolerance), ...
        'F2W-SYS-001',p.dt_range,intervals,tr);
    ordinary=~data.missing & ~data.spike;
    verify(all(abs(data.measured(ordinary)-data.plateau_model(ordinary))<=p.noise_bound+p.tolerance), ...
        'F2W-SYS-005','Actual non-spike measurements obey the declared noise support', ...
        data.measured(ordinary)-data.plateau_model(ordinary),tr);
    for phase=[1 5]
        idx=find(data.phase==phase); count=1:numel(idx);
        span=tr.time(idx)-tr.time(idx(1));
        ready=count>=cfg.main.min_samples & span>=cfg.main.min_span_seconds;
        verify(all(~isfinite(tr.output(idx(~ready)))),'F2W-SYS-002', ...
            'No output before BOTH initial count and elapsed span',tr.output(idx(~ready)),tr);
        first=find(ready,1);
        verify(~isempty(first) && isfinite(tr.output(idx(first))), ...
            'F2W-SYS-004','Initial/restarted base becomes valid when ready',first,tr);
    end
    for phase=[2 3]
        idx=find(data.phase==phase); first=idx(1);
        span=tr.time(idx)-tr.time(first); count=1:numel(idx);
        eligible=count>=cfg.alt.min_samples & span>=cfg.alt.min_span_seconds & ...
            span>=cfg.alt.confirm_seconds & span>=cfg.handover.wait_seconds;
        start=find(eligible,1); start=idx(start);
        verify(~isempty(start) && tr.status(start)==14,'F2W-SYS-003', ...
            'Autonomous handover at independent count/time boundary',tr.status(start),tr);
        finish=idx(find(tr.time(idx)-tr.time(start)>=cfg.handover.duration_seconds,1));
        verify(~isempty(finish) && tr.status(finish)==6,'F2W-SYS-003', ...
            'Autonomous capture after handover duration',tr.status(finish),tr);
        level=data.plateau_model(first);
        verify(abs(tr.output(finish)-level)<=p.noise_bound+p.tolerance, ...
            'F2W-SYS-003','Captured output is inside declared measurement-noise support',tr.output(finish)-level,tr);
        settling=idx(idx>finish & tr.time(idx)-tr.time(finish)<cfg.handover.settle_seconds);
        verify(all(tr.status(settling)==16),'F2W-SYS-006','Post-capture settling mode',tr.status(settling),tr);
        tail=idx(tr.time(idx)-tr.time(finish)>=cfg.handover.settle_seconds & ...
            (1:numel(idx))>find(idx==finish)+cfg.handover.settle_min_samples);
        tail=tail(~data.spike(tail));
        verify(~isempty(tail) && all(isfinite(tr.output(tail))) && ...
            all(abs(tr.output(tail)-level)<=p.noise_bound+p.tolerance), ...
            'F2W-SYS-005','Tracking remains within bounded rough-plateau support',tr.output(tail)-level,tr);
    end
    spikes=find(data.spike);
    for k=spikes
        verify(tr.status(k)==3 && abs(tr.output(k)-data.plateau_model(k))<=p.noise_bound+p.tolerance && ...
            tr.records{k}.main_count==tr.records{k}.main_before, ...
            'F2W-SYS-005','Isolated spike never enters the main FIFO',tr.records{k},tr);
    end
    gaps=find(data.phase==4); previous=gaps(1)-1;
    elapsed=tr.time(gaps)-tr.time(previous);
    expected=8*ones(size(gaps)); expected(elapsed<=cfg.flow.gap_hold_seconds)=7;
    expected(elapsed>cfg.flow.timeout_seconds)=9;
    verify(isequal(tr.status(gaps),expected),'F2W-SYS-004',expected,tr.status(gaps),tr);
    verify(isequal(isfinite(tr.output(gaps)),expected==7),'F2W-SYS-004', ...
        'Valid only through the inclusive gap-hold boundary',isfinite(tr.output(gaps)),tr);
    reset=gaps(end);
    verify(tr.records{reset}.main_count==0 && tr.records{reset}.alt_count==0, ...
        'F2W-SYS-004','Timeout clears both real-data queues',tr.records{reset},tr);
    traces{end+1}=tr; %#ok<AGROW>
end
% Deterministic arithmetic fixtures isolate guards from noise and generation.
base=data.levels(1); target=base+data.jump; origin=floor(data.time(1));
for offsets={p.fast_offsets(:).',p.slow_offsets(:).'}
    dt=offsets{1}; name=sprintf('main_span_%g',dt(end));
    tr=execute(cfg,origin+dt,base*ones(size(dt)),false(size(dt)),name,verify);
    expected=numel(dt)>=cfg.main.min_samples && dt(end)>=cfg.main.min_span_seconds;
    verify(isfinite(tr.output(end))==expected,'F2W-SYS-002',expected,isfinite(tr.output(end)),tr);
    traces{end+1}=tr; %#ok<AGROW>
    [t,x]=with_baseline(p,origin,base,target,dt);
    tr=execute(cfg,t,x,false(size(t)),['alt_' name],verify);
    expected=dt(end)>=cfg.alt.confirm_seconds && dt(end)>=cfg.alt.min_span_seconds;
    verify((tr.status(end)==14)==expected && tr.records{end}.alt_count==numel(dt), ...
        'F2W-SYS-002','Equal candidate counts, independently different elapsed evidence',tr.status(end),tr);
    traces{end+1}=tr; %#ok<AGROW>
end
for j=1:numel(p.profiles)
    profile=p.profiles(j); c=profile_config(cfg,profile);
    offsets=profile.offsets(:).'; [t,x]=with_baseline(p,origin,base,target,offsets);
    tr=execute(c,t,x,false(size(t)),profile.name,verify); n=numel(p.baseline_time);
    verify(isequal(tr.status(n+1:end),profile.expected_status(:).'), ...
        'F2W-SYS-006',profile.expected_status,tr.status(n+1:end),tr);
    collecting=n+find(ismember(tr.status(n+1:end),[3 4]));
    if c.flow.outlier_hold_seconds==0
        verify(all(isnan(tr.output(collecting))),'F2W-SYS-006', ...
            'Zero hold gives NaN while confirmation is pending',tr.output(collecting),tr);
    end
    blending=find(tr.status==14);
    if ~isempty(blending)
        elapsed=tr.time(blending)-tr.time(blending(1)); u=elapsed/c.handover.duration_seconds;
        if strcmp(c.handover.curve,'smoothstep'), u=u.^2.*(3-2*u); end
        expected=(1-u)*base+u*target;
        verify(all(abs(tr.output(blending)-expected)<=p.tolerance), ...
            'F2W-SYS-006','Independent linear/smoothstep interpolation',tr.output(blending)-expected,tr);
    end
    verify(abs(tr.output(end)-target)<=p.tolerance,'F2W-SYS-006',target,tr.output(end),tr);
    traces{end+1}=tr; %#ok<AGROW>
end
traces=[traces compatibility_cases(cfg,p,origin,base,target,verify) ...
    boundary_cases(cfg,p,origin,base,target,verify) ...
    time_cases(cfg,p,origin,base,target,verify)];
result=struct('cfg',cfg,'spec',p,'checks',checks,'traces',{traces}, ...
    'status','PASS','executed_checks',numel(checks));

    function check(condition,id,expected,actual,memory)
        if ~condition
            stack=dbstack('-completenames'); frame=stack(min(2,numel(stack)));
            location=struct('file',frame.file,'line',frame.line);
            folder=fullfile(root,'runtime','defects'); if ~isfolder(folder), mkdir(folder); end
            [~,token]=fileparts(tempname(folder));
            snapshot=fullfile(folder,['defect_' datestr(now,'yyyymmdd_HHMMSS_FFF') '_' token '.mat']);
            rng_context=rng; save(snapshot,'cfg','p','memory','expected','actual','rng_context');
            defect=struct('status','FAILED','test_id',id,'location',location, ...
                'condition','Independent system invariant','failure_reason',memory.case_id, ...
                'expected',expected,'actual',actual,'memory_snapshot', ...
                struct('mat_file',snapshot,'rng',rng_context,'inputs','See MAT memory', ...
                'state','See MAT memory.states and memory.state'));
            file=[snapshot '.json']; fid=fopen(file,'w','n','UTF-8');
            if fid~=-1, fprintf(fid,'%s\n',jsonencode(defect)); fclose(fid); end
            error('libtr:filter2win:System','%s / %s. Snapshot: %s',id,memory.case_id,snapshot);
        end
        checks(end+1)=struct('requirement',id,'case_id',memory.case_id, ...
            'status','PASS','expected',expected,'actual',actual);
    end
end

function data=observations(c,p,noise_profile)
origin=draw(p.time_origin_range); base=draw(p.level_range); jump=draw(p.jump_range);
% Both directions are exercised; no fixed plateau coordinate enters a guard.
if rand<0.5, jump=-jump; end
renewal=draw(p.level_range);
time=[]; phase=[]; levels=[base base+jump base base renewal];
requested_durations=NaN(1,5); event_times=NaN(1,5);
cursor=origin;
for j=1:5
    if j==4
        e=p.boundary_epsilon_seconds;
        offsets=[e c.flow.gap_hold_seconds-e c.flow.gap_hold_seconds ...
            c.flow.gap_hold_seconds+e c.flow.timeout_seconds-e ...
            c.flow.timeout_seconds c.flow.timeout_seconds+e];
        times=cursor+offsets;
    else
        duration=draw(p.phase_duration_range); requested_durations(j)=duration;
        finish=cursor+duration; times=[];
        while cursor<finish
            cursor=cursor+draw(p.dt_range);
            if cursor<finish, times(end+1)=cursor; end %#ok<AGROW>
        end
    end
    event_times(j)=times(1);
    time=[time times]; phase=[phase j*ones(size(times))]; %#ok<AGROW>
    cursor=times(end);
end
plateau_model=levels(phase); reference=base*ones(size(time)); reference(phase==5)=renewal;
switch noise_profile
    case 'bounded_uniform', noise=p.noise_bound*(2*rand(size(time))-1);
    case 'bounded_skew', noise=p.noise_bound*(2*rand(size(time)).^2-1);
    case 'bounded_cauchy'
        noise=p.noise_bound*max(-1,min(1,tan(pi*(rand(size(time))-0.5))));
    otherwise, error('libtr:f2w:NoiseProfile','Unknown noise profile');
end
measured=plateau_model+noise; spike=false(size(time));
% Put isolated gross errors only in the initial steady phase. Their next
% observation is always genuine main-band data, not another candidate.
idx=find(phase==1);
for fraction=p.spike_fractions(:).'
    k=idx(max(1,min(numel(idx),round(fraction*numel(idx)))));
    spike(k)=true; measured(k)=measured(k)+p.spike_jump_multiplier*jump;
end
missing=phase==4; measured(missing)=NaN;
data=struct('time',time,'phase',phase,'measured',measured,'missing',missing, ...
    'reference',reference,'plateau_model',plateau_model,'spike',spike, ...
    'levels',levels,'jump',jump,'noise_profile',noise_profile,'origin',origin, ...
    'requested_durations',requested_durations,'event_times',event_times);
end

function value=draw(bounds)
value=bounds(1)+(bounds(2)-bounds(1))*rand;
end

function tr=execute(c,t,x,missing,name,check)
[ok,reason]=filter2win_validate(c); assert(ok,reason);
tr=struct('case_id',name,'cfg',c,'time',t,'measured',x,'missing',missing, ...
    'output',NaN(size(t)),'status',NaN(size(t)), ...
    'records',{cell(size(t))},'states',{cell(size(t))});
state=struct();
for k=1:numel(t)
    [rc,state,d]=filter2win(c,state,t(k),x(k),missing(k));
    tr.records{k}=d; tr.state=state; tr.last_step=k;
    if isfield(state,'FILTER_STATE'), tr.states{k}=state.FILTER_STATE; end
    check(rc==0,'F2W-SYS-007','Accepted valid API step',d,tr);
    tr.output(k)=state.X_FILTERED_OUTPUT; tr.status(k)=state.FILTER_STATUS;
    check(state.FILTER_STATUS==state.FILTER_STATE.status && ...
        state.FILTER_VALID==isfinite(state.X_FILTERED_OUTPUT), ...
        'F2W-SYS-007','Published status/valid/output agree with numerical state',d.status,tr);
    for field={'main','alt'}
        [code,~,samples]=fifo_double('read',state.FILTER_STATE.(field{1}));
        [found,indices]=ismember(samples.time,t(1:k));
        genuine=code==0 && all(found);
        if genuine
            genuine=all(~missing(indices)) && isequal(samples.value,x(indices)) && ...
                all(diff(samples.time)>0);
        end
        check(genuine,'F2W-SYS-004','FIFO contains only actual earlier finite measurements',samples,tr);
    end
end
end

function [t,x]=with_baseline(p,origin,base,target,offsets)
baseline=origin+p.baseline_time(:).';
t=[baseline baseline(end)+p.candidate_delay_seconds+offsets];
x=[base*ones(size(baseline)) target*ones(size(offsets))];
end

function c=profile_config(c,p)
c.flow.outlier_hold_seconds=p.hold; c.handover.wait_seconds=p.wait;
c.handover.duration_seconds=p.duration; c.handover.curve=p.curve;
c.handover.settle_seconds=p.settle_seconds; c.handover.settle_min_samples=p.settle_samples;
c.alt.allow_partial=p.allow_partial; c.alt.partial_confirm_seconds=p.partial_confirm;
end

function traces=compatibility_cases(c,p,origin,base,target,check)
traces={}; baseline=origin+p.baseline_time(:).'; candidate=baseline(end)+p.candidate_delay_seconds;
for j=1:numel(p.compatibility_methods)
    cfg=c; cfg.alt.compatibility.method=p.compatibility_methods{j};
    % Ignore until BOTH streak thresholds hold. Missing input never adds a hit.
    cfg.alt.incompatible_min_samples=p.incompatible_min_samples;
    cfg.alt.incompatible_min_seconds=p.incompatible_min_seconds;
    start=candidate+p.fast_offsets(end)+p.candidate_delay_seconds;
    offsets=sort([p.incompatible_offsets(:).' p.incompatible_missing_offset]);
    mismatch=start+offsets; missing=offsets==p.incompatible_missing_offset;
    t=[baseline candidate+p.fast_offsets(:).' mismatch];
    x=[base*ones(size(baseline)) target*ones(size(p.fast_offsets(:).')) ...
        (target+p.spike_jump_multiplier*(target-base))*ones(size(mismatch))];
    m=[false(1,numel(baseline)+numel(p.fast_offsets)) missing]; x(m)=NaN;
    tr=execute(cfg,t,x,m,['streak_' cfg.alt.compatibility.method],check);
    first=numel(baseline)+numel(p.fast_offsets)+1; before=tr.records{first}.alt_before;
    retained=first:numel(t)-1;
    check(all(cellfun(@(d) d.alt_count==before,tr.records(retained))), ...
        'F2W-SYS-005','Incompatible/missing points retain evidence before joint streak boundary', ...
        cellfun(@(d) d.alt_count,tr.records(retained)),tr);
    check(strcmp(tr.records{end}.guards.incompatible_action,'restart') && ...
        tr.records{end}.alt_count==1,'F2W-SYS-005', ...
        'Joint count AND duration restarts from one actual point',tr.records{end},tr);
    traces{end+1}=tr; %#ok<AGROW>
    for action={'clear','restart'}
        cfg.alt.on_incompatible=action{1};
        tr=execute(cfg,t(1:first),x(1:first),m(1:first), ...
            [action{1} '_' cfg.alt.compatibility.method],check);
        expected=double(strcmp(action{1},'restart'));
        check(tr.records{end}.alt_count==expected,'F2W-SYS-005',expected,tr.records{end}.alt_count,tr);
        traces{end+1}=tr; %#ok<AGROW>
    end
end
% Absolute robust quality, independent of local compatibility.
for action={'retain','clear','restart'}
    cfg=c; cfg.alt.band.max_mad=p.quality_max_mad; cfg.alt.on_reject=action{1};
    [t,x]=with_baseline(p,origin,base,target,p.slow_offsets(:).');
    x(end-numel(p.quality_values)+1:end)=target+p.quality_values(:).';
    tr=execute(cfg,t,x,false(size(t)),['quality_' action{1}],check);
    expected=numel(p.quality_values);
    if strcmp(action{1},'clear'), expected=0; elseif strcmp(action{1},'restart'), expected=1; end
    check(tr.status(end)==5 && tr.records{end}.alt_count==expected, ...
        'F2W-SYS-005','Quality rejection with declared buffer policy',tr.records{end},tr);
    traces{end+1}=tr; %#ok<AGROW>
end
end

function traces=boundary_cases(c,p,origin,base,target,check)
traces={}; cfg=c;
for field=fieldnames(p.asymmetric_band).'
    cfg.main.band.(field{1})=p.asymmetric_band.(field{1});
end
b=p.asymmetric_band; e=p.residual_epsilon;
residuals=[-b.lower_margin -b.lower_margin-e -b.exit_lower_margin ...
    -b.exit_lower_margin-e b.upper_margin b.upper_margin+e ...
    b.exit_upper_margin b.exit_upper_margin+e];
expected_status=p.expected_band_status(:).'; expected_alt=p.expected_band_alt(:).';
for j=1:numel(residuals)
    [t,x]=with_baseline(p,origin,base,base+residuals(j),0);
    tr=execute(cfg,t,x,false(size(t)),sprintf('asymmetric_band_%d',j),check);
    check(tr.status(end)==expected_status(j) && tr.records{end}.alt_count==expected_alt(j), ...
        'F2W-SYS-006','Inclusive entry/exit bands and asymmetric hysteresis',tr.records{end},tr);
    traces{end+1}=tr; %#ok<AGROW>
end
% Extra rule clocks act after the candidate's own physical evidence guards.
cfg=c; r=find(strcmp({cfg.rules.event},'ALTERNATIVE_READY'));
cfg.rules(r).confirm_ticks=p.extra_rule_ticks; cfg.rules(r).confirm_seconds=p.extra_rule_seconds;
offsets=[p.slow_offsets(:).' p.slow_offsets(end)+p.extra_rule_offsets(2:end).'];
[t,x]=with_baseline(p,origin,base,target,offsets);
tr=execute(cfg,t,x,false(size(t)),'extra_rule_confirmation',check);
verify_idx=numel(p.baseline_time)+numel(p.slow_offsets);
check(all(tr.status(verify_idx:end-1)==4) && tr.status(end)==14, ...
    'F2W-SYS-006','Additional rule count/time confirmation delays the transition',tr.status(verify_idx:end),tr);
traces{end+1}=tr;
% Controlled missing input during a confirmed handover, all three policies.
for policy={'pause','continue','cancel'}
    cfg=c; cfg.handover.on_missing=policy{1};
    [t,x]=with_baseline(p,origin,base,target,p.slow_offsets(:).');
    t=[t t(end)+p.handover_gap_seconds t(end)+2*p.handover_gap_seconds];
    x=[x NaN target]; m=false(size(t)); m(end-1)=true;
    tr=execute(cfg,t,x,m,['handover_missing_' policy{1}],check);
    if strcmp(policy{1},'cancel')
        check(tr.status(end-1)==8 && isnan(tr.output(end-1)), ...
            'F2W-SYS-006','Cancel policy invalidates handover on missing input',tr.records{end-1},tr);
    else
        expected=0;
        if strcmp(policy{1},'continue'), expected=2*p.handover_gap_seconds; end
        check(tr.status(end)==14 && abs(tr.records{end}.guards.blend_elapsed-expected)<=p.tolerance, ...
            'F2W-SYS-006','Pause/continue uses actual timestamp intervals',tr.records{end},tr);
    end
    traces{end+1}=tr; %#ok<AGROW>
end
end

function traces=time_cases(c,p,origin,base,target,check)
traces={}; instant=c; instant.handover.duration_seconds=0;
% Minimum occupied span can be adjusted independently of sequence confirmation.
cfg=instant; cfg.alt.confirm_seconds=p.span_test_confirm_seconds;
cfg.alt.min_span_seconds=p.alt_span_test_seconds;
for offsets={p.fast_offsets(:).',p.slow_offsets(:).'}
    dt=offsets{1}; [t,x]=with_baseline(p,origin,base,target,dt);
    tr=execute(cfg,t,x,false(size(t)),sprintf('alt_min_span_%g',dt(end)),check);
    expected=dt(end)>=cfg.alt.min_span_seconds;
    check((tr.status(end)==6)==expected,'F2W-SYS-002', ...
        'Occupied span guard with separate confirmation disabled',tr.status(end),tr);
    traces{end+1}=tr; %#ok<AGROW>
end
for cadence={'fast','slow'}
    offsets=p.(['settle_' cadence{1} '_offsets']); offsets=offsets(:).';
    expected=p.(['settle_' cadence{1} '_status']); expected=expected(:).';
    [t,x]=with_baseline(p,origin,base,target,p.slow_offsets(:).'); n=numel(t);
    t=[t t(end)+offsets]; x=[x target*ones(size(offsets))];
    tr=execute(instant,t,x,false(size(t)),['settle_' cadence{1}],check);
    check(isequal(tr.status(n+1:end),expected),'F2W-SYS-006',expected,tr.status(n+1:end),tr);
    for k=n+find(expected==16)
        check(tr.records{k}.guards.primary_model.n==c.alt.min_samples && ...
            tr.records{k}.main_count>c.alt.min_samples, ...
            'F2W-SYS-006','Retained prior frozen while genuine samples accumulate',tr.records{k},tr);
    end
    check(tr.state.FILTER_STATE.primary.n==tr.state.FILTER_STATE.main.count, ...
        'F2W-SYS-006','Main fit resumes once BOTH settling guards are satisfied',tr.state,tr);
    traces{end+1}=tr; %#ok<AGROW>
end
% Candidate max-gap boundary: clear/restart before accepting an excessive gap.
for action={'restart','retain'}
    for excess=[0 p.boundary_epsilon_seconds]
        cfg=instant; cfg.alt.gap_action=action{1}; dt=p.slow_offsets(:).';
        dt(end)=dt(end-1)+cfg.alt.max_gap_seconds+excess;
        [t,x]=with_baseline(p,origin,base,target,dt);
        tr=execute(cfg,t,x,false(size(t)),sprintf('alt_gap_%s_%g',action{1},excess),check);
        expected=excess==0;
        check((tr.status(end)==6)==expected,'F2W-SYS-006', ...
            'Candidate max-gap is inclusive and independent of count',tr.status(end),tr);
        if ~expected
            count=numel(dt); if strcmp(action{1},'restart'), count=1; end
            check(tr.records{end}.alt_count==count,'F2W-SYS-006',count,tr.records{end}.alt_count,tr);
        end
        traces{end+1}=tr; %#ok<AGROW>
    end
end
for window={'main','alt'}
    for excess=[0 p.boundary_epsilon_seconds]
        cfg=c; cfg.(window{1}).freshness_seconds=p.freshness_test_seconds;
        if strcmp(window{1},'main')
            t=origin+p.baseline_time(:).'; x=base*ones(size(t)); expected=7;
        else
            [t,x]=with_baseline(p,origin,base,target,p.slow_offsets(:).'); expected=14;
        end
        t=[t t(end)+p.freshness_test_seconds+excess]; x=[x NaN]; m=false(size(t)); m(end)=true;
        if excess>0, expected=8; end
        tr=execute(cfg,t,x,m,sprintf('%s_freshness_%g',window{1},excess),check);
        check(tr.status(end)==expected,'F2W-SYS-006',expected,tr.status(end),tr);
        traces{end+1}=tr; %#ok<AGROW>
    end
end
end
