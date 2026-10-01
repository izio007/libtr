function unit_test_fifo_relocation
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
old=path; cleanup=onCleanup(@() path(old));
restoredefaultpath;
addpath(fullfile(root,'matlab','function'));
clear fifo_clear fifo_push fifo_delete_at fifo_peek_recent;
for name={'fifo_clear','fifo_push','fifo_delete_at','fifo_peek_recent'}
    assert(strcmpi(which(name{1}),fullfile(root,'matlab','function',[name{1} '.m'])));
    assert(numel(which(name{1},'-all'))==1);
    assert(~isfile(fullfile(root,'matlab',[name{1} '.m'])));
end
[n,q]=fifo_clear(int32(2),int32([9 8]));
[n,q]=fifo_push(n,int32(2),q,int32(7));
[valid,value]=fifo_peek_recent(n,q);
assert(valid && value==7);
[n,q]=fifo_delete_at(n,q,int32(1));
assert(n==0 && isequal(q,int32([0 0])));
fprintf('FIFO isolated production resolution: PASS\n');
end