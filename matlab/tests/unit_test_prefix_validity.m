function unit_test_prefix_validity
setup_test_paths;
base=[3 0;4 0;0 0]; truth=zeros(3,1);
badInputs={{single(base),[0 0],truth}, {complex(base,ones(3,2)),[0 0],truth}, ...
    {zeros(3,0),[],truth}, {base,[0 NaN],truth}, {base,[0 0.5],truth}, ...
    {base,[0 0],single(truth)}, {base,[0 0],[NaN;0;0]}, ...
    {base,[0 0],complex(truth,ones(3,1))}};
for k=1:numel(badInputs)
    args=badInputs{k}; caught=false;
    try
        service_cumulative_rmse(args{:});
    catch e
        caught=strcmp(e.identifier,'libtr:metrics:Input');
    end
    assert(caught);
end
row=service_cumulative_rmse(base,[0 0],truth);
column=service_cumulative_rmse(base,[0;0],truth);
assert(isequaln(row,column));
missing=service_cumulative_rmse([NaN Inf 3;0 0 4;0 0 0],[0 0 0],truth);
assert(isequal(missing.valid,logical([0 0 1])) && missing.rmse(3)==5);
X=[3 300 0 NaN 9;4 400 0 0 0;0 0 0 0 0]; s=[0 0 0 0 2];
p=service_cumulative_rmse(X,s,zeros(3,1),logical([1 0 1 1 1]));
assert(isequal(p.valid,logical([1 0 1 0 0])));
assert(isequal(p.successful,[1 1 2 2 2]));
assert(isequal(p.rmse,[5 5 sqrt(12.5) sqrt(12.5) sqrt(12.5)]));
assert(all(isnan(p.plot_rmse([2 4 5]))));
for mask={ones(1,5),true(1,4),true(5,5)}
    caught=false;
    try
        service_cumulative_rmse(X,s,zeros(3,1),mask{1});
    catch e
        caught=strcmp(e.identifier,'libtr:metrics:Mask');
    end
    assert(caught);
end
unit_test_graphical_experiments;
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
folder=tempname(fullfile(root,'runtime'));
report=generate_tis_static_passport(folder,4,1,30000,'B');
d=load(fullfile(folder,'repeat_1.mat'));
names={'LLS','WLLS','GN','GNP'};
for m=1:4
    q=load(fullfile(folder,['prefix_' names{m} '.mat'])); r=d.results{m};
    assert(isequal(q.prefix.valid,r.valid));
    for k=1:4
        v=r.valid(1:k); samples=r.samples(:,1:k);
        assert(q.prefix.successful(k)==sum(v));
        if any(v)
            expected=sqrt(mean(sum((samples(:,v)-d.truth).^2,1)));
            assert(abs(q.prefix.rmse(k)-expected)<=1e-12*max(1,expected));
        else
            assert(isnan(q.prefix.rmse(k)));
        end
    end
end
assert(numel(report.files)==4);
fprintf('PREFIX-VALID-001/002/003 PASS; %s\n',folder);
end