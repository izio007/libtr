function unit_test_quadratic_guard
setup_test_paths;
clear unit_test_cov2std unit_test_cov2std_3d;
assert_unit_quadratic_forms([1 1],1e-10);
% Exact binary boundary avoids cancellation at a decimal threshold.
t=2^-20;
assert_unit_quadratic_forms([1-t 1+t],t);
for value={NaN,Inf,-Inf,1+1i,[],[1 NaN],1+2*t,1-2*t}
    reject(@() assert_unit_quadratic_forms(value{1},t),'libtr:check:QuadraticForm');
end
for tolerance={NaN,Inf,-1,1i,[1 2]}
    reject(@() assert_unit_quadratic_forms(1,tolerance{1}),'libtr:check:Tolerance');
end
assert_unit_quadratic_forms(1,0);
unit_test_cov2std_reporting;
fprintf('Finite quadratic guard: injected invalid inputs, boundary and geometry PASS\n');
end
function reject(action,id)
try, action(); catch e, assert(strcmp(e.identifier,id)); return; end
error('libtr:test:FalsePass','Expected refusal %s',id);
end