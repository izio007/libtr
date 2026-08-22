function [P_exp, V_a_exp, V_b_exp] = service_expand_tact_matrix(P_base, V_a_base, V_b_base, N_total_exp)
% =========================================================================
% СЛУЖЕБНАЯ ФУНКЦИЯ: ЦИКЛИЧЕСКОЕ РАСШИРЕНИЕ ИЗМЕРИТЕЛЬНЫХ МАТРИЦ ТИС
% Path: d:\workspace\libtr\matlabtests\service_expand_tact_matrix.m
% =========================================================================

P_exp = zeros(3, N_total_exp);
V_a_exp = zeros(N_total_exp, 1);
V_b_exp = zeros(N_total_exp, 1);
M_base = size(P_base, 2);

for idx = 1:N_total_exp
    base_idx = mod(idx - 1, M_base) + 1;
    P_exp(1, idx) = P_base(1, base_idx);
    P_exp(2, idx) = P_base(2, base_idx);
    P_exp(3, idx) = P_base(3, base_idx);
    V_a_exp(idx) = V_a_base(base_idx);
    V_b_exp(idx) = V_b_base(base_idx);
end
end
