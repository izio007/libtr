% Start the local structured MATLAB pipeline endpoint.
% documents checks PlainTextPrincipe before liveeditor exports.
% JSON Lines: {"v":1,"op":"submit","id":"docs_check","action":"documents"}
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'tools', 'pipeline'));
if exist('pipeline', 'var')
    pipeline.stop();
end
if exist('server', 'var') && isvalid(server)
    delete(server);
end
pipeline = service_pipeline_server(5555);
fprintf('libtr pipeline v1 listening on 127.0.0.1:5555\n');
fprintf('Document gate: PlainTextPrincipe; rendering and audit tracked separately.\n');