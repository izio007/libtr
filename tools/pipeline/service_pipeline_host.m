function service_pipeline_host(port)
% Persistent dedicated host. Stop by creating runtime/pipeline/stop-server.
if nargin==0, port=5555; end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
stopfile=fullfile(root,'runtime','pipeline','stop-server');
assert(~isfile(stopfile),'Remove stop-server before starting host');
endpoint=service_pipeline_server(port);
cleanup=onCleanup(@() endpoint.stop());
while isvalid(endpoint.server) && ~isfile(stopfile)
    pause(0.25);
end
end