function unit_test_fifo
% Independent list model on the declared valid-state domain.
setup_test_paths;
for capacity=[1 2 5]
    for column=[false true]
        q=zeros(1,capacity,'int32');
        if column, q=q.'; end
        shape=size(q); count=int32(0); model=int32([]);
        check;
        for value=int32([-1 0 17 -23 42 100 200])
            before=q;
            [count,q]=fifo_push(count,int32(capacity),q,value);
            model=[model value]; %#ok<AGROW>
            if numel(model)>capacity, model=model(end-capacity+1:end); end
            assert(isequal(size(before),size(q)));
            check;
        end
        for index=int32([0 capacity+1])
            [count,q]=fifo_delete_at(count,q,index);
            check;
        end
        while ~isempty(model)
            index=ceil(numel(model)/2);
            [count,q]=fifo_delete_at(count,q,int32(index));
            model(index)=[];
            check;
        end
        [count,q]=fifo_delete_at(count,q,int32(1)); check;
        [count,q]=fifo_push(count,int32(capacity),q,int32(99)); model=int32(99); check;
        [count,q]=fifo_clear(int32(capacity),q); model=int32([]); check;
    end
end
fprintf('FIFO independent list regression: PASS\n');

    function check
        assert(isa(count,'int32') && count==numel(model));
        assert(isa(q,'int32') && isequal(size(q),shape));
        expected=zeros(1,capacity,'int32'); expected(1:numel(model))=model;
        assert(isequal(q(:),expected(:)));
        before=q;
        [valid,value]=fifo_peek_recent(count,q);
        assert(isequal(q,before) && islogical(valid) && isa(value,'int32'));
        if isempty(model), assert(~valid && value==int32(-1));
        else, assert(valid && value==model(end)); end
    end
end