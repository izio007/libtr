function result=filter2win_persistent_run(root,folder)
% Execute the working kernel on the eight saved optimizer-output scenarios.
cfg=filter2win_config;
spec=jsondecode(fileread(fullfile(root,'matlab','tests','configs','filter2win_optimizer_experiments.json')));
checks=struct('case_id',{},'requirement',{},'status',{}); traces={};
for j=1:numel(spec.scenarios)
    item=spec.scenarios(j); history=item.prehistory;
    all_time=history.A(:,1);
    if ~isempty(history.B), all_time=[all_time;history.B(:,1)]; end
    [rc,state]=filter2win(cfg,struct(),min(all_time)-1,NaN,true); assert(rc==0);
    % Explicit retained prehistory is a test initial condition, not a new
    % observation or knowledge of the true coordinate supplied to the filter.
    for k=1:2
        names={'main','alt'}; labels={'A','B'}; data=history.(labels{k});
        [~,q]=fifo_double('init',[],cfg.(names{k}).capacity);
        for n=1:size(data,1), [rc,q]=fifo_double('push',q,data(n,1),data(n,2)); assert(rc==0); end
        state.FILTER_STATE.(names{k})=q;
        if ~isempty(data), state.FILTER_STATE.last_accept(k)=data(end,1); end
    end
    state.FILTER_STATE.last_tick=max(all_time);
    state.FILTER_STATE.last_input=max(all_time);
    state.FILTER_STATE.status_since=max(all_time);
    state.FILTER_STATE.status=2; state.FILTER_STATE.active=1;
    state.FILTER_STATE.last_output=median(history.A(:,2));
    n=numel(item.events); records=cell(1,n); states=cell(1,n);
    for k=1:n
        e=item.events(k); x=e.x; if isempty(x), x=NaN; end
        old=state.FILTER_STATE;
        [rc,state,d]=filter2win(cfg,state,e.t,x,isnan(x));
        assert(rc==0,'libtr:f2w:Scenario','%s tick %d: %s',item.id,k,d.reason);
        records{k}=d; states{k}=state.FILTER_STATE;
        assert(d.valid==isfinite(d.output));
        if d.valid, assert(d.active_window>0 && d.windows(d.active_window).ready); end
        for w={'main','alt'}
            [~,~,before]=fifo_double('read',old.(w{1}));
            [~,~,after]=fifo_double('read',state.FILTER_STATE.(w{1}));
            route=1+double(strcmp(w{1},'alt'));
            if ~d.accepted || d.route~=route
                assert(isequaln(old.(w{1}),state.FILTER_STATE.(w{1})));
            else
                wanted=[before.time e.t];
                if ~isempty(d.evicted.time)
                    assert(d.evicted.time==wanted(1)); wanted(1)=[];
                end
                assert(all(ismember(d.removed.time,wanted)) && ~ismember(e.t,d.removed.time));
                wanted=wanted(~ismember(wanted,d.removed.time));
                assert(isequal(after.time,wanted) && all(diff(after.time)>0));
            end
        end
    end
    time=[item.events.t]; input=arrayfun(@value,item.events); truth=[item.events.truth];
    status=cellfun(@(d)d.status,records); output=cellfun(@(d)d.output,records);
    active=cellfun(@(d)d.active_window,records); countA=cellfun(@(d)d.main_count,records); countB=cellfun(@(d)d.alt_count,records);
    source={item.events.source_for_review}; switched=cellfun(@(d)d.reacquired,records);
    wrong=find(strcmp(source,'wrong')); returns=find(strcmp(source,'normal') & (1:n)>max([0 wrong]),1);
    aftergap=find(isnan(input(1:end-1)) & ~isnan(input(2:end)),1)+1;
    quality=cellfun(@(d)strcmp(d.reason,'NEW_POINT_OUTLIER') || strcmp(d.reason,'PROPOSED_SPREAD_REJECTED'),records);
    middle=strcmp(source,'middle');
    actual=struct('switches',sum(switched),'alternative_eventually_ready',any(cellfun(@(d)d.windows(2).ready,records)), ...
        'alternative_unready',all(cellfun(@(d)~d.windows(2).ready,records)), ...
        'first_main_return_immediate',~isempty(returns) && active(returns)==1 && isfinite(output(returns)), ...
        'fifo_unchanged_on_missing',true,'first_after_gap_activates_B',~isempty(aftergap) && active(aftergap)==2 && isfinite(output(aftergap)), ...
        'first_wrong_activates_B',~isempty(wrong) && active(wrong(1))==2 && switched(wrong(1)), ...
        'quality_rejections',any(quality),'rejected_point_leaves_fifo_unchanged',true, ...
        'middle_rejected',any(middle) && all(cellfun(@(d)~d.accepted,records(middle))));
    for key=fieldnames(item.expected).'
        assert(isequal(actual.(key{1}),item.expected.(key{1})),'libtr:f2w:Expectation','%s: %s',item.id,key{1});
        checks(end+1)=struct('case_id',item.id,'requirement',key{1},'status','PASS'); %#ok<AGROW>
    end
    tr=struct('case_id',item.id,'title',item.title,'time',time,'measured',input,'truth',truth, ...
        'output',output,'status',status,'active',active,'records',{records},'states',{states});
    traces{end+1}=tr; %#ok<AGROW>
    writetable(table(time(:),input(:),truth(:),output(:),status(:),active(:),countA(:),countB(:), ...
        'VariableNames',{'time','measurement','truth','output','status','active','count_A','count_B'}),fullfile(folder,[item.id '.csv']));
end
result=struct('schema_version',3,'status','PASS','production_kernel_executed',true, ...
    'physical_optimizer_executed',false,'cfg',cfg,'spec',spec,'checks',checks,'traces',{traces});
end
function x=value(e)
x=e.x; if isempty(x), x=NaN; end
end
