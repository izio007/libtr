function endpoint = service_pipeline_server(port)
% Local JSON Lines endpoint; computation is serial and cooperative.
if nargin == 0, port = 5555; end
root = fileparts(fileparts(mfilename('fullpath')));
jobs = fullfile(root, 'runtime', 'pipeline');
if ~isfolder(jobs), mkdir(jobs); end
queue = {};
active = '';
old = dir(fullfile(jobs,'*','report.json'));
for k=1:numel(old)
    file=fullfile(old(k).folder,old(k).name);
    report=jsondecode(fileread(file));
    if ismember(report.state,{'queued','running'})
        report.state='interrupted';
        service_pipeline_write_json(file,report);
    end
end
server = tcpserver('127.0.0.1', port, 'Timeout', 5);
configureTerminator(server, 'LF');
configureCallback(server, 'terminator', @receive);
worker = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.25, ...
    'BusyMode', 'drop', 'TimerFcn', @execute);
start(worker);
endpoint = struct('server', server, 'worker', worker, 'stop', @shutdown);

    function receive(src, ~)
        reply = struct('v', 1, 'ok', false);
        try
            line = char(readline(src));
            assert(numel(line)<=8192,'libtr:pipeline:Frame','Frame too long');
            request = jsondecode(line);
            assert(isstruct(request) && isscalar(request) && ...
                isfield(request,'v') && isequal(request.v,1) && ...
                isfield(request,'op') && ischar(request.op), ...
                'libtr:pipeline:Protocol','Expected v=1 and op');
            switch request.op
                case 'ping'
                    reply.active = active;
                    reply.queued = numel(queue);
                    reply.actions = {'all','environment','unit','integration','png','documents','liveeditor','mapping','mapping5000'};
                case {'submit','status','cancel'}
                    assert(isfield(request,'id') && ischar(request.id) && ...
                        ~isempty(regexp(request.id,'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$','once')), ...
                        'libtr:pipeline:Id','Invalid id');
                    folder = fullfile(jobs, request.id);
                    file = fullfile(folder, 'report.json');
                    reply.id = request.id;
                    if strcmp(request.op,'submit')
                        assert(isfield(request,'action') && ischar(request.action) && ...
                            ismember(request.action,{'all','environment','unit','integration','png','documents','liveeditor','mapping','mapping5000'}), ...
                            'libtr:pipeline:Action','Unknown action');
                        if isfile(file)
                            saved = jsondecode(fileread(fullfile(folder,'request.json')));
                            assert(strcmp(saved.action,request.action), ...
                                'libtr:pipeline:Conflict','Id belongs to another action');
                        else
                            assert(numel(queue)<16,'libtr:pipeline:Busy','Queue is full');
                            mkdir(folder);
                            service_pipeline_write_json(fullfile(folder,'request.json'),request);
                            report=struct('v',1,'id',request.id,'action',request.action, ...
                                'state','queued','stages',{{}},'matlab',version);
                            service_pipeline_write_json(file,report);
                            queue{end+1}=request;
                        end
                    else
                        assert(isfile(file),'libtr:pipeline:NotFound','Unknown id');
                        if strcmp(request.op,'cancel')
                            fid=fopen(fullfile(folder,'cancel'),'w');
                            assert(fid~=-1,'libtr:pipeline:IO','Cannot cancel');
                            fclose(fid);
                        end
                    end
                    reply.report=jsondecode(fileread(file));
                otherwise
                    error('libtr:pipeline:Operation','Unknown operation');
            end
            reply.ok=true;
        catch exception
            reply.error=struct('identifier',exception.identifier,'message',exception.message);
        end
        if src.Connected
            write(src,unicode2native([jsonencode(reply) newline],'UTF-8'),'uint8');
        end
    end

    function execute(~, ~)
        if ~isempty(active) || isempty(queue), return; end
        request=queue{1}; queue(1)=[];
        active=request.id;
        folder=fullfile(jobs,active);
        try
            service_pipeline_run(request,folder);
        catch exception
            file=fullfile(folder,'report.json');
            report=jsondecode(fileread(file));
            report.state='failed';
            report.error=getReport(exception,'extended','hyperlinks','off');
            active='';
            service_pipeline_write_json(file,report);
        end
        active='';
    end
    function shutdown
        stop(worker); delete(worker);
        configureCallback(server,'off'); delete(server);
        for j=1:numel(queue)
            file=fullfile(jobs,queue{j}.id,'report.json');
            report=jsondecode(fileread(file)); report.state='interrupted';
            service_pipeline_write_json(file,report);
        end
    end
end