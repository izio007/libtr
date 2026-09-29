function name = tis_context_filename(cfg)
% Artifact naming only; geometry comes from the configuration.
range=cfg.Trajectory.Y_center_true;
validateattributes(range,{'double'},{'scalar','real','finite','positive'});
name=sprintf('context_%.15gkm.mat',range/1000);
end