# 🔬 СТАНДАРТ ПРОЕКТИРОВАНИЯ И ТРАНСЛЯЦИИ MATLAB LIVE CODE (.m) — ВЕРСИЯ 4.2

Этот набор правил является единственным безальтернативным эталоном для генерации, конвертации или изменения любого технического, математического и аналитического контента под внутренний синтаксис файлов MATLAB Live Editor (`.m`).

## 1. Контейнеризация вывода (Аппаратная защита)
* **Строго в блоке кода:** Вся без исключения трансляция (готовый текст для файла `.m`) должна возвращаться пользователю строго внутри окна кода ` ```text ... ``` `. Это полностью отключает веб-парсер ИИ-интерфейса и гарантирует побитовую точность передачи символов.

## 2. Построчная структура и префиксы
* **Монолитность строк:** Каждый логический элемент текста, заголовок или математическое выражение записывается строго на одной физической строке файла. Любые несанкционированные разрывы и переносы строк внутри одной формулы или предложения запрещены.
* **Обязательный префикс:** Каждая строка в текстовом блоке должна начинаться с префикса `%[text] `.
* **Разделители:** Пустые строки между абзацами, заголовками или формулами должны генерироваться как префикс с концевым пробелом: `%[text] `. Пропуск префикса на пустых строках нарушает логику разбиения блоков в ОЗУ.

## 3. Матричное экранирование в Live Editor (КРИТИЧЕСКОЕ ПРАВИЛО)
При формировании матриц, векторов, систем уравнений и Якобианов внутри одиночных знаков доллара `$ ... $` модель обязана строго соблюдать однострочный синтаксис компилятора MATLAB:
* **ПОЛНЫЙ ЗАПРЕТ НА МНОГОСТРОЧНЫЕ СРЕДЫ LaTeX:** Категорически запрещено использовать теги `\begin{bmatrix}`, `\end{bmatrix}`, `\begin{matrix}`, `\end{matrix}`, а также символы переноса строк `\\` и амперсанды `&`. Их использование вызывает аварийный срыв компиляции в Live Editor и окрашивает формулы в красный цвет.
* **Строгий однострочный стандарт:** Все матрицы, векторы-столбцы и Якобианы записываются монолитно в одну строку через экранированные квадратные скобки `\[` и `\]`.
* **Разделители элементов матриц:** Элементы внутри одной строки матрицы разделяются запятыми `,`, а строки между собой — точкой с запятой `;`. 
* **Запрет на веб-мнемоники:** Полностью исключить появление системных символов веб-разметки вроде `&amp;` внутри сгенерированного кода. Все разделители должны быть чистыми.

## 4. Символьное экранирование LaTeX в Live Editor
* **Команды LaTeX:** Все математические операторы и греческие буквы пишутся строго через два обратных слэша: `\\mathbf`, `\\sin`, `\\cos`, `\\sqrt`, `\\alpha`, `\\beta`, `\\Delta`, `\\sum`, `\\text`, `\\cdot`, `\\dots`, `\\mathbb`, `\\partial`, `\\Vert`, `\\le`, `\\ge`.
* **Индексы и подчеркивания:** Символ нижнего подчеркивания для индексов всегда экранируется как `\\_`. Сложные индексы оборачиваются в фигурные скобки: `\\_{index}`.

## 5. Запрет на сжатие выкладок и англицизмы
* **Полнота выкладок:** Математические выводы, формулы и промежуточные шаги переносятся со 100% точностью и полнотой. Сокращение индексов, функциональных аргументов (например, превращение `\\Delta x\\_i(\\mathbf{Y})` в `\\Delta x`) или знаков умножения запрещено.
* **Чистота языка:** Все технические термины, описания и комментарии переводятся на чистый русский язык (без ломанных англицизмов вроде `active постов`, `matrix Якоби`, `residual невязок` и т.д.).

## 6. Обязательный системный постфикс интерфейса
После завершения основного текста в самом конце файла добавляется фиксированный блок метаданных отображения интерфейса Live Editor (строго без префикса `%[text]`):
```text
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"hidecode","rightPanelPercent":6.7}
%---
```

## 7. Полная библиотека верифицированных эталонных примеров
При генерации кода ориентироваться строго на следующие нативные рабочие конструкции, успешно прошедшие компиляцию в MATLAB без ошибок рендеринга:

```text
%[text] \(\mathbf{X}=\)\[x,y,z\]^T \(\in \mathbb{R}^3\)\(\%[text]\)\(\mathbf{X}\_\){si}=\[x\_{si},y\_{si},z\_{si}\]^T\(,\quad i=1,\dots,\)M\(\%[text]\)\(\mathbf{X}\_0=\)\[x\_0,y\_0,z\_0\]^T=\[\frac{1}{M}\sum\_{i=1}^{M}x\_{si},\frac{1}{M}\sum\_{i=1}^{M}y\_{si},\frac{1}{M}\sum\_{i=1}^{M}z\_{si}\]^T\$
%[text] \(\mathbf{Y}=\)\[\alpha\_0,\beta\_0,R\_0\]^T\$
%[text] \(\Delta x\_i(\mathbf{Y})=x(\mathbf{Y})-x\_{si}=(x\_0-x\_{si})+R\_0\cdot\cos\beta\_0\cdot\cos\alpha\_0\)
%[text] \(r\_{xy,i}=\sqrt{\Delta x\_i^2+\Delta y\_i^2}\)
%[text] \(W=\text{diag}(\frac{1}{\sigma\_{\alpha 1}^2\cdot\rho\_1^2},\quad\frac{1}{\sigma\_{\beta 1}^2\cdot\rho\_1^2},\quad\dots,\quad\frac{1}{\sigma\_{\alpha M}^2\cdot\rho\_M^2},\quad\frac{1}{\sigma\_{\beta M}^2\cdot\rho\_M^2})\)
%[text] Линейный взвешенный метод (WLLS) требует преобразования нелинейных уравнений связи к виду взвешенной линейной системы нормальных уравнений \(H\cdot\mathbf{X}=b\), где каждая строка нормируется на СКО промаха на местности \(\sigma\cdot\rho\_i\).
%[text] ### 2.1. Аналитический вывод строки горизонтального канала (Азимут \(\alpha\_i\))
%[text] \(\frac{\sin\alpha\_i}{\sigma\_{\alpha i}\cdot\rho\_i}\cdot x-\frac{\cos\alpha\_i}{\sigma\_{\alpha i}\cdot\rho\_i}\cdot y=\frac{\sin\alpha\_i\cdot x\_{si}-\cos\alpha\_i\cdot y\_{si}}{\sigma\_{\alpha i}\cdot\rho\_i}\)
%[text] \(H(2i-1,1)=\frac{\sin\alpha\_i}{\sigma\_{\alpha i}\cdot\rho\_i}\)
%[text] \(H(2i-1,2)=\frac{-\cos\alpha\_i}{\sigma\_{\alpha i}\cdot\rho\_i}\)
%[text] \(H(2i-1,3)=0\)
%[text] \(b(2i-1,1)=\frac{\sin\alpha\_i\cdot x\_{si}-\cos\alpha\_i\cdot y\_{si}}{\sigma\_{\alpha i}\cdot\rho\_i}\)
%[text] \(-\frac{\cos\alpha\_i\sin\beta\_i}{\sigma\_{\beta i}\cdot\rho\_i}\cdot x-\frac{\sin\alpha\_i\sin\beta\_i}{\sigma\_{\beta i}\cdot\rho\_i}\cdot y+\frac{\cos\beta\_i}{\sigma\_{\beta i}\cdot\rho\_i}\cdot z=\frac{-\cos\alpha\_i\sin\beta\_i\cdot x\_{si}-\sin\alpha\_i\sin\beta\_i\cdot y\_{si}+\cos\beta\_i\cdot z\_{si}}{\sigma\_{\beta i}\cdot\rho\_i}\)
%[text] \(H(2i,1)=\frac{-\cos\alpha\_i\sin\beta\_i}{\sigma\_{\beta i}\cdot\rho\_i}\)
%[text] \(H(2i,2)=\frac{-\sin\alpha\_i\sin\beta\_i}{\sigma\_{\beta i}\cdot\rho\_i}\)
%[text] \(H(2i,3)=\frac{\cos\beta\_i}{\sigma\_{\beta i}\cdot\rho\_i}\)
%[text] \(b(2i,1)=\frac{-\cos\alpha\_i\sin\beta\_i\cdot x\_{si}-\sin\alpha\_i\sin\beta\_i\cdot y\_{si}+\cos\beta\_i\cdot z\_{si}}{\sigma\_{\beta i}\cdot\rho\_i}\)
%[text] \(\mathbf{X}\_{WLLS}=(H^TH)^{-1}H^T\mathbf{b}\)
%[text] %[text] Где кососимметрический оператор \([\mathbf{1}\_i]\_\times\) имеет вид:
%[text] \([\mathbf{1}\_i]\_\times=\)\[0,-\sin\beta\_i,\sin\alpha\_i\cos\beta\_i;\quad\sin\beta\_i,0,-\cos\alpha\_i\cos\beta\_i;\quad-\sin\alpha\_i\cos\beta\_i,\cos\alpha\_i\cos\beta\_i,0\]\(\%[text]\)J\(\_{\text{GNP}}(2i-1,1)=\frac{\partial\alpha\_i}{\partial\alpha\_0}=\frac{\partial\alpha\_i}{\partial x}\frac{\partial x}{\partial\alpha\_0}+\frac{\partial\alpha\_i}{\partial y}\frac{\partial y}{\partial\alpha\_0}=(\frac{-\Delta y\_i}{r\_{h,i}^2})\)(-R\(\_0\cdot\cos\beta\_0\cdot\sin\alpha\_0\))\(+(\frac{\Delta x\_i}{r\_{h,i}^2})\)(R\(\_0\cdot\cos\beta\_0\cdot\cos\alpha\_0\))\(\%[text]\)J\(\_{\text{GNP}}(2i-1,:)=\)\[\frac{R\_0\cdot\cos\beta\_0\cdot(\Delta x\_i\cdot\cos\alpha\_0+\Delta y\_i\cdot\sin\alpha\_0)}{r\_{h,i}^2},\quad\frac{R\_0\cdot\sin\beta\_0\cdot(\Delta y\_i\cdot\cos\alpha\_0-\Delta x\_i\cdot\sin\alpha\_0)}{r\_{h,i}^2},\quad\frac{\cos\beta\_0\cdot(\Delta x\_i\cdot\sin\alpha\_0-\Delta y\_i\cdot\cos\alpha\_0)}{r\_{h,i}^2}\]\(\%[text]\)J\_{polar}\(=\frac{\partial \mathbf{X}}{\partial \mathbf{q}}=\)\[\frac{\partial x}{\partial \alpha\_c},\frac{\partial x}{\partial \beta\_c},\frac{\partial x}{\partial \rho\_c};\quad\frac{\partial y}{\partial \alpha\_c},\frac{\partial y}{\partial \beta\_c},\frac{\partial y}{\partial \rho\_c};\quad\frac{\partial z}{\partial \alpha\_c},\frac{\partial z}{\partial \beta\_c},\frac{\partial z}{\partial \rho\_c}\]\(\%[text]\)J\_{polar}=\[-\rho\_c\sin\alpha\_c\cos\beta\_c,-\rho\_c\cos\alpha\_c\sin\beta\_c,\cos\alpha\_c\cos\beta\_c;\quad\rho\_c\cos\alpha\_c\cos\beta\_c,-\rho\_c\sin\alpha\_c\sin\beta\_c,\sin\alpha\_c\cos\beta\_c;\quad 0,\rho\_c\cos\beta\_c,\sin\beta\_c\]\$
%[text] \(K\_{\text{cart}} = J\_{\text{polar}\rightarrow\text{cart}} \cdot K\_{\text{polar}} \cdot J\_{\text{polar}\rightarrow\text{cart}}^T\)
```
