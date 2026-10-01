function [P,alpha,beta,variance,next] = service_sample_bearings(stations,truth,sigma,repeats,runs,context)
% Independent raw bearing pairs; repeated columns denote the same physical post.
validateattributes(stations,{'double'},{'real','finite','nrows',3,'nonempty'});
validateattributes(truth,{'double'},{'real','finite','size',[3 1]});
validateattributes(sigma,{'double'},{'real','finite','scalar','positive'});
validateattributes(repeats,{'double'},{'scalar','integer','positive'});
validateattributes(runs,{'double'},{'scalar','integer','positive'});
P=repmat(stations,1,repeats);
d=truth-P;
a=atan2(d(2,:),d(1,:)).';
b=atan2(d(3,:),hypot(d(1,:),d(2,:))).';
[na,next]=engine_rng_normal(context,size(P,2),runs);
[nb,next]=engine_rng_normal(next,size(P,2),runs);
alpha=a+sigma*na;
beta=b+sigma*nb;
variance=repmat(sigma^2,size(P,2),1);
end