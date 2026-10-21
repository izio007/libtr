function [rc,ctx,debug]=filter2win_persistent(c,ctx,t,x,missing)
% Schema 3 dispatcher. A=main and B=alt retain identity.
% Preparation, transition calculation, and numerical actions are separate.
rc=1;
[ok,s,missing,debug]=filter2win_persistent_prepare(c,ctx,t,x,missing);
if ~ok, return; end
[s,step]=filter2win_persistent_transition(c,s,t,x,missing);
[rc,ctx,debug]=filter2win_persistent_execute(c,ctx,s,step,debug);
end
