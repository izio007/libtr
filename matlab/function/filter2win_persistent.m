function [rc,ctx,debug]=filter2win_persistent(c,ctx,t,x,missing)
% Schema 3 dispatcher. A=main and B=alt retain identity.
% Observe a candidate, choose from facts, execute, then publish one result.
rc=1;
[ok,s,missing,debug]=filter2win_persistent_prepare(c,ctx,t,x,missing);
if ~ok, return; end
[s,step]=filter2win_persistent_conditions(c,s,t,x,missing);
decision=filter2win_persistent_transition(step.facts);
[rc,ctx,debug]=filter2win_persistent_execute(c,ctx,s,step,decision,debug);
end
