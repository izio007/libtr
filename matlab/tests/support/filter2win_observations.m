function [cfg,ctx,t,truth,measured,missing] = filter2win_observations
% Synthetic input only; preserves the original single rand draw and ordering.
cfg=filter2win_config;
ctx=struct('X_MAIN_REF',10);
t=0:3:300;
truth=10.0*ones(1,numel(t));
measured=truth;
measured(t==30)=40;
measured(t>=60 & t<=100)=25;
measured(t>=171 & t<=216)=25;
measured(t==252 | t==255)=28;
noise=4.0*rand(size(measured))-2.0;
measured=measured+noise;
missing=t>100 & t<170;
measured(missing)=NaN;
end