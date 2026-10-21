function v=filter2win_window_view(q,w)
% Numerical model and readiness of one persistent window.
[~,~,d]=fifo_double('read',q); m=filter2win_model(d,w);
span=0; if q.count>1, span=d.time(end)-d.time(1); end
range=m.max_residual-m.min_residual;
quality=isfinite(m.level) && isfinite(m.velocity) && isfinite(m.mad) && ...
    isfinite(range) && m.mad<=w.band.max_mad && range<=w.band.max_range && ...
    abs(m.velocity)<=w.band.max_abs_velocity;
v=struct('count',q.count,'span',span,'range',range,'quality',quality, ...
    'ready',quality && q.count>=w.min_samples && span>=w.min_span_seconds,'model',m);
end
