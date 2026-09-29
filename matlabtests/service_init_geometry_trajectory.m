function DataContext = service_init_geometry_trajectory(contextFileName)
% Construct a trajectory exclusively from its saved physical parameters.
saved=load(contextFileName); names=fieldnames(saved);
assert(numel(names)==1,'libtr:context:Schema','Expected one configuration');
cfg=saved.(names{1});
state=rng; cleanup=onCleanup(@() rng(state));
rng(cfg.Hardware.Random_Seed,'twister');
Points=cfg.Trajectory.Points;
DataContext.Points=Points;
DataContext.CountsVector=unique(round(logspace(log10(4),log10(124),20)));
DataContext.Fixed_N_Stations=DataContext.CountsVector(cfg.Hardware.Fixed_N_Index);
DataContext.Hardware.Fixed_N_Stations=DataContext.Fixed_N_Stations;
anchors=[cfg.Stations.X_anchors;cfg.Stations.Y_anchors;cfg.Stations.Z_anchors];
count=max(DataContext.CountsVector);
DataContext.P_max_matrix=spline(1:size(anchors,2),anchors,linspace(1,size(anchors,2),count));
t=linspace(0,1,Points);
DataContext.X_true=linspace(cfg.Trajectory.X_limits(1),cfg.Trajectory.X_limits(2),Points);
DataContext.Y_true=cfg.Trajectory.Y_center_true*ones(1,Points);
DataContext.Z_true=cfg.Trajectory.Z_base+cfg.Trajectory.Z_amplitude*sin(pi*t);
DataContext.D_Error_Degree=cfg.Hardware.D_Error_Degree;
sigma=cfg.Hardware.D_Error_Degree*pi/180;
DataContext.var_alpha_max=repmat(sigma^2,count,1);
DataContext.var_beta_max=DataContext.var_alpha_max;
DataContext.alpha_noisy_matrix=zeros(count,Points);
DataContext.beta_noisy_matrix=zeros(count,Points);
for k=1:count
    dx=DataContext.X_true-DataContext.P_max_matrix(1,k);
    dy=DataContext.Y_true-DataContext.P_max_matrix(2,k);
    dz=DataContext.Z_true-DataContext.P_max_matrix(3,k);
    DataContext.alpha_noisy_matrix(k,:)=atan2(dy,dx)+sigma*randn(1,Points);
    DataContext.beta_noisy_matrix(k,:)=atan2(dz,hypot(dx,dy))+sigma*randn(1,Points);
end
DataContext.cfg=cfg;
DataContext.Methods=cfg.Methods;
end