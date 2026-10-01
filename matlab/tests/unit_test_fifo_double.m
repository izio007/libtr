function unit_test_fifo_double
% F2W-FIFO-CHK-001: independent explicit pairs, boundaries and refusal.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
c=jsondecode(fileread(fullfile(root,'matlab','tests','configs','fifo_double_cases.json')));
[st,s]=fifo_double('init',struct(),c.capacity,NaN); assert(st==0);
for j=1:numel(c.values)
    [st,s]=fifo_double('push',s,c.values(j),c.times(j)); assert(st==0);
    assert(isequal(size(s.values),[1 c.capacity]) && isequal(size(s.times),[1 c.capacity]));
end
for j=1:c.capacity
    old=s; [st,s,v,t]=fifo_double('get',s,j,NaN);
    assert(st==0 && isequaln(s,old) && v==c.expected_values(j) && t==c.expected_times(j));
end
old=s; [st,s]=fifo_double('push',s,NaN,c.times(1)); assert(st==1 && isequaln(s,old));
[st,s]=fifo_double('get',s,c.capacity+1,NaN); assert(st==1 && isequaln(s,old));
[st,s]=fifo_double('init',s,c.invalid_capacity,NaN); assert(st==1 && isequaln(s,old));
bad=s; bad.count=c.capacity+1;
[st,out]=fifo_double('clear',bad,NaN,NaN); assert(st==1 && isequaln(out,bad));
bad=s; bad.times=bad.times(1:end-1);
[st,out]=fifo_double('push',bad,c.values(1),c.times(1)); assert(st==1 && isequaln(out,bad));
[st,s]=fifo_double('clear',s,NaN,NaN);
assert(st==0 && s.count==0 && isequal(s.values,old.values) && isequal(s.times,old.times));
old=s; [st,s]=fifo_double('get',s,1,NaN); assert(st==1 && isequaln(s,old));
[st,s]=fifo_double('init',struct(),c.single_capacity,NaN); assert(st==0);
for j=1:numel(c.values)
    [st,s]=fifo_double('push',s,c.values(j),c.times(j)); assert(st==0);
    [st,~,v,t]=fifo_double('get',s,1,NaN);
    assert(st==0 && v==c.values(j) && t==c.times(j) && s.count==1);
end
end