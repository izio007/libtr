function [pass,checks]=filter2win_rule_checks(rule,metrics)
% Named numerical guards; no eval, expressions, callbacks or scenario data.
checks=struct('metric',{},'actual',{},'operator',{},'threshold',{},'passed',{});
pass=true;
if isempty(rule.conditions), return; end
results=false(1,numel(rule.conditions));
for k=1:numel(rule.conditions)
    condition=rule.conditions(k); actual=metrics.(condition.metric);
    threshold=condition.value;
    result=false;
    if ~isnan(actual)
        switch condition.operator
            case 'lt', result=actual<threshold;
            case 'le', result=actual<=threshold;
            case 'gt', result=actual>threshold;
            case 'ge', result=actual>=threshold;
            case 'eq', result=actual==threshold;
        end
    end
    results(k)=result;
    checks(k)=struct('metric',condition.metric,'actual',actual, ...
        'operator',condition.operator,'threshold',threshold,'passed',result);
end
if strcmp(rule.combine,'ANY'), pass=any(results); else, pass=all(results); end
end
