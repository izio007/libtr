%[text] ## 🔬 ЭТАП 1: ПОЛНЫЙ АНАЛИТИЧЕСКИЙ ВЫВОД ИЗМЕРИТЕЛЬНОЙ МАТЕМАТИКИ ТИС
%[text] ## 1. Геометрия задачи на декартовой земле
%[text] Триангуляционно-Измерительная Система (ТИС) осуществляет оценивание пространственного положения цели, находящейся в точке с истинными декартовыми координатами:
%[text] $\mathbf{X}=\[x,y,z\]^T \in \mathbb{R}^3$
%[text] Измерительная сеть состоит из $M$ наземных базовых постов с известными, статичными декартовыми координатами:
%[text] $\mathbf{X}\_{si}=\[x\_{si},y\_{si},z\_{si}\]^T,\quad i=1,\dots,M$
%[text] Для каждого поста ТИС вектор геометрического смещения (визирный луч «пост $\rightarrow$ цель») задается разностью декартовых координат:
%[text] $\mathbf{\Delta X}\_i=\mathbf{X}-\mathbf{X}\_{si}=\[x-x\_{si},y-y\_{si},z-z\_{si}\]^T=\[\Delta x\_i,\Delta y\_i,\Delta z\_i\]^T$
%[text] Продольная дальность до цели в горизонтальной проекции $XOY$ и полная пространственная дальность до $i$-го поста равны соответственно:
%[text] $r\_{xy,i}=\sqrt{\Delta x\_i^2+\Delta y\_i^2}$
%[text] $\rho\_i=\Vert\mathbf{\Delta X}\_i\Vert=\sqrt{\Delta x\_i^2+\Delta y\_i^2+\Delta z\_i^2}$
%[text] 
%[text] ## 2. Выбор базиса измерительных векторов и тригонометрический закон OX
%[text] Аппаратура каждого поста ТИС измеряет угловое направление на цель (вектор пеленгации) строго от инвариантной оси $OX$ декартовой земли против часовой стрелки [hc3vF-]:
%[text]    1. Азимут ($\alpha\_i$) — угол в плоскости $XOY$ между положительным направлением оси $OX$ и проекцией визирного луча:
%[text]    $\alpha\_i=\text{atan2}(\Delta y\_i,\Delta x\_i)\quad\rightarrow\quad\tan\alpha\_i=\frac{\Delta y\_i}{\Delta x\_i}$
%[text]    2. Угол места ($\beta\_i$) — угол в вертикальной плоскости между плоскостью $XOY$ и пространственным визирным лучем:
%[text]    $\beta\_i=\text{atan2}(\Delta z\_i,r\_{xy,i})\quad\rightarrow\quad\tan\beta\_i=\frac{\Delta z\_i}{r\_{xy,i}}$
%[text] Единичный направляющий вектор направления (луч пеленгации) $\mathbf{1}\_i$, выходящий из $i$-го поста в сторону цели, формирует строго ортонормированный угловой базис:
%[text] $\mathbf{1}\_i=\[\cos\alpha\_i\cos\beta\_i,\sin\alpha\_i\cos\beta\_i,\sin\beta\_i\]^T,\quad\Vert\mathbf{1}\_i\Vert\equiv 1$
%[text] 
%[text] ## 3. Вывод уравнений связи через векторное кросс-произведение
%[text] Истинные декартовы координаты цели жестко связаны с вектором направления луча через нелинейный масштаб дальности $\rho\_i$:
%[text] $\mathbf{X}=\mathbf{X}\_{si}+\rho\_i\cdot\mathbf{1}\_i$
%[text] Чтобы исключить неизвестную нелинейную дальность $\rho\_i$ без привлечения итераций (для голого LLS/WLLS), теоретик умножает обе части уравнения слева на кососимметрическую матрицу векторного произведения $\[\mathbf{1}\_i\]\_ \times$ луча пеленгации. Так как векторное произведение соосных векторов тождественно равно нулю ($\[\mathbf{1}\_i\]\_ \times\cdot\mathbf{1}\_i\equiv\mathbf{0}$), нелинейный масштаб исчезает:
%[text] $\[\mathbf{1}\_i\]\_ \times\cdot\mathbf{X}=\[\mathbf{1}\_i\]\_ \times\cdot\mathbf{X}\_{si}$
%[text] Где кососимметрический оператор $\[\mathbf{1}\_i\]\_ \times$ имеет вид:
%[text] $\[\mathbf{1}\_i\]\_ \times=\[0,-\sin\beta\_i,\sin\alpha\_i\cos\beta\_i;\sin\beta\_i,0,-\cos\alpha\_i\cos\beta\_i;-\sin\alpha\_i\cos\beta\_i,\cos\alpha\_i\cos\beta\_i,0\]$
%[text] Разворачивая это векторное произведение в декартовых осях земли и выполняя деление строк на косинус угла места $\cos\beta\_i$ (для исключения тригонометрических сингулярностей), мы получаем строго выведенную систему измерительных МНК-строк, знаки которых были верифицированы вашим ручным аудитом [hc3vF-]:
%[text]    1. Горизонтальная строка связи (Азимут):
%[text]    $\sin\alpha\_i\cdot x-\cos\alpha\_i\cdot y=\sin\alpha\_i\cdot x\_{si}-\cos\alpha\_i\cdot y\_{si}$
%[text]    2. Вертикальная строка связи (Угол места):
%[text]    -\cos\alpha\_i\sin\beta\_i\cdot x-\sin\alpha\_i\sin\beta\_i\cdot y+\cos\beta\_i\cdot z=-\cos\alpha\_i\sin\beta\_i\cdot x\_{si}-\sin\alpha\_i\sin\beta\_i\cdot y\_{si}+\cos\beta\_i\cdot z\_{si}$
%[text] 
%[text] ## 4. Перенос в инвариантный полярный базис центра тяжести задач
%[text] Чтобы полностью уничтожить декартово Bias-сжатие, вызванное асимметрией линейного раскрыва котангенса на дальнем рубеже, теоретик переносит вектор состояния задачи в полярный инвариантный базис относительно мгновенного центра тяжести сети активных постов задачи ТИС $\mathbf{X}\_c$:
%[text] $\mathbf{X}\_c=\[x\_c,y\_c,z\_c\]^T=\[\frac{1}{M}\sum\_{i=1}^{M}x\_{si},\frac{1}{M}\sum\_{i=1}^{M}y\_{si},\frac{1}{M}\sum\_{i=1}^{M}z\_{si}\]^T$
%[text] Локальный вектор приращений цели относительно центра тяжести равен:
%[text] $\mathbf{\Delta X}\_c=\mathbf{X}-\mathbf{X}\_c=\[x-x\_c,y-y\_c,z-z\_c\]^T=\[\Delta x\_c,\Delta y\_c,\Delta z\_c\]^T$
%[text] Мы выбираем новый инвариантный вектор состояния цели $\mathbf{q}$ в сферической (полярной) системе координат измерительного пучка:
%[text] $\mathbf{q}=\[\alpha\_c,\beta\_c,\rho\_c\]^T$
%[text] Связь между декартовым пространством земли и инвариантным полярным базисом пучка задается строгими функциональными преобразованиями:
%[text] * Прямой переход («Земля $\rightarrow$ Пучок»):
%[text] $\rho\_c=\Vert\mathbf{\Delta X}\_c\Vert=\sqrt{\Delta x\_c^2+\Delta y\_c^2+\Delta z\_c^2}$
%[text] $\alpha\_c=\text{atan2}(\Delta y\_c,\Delta x\_c)$
%[text] $\beta\_c=\text{atan2}(\Delta z\_c,\sqrt{\Delta x\_c^2+\Delta y\_c^2})$
%[text] * Обратный переход («Пучок $\rightarrow$ Земля»):
%[text] $\mathbf{X}=\mathbf{X}\_c+\rho\_c\cdot\mathbf{1}\_c=\[x\_c+\rho\_c\cos\alpha\_c\cos\beta\_c,y\_c+\rho\_c\sin\alpha\_c\cos\beta\_c,z\_c+\rho\_c\sin\beta\_c\]^T$
%[text] 
%[text] ## 5. Выбор базиса векторов Якоби и ортогональный разворот луча
%[text] Связь между дифференциалами декартовых метров земли и дифференциалами инвариантного полярного пучка $\mathbf{q}$ определяется матрицей Якоби полярного перехода $J\_{polar}$ размера $3 \times 3$:
%[text] $J\_{polar}=\frac{\partial \mathbf{X}}{\partial \mathbf{q}}=\[\frac{\partial x}{\partial \alpha\_c},\frac{\partial x}{\partial \beta\_c},\frac{\partial x}{\partial \rho\_c};\frac{\partial y}{\partial \alpha\_c},\frac{\partial y}{\partial \beta\_c},\frac{\partial y}{\partial \rho\_c};\frac{\partial z}{\partial \alpha\_c},\frac{\partial z}{\partial \beta\_c},\frac{\partial z}{\partial \rho\_c}\]$
%[text] Дифференцируя уравнения обратного перехода по вектору $\mathbf{q}=\[\alpha\_c,\beta\_c,\rho\_c\]^T$, получаем строгую аналитическую структуру Якобиана, столбцы которой образуют ортогональный визирный базис направления (Line-of-Sight, LOS) ТИС:
%[text] $J\_{polar}=\[-\rho\_c\sin\alpha\_c\cos\beta\_c,-\rho\_c\cos\alpha\_c\sin\beta\_c,\cos\alpha\_c\cos\beta\_c;\rho\_c\sin\alpha\_c\cos\beta\_c,-\rho\_c\sin\alpha\_c\sin\beta\_c,\sin\alpha\_c\cos\beta\_c;0,\rho\_c\cos\beta\_c,\sin\beta\_c\]$
%[text] 
%[text] ## 6. Математическое ожидание и строгий вывод CRLB Рао-Крамера
%[text] Пусть аппаратура постов ТИС генерирует вектор случайных измерительных погрешностей (Гауссов шум угловых каналов) $\mathbf{n}=\[\delta\alpha\_1,\delta\beta\_1,\dots,\delta\alpha\_M,\delta\beta\_M\]^T$.
%[text] Математическое ожидание (первый момент) измерительного шума строго равно нулю:
%[text] $M\[\mathbf{n}\]=\mathbf{0}$
%[text] Погрешности датчиков независимы, их паспортные дисперсии формируют приборную ковариационную матрицу $R=\text{diag}(\sigma\_{\alpha 1}^2,\sigma\_{\beta 1}^2,\dots)$.
%[text] Минимум рассеяния любой несмещенной оценки координат ТИС (параметры геометрического эллипса ошибок рассеяния $1\sigma$) жестко ограничен пределом Рао-Крамера (CRLB) через второй центральный момент — квадрат математического ожидания отклонений невязок:
%[text] $D(\hat{\mathbf{X}})=M\[(\hat{\mathbf{X}}-\mathbf{X}\_{true})(\hat{\mathbf{X}}-\mathbf{X}\_{true})^T\] \ge I\_{F,cart}^{-1}$
%[text] Где декартова информационная матрица Фишера $I\_{F,cart}$ является математическим ожиданием квадрата градиента логарифма функции правдоподобия резольвенты по оцениваемому декартову вектору $\mathbf{X}$ [hc3vF-]:
%[text] $I\_{F,cart}=M\[\left(\frac{\partial \ln L}{\partial \mathbf{X}}\right)\left(\frac{\partial \ln L}{\partial \mathbf{X}}\right)^T\]=\sum\_{i=1}^{M}\[\frac{1}{\sigma\_{\alpha i}^2}\left(\frac{\partial\alpha\_i}{\partial\mathbf{X}}\right)\left(\frac{\partial\alpha\_i}{\partial\mathbf{X}}\right)^T+\frac{1}{\sigma\_{\beta i}^2}\left(\frac{\partial\beta\_i}{\partial\mathbf{X}}\right)\left(\frac{\partial\beta\_i}{\partial\mathbf{X}}\right)^T\]$
%[text] Для полярного пространства измерительного пучка ТИС, где целевая функция представляет собой идеальную круглую «чашу», а не вытянутый декартов овраг, взвешенная матрица Фишера трансформируется через выведенный нами ортогональный визирный Якобиан перехода $J\_{polar}$:
%[text] $I\_{polar}=J\_{polar}^T\cdot I\_{F,cart}\cdot J\_{polar}$
%[text] Инвертируя эту матрицу в ОЗУ, теоретик получает честную полярную ковариационную матрицу нижнего предела Рао-Крамера $K\_{polar, CRLB}=I\_{polar}^{-1}$, диагональные элементы которой определяют физическое дно точности ТИС по осям Cross-track (поперечный промах), Along-track (угломестный промах) и Range (радиальный промах по дальности):
%[text] $\sigma^2\_{cross, CRLB}=K\_{polar}(1,1),\quad\sigma^2\_{along, CRLB}=K\_{polar}(2,2),\quad\sigma^2\_{range, CRLB}=K\_{polar}(3,3)$
%[text] Именно из этой бесшумной полярной информационной матрицы, развернутой обратно на землю, и извлекается абсолютно точный, неуязвимый для декартова Bias-сжатия Mock-эталон для автоконтроля наших ядер ТИС [hc3vF-].


%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"hidecode","rightPanelPercent":6.7}
%---
