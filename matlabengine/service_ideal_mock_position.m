function [status, lambda_ideal] = service_ideal_mock_position(P, X_target, Y_target, Z_target)
% Ideal-observation adapter to mock_theory section 1, not an independent oracle.
% No clipping or scenario policy. Status 1 denotes fewer than two posts.
d=[X_target;Y_target;Z_target]-P;
alpha=atan2(d(2,:),d(1,:)).';
beta=atan2(d(3,:),hypot(d(1,:),d(2,:))).';
unused=ones(size(P,2),1);
[status,lambda_ideal]=mock_position(P,alpha,beta,unused,unused);
end
