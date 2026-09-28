function unit_test_matmul3()
% UNIT_TEST_MATMUL3 Автономная проверка контракта и арифметики matmul3.
% Явные суммы используются только в независимом тестовом эталоне.
% Файлы и графики не создаются, состояние генератора восстанавливается.

s = rng;
cleanup = onCleanup(@() rng(s));
rng(1729, 'twister');
count = 0;

check_exact([1 2; 3 4], [5 6; 7 8], [1; 2], [63; 143]);
check_exact(2, 3, 4, 24);
check_exact([1 2 3], eye(3), [4; 5; 6], 32);
check_exact([1; 2], 3, [4 5], [12 15; 24 30]);
check_exact(eye(2), [1 2; 2 4], eye(2), [1 2; 2 4]);
check_exact(diag([2 3]), diag([4 5]), diag([6 7]), diag([48 105]));
check_exact(zeros(2, 3), ones(3, 4), ones(4, 5), zeros(2, 5));
check_exact(diag([1 1e-20]), eye(2), eye(2), diag([1 1e-20]));
% Правые скобки дали бы конечное число, но контракт требует левых.
check_failure(realmax, 2, 0.5, 2, [1 1]);
check_failure(realmax, 1, 2, 2, [1 1]);
check_failure([realmax 0; 0 1], 2 * eye(2), eye(2), 2, [2 2]);
check_failure([realmax 0; 0 1], eye(2), 2 * eye(2), 2, [2 2]);

% Все комбинации нулевых и единичных размерностей.
for m = 0:2
    for n = 0:2
        for p = 0:2
            for q = 0:2
                check_exact(ones(m,n), ones(n,p), ones(p,q), ...
                    (n*p) * ones(m,q));
            end
        end
    end
end

shapes = [2 3 4 5; 7 2 9 3; 1 8 3 1; 3 5 2 11; 17 13 19 7];
for k = 1:size(shapes, 1)
    d = shapes(k,:);
    A = randn(d(1),d(2));
    B = randn(d(2),d(3));
    C = randn(d(3),d(4));
    [R, S] = reference_product(A, B, C);
    [status, D] = matmul3(A, B, C);
    check_output(status, D, 0, [d(1) d(4)]);
    tol = 32 * eps * (d(2) + d(3) + 1) .* max(1, S);
    assert(all(abs(D(:) - R(:)) <= tol(:)), ...
        'matmul3:reference', 'Independent reference mismatch.');
    assert(isequal(D, (A * B) * C), ...
        'matmul3:order', 'Left-associated product mismatch.');
    count = count + 1;
end

invalid = {single(eye(2)), int32(eye(2)), logical(eye(2)), ...
    complex(eye(2), ones(2)), sparse(eye(2)), {1}, 'ab', ...
    struct('x', 1), ones(2,2,2)};
for k = 1:numel(invalid)
    for j = 1:3
        args = {eye(2), eye(2), eye(2)};
        args{j} = invalid{k};
        check_failure(args{1}, args{2}, args{3}, 1, [1 1]);
    end
end
check_failure(ones(2,3), eye(2), eye(2), 1, [1 1]);
check_failure(eye(2), eye(2), ones(3,2), 1, [1 1]);
check_failure(2, eye(2), eye(2), 1, [1 1]);
check_failure(eye(2), 2, eye(2), 1, [1 1]);
check_failure(eye(2), eye(2), 2, 1, [1 1]);
check_failure(NaN(2,3), eye(2), eye(2), 1, [1 1]);
check_failure(zeros(2,0), zeros(1,0), zeros(0,3), 1, [1 1]);

for x = [NaN Inf -Inf]
    for j = 1:3
        args = {eye(2), eye(2), eye(2)};
        args{j}(1,1) = x;
        check_failure(args{1}, args{2}, args{3}, 2, [2 2]);
    end
end
check_failure(zeros(0,2), NaN(2,3), ones(3,4), 2, [0 4]);
check_failure(zeros(2,0), zeros(0,3), Inf(3,4), 2, [2 4]);
check_failure(Inf(2,3), zeros(3,0), zeros(0,4), 2, [2 4]);
check_failure(ones(2,3), Inf(3,4), zeros(4,0), 2, [2 0]);

A = randn(3,4); B = randn(4,2); C = randn(2,5);
before = {A, B, C};
state = rng;
matmul3(A, B, C);
assert(isequal(before, {A, B, C}), 'matmul3:inputs', 'Inputs changed.');
assert(isequal(state, rng), 'matmul3:rng', 'Random state changed.');
count = count + 1;
fprintf('unit_test_matmul3: SUCCESS (%d cases)\n', count);

    function check_exact(A, B, C, R)
        [status, D] = matmul3(A, B, C);
        check_output(status, D, 0, size(R));
        assert(isequal(D, R), 'matmul3:exact', 'Exact result mismatch.');
        count = count + 1;
    end

    function check_failure(A, B, C, expected, shape)
        [status, D] = matmul3(A, B, C);
        check_output(status, D, expected, shape);
        assert(all(isnan(D(:))), 'matmul3:nan', 'Output must be all NaN.');
        count = count + 1;
    end
end

function check_output(status, D, expected, shape)
assert(isequal(status, expected), 'matmul3:status', 'Wrong status.');
assert(isa(D, 'double') && isreal(D) && ~issparse(D), ...
    'matmul3:type', 'Wrong output type.');
assert(isequal(size(D), shape), 'matmul3:shape', 'Wrong output shape.');
end

function [R, S] = reference_product(A, B, C)
% Независимый эталон: явная двойная сумма и сумма модулей слагаемых.
m = size(A,1); n = size(A,2); p = size(B,2); q = size(C,2);
R = zeros(m,q);
S = zeros(m,q);
for i = 1:m
    for j = 1:q
        for k = 1:n
            for l = 1:p
                t = A(i,k) * B(k,l) * C(l,j);
                R(i,j) = R(i,j) + t;
                S(i,j) = S(i,j) + abs(t);
            end
        end
    end
end
end