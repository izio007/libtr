function name=filter2win_status_name(code,schema)
% Stable public operating-mode IDs; API return status is a different value.
names={'WAITING_FOR_DATA','ACCUMULATING','STEADY_TRACKING', ...
    'TRACKING_WITH_OUTLIERS','ALT_ACCUMULATING','ALT_QUALITY_REJECTED', ...
    'ALT_ACCEPTED','GAP_PROLONGATION','GAP_EXPIRED','TIMEOUT_RESET', ...
    'ALT_COMPACTNESS_REJECTED','WARMUP_OUTLIER','WARMUP_GAP', ...
    'INITIAL_REBASE','TRANSITIONING','POLICY_HOLD','REACQUISITION_SETTLING'};
if nargin>1 && schema==3
    names{6}='QUALITY_REJECTED'; names{7}='WINDOW_SELECTED';
    names{9}='OUTPUT_EXPIRED'; names{11}='OUTSIDE_BOTH_WINDOWS';
    names{12}='WARMUP_REJECTED'; names{14}='INITIAL_BASE_READY';
end
name='UNKNOWN';
if isa(code,'double') && isscalar(code) && isfinite(code) && ...
        code==fix(code) && code>=0 && code<numel(names)
    name=names{code+1};
end
end
