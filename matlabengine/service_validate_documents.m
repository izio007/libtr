function metrics = service_validate_documents(root, folder)
% Static document gate, not a claim of rendered acceptance.
% Read the approved profile instead of maintaining a stale duplicate.
standard = readUtf8(fullfile(root,'PlainTextPrincipe.md'));
version = regexp(standard,'ВЕРСИЯ\s+(\d+\.\d+)','tokens','once');
profile = regexp(standard,'(?m)^[ \t]+\* [^\r\n]+','match');
assert(~isempty(version) && numel(profile)==6, ...
    'libtr:docs:Standard','Cannot identify the six approved profile categories');
commands = regexp(strjoin(profile,newline),'`\\([A-Za-z]+)`','tokens');
allowed = cellfun(@(x) x{1},commands,'UniformOutput',false);
assert(~isempty(allowed),'libtr:docs:Standard','Empty command profile');
sources = dir(fullfile(root,'docs','*_theory.txt'));
assert(~isempty(sources),'libtr:docs:Empty','No document sources');
results = cell(1,numel(sources));
failures = 0;
for k=1:numel(sources)
    source = fullfile(sources(k).folder,sources(k).name);
    name = erase(sources(k).name,'_theory.txt');
    result = struct('name',name,'state','passed','errors',{{}}, ...
        'formulas',0,'png',0,'html_rendering','pending','visual_audit','pending');
    try
        text = readUtf8(source);
        lines = regexp(text,'\r?\n','split');
        expected = {}; code = false;
        for j=1:numel(lines)
            line = lines{j};
            if startsWith(line,'```'), code=~code; continue; end
            if code, continue; end
            tokens = regexp(line,'`[^`\n]+`|\$\$.*?\$\$|\$[^$\n]+\$','match');
            plain = regexprep(line,'`[^`\n]+`|\$\$.*?\$\$|\$[^$\n]+\$','');
            assert(~contains(plain,'$') && isempty(regexp(plain,'\\[A-Za-z]+','once')), ...
                'libtr:docs:Markup','Line %d: unmarked mathematics or unbalanced dollars',j);
            for t=1:numel(tokens)
                token=tokens{t};
                if token(1)~='$', continue; end
                n=1+startsWith(token,'$$');
                tex=token(n+1:end-n); expected{end+1}=tex; %#ok<AGROW>
                checked=strrep(tex,'\operatorname{rcond}','\mathrm{rcond}');
                commands=regexp(checked,'\\([A-Za-z]+)','tokens');
                for c=1:numel(commands)
                    assert(ismember(commands{c}{1},allowed),'libtr:docs:Profile', ...
                        'Line %d: command outside profile: %s',j,commands{c}{1});
                end
                env=regexp(tex,'\\(?:begin|end)\{([^}]+)\}','tokens');
                for e=1:numel(env)
                    assert(ismember(env{e}{1},{'bmatrix','cases'}), ...
                        'libtr:docs:Environment','Line %d: unsupported environment',j);
                end
            end
            image=regexp(line,'^\[image: ([A-Za-z0-9_-]+\.png)\]$','tokens','once');
            if ~isempty(image)
                info=imfinfo(fullfile(root,'runtime',image{1}));
                assert(strcmpi(info.Format,'png'),'libtr:docs:PNG','Not a PNG');
                result.png=result.png+1;
            elseif contains(line,'[image:')
                error('libtr:docs:ImageMarker','Line %d: malformed image marker',j);
            end
        end
        assert(~code,'libtr:docs:Fence','Unclosed code fence');
        page=fileread(fullfile(root,'docs','html',[name '.html']));
        live=fileread(fullfile(root,'docs','liveeditor',[name '_theory.m']));
        result.formulas=numel(expected);
        assert(count(page,'class="math"')==numel(expected), ...
            'libtr:docs:Count','HTML formula count differs from source');
        liveLines=regexp(live,'\r?\n','split'); actual={};
        for j=1:numel(liveLines)
            if startsWith(liveLines{j},'%[text] ')
                found=regexp(liveLines{j},'\$[^$\n]+\$','match');
                actual=[actual found]; %#ok<AGROW>
            end
        end
        assert(numel(actual)==numel(expected),'libtr:docs:Count', ...
            'Live Editor formula count differs from source');
        for j=1:numel(expected)
            for environment={'bmatrix','cases'}
                env=environment{1};
                if contains(expected{j},['\begin{' env '}'])
                    assert(contains(actual{j},['\\begin{' env '}']) && ...
                        contains(actual{j},['\\end{' env '}']) && ...
                        count(actual{j},'&')==count(expected{j},'&') && ...
                        count(actual{j},'\\\\')==count(expected{j},'\\'), ...
                        'libtr:docs:Matrix','Formula %d: matrix structure lost',j);
                end
            end
        end
    catch exception
        result.state='failed'; failures=failures+1;
        result.errors={exception.identifier,exception.message};
    end
    results{k}=result;
end

metrics=struct('total',numel(sources),'failures',failures, ...
    'standard',['PlainTextPrincipe ' version{1}],'html_rendering','pending', ...
    'visual_audit','pending','acceptance','pending');
service_pipeline_write_json(fullfile(folder,'documents_results.json'), ...
    struct('metrics',metrics,'documents',{results}));
end

function text = readUtf8(file)
fid=fopen(file,'r','n','UTF-8');
assert(fid~=-1,'libtr:docs:IO','Cannot read %s',file);
cleanup=onCleanup(@() fclose(fid));
text=fscanf(fid,'%c');
end