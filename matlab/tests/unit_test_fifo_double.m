function unit_test_fifo_double
% F2W-S2-03: JSON data, independent chronological reference.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
c=jsondecode(fileread(fullfile(root,'matlab','tests','configs','fifo_double_cases.json')));
[rc,q]=fifo_double('init',[],c.capacity); assert(rc==0);
for k=1:numel(c.times)
    [rc,q]=fifo_double('push',q,c.times(k),c.values(k)); assert(rc==0);
end
[rc,unchanged,d]=fifo_double('read',q);
assert(rc==0 && isequaln(q,unchanged));
assert(isequal(d.time,c.expected_times(:).') && isequal(d.value,c.expected_values(:).'));
% Retain operates on chronological positions after ring wraparound.
[rc,kept,removed]=fifo_double('retain',q,c.retain_mask);
assert(rc==0 && isequal(removed.time,c.removed_times(:).') && kept.last_time==q.last_time);
[~,~,data]=fifo_double('read',kept);
assert(isequal(data.time,c.retained_times(:).') && isequal(data.value,c.retained_values(:).'));
[rc,unchanged]=fifo_double('retain',q,true(1,q.count)); assert(rc==0 && isequaln(q,unchanged));
[rc,unchanged]=fifo_double('retain',q,c.invalid_mask); assert(rc==1 && isequaln(q,unchanged));
[rc,empty]=fifo_double('retain',q,false(1,q.count)); assert(rc==0 && empty.count==0 && empty.last_time==q.last_time);
[rc,unchanged]=fifo_double('push',empty,c.times(end),c.values(end)); assert(rc==1 && isequaln(empty,unchanged));
[rc,unchanged]=fifo_double('retain',q,[true false]); assert(rc==1 && isequaln(q,unchanged));
old=q; [rc,q]=fifo_double('push',q,c.times(end),c.values(end));
assert(rc==1 && isequaln(q,old));
[rc,q]=fifo_double('push',q,c.times(end)+1,NaN);
assert(rc==1 && isequaln(q,old));
[rc,q]=fifo_double('prune',q,c.expected_times(2)); assert(rc==0);
[rc,~,d]=fifo_double('peek',q); assert(rc==0 && d.time==c.expected_times(2));
[rc,q,d]=fifo_double('pop',q); assert(rc==0 && d.value==c.expected_values(2));
[rc,q]=fifo_double('clear',q); assert(rc==0 && q.count==0);
[rc,~,d]=fifo_double('read',q); assert(rc==0 && isempty(d.time));
old=q; [rc,q]=fifo_double('init',q,c.invalid_capacity);
assert(rc==1 && isequaln(q,old));
end