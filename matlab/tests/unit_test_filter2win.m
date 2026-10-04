function unit_test_filter2win
% F2W-S2-02/04/05: independent robust arithmetic and API invariants.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'matlab','tests','support'));
c=filter2win_config;
p=jsondecode(fileread(fullfile(root,'matlab','tests','configs','filter2win_schema2_cases.json')));
[ok,reason]=filter2win_validate(c); assert(ok,reason);
samples=struct('time',p.model_time(:).','value',p.model_value(:).');
m=filter2win_model(samples,c.main);
assert(abs(m.level-p.expected_median)<=p.tolerance);
assert(abs(m.mad-p.expected_mad)<=p.tolerance);
w=c.main; w.model='linear';
samples.value=p.line_level+p.line_velocity*samples.time;
m=filter2win_model(samples,w);
assert(abs(m.velocity-p.line_velocity)<=p.tolerance);
assert(abs(m.level-samples.value(end))<=p.tolerance && m.mad<=p.tolerance);
w.model='known_velocity'; w.known_velocity=p.line_velocity;
m=filter2win_model(samples,w);
assert(abs(m.level-samples.value(end))<=p.tolerance);
a=struct(); b=struct('X_MAIN_REF',p.unrelated_reference);
for k=1:numel(p.startup_time)
    t=p.startup_time(k);
    [rc,a]=filter2win(c,a,t,p.level,false); assert(rc==0);
    [rc,b]=filter2win(c,b,t,p.level,false); assert(rc==0);
    assert(isequaln(a.X_FILTERED_OUTPUT,b.X_FILTERED_OUTPUT));
    assert(a.FILTER_VALID==isfinite(a.X_FILTERED_OUTPUT));
    if k<c.main.min_samples || t-p.startup_time(1)<c.main.min_span_seconds
        assert(~a.FILTER_VALID);
    end
end
assert(a.FILTER_STATUS==2 && abs(a.X_FILTERED_OUTPUT-p.level)<=p.tolerance);
old=a;
[rc,a]=filter2win(c,a,p.startup_time(end),p.level,false);
assert(rc==1 && isequaln(a,old));
flat=struct('N',1);
[rc,out]=filter2win(flat,old,p.refusal_time,p.level,false);
assert(rc==1 && isequaln(out,old));
bad=c; bad.schema_version=1;
[rc,a]=filter2win(bad,a,p.refusal_time,p.level,false);
assert(rc==1 && isequaln(a,old));
legacy=struct('FILTER_STATE',struct('anchor',p.level));
[rc,out]=filter2win(c,legacy,p.refusal_time,p.level,false);
assert(rc==1 && isequaln(out,legacy));
for k=1:numel(p.gap_time)
    [rc,a]=filter2win(c,old,p.gap_time(k),NaN,true);
    assert(rc==0 && a.FILTER_STATUS==p.gap_status(k));
    assert(a.FILTER_VALID==p.gap_valid(k));
end
end