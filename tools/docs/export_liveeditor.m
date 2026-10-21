function export_liveeditor(source, destination)
% Export one existing Live Editor .m/.mlx document without running its code.
% Example: export_liveeditor('docs/liveeditor/filter2win_theory.m', ...
%                            'runtime/filter2win.pdf')
folder=fileparts(destination);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
export(source,destination,'Run',false,'HideCode',true,'OpenExportedFile',false);
fprintf('%s\n',destination);
end
