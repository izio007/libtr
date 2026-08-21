function [status, P_out, alpha_out, beta_out, var_alpha_out, var_beta_out] = lls3d_prepare_data(P, alpha, beta, var_alpha, var_beta)
MAX_STATIONS = 64;
CLUSTER_TRIGGER_THRESHOLD = 16;
MIN_ANGLE_SPACING_RAD = deg2rad(4.0); % Порог квазипараллельности лучей
MAX_ALLOWABLE_OUTLIER = deg2rad(8.0); % Все, что улетело дальше этого порога от медианы — жесткий выброс

P_out = P; alpha_out = alpha; beta_out = beta;
var_alpha_out = var_alpha; var_beta_out = var_beta;
M = size(P, 2);

if M < 2 || M > MAX_STATIONS || length(alpha) < M || length(beta) < M
    status = 1; return;
end

if M <= CLUSTER_TRIGGER_THRESHOLD
    status = 0; return;
end

% 1. Грубый робастный поиск центра (Медианный фильтр углов защищает от влияния выбросов)
[st_coarse, lambda_coarse] = lls3d_position(P, alpha, beta);
if st_coarse ~= 0
    status = 2; return;
end

geom_angles = zeros(M, 1);
for i = 1:M
    dx = lambda_coarse(1) - P(1, i);
    dy = lambda_coarse(2) - P(2, i);
    geom_angles(i) = atan2(dy, dx);
end

% 2. ЖЕСТКАЯ ФИЛЬТРАЦИЯ ВЫБРОСОВ (Outlier Rejection)
% Вычисляем медиану невязки между измеренными и геометрическими углами
angle_residuals = alpha - geom_angles;
% Приводим к диапазону [-pi, pi]
angle_residuals = atan2(sin(angle_residuals), cos(angle_residuals));
median_residual = median(angle_residuals);

% Маска чистых (валидных) станций
clean_mask = abs(angle_residuals - median_residual) <= MAX_ALLOWABLE_OUTLIER;

% Если выбросы уничтожили слишком много данных, аварийно выходим
if sum(clean_mask) < 2
    status = 3; return;
end

% Отсекаем битые станции из дальнейшей работы
P = P(:, clean_mask);
alpha = alpha(clean_mask);
beta = beta(clean_mask);
var_alpha = var_alpha(clean_mask);
var_beta = var_beta(clean_mask);
geom_angles = geom_angles(clean_mask);
M = size(P, 2);

% 3. СКВОЗНАЯ КЛАСТЕРИЗАЦИЯ НА ПАРАЛЛЕЛЬНЫХ КУРСАХ (Борьба с усилением на флангах)
cluster_labels = zeros(M, 1);
current_cluster_id = 0;

for i = 1:M
    if cluster_labels(i) > 0, continue; end
    
    current_cluster_id = current_cluster_id + 1;
    cluster_labels(i) = current_cluster_id;
    
    for j = (i+1):M
        if cluster_labels(j) > 0, continue; end
        
        % Проверка на квазипараллельность лучей (физическое расположение станций игнорируем!)
        diff_a = abs(geom_angles(i) - geom_angles(j));
        if diff_a > pi, diff_a = 2*pi - diff_a; end
        
        % Если для дальней цели лучи слились в один пучок — это ОДИН кластер
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

for c = 1:num_clusters
    mask = (cluster_labels == c);
    N_c = sum(mask);
    
    % Находим индекс "лидера" — первой станции, которая породила этот кластер
    leader_idx = find(mask, 1, 'first');
    
    % ИСКЛЮЧАЕМ СДВИГ БАЗЫ: Виртуальный пункт жестко наследует физические координаты лидера
    P_out(:, c) = P(:, leader_idx);
    
    % Углы также наследуются от лидера во избежание тригонометрического перекоса
    alpha_out(c) = alpha(leader_idx);
    beta_out(c)  = beta(leader_idx);
    
    % Эффект усреднения и избыточности сохраняется: шум падает в N_c раз!
    var_alpha_out(c) = var_alpha(leader_idx) / N_c;
    var_beta_out(c)  = var_beta(leader_idx) / N_c;
end


status = 0;
end
