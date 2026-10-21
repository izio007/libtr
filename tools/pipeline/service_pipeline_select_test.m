function selected = service_pipeline_select_test(request, root)
% Explicit test names only; integrations have a small fixed allowlist.
selected='';
if ~isfield(request,'test'), return; end
assert(ischar(request.test) && isrow(request.test), ...
    'libtr:pipeline:Test','Invalid test selection');
switch request.action
    case 'unit'
        allowed=~isempty(regexp(request.test,'^unit_test_[A-Za-z0-9_]+$','once'));
    case 'integration'
        allowed=ismember(request.test, ...
            {'integration_filter2win','integration_context','integration_tis'});
    otherwise
        allowed=false;
end
assert(allowed,'libtr:pipeline:Test','Invalid test selection');
assert(isfile(fullfile(root,'matlab','tests',[request.test '.m'])), ...
    'libtr:pipeline:Test','Unknown test');
selected=request.test;
end
