function unit_test_covariance_boundaries
% LLS/WLLS normal-matrix boundary; all covariance output refusal contracts.
% Two rows per station: H = [sin(a),-cos(a),0;0,0,1].
% For opposite azimuths, H'*H=diag(2*sin(t)^2,2*cos(t)^2,2).
% This analytic oracle does not call another production kernel.
solvers={@lls_covariance,@wlls_covariance,@gn_covariance, ...
    @gnp_covariance,@mock_covariance};
for k=1:numel(solvers)
    [s,K]=solvers{k}(zeros(3,1),0,0,1,1,[2;3;4]);
    assert(s==1 && isequal(size(K),[3 3]) && all(isnan(K(:))), ...
        'libtr:test:CovarianceShort','%s: invalid short-network refusal',func2str(solvers{k}));
end
% Samples on both sides, away from the rounding-sensitive exact boundary.
for factor=[0.25 0.5 2 4 16]
    t=sqrt(factor*eps); a=[t;-t]; b=zeros(2,1);
    P=-[cos(a).';sin(a).';zeros(1,2)]; x=zeros(3,1);
    expectedRcond=sin(t)^2;
    expected=diag(1./[2*sin(t)^2,2*cos(t)^2,2]);
    for k=1:2
        [s,K]=solvers{k}(P,a,b,ones(2,1),ones(2,1),x);
        if expectedRcond < 2.2204e-16
            assert(s==2 && isequal(size(K),[3 3]) && all(isnan(K(:))), ...
                'libtr:test:CovarianceRefusal','%s: boundary refusal',func2str(solvers{k}));
        else
            assert(s==0 && all(isfinite(K(:))), ...
                'libtr:test:CovarianceFinite','%s: unexpected boundary failure',func2str(solvers{k}));
            scaled=diag(1./sqrt(diag(expected)))*K*diag(1./sqrt(diag(expected)));
            assert(norm(scaled-eye(3),'fro')<1e-12, ...
                'libtr:test:CovarianceOracle','%s: analytic diagonal oracle',func2str(solvers{k}));
        end
    end
end
% Exact rank loss, valid nonzero ranges and nonsingular angular coordinates.
P=[-1 -2;0 0;0 0];
for k=1:numel(solvers)
    [s,K]=solvers{k}(P,zeros(2,1),zeros(2,1),ones(2,1),ones(2,1),zeros(3,1));
    assert(s==2 && isequal(size(K),[3 3]) && all(isnan(K(:))), ...
        'libtr:test:CovarianceRank','%s: exact rank-loss refusal',func2str(solvers{k}));
end
end