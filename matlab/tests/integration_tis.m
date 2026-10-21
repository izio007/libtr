function result = integration_tis(folder,showFigures)
% Independent solvers on five geometries; 64 trials at each reference point.
setup_test_paths;
if nargin<2, showFigures=false; end
if ~isfolder(folder), mkdir(folder); end
result=test_tis_ensemble(folder,64,true,showFigures);
end
