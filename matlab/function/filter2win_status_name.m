function name=filter2win_status_name(code,schema)
% Stable public diagnostic IDs; API return status is a different value.
name='UNKNOWN';
if nargin>1 && ~(isequal(schema,2) || isequal(schema,3)), return; end
names={'WAITING_FOR_DATA','ACCUMULATING','STEADY_TRACKING', ...
    'TRACKING_WITH_OUTLIERS','ALT_ACCUMULATING','ALT_QUALITY_REJECTED', ...
    'ALT_ACCEPTED','GAP_PROLONGATION','GAP_EXPIRED','TIMEOUT_RESET', ...
    'ALT_COMPACTNESS_REJECTED','WARMUP_OUTLIER','WARMUP_GAP', ...
    'INITIAL_REBASE','TRANSITIONING','NO_ACTIONABLE_TRANSITION','REACQUISITION_SETTLING'};
if nargin>1 && schema==3
    names{6}='QUALITY_REJECTED'; names{7}='WINDOW_SELECTED';
    names{9}='OUTPUT_EXPIRED'; names{11}='OUTSIDE_BOTH_WINDOWS';
    names{12}='WARMUP_REJECTED'; names{14}='INITIAL_BASE_READY';
    names{16}='WAITING_FOR_SWITCH';
end
if isa(code,'double') && isscalar(code) && isfinite(code) && ...
        code==fix(code) && code>=0 && code<numel(names)
    if nargin>1 && schema==3 && (code==9 || code==16), return; end
    name=names{code+1};
end
end
