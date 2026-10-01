function unit_test_trajectory_reload
% Reload only this changed package in a persistent TCP MATLAB session.
clear test_model_step test_model_result test_trajectory_init unit_test_trajectory_model;
rehash;
unit_test_trajectory_model;
end