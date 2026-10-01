function [status,x,next] = test_filter_step(state,frame)
[raw,ctx]=filter2win(state.cfg,state.ctx,frame.time,frame.measurement,frame.missing);
assert(raw==0,'libtr:testmodel:FilterRefusal','filter2win refused frame %d',frame.index);
next=state; next.ctx=ctx; x=ctx.X_FILTERED_OUTPUT;
status=0;
if isnan(x), status=2; end
end