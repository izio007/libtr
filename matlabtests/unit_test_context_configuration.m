function unit_test_context_configuration
% Changing a physical parameter must not require changing any dispatch names.
setup_test_paths;
root=fileparts(fileparts(mfilename('fullpath')));
folder=tempname(fullfile(root,'runtime')); mkdir(folder);
cleanup=onCleanup(@() rmdir(folder,'s'));
scenarios=tis_trajectory_scenarios;
for k=1:numel(scenarios)
    cfg=scenarios{k};
    for range=[cfg.Trajectory.Y_center_true 160000 37500]
        cfg.Trajectory.Y_center_true=range;
        cfg.Trajectory.Points=7;
        cfg.Hardware.D_Error_Degree=0.123;
        file=fullfile(folder,tis_context_filename(cfg)); save(file,'cfg');
        state=rng;
        a=service_init_geometry_criteria(file);
        assert(isequal(rng,state));
        renamed=fullfile(folder,'unrelated_name.mat'); copyfile(file,renamed);
        b=service_init_geometry_criteria(renamed);
        assert(isequaln(a,b),'Renaming changed calculations');
        assert(all(a.Y_true==range) && a.Points==7);
        assert(a.D_Error_Degree==cfg.Hardware.D_Error_Degree);
        assert(all(a.var_alpha_max==(0.123*pi/180)^2));
        assert(isequal(a.Z_true,cfg.Trajectory.Z_base+ ...
            cfg.Trajectory.Z_amplitude*sin(pi*linspace(0,1,7))));
        assert(isequaln(service_init_geometry_30km(file),a));
        assert(isequaln(service_init_geometry_450km(file),a));
    end
end
assert(strcmp(tis_context_filename(cfg),'context_37.5km.mat'));
fprintf('Context parameter and filename independence: PASS\n');
end