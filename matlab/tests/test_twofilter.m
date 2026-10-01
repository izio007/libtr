clear; clc;
setup_test_paths;
[t_axes, X_true, X_meas, X_filtered_history, W_alt_power_history] = filter2win_scenario;
matplot_twofilter_screen(t_axes, X_true, X_meas, X_filtered_history, W_alt_power_history);
