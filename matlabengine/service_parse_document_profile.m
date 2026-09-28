function [allowed, version] = service_parse_document_profile(standard)
% Parse only item 9; validate category identities, not global bullet count.
v=regexp(standard,'ВЕРСИЯ\s+(\d+\.\d+)','tokens','once');
assert(~isempty(v),'libtr:docs:Standard','Missing standard version');
version=v{1};
lines=regexp(standard,'\r\n|\n|\r','split');
first=find(~cellfun('isempty',regexp(lines,'^\s*9\.\s+','once')));
assert(numel(first)==1,'libtr:docs:Standard','Expected one profile item 9');
last=find(~cellfun('isempty',regexp(lines,'^\s*10\.\s+','once')));
last=last(last>first);
assert(~isempty(last),'libtr:docs:Standard','Missing profile boundary item 10');
expected={'Структурные средства и шрифты','Функции и операторы', ...
    'Операции, отношения и символы','Греческие буквы (регистр значим)', ...
    'Акценты и многоточия','Пробельные команды'};
seen=false(size(expected)); allowed={};
for k=first+1:last(1)-1
    line=strtrim(lines{k});
    if isempty(line), continue; end
    category=regexp(line,'^[*+-]\s+([^:]+):\s*(.+)$','tokens','once');
    assert(~isempty(category),'libtr:docs:Standard', ...
        'Malformed profile category on line %d',k);
    index=find(strcmp(strtrim(category{1}),expected));
    assert(numel(index)==1,'libtr:docs:Standard', ...
        'Unknown profile category on line %d',k);
    assert(~seen(index),'libtr:docs:Standard', ...
        'Duplicate profile category on line %d',k);
    commands=regexp(category{2},'`\\([A-Za-z]+|[,;!])`','tokens');
    assert(~isempty(commands),'libtr:docs:Standard', ...
        'Empty profile category on line %d',k);
    allowed=[allowed cellfun(@(x) x{1},commands,'UniformOutput',false)]; %#ok<AGROW>
    seen(index)=true;
end
assert(all(seen),'libtr:docs:Standard','Missing approved profile categories: %s', ...
    strjoin(expected(~seen),', '));
allowed=unique(allowed);
end