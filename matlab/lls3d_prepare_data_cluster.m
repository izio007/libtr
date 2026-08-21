function [status, P_out, alpha_out, beta_out, var_alpha_out, var_beta_out] = lls3d_prepare_data_cluster(P, alpha, beta, var_alpha, var_beta)
% =========================================================================
% ФУНКЦИЯ ПРОСТРАНСТВЕННО-УГЛОВОЙ КЛАСТЕРИЗАЦИИ С ОТБРАКОВКОЙ ВЫБРОСОВ
% =========================================================================
% Входные параметры:
%   P, alpha, beta, var_alpha, var_beta - Исходные массивы группировки
% Выходные параметры:
%   P_out, alpha_out, beta_out, var_alpha_out, var_beta_out - Сжатые кластеры
% =========================================================================

MAX_STATIONS = 128;
CLUSTER_TRIGGER_THRESHOLD = 16;
MIN_ANGLE_SPACING_RAD = deg2rad(4.0);  % Порог квазипараллельности пучка
MAX_ALLOWABLE_OUTLIER = deg2rad(8.0);  % Граница жесткого отсечения помех

P_out = P; alpha_out = alpha; beta_out = beta;
var_alpha_out = var_alpha; var_beta_out = var_beta;
M = size(P, 2);

if M < 2 || M > MAX_STATIONS || length(alpha) < M || length(beta) < M
    status = 1; return;
end

% Если избыточность мала, пропускаем препроцессинг ради экономии тактов
if M <= CLUSTER_TRIGGER_THRESHOLD
    status = 0; return;
end

% 1. Робастная предварительная оценка координат через базовый LLS
H_lls = zeros(2*M, 3); b_lls = zeros(2*M, 1);
for i = 1:M
    sa = sin(alpha(i)); ca = cos(alpha(i)); sb = sin(beta(i)); cb = cos(beta(i));
    xs = P(1, i); ys = P(2, i); zs = P(3, i);
    H_lls(2*i-1, 1) = -sa;    H_lls(2*i-1, 2) =  ca;    H_lls(2*i-1, 3) =  0;
    b_lls(2*i-1, 1) = -sa*xs + ca*ys;
    H_lls(2*i, 1) = -sb * ca; H_lls(2*i, 2) = -sb * sa; H_lls(2*i, 3) =  cb;
    b_lls(2*i, 1) = -sb*ca*xs - sb*sa*ys + cb*zs;
end
AtA = H_lls.' * H_lls;
if rcond(AtA) < 1e-12, status = 2; return; end
lambda_coarse = AtA \ (H_lls.' b_lls);

geom_angles = zeros(M, 1);
for i = 1:M
    dx = lambda_coarse(1) - P(1, i); dy = lambda_coarse(2) - P(2, i);
    geom_angles(i) = atan2(dy, dx);
end

% 2. ЖЕСТКАЯ ОТБРАКОВКА ВЫБРОСОВ (Outlier Rejection)
angle_residuals = alpha - geom_angles;
angle_residuals = atan2(sin(angle_residuals), cos(angle_residuals));
median_residual = median(angle_residuals);

% Маска чистых, подтвержденных геометрией станций
clean_mask = abs(angle_residuals - median_residual) <= MAX_ALLOWABLE_OUTLIER;
if sum(clean_mask) < 2, status = 3; return; end

% Очищаем выборку от помех
P = P(:, clean_mask); alpha = alpha(clean_mask); beta = beta(clean_mask);
var_alpha = var_alpha(clean_mask); var_beta = var_beta(clean_mask);
geom_angles = geom_angles(clean_mask);
M = size(P, 2);

% 3. РАЗМЕТКА КЛАСТЕРОВ НА ПАРАЛЛЕЛЬНЫХ КУРСАХ
cluster_labels = zeros(M, 1);
current_cluster_id = 0;

for i = 1:M
    if cluster_labels(i) > 0, continue; end
    current_cluster_id = current_cluster_id + 1;
    cluster_labels(i) = current_cluster_id;
    
    for j = (i+1):M
        if cluster_labels(j) > 0, continue; end
        diff_a = abs(geom_angles(i) - geom_angles(j));
        if diff_a > pi, diff_a = 2*pi - diff_a; end
        if diff_a <= MIN_ANGLE_SPACING_RAD
            cluster_labels(j) = current_cluster_id;
        end
    end
end

num_clusters = current_cluster_id;
P_out = zeros(3, num_clusters);
alpha_out = zeros(num_clusters, 1);
beta_out = zeros(num_clusters, 1);
var_alpha_out = zeros(num_clusters, 1);
var_beta_out = zeros(num_clusters, 1);

% 4. СБОРКА ИНФОРМАЦИОННЫХ КЛАСТЕРОВ ПО СХЕМЕ "ЛИДЕРА"
for c = 1:num_clusters
    mask = (cluster_labels == c);
    N_c = sum(mask);
    leader_idx = find(mask, 1, 'first');
    
    % ИНВАРИАНТНОСТЬ БАЗЫ: Виртуальный пункт строго наследует физику лидера
    P_out(:, c)  = P(:, leader_idx);
    alpha_out(c) = alpha(leader_idx);
    beta_out(c)  = beta(leader_idx);
    
    % Фильтрация случайного шума за счет избыточности внутри пучка
    var_alpha_out(c) = var_alpha(leader_idx) / N_c;
    var_beta_out(c)  = var_beta(leader_idx) / N_c;
end

status = 0;
end
