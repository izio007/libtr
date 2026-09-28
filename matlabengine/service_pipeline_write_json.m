function service_pipeline_write_json(filename, value)
% Atomically publish a UTF-8 report.
temporary = [filename '.tmp'];
fid = fopen(temporary, 'w', 'n', 'UTF-8');
assert(fid ~= -1, 'libtr:pipeline:IO', 'Cannot write %s', temporary);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(value));
clear cleanup;
[ok, message] = movefile(temporary, filename, 'f');
assert(ok, 'libtr:pipeline:IO', '%s', message);
end