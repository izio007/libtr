function model=filter2win_model(samples,window)
% Robust model centered at the newest REAL observation.
% constant: median; known_velocity: detrended median with configured V;
% linear: Theil-Sen median of pair slopes on actual timestamps.
% mad is RAW median absolute deviation, without Gaussian normalization.
% trim_fraction discards that fraction at EACH tail for range diagnostics.
% A string model name is accepted for direct diagnostic calls only.
if ischar(window)
    window=struct('model',window,'known_velocity',0, ...
        'linear_min_pair_seconds',0,'trim_fraction',0);
end
model=struct('n',numel(samples.time),'first',NaN,'last',NaN, ...
    'level',NaN,'velocity',NaN,'mad',NaN, ...
    'min_residual',NaN,'max_residual',NaN, ...
    'trimmed_min_residual',NaN,'trimmed_max_residual',NaN, ...
    'trimmed_range',NaN,'trimmed_count',0);
n=model.n;
if n==0, return; end
t=samples.time(:).'; x=samples.value(:).';
model.first=t(1); model.last=t(end);
dt=t-t(end);
if ~all(isfinite(dt)), return; end
switch window.model
    case 'constant'
        v=0;
    case 'known_velocity'
        v=window.known_velocity;
    case 'linear'
        if n<2, return; end
        slopes=zeros(1,n*(n-1)/2); count=0;
        for i=1:n-1
            elapsed=t(i+1:end)-t(i);
            eligible=isfinite(elapsed) & elapsed>0 & ...
                elapsed>=window.linear_min_pair_seconds;
            differences=x(i+1:end)-x(i);
            if any(~isfinite(differences(eligible))), return; end
            values=differences(eligible)./elapsed(eligible);
            if any(~isfinite(values)), return; end
            last=count+numel(values);
            slopes(count+1:last)=values; count=last;
        end
        if count==0, return; end
        v=safe_median(slopes(1:count));
    otherwise
        return;
end
q=x-v*dt;
if ~isfinite(v) || ~all(isfinite(q)), return; end
level=safe_median(q);
residual=q-level;
if ~all(isfinite(residual)), return; end
mad=safe_median(abs(residual));
ordered=sort(residual);
trim=min(floor(window.trim_fraction*n),floor((n-1)/2));
core=ordered(trim+1:n-trim);
range=core(end)-core(1);
if ~isfinite(level) || ~isfinite(mad) || ~isfinite(range), return; end
model.level=level; model.velocity=v; model.mad=mad;
model.min_residual=ordered(1); model.max_residual=ordered(end);
model.trimmed_min_residual=core(1); model.trimmed_max_residual=core(end);
model.trimmed_range=range; model.trimmed_count=numel(core);
end

function value=safe_median(values)
% Halving before addition avoids overflow of the two central finite values.
ordered=sort(values); n=numel(ordered); center=floor(n/2);
if mod(n,2)==1
    value=ordered(center+1);
else
    value=ordered(center)/2+ordered(center+1)/2;
end
end
