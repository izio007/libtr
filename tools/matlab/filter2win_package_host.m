function filter2win_package_host
% FILTER2WIN_PACKAGE_HOST Dedicated loopback server for an extracted package.
% Start from the package root after restoredefaultpath; stop with results/stop-server.
% Only the registered package suite is accepted. No MATLAB code is accepted over TCP.
package = pwd;
% restoredefaultpath is a script and cannot run in this nested static workspace.
% The launcher calls it before entering this function.
entries = strsplit(path, pathsep);
for k = 1:numel(entries)
    if ~startsWith(lower(entries{k}), lower([matlabroot filesep]))
        rmpath(entries{k});
    end
end
addpath(fullfile(package, 'matlab', 'function'), fullfile(package, 'matlab', 'tests'));
stopFile = fullfile(package, 'results', 'stop-server');
assert(~isfile(stopFile), 'Remove the previous stop marker before starting');
jobId = '';
jobState = 'idle';
failure = '';
server = tcpserver('127.0.0.1', 5555, 'Timeout', 5);
configureTerminator(server, 'LF');
configureCallback(server, 'terminator', @receive);
worker = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.25, ...
    'BusyMode', 'drop', 'TimerFcn', @execute);
cleanup = onCleanup(@shutdown);
start(worker);
while ~isfile(stopFile)
    pause(0.25);
end

    function receive(connection, ~)
        reply = struct('v', 1, 'ok', false);
        try
            request = jsondecode(char(readline(connection)));
            assert(request.v == 1, 'Unsupported protocol');
            switch request.op
                case 'ping'
                    reply.pid = feature('getpid');
                    reply.active = '';
                    if strcmp(jobState, 'running')
                        reply.active = jobId;
                    end
                    reply.queued = double(strcmp(jobState, 'queued'));
                    reply.package_root = package;
                case 'submit'
                    assert(strcmp(request.suite, 'filter2win_package'), 'Unknown suite');
                    assert(ismember(jobState, {'idle', 'passed', 'failed'}), 'Server busy');
                    jobId = request.id;
                    jobState = 'queued';
                    failure = '';
                case 'status'
                    assert(strcmp(request.id, jobId), 'Unknown job');
                otherwise
                    error('Unsupported operation');
            end
            reply.report = struct('id', jobId, 'state', jobState, 'failure_reason', failure);
            reply.ok = true;
        catch exception
            reply.error = exception.message;
        end
        write(connection, unicode2native([jsonencode(reply) newline], 'UTF-8'), 'uint8');
    end

    function execute(~, ~)
        if ~strcmp(jobState, 'queued')
            return;
        end
        jobState = 'running';
        try
            run_filter2win_package;
            jobState = 'passed';
        catch exception
            failure = getReport(exception, 'extended', 'hyperlinks', 'off');
            jobState = 'failed';
        end
    end

    function shutdown
        stop(worker);
        delete(worker);
        configureCallback(server, 'off');
        delete(server);
    end
end