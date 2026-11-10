;;; ======================================================================
;;;  MM_CABLE.LSP  —  кабели из участков с разными способами прокладки
;;;  AutoCAD 2024. Кодировка файла: Windows-1251 (ANSI). Чертёж в мм.
;;; ----------------------------------------------------------------------
;;;  КАБЕЛЬ = безымянная группа AutoCAD из полилиний-участков.
;;;  Один щелчок выделяет весь кабель. У каждого участка: способ прокладки
;;;  (свой тип линии), высота, коэффициент запаса. У опусков к приборам и
;;;  переходов по высоте - свой способ прокладки и коэффициент (по умолчанию
;;;  как у соседнего участка).
;;; ----------------------------------------------------------------------
;;;  КОМАНДЫ:
;;;   ММ_КАБЕЛЬ (MM_CABLE) - нарисовать кабели: окно параметров
;;;     (тип и марка кабеля, диаметр, ПОЗИЦИЯ, прокладка по умолчанию, высота,
;;;     коэф. запаса, отступ, слой) -> полилиния от прибора до прибора.
;;;   ММ_КАБЕЛЬ_ИЗ_ЛИНИИ (MM_CABLE_FROM_LINE) - сделать кабелем готовые линии/
;;;     полилинии: выбор линий -> окно параметров. Цвет, вес линии и ширина
;;;     сохраняются; каждая линия - отдельный кабель.
;;;   ММ_КАБЕЛЬ_УЧАСТОК (MM_CABLE_SEGMENT) - другая прокладка на участке:
;;;     рамка (область): все отрезки кабелей между соседними вершинами,
;;;     попавшие в рамку, получают новые параметры; [Щелчок] - один отрезок
;;;     и наложенные на него кабели, [Точки] - часть отрезка.
;;;     Пересчитываются только затронутые кабели и их выноски.
;;;     В окне - сечения кабелей; для лотка/короба - сечение всей группы,
;;;     размер (Ш x В) и заполнение.
;;;   Прокладка: по умолчанию каждый кабель - в своём материале (гофротруба),
;;;     считается по каждому кабелю. Лотки, короба, тросы - общие для группы
;;;     кабелей, считаются отдельно: наложенные участки - один раз.
;;;   ПЕРЕНОС НА ДР. ЛИСТ (PERENOS) - как стояк (см. ниже), но слой _ПЕРЕНОС
;;;     (бледно-зелёный, не печатается), длина по умолчанию 0 м (можно задать).
;;;   СТОЯК - способ прокладки "стояк" (без букв, штриховая, бледно-жёлтая,
;;;     непечатаемый слой _СТОЯК, на заднем плане); длина участка-стояка
;;;     по умолчанию 5 м (можно задать). ЭТАЖ - у каждого участка: до стояка -
;;;     атрибут ЭТАЖ блока-стояка в начале участка "стояк", после - блока-
;;;     стояка в его конце; без стояков - ЭТАЖ блока "откуда" (после
;;;     последнего стояка без блока - "куда"). Этаж и длину участка можно
;;;     задать вручную в окне СВОЙСТВА ("Выбранная строка").
;;;   ММ_КАБЕЛЬ_СВОЙСТВА (MM_CABLE_PROPS) - окно кабеля: параметры и
;;;     таблица: опуски, участки, переходы по высоте - у каждой строки
;;;     способ прокладки, длина, коэф. запаса, длина с запасом.
;;;   ММ_КАБЕЛЬ_ПЕРЕСОБРАТЬ (MM_CABLE_REBUILD) - после правки ручками:
;;;     сшить стыки участков, заново найти приборы у концов.
;;;   ММ_КАБЕЛЬ_ВЫНОСКА (MM_CABLE_LEADER) - общая выноска для кабелей:
;;;     кабели -> точка на кабеле [Параметры] -> положение текста.
;;;     Начало выноски - закрашенный кружок. Привязка текста "Авто":
;;;     вверх - к нижней строке, вниз - к верхней; выноска вправо - полка
;;;     к тексту слева, влево - справа.
;;;   СПРАВОЧНИК КАБЕЛЕЙ - файл cable_type.csv в папке чертежа (колонки:
;;;     тип;оболочка;проводник;номенклатура;сечение;диаметр_мм; UTF-8 с BOM
;;;     или Windows-1251). Нет файла - окно выбора файла; отмена - ввод
;;;     номенклатуры и диаметра вручную. В окнах кабеля: Тип, Оболочка,
;;;     Проводник, Сечение - зависимые фильтры, Номенклатура - выбор;
;;;     кнопка "Обновить" (или ММ_КАБЕЛЬ_СПРАВОЧНИК, MM_CABLE_CATALOG) -
;;;     дочитать файл: новые добавляются, изменённые обновляются, без дублей.
;;;   ММ_КАБЕЛЬ_ТРАССИРОВКА (MM_CABLE_TRACE) - окно параметров -> блок
;;;     начала -> блок конца -> щелчок по кабелю-трассе [Нет]: от блока до
;;;     ближайшей точки трассы - подводка по горизонтали/вертикали (гофр.
;;;     труба d20), далее по трассе (её способы, высоты, диаметры, стояки),
;;;     подводка к блоку конца. [Нет] - Г-образная подводка напрямую.
;;;     Можно указать несколько трасс по порядку (Enter - готово): переход
;;;     с трассы на трассу - в ближайших точках. Вопрос "Трасса существующая?"
;;;     - участки по трассам получают отметку "сущ." (материал не считается).
;;;   ММ_КАБЕЛЬ_ТРАССИРОВКА_УСТРОЙСТВО (MM_CABLE_TRACE_DEVICE) - указать новое
;;;     устройство -> щёлкнуть ранее созданный кабель: новый кабель идёт из
;;;     НАЧАЛА выбранного кабеля по его же пути (способы прокладки, высоты,
;;;     диаметры, стояки и переносы на др. лист, "сущ.") до ближайшей к устройству точки, затем
;;;     подводка к устройству (гофр. труба d20). Окно параметров - марка и
;;;     этаж как у выбранного, ПОЗИЦИЯ - следующая свободная. Затем можно
;;;     указывать следующие устройства по тому же кабелю (Enter - выход).
;;;   ММ_КАБЕЛЬ_ТРАССИРОВКА_ГРУППА (MM_CABLE_TRACE_GROUP) - то же для нескольких
;;;     устройств: выделить устройства рамкой -> щёлкнуть кабель-образец ->
;;;     окно: список устройств (по порядку вдоль пути), выделить нужные ->
;;;     окно параметров (ПОЗИЦИЯ первого, дальше подряд, свободные).
;;;   ПРАВКА ГЕОМЕТРИИ В ГРУППЕ: GROUPDISPLAYMODE=0 (ставится при загрузке) -
;;;     у выбранного кабеля видны ручки всех участков, правка без разгруппировки.
;;;     После правки стыки участков подтягиваются (кабель не рвётся), концы
;;;     заново привязываются к блокам (если не закреплены), подпись ПОЗИЦИИ
;;;     переносится в конец.
;;;   ММ_КАБЕЛЬ_ПЕРЕИМЕНОВАТЬ (MM_CABLE_RENAME) - выделить устройства -> окно типов блоков (и блоки
;;;     без кабелей) -> окно переименования: таблица кабелей, первая колонка - новое имя по маске;
;;;     нумерация {#}: по порядку / по номеру конечного устройства / авто (слева направо, сверху вниз).
;;;   ММ_КАБЕЛЬ_ВСЕ -> "Переименовать...": новая ПОЗИЦИЯ выделенных (или всех
;;;     отобранных) кабелей по маске: {#} {##} номер, {ПОЗ}, {Н.АТРИБУТ} / {К.АТРИБУТ}
;;;     блока начала / конца, {ЭТ1} {ЭТ2} {Э1} {Э2} этажи, {ПОМ1} {ПОМ2} помещения,
;;;     поля выносок ({НОМ} ...); предпросмотр "было -> стало" сразу.
;;;   СУЩ. ТРАССА - отметка участка (окно СВОЙСТВА, окно УЧАСТОК): материал
;;;     прокладки на участке уже есть - в спецификацию не идёт (кабель идёт).
;;;   ММ_КАБЕЛЬ_ЭЛ (MM_CABLE_POWER) - потери напряжения: список кабелей
;;;     (фильтр), выделенным - род тока (пост./~1ф/~3ф), U, I или P, cos fi,
;;;     допустимые потери %, сечение и материал жилы (по умолчанию из
;;;     справочника); не проходящие помечены "!!"; двойной щелчок - потери по
;;;     участкам; выгрузка CSV / таблица на чертёж: кабели и по участкам.
;;;     В окне участков - мощность P, Вт отдельно для участка (пусто - как у
;;;     кабеля): ток и потери этой строки считаются по мощности участка.
;;;   Журнал: колонки по способам - с запасом, вверх до 1 м; "Итого" = их сумма.
;;;   ММ_КАБЕЛЬ_ВЫНОСКА_СТОЯК (MM_CABLE_LEADER_RISER) - (и для переноса на др. лист) выбрать БЛОК-стояк: по
;;;     выноске на каждое направление стояков у этого блока (проходной - две:
;;;     "с N этажа" и "на M этаж"); или участок-стояк - выноски у обоих концов.
;;;     Строки кабелей стояка + этаж (атрибут ЭТАЖ блока на другом конце).
;;;   ТРУБЫ: заполнение считается по ВНУТРЕННЕМУ диаметру (таблица типовых
;;;     значений *bk:dint*: гофра d20 - 14,1 мм и т.п.); в окне СВОЙСТВА -
;;;     колонка "Зап., %"; в окне УЧАСТОК - подбор диаметра трубы.
;;;   ММ_КАБЕЛЬ_ВЫНОСКА_ФОРМАТ (MM_CABLE_LEADER_FORMAT) - формат записи всех
;;;     выносок: шаблоны с полями {ПОЗ} {НОМ} {ТИП} {ОБОЛ} {ПРОВ} {СЕЧ} {D}
;;;     {ЭТАЖ} {ОТКУДА} {КУДА} {ПОМ1} {ПОМ2} {ДЛИНА}; нижняя строка {ПРОКЛ};
;;;     выноска прокладки {ПРОКЛ} {DРАСЧ} {ОБЩ} {N} {SUMS} {ЗАП}. По OK
;;;     обновляются все выноски. Также [Формат] при создании выноски.
;;;   ММ_КАБЕЛЬ_ВЫНОСКА_ПРОКЛ (MM_CABLE_LEADER_ROUTE) - выноска в точке на кабеле:
;;;     в чём идёт кабель (способ, d материала / размер лотка), расчётный
;;;     диаметр (у наложенных кабелей - общий диаметр пучка), % заполнения.
;;;   Все выноски - в общей рамке, без подчёркивания, с маскировкой фона;
;;;     таблицы на чертеже - с маскировкой фона. Длины - вверх до 1 м.
;;;   ММ_КАБЕЛЬ_ВЫНОСКА_ПАРАМ (MM_CABLE_LEADER_PARAMS) - изменить у готовых
;;;     выносок высоту текста, размер кружка, привязку текста.
;;;   ММ_КАБЕЛЬ_ОБНОВИТЬ (MM_CABLE_UPDATE) - обновить ВЕСЬ чертёж: стыки и концы всех кабелей, копии
;;;     (новые id/ПОЗИЦИИ), выноски, подписи. После правок автоматически обновляются только
;;;     изменённые кабели, кабели перемещённых блоков и их выноски.
;;;     ПОЗИЦИИ в концах кабелей (слой КАБЕЛИ_ПОЗ, не печатается; высота =
;;;     высота атрибута ПОЗИЦИЯ блока конца / 5) сейчас;
;;;     [Авто] - включить/выключить автообновление. Автообновление (по
;;;     умолчанию ВКЛ) срабатывает после правки ручками, ПЕРЕНЕСТИ,
;;;     СТЕРЕТЬ, ОТМЕНИТЬ, КОПИРОВАТЬ, окна Свойства и т.п., пока файл загружен.
;;;   ММ_КАБЕЛЬ_ЖУРНАЛ (MM_CABLE_LOG) - кабельный журнал в CSV.
;;;   ММ_КАБЕЛЬ_ВСЕ (MM_CABLE_ALL) - все кабели чертежа:
;;;     фильтр, длины, откуда/куда; "Свойства выделенных" - правка одного
;;;     или нескольких кабелей; "Показать" - зум на кабель.
;;;   ММ_КАБЕЛЬ_ЛЕГЕНДА (MM_CABLE_LEGEND) - таблица условных обозначений:
;;;     только способы прокладки, реально нарисованные на чертеже.
;;;   ММ_КАБЕЛЬ_ЛИНИИ (MM_CABLE_LINES) - затем цвет [ПоСлою/ПоТипам/Оставить]:
;;;     все кабели одним цветом слоя или цветом своего способа прокладки
;;;     (цвет способа - в ММ_КАБЕЛЬ_ТИПЫ). [Типы/Сплошная/Штриховая]: рисовать
;;;     кабели без обозначения типа прокладки (все сплошные или штриховые);
;;;     способы прокладки у участков сохраняются. Режим хранится в чертеже.
;;;   ММ_КАБЕЛЬ_ТИПЫ (MM_CABLE_TYPES) - способы прокладки: добавить,
;;;     изменить (название, надпись в линии, высота, длина штриха), удалить
;;;     неиспользуемый. Хранятся в чертеже. Та же кнопка есть в окнах.
;;;   ММ_КАБЕЛЬ_ЕЩЕ (MM_CABLE_MORE) - новый кабель по пути выбранного:
;;;     те же участки, прокладка, опуски, привязки; своя марка и ПОЗИЦИЯ.
;;;   ММ_КАБЕЛЬ_ВЕТКА (MM_CABLE_BRANCH) - ответвление: щелчок по кабелю в точке
;;;     ответвления, окно параметров (как у кабеля, та же ПОЗИЦИЯ),
;;;     полилиния до прибора. Ветка связана с родителем (par) и корнем (lin);
;;;     в ММ_КАБЕЛЬ_ВСЕ и журнале кабель с ветками - одна строка; кнопка
;;;     «Участки между устройствами в CSV» - все участки кабеля по вершинам. Коробку в точке ответвления ставит
;;;     пользователь; если прибор начала имеет ПРИМ-1 «с коробкой [марка]» -
;;;     коробка не рисуется, но идёт в спецификацию (шт.).
;;;   В окне СВОЙСТВА: "Начало/Конец - указать блок <" - привязать кабель к
;;;     блоку (с подтягиванием конца линии), "Найти по концам" - авто,
;;;     "Отвязать" - убрать привязку.
;;; ----------------------------------------------------------------------
;;;  ПРАВКА ГЕОМЕТРИИ: щелчок по кабелю - ручки всех участков; ручка на
;;;  стыке двигает оба участка; меню ручки - добавить/удалить вершину;
;;;  ПЕРЕНЕСТИ, РАСТЯНУТЬ - как обычно; Ctrl+Shift+A - править один участок.
;;;  После правки - ММ_КАБЕЛЬ_ПЕРЕСОБРАТЬ.
;;;  Диаметры кабелей в справочнике - типовые (ориентировочные), уточняйте
;;;  по каталогу производителя; в окне диаметр можно изменить.
;;; ======================================================================

(vl-load-com)

;;; ---------- способы прокладки: код название тип_линии надпись высота ----------
(setq *bk:types-default*
  '(("GOFRA" "в гофр. трубе"                    "BK_GOFRA" "Тг" 3.0)
    ("LOTOK" "в лотке"                          "BK_LOTOK" "Л"  3.0)
    ("KOROB" "в кабель-канале"                  "BK_KOROB" "К"  2.5)
    ("TRUBA" "в трубе жёсткой"                  "BK_TRUBA" "Т"  3.0)
    ("POL"   "в трубе в полу"                   "BK_POL"   "П"  0.0)
    ("MR"    "в металлорукаве"                  "BK_MR"    "Мр" 3.0)
    ("SKR"   "в гофр. трубе скрыто в штробе"    "BK_SKR"   nil  2.5)
    ("TROS"  "на тросе"                         "BK_TROS"  "Тр" 3.0)
    ("TROSG" "на тросе в гофр. трубе"           "BK_TROSG" "ТрГ" 3.0)
    ("OTKR"  "открыто"                          "Continuous" "-" 3.0)
    ("STOYAK" "стояк"                           "BK_STOYAK" nil 0.0 6.0 "N" 40.0)
    ("PERENOS" "перенос на др. лист"            "BK_PERENOS" nil 0.0 6.0 "N" 40.0)))
;; стояк и перенос на другой лист - одинаковая логика (переход между блоками, своя длина, свой слой)
(defun bk:stc (c) (member c '("STOYAK" "PERENOS")))

;; первая буква строчная
(defun bk:lc1 (s) (if (and s (> (strlen s) 0)) (strcat (strcase (substr s 1 1) T) (substr s 2)) s))

;; способы прокладки хранятся в чертеже (можно добавлять и менять в окне).
;; Старые чертежи приводятся к новым названиям; "за подвесным потолком" убирается, если не используется.
(defun bk:load-types (/ l new ch)
  (setq l (vlax-ldata-get "BK" "types"))
  (if (and l (listp l))
    (progn
      (foreach tp l
        (setq new (cond ((assoc (car tp) '(("GOFRA" . "в гофр. трубе") ("TRUBA" . "в трубе жёсткой")
                                           ("SKR" . "в гофр. трубе скрыто в штробе"))))))
        (cond
          ((and (= (car tp) "GOFZP") (not (bk:type-used "GOFZP"))) (setq ch T))
          (T (setq new (if new (bk:replace-nth 1 (cdr new) tp) (bk:replace-nth 1 (bk:lc1 (cadr tp)) tp)))
             (if (not (equal new tp)) (setq ch T))
             (setq *bk:tl* (cons new *bk:tl*)))))
      (setq l (reverse *bk:tl*) *bk:tl* nil)
      (if (not (assoc "STOYAK" l))
        (setq l (append l (list (assoc "STOYAK" *bk:types-default*))) ch T))
      (if (not (assoc "PERENOS" l))
        (setq l (append l (list (assoc "PERENOS" *bk:types-default*))) ch T))
      (if (not (assoc "TROSG" l))
        (setq l (append (reverse (cdr (reverse l))) (list (assoc "TROSG" *bk:types-default*)) (list (last l))) ch T))
      (setq *bk:types* l)
      (if ch (bk:save-types)))
    (setq *bk:types* *bk:types-default*)))
(defun bk:save-types ()
  (vlax-ldata-put "BK" "types" *bk:types*)
  ;; слои стояка / переноса - сразу в цвет из типов
  (foreach c '("STOYAK" "PERENOS")
    (if (tblsearch "LAYER" (if (= c "PERENOS") "_ПЕРЕНОС" "_СТОЯК")) (vl-catch-all-apply 'bk:stoyak-layer (list c)))))
(setq *bk:types* *bk:types-default*)

;;; ---------- справочник кабелей: внешний файл cable_type.csv ----------
;; Файл лежит в папке чертежа (или указывается один раз, путь запоминается в чертеже).
;; Колонки (по заголовку, порядок любой): тип;оболочка;проводник;номенклатура;сечение;диаметр_мм
;; Кодировка: UTF-8 с BOM (CSV UTF-8 из Excel) или Windows-1251. Разделитель ";".
;; Справочник хранится в чертеже (ldata "BK" "cat"); "Обновить" - дочитать файл:
;; новые номенклатуры добавляются, существующие обновляются, дублей нет.
;; строка справочника: (тип оболочка проводник сечение номенклатура диаметр)
(defun bk:cat () (vlax-ldata-get "BK" "cat"))

;; прочитать файл целиком через ADODB.Stream (1251 / UTF-8 по метке BOM); nil - не удалось
(defun bk:ado-read (fn / st txt r)
  (setq st (vl-catch-all-apply 'vlax-create-object (list "ADODB.Stream")))
  (if (and st (not (vl-catch-all-error-p st)))
    (progn
      (setq r (vl-catch-all-apply
                '(lambda ()
                   (vlax-put st 'Type 2) (vlax-put st 'Charset "windows-1251")
                   (vlax-invoke st 'Open) (vlax-invoke st 'LoadFromFile fn)
                   (setq txt (vlax-invoke st 'ReadText -1))
                   (if (= (substr txt 1 3) "п»ї")      ; метка UTF-8 (BOM) -> перечитать как UTF-8
                     (progn (vlax-put st 'Position 0) (vlax-put st 'Charset "utf-8")
                            (setq txt (vlax-invoke st 'ReadText -1))))
                   txt)))
      (vl-catch-all-apply 'vlax-invoke (list st 'Close))
      (vlax-release-object st)
      (if (vl-catch-all-error-p r) nil r))))

;; запасной путь: обычное чтение AutoLISP (с кодировкой UTF-8, если есть BOM)
(defun bk:lsp-read (fn / f l txt enc)
  (setq f (vl-catch-all-apply 'open (list fn "r")))
  (if (vl-catch-all-error-p f) (setq f nil))
  (if f
    (progn (setq l (read-line f)) (close f)
           (if (and l (= (substr l 1 3) "п»ї")) (setq enc "utf8"))
           (setq f (if enc (vl-catch-all-apply 'open (list fn "r" enc)) (open fn "r")))
           (if (and f (not (vl-catch-all-error-p f)))
             (progn (setq txt "")
                    (while (setq l (read-line f)) (setq txt (strcat txt l "\n")))
                    (close f)
                    (if (= (substr txt 1 3) "п»ї") (setq txt (substr txt 4)))
                    txt)))))

;; порядок: обычное чтение AutoLISP (UTF-8 по метке BOM) -> ADODB.Stream -> временная копия
(defun bk:read-text (fn / txt tmp)
  (setq fn (vl-string-translate "/" "\\" fn))
  (setq txt (bk:lsp-read fn))
  (if (null txt) (setq txt (bk:ado-read fn)))
  (if (null txt)
    (progn
      (setq tmp (vl-filename-mktemp "bk_cat.csv"))
      (if (vl-file-copy fn tmp) (setq txt (cond ((bk:lsp-read tmp)) ((bk:ado-read tmp)))))
      (vl-file-delete tmp)))
  (if (and txt (> (strlen txt) 0) (= (ascii txt) 65279)) (setq txt (substr txt 2)))
  (if (null txt)
    (alert (strcat "Не удаётся открыть файл:\n" fn
                   "\n\nПроверьте, что файл существует и не занят другой программой.")))
  txt)

(defun bk:csv-split (l sep / i r)
  (while (setq i (vl-string-search sep l)) (setq r (cons (substr l 1 i) r) l (substr l (+ i 1 (strlen sep)))))
  (mapcar '(lambda (x) (vl-string-trim " \t\"" x)) (reverse (cons l r))))

(defun bk:cat-parse (fn / txt lines i hdr ix rows f v)
  (setq txt (bk:read-text fn))
  (if txt
    (progn
      (while (setq i (vl-string-search "\n" txt))
        (setq lines (cons (vl-string-trim "\r" (substr txt 1 i)) lines) txt (substr txt (+ i 2))))
      (setq lines (vl-remove "" (reverse (cons (vl-string-trim "\r" txt) lines))))
      ;; индексы колонок по заголовку
      (setq hdr (mapcar 'bk:up (bk:csv-split (car lines) ";")))
      (defun ix (m d / j r) (setq j 0) (foreach h hdr (if (and (null r) (wcmatch h m)) (setq r j)) (setq j (1+ j))) (if r r d))
      (setq v (list (ix "ТИП*" 0) (ix "ОБОЛОЧ*" 1) (ix "ПРОВОДН*" 2) (ix "СЕЧЕН*,РАЗМЕР*" 4) (ix "НОМЕНКЛ*,МАРКА*" 3) (ix "ДИАМ*" 5)))
      (if (wcmatch (car hdr) "ТИП*,ОБОЛОЧ*,ПРОВОДН*,НОМЕНКЛ*") (setq lines (cdr lines)))
      (foreach l lines
        (setq f (bk:csv-split l ";"))
        (if (/= (setq f (mapcar '(lambda (k) (cond ((nth k f)) (""))) v)) nil)
          (if (/= (nth 4 f) "")
            (setq rows (cons (list (nth 0 f) (nth 1 f) (nth 2 f) (nth 3 f) (nth 4 f) (bk:num (nth 5 f))) rows)))))
      (reverse rows))))

(defun bk:cat-merge (rows / cat p add upd k)
  (setq cat (bk:cat) add 0 upd 0)
  (foreach r rows
    (setq k (bk:up (nth 4 r)))
    (if (setq p (vl-some '(lambda (x) (if (= (bk:up (nth 4 x)) k) x)) cat))
      (if (not (equal p r)) (setq cat (subst r p cat) upd (1+ upd)))
      (setq cat (append cat (list r)) add (1+ add))))
  (vlax-ldata-put "BK" "cat" cat)
  (list add upd))

(defun bk:cat-file (ask / fn)
  ;; сначала папка чертежа, затем запомненный путь (только строка - старые записи могли быть испорчены)
  (setq fn (cond ((findfile (strcat (getvar "DWGPREFIX") "cable_type.csv")))
                 ((and (= (type (vlax-ldata-get "BK" "catpath")) 'STR) (findfile (vlax-ldata-get "BK" "catpath")))
                  (findfile (vlax-ldata-get "BK" "catpath")))))
  (if (and (null fn) ask)
    (progn
      (alert "Файл cable_type.csv не найден в папке чертежа.\nУкажите его расположение.\n(Отмена - ввод кабеля вручную.)")
      (setq fn (getfiled "Справочник кабелей cable_type.csv" (getvar "DWGPREFIX") "csv" 0))))
  (if (= (type fn) 'STR) (vlax-ldata-put "BK" "catpath" fn) (setq fn nil))
  fn)

(defun bk:cat-update (ask / fn rows r)
  (if (setq fn (bk:cat-file ask))
    (progn
      (setq rows (bk:cat-parse fn) r (bk:cat-merge rows))
      (princ (strcat "\nСправочник кабелей: " fn "\n  строк в файле " (itoa (length rows)) ", добавлено " (itoa (car r))
                     ", обновлено " (itoa (cadr r)) ", всего в чертеже " (itoa (length (bk:cat))) "."))
      T)
    (progn (princ "\nСправочник кабелей не загружен - номенклатура и диаметр вводятся вручную.") nil)))

;; при первом открытии окна в сеансе, если справочника в чертеже нет
(defun bk:cat-ensure ()
  (if (and (null (bk:cat)) (not *bk:catask*)) (progn (setq *bk:catask* T) (bk:cat-update T))))

(defun bk:cat-row (nom / k) (setq k (bk:up nom)) (vl-some '(lambda (x) (if (= (bk:up (nth 4 x)) k) x)) (bk:cat)))

(if (not *bk:tol*) (setq *bk:tol* 200.0))          ; поиск прибора у конца кабеля, мм

;;; ---------- утилиты ----------
(defun bk:st (k v) (set_tile k (cond ((null v) "") ((numberp v) (rtos v 2 2)) (T v))))
(defun bk:num (s) (cond ((numberp s) s) (T (atof (vl-string-translate "," "." (if s s ""))))))
(defun bk:doc () (vla-get-ActiveDocument (vlax-get-acad-object)))
(defun bk:space () (vla-get-Block (vla-get-ActiveLayout (bk:doc))))
(defun bk:trim (s) (vl-string-trim " \t" (if s s "")))
(defun bk:type (c) (if (= c "_DASH") '("_DASH" "штриховая" "BK_DASH" nil 3.0 12.0) (assoc c *bk:types*)))
(defun bk:tname (c) (if (bk:type c) (cadr (bk:type c)) (if c c "")))
(defun bk:tidx (c) (cond ((vl-position c (mapcar 'car *bk:types*))) (0)))
(defun bk:2d (p) (list (car p) (cadr p)))
(defun bk:r (x n) (rtos (bk:num x) 2 n))
(defun bk:ss->l (ss / i l)
  (if ss (repeat (setq i (sslength ss)) (setq l (cons (ssname ss (setq i (1- i))) l))))
  l)
(defun bk:join (l sep / s) (setq s "") (foreach x l (setq s (if (= s "") x (strcat s sep x)))) s)
(defun bk:incr (s / i)                           ; ШС1 -> ШС2
  (setq i (strlen s))
  (while (and (> i 0) (wcmatch (substr s i 1) "#")) (setq i (1- i)))
  (if (= i (strlen s)) s (strcat (substr s 1 i) (itoa (1+ (atoi (substr s (1+ i))))))))
;; занятые позиции кабелей (без учёта регистра)
(defun bk:used-pos (/ l v)
  (foreach e (bk:all-segs)
    (setq v (strcase (bk:f (bk:get e) "pos")))
    (if (and (/= v "") (not (member v l))) (setq l (cons v l))))
  l)
;; следующая свободная позиция: последнее число +1, пока позиция занята
(defun bk:free-pos (s used / n)
  (if (null used) (setq used (bk:used-pos)))
  (setq s (if s s "") n 0)
  (while (and (member (strcase s) used) (< n 10000))
    (setq n (1+ n) s (if (= (bk:incr s) s) (strcat s "1") (bk:incr s))))
  s)
;; диаметр материала прокладки по умолчанию, мм
(setq *bk:mddef* '(("GOFRA" . 20) ("GOFZP" . 20) ("MR" . 15) ("TRUBA" . 20) ("POL" . 25) ("SKR" . 20) ("TROSG" . 20)))
(defun bk:mddef (code) (if (= (bk:type-mode code) "E") (cond ((cdr (assoc code *bk:mddef*))) (0)) 0))
;; диаметр материала вводится для всех способов, кроме общих для группы (лоток, короб)
(defun bk:md-on (code) (/= (bk:type-mode code) "O"))
(defun bk:ceil0 (x) (if (> x (fix x)) (1+ (fix x)) (fix x)))   ; вверх до целого метра
(defun bk:plen (pts / l)
  (setq l 0.0)
  (while (cdr pts) (setq l (+ l (distance (car pts) (cadr pts))) pts (cdr pts)))
  l)
;; установить n-й элемент, дополнив список nil при необходимости
(defun bk:pset (l n v) (while (<= (length l) n) (setq l (append l (list nil)))) (bk:replace-nth n v l))
(defun bk:replace-nth (n v l / i)
  (setq i -1)
  (mapcar '(lambda (x) (if (= (setq i (1+ i)) n) v x)) l))
(defun bk:layers (/ l)
  (vlax-for y (vla-get-Layers (bk:doc)) (setq l (cons (vla-get-Name y) l)))
  (vl-sort l '<))
(defun bk:marka-diam (m / r)                     ; диаметр по номенклатуре из справочника
  (if (setq r (bk:cat-row m)) (nth 5 r)))

(defun bk:open-dcl (fn / f)
  ;; кодировка DCL по LISPSYS: 1 - UTF-8 с BOM, 0 - ANSI
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0))
    (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  f)

(defun bk:write-dcl (name lines / fn f)
  (setq fn (vl-filename-mktemp name) f (bk:open-dcl fn))
  (foreach l lines (write-line l f))
  (close f)
  fn)

(defun bk:write-1251 (fn txt / st r)   ; .lin в кодировке 1251 через ADODB.Stream; T - записан
  (setq st (vl-catch-all-apply 'vlax-create-object (list "ADODB.Stream")))
  (if (and st (not (vl-catch-all-error-p st)))
    (progn
      (setq r (vl-catch-all-apply
                '(lambda () (vlax-put st 'Type 2) (vlax-put st 'Charset "windows-1251")
                            (vlax-invoke st 'Open) (vlax-invoke st 'WriteText txt)
                            (vlax-invoke st 'SaveToFile fn 2) T)))
      (vl-catch-all-apply 'vlax-invoke (list st 'Close))
      (vlax-release-object st)
      (and r (not (vl-catch-all-error-p r))))))

;;; ---------- типы линий ----------
;; режим линий: nil - по типам прокладки, "C" - все сплошные, "D" - все штриховые (хранится в чертеже)
(defun bk:plain () (vlax-ldata-get "BK" "plain"))
;; цвет линий кабелей: nil - как есть (цвет участка сохраняется), "L" - по слою, "T" - по типу прокладки
;; режим цвета линий: "T" - по типам (по умолчанию: цвет линии = цвет в ММ_КАБЕЛЬ_ТИПЫ), "L" - по слою
(defun bk:pcolor () (cond ((vlax-ldata-get "BK" "pcolor")) ("T")))
(setq *bk:tcol-def* '(("STOYAK" . 51) ("PERENOS" . 71) ("GOFRA" . 5) ("LOTOK" . 1) ("KOROB" . 3) ("TRUBA" . 6) ("POL" . 30) ("MR" . 4)
                      ("SKR" . 140) ("TROS" . 40) ("TROSG" . 200) ("OTKR" . 8) ("GOFZP" . 150)))
(defun bk:tcolor (code / p)
  (cond ((and (setq p (bk:type code)) (numberp (nth 8 p)) (> (nth 8 p) 0)
              ;; у стояка/переноса прежние версии сохраняли 7 (белый) - это не выбор пользователя
              (not (and (bk:stc code) (= (nth 8 p) 7))))
         (nth 8 p))
        ((cdr (assoc code *bk:tcol-def*))) (7)))
;; применить режим цвета к участку (стояк - всегда по своему слою)
(defun bk:seg-color (e code)
  ;; стояк / перенос: свой слой (цвет слоя = цвет типа), линия - тем же цветом
  (if (bk:stc code) (vla-put-Layer (vlax-ename->vla-object e) (bk:stoyak-layer code)))
  ;; цвет задаётся по номеру; цвет RGB / из альбома (420/430), унаследованный от старой линии, убирается
  (bk:no-truecolor e)
  (cond ((= (bk:pcolor) "T") (vla-put-Color (vlax-ename->vla-object e) (bk:tcolor code)))
        ((= (bk:pcolor) "L") (vla-put-Color (vlax-ename->vla-object e) 256))))
(defun bk:no-truecolor (e / ed)
  (setq ed (entget e))
  (if (or (assoc 420 ed) (assoc 430 ed))
    (entmod (vl-remove-if '(lambda (x) (member (car x) '(420 430))) ed))))
(defun bk:load-lt (code / p txt fn gap)
  (if (bk:stc code) (setq code "_DASH"))        ; стояк - всегда штриховая
  (setq p (bk:type code) txt (nth 3 p))
  (cond
    ((and (= (bk:plain) "C") (/= code "_DASH")) "Continuous")
    ((and (= (bk:plain) "D") (/= code "_DASH")) (bk:load-lt "_DASH"))
    ((or (null p) (= txt "-")) "Continuous")
    ((tblsearch "LTYPE" (nth 2 p)) (nth 2 p))
    (T
      (if (not (tblsearch "STYLE" "BK_LT"))
        (vl-catch-all-apply 'vla-put-FontFile
          (list (vla-Add (vla-get-TextStyles (bk:doc)) "BK_LT") "arial.ttf")))
      ;; каждый раз новый временный файл: прежний .lin может быть ещё занят AutoCAD
      (setq fn (vl-filename-mktemp "bk" (getvar "TEMPPREFIX") ".lin"))
      (bk:write-1251 fn
        (strcat "*" (nth 2 p) "," (nth 1 p) "\r\n"
          (if txt
            (progn (setq gap (+ 1.5 (* 1.9 (strlen txt))))
                   (strcat "A," (rtos (if (nth 5 p) (nth 5 p) 12.0) 2 1)
                           ",-1,[\"" txt "\",BK_LT,S=2.5,U=0.0,X=0.0,Y=-1.25],-" (rtos gap 2 1) "\r\n"))
            (strcat "A," (rtos (if (nth 5 p) (* 0.5 (nth 5 p)) 6.0) 2 1) ",-3\r\n"))))
      (vl-catch-all-apply 'vla-Load (list (vla-get-Linetypes (bk:doc)) (nth 2 p) fn))
      (vl-file-delete fn)
      (if (tblsearch "LTYPE" (nth 2 p)) (nth 2 p) "Continuous"))))

;;; ---------- данные участка: XDATA "BK", записи "ключ=значение" ----------
;; кабель: id marka diam pos beg end ld layer lts bcode bk ecode ek
;; участок: code h k tcode tk ord sz(размер лотка/короба "ШxВ")   (tcode/tk - переход по высоте перед участком)
(setq *bk:keys* '("id" "marka" "diam" "pos" "floor" "beg" "end" "ld" "layer" "lts"
                  "bcode" "bk" "ecode" "ek" "bfix" "efix" "bh" "eh" "bmd" "emd" "md" "tmd" "sz" "slen" "sflm" "sfl" "ex" "bex" "eex" "floors" "et" "eu" "ei" "ep" "ecos" "edu" "esec" "emat" "sp" "code" "h" "k" "tcode" "tk" "ord" "par" "lin"))

(defun bk:get (e / x d i s)
  (if (and e (entget e) (setq x (assoc -3 (entget e '("BK")))))
    (progn
      (foreach p (cdr (cadr x))
        (if (and (= (car p) 1000) (setq i (vl-string-search "=" (cdr p))))
          (setq d (cons (cons (substr (cdr p) 1 i) (substr (cdr p) (+ i 2))) d))))
      (foreach k *bk:keys* (if (not (assoc k d)) (setq d (cons (cons k "") d))))
      d)))

(defun bk:f (d k) (cond ((cdr (assoc k d))) ("")))
(defun bk:fn (d k) (bk:num (bk:f d k)))
(defun bk:setf (d k v)
  (setq v (cond ((null v) "") ((numberp v) (rtos v 2 4)) (T v)))
  (if (assoc k d) (subst (cons k v) (assoc k d) d) (cons (cons k v) d)))

(defun bk:put (e d)
  (regapp "BK")
  (entmod (append (entget e)
    (list (list -3 (cons "BK" (mapcar '(lambda (k) (cons 1000 (strcat k "=" (bk:f d k)))) *bk:keys*)))))))

(defun bk:all-segs () (bk:ss->l (ssget "_X" '((-3 ("BK"))))))

;; участки кабеля: быстро - через его группу (индекс id -> хэндл участка), иначе полный перебор
(defun bk:segs-sort (l) (vl-sort l '(lambda (a b) (< (bk:fn (bk:get a) "ord") (bk:fn (bk:get b) "ord")))))
(defun bk:segs-grp (e id / g l x)
  (if (setq g (bk:group-of e))
    (foreach p (entget g)
      (if (and (= (car p) 340) (setq x (cdr p)) (entget x) (assoc -3 (entget x '("BK"))) (= (bk:f (bk:get x) "id") id))
        (setq l (cons x l)))))
  (if l (bk:segs-sort l)))
(defun bk:segs (id / h e r)
  (if (and (setq h (cdr (assoc id *bk:sidx*))) (setq e (handent h)) (entget e)
           (assoc -3 (entget e '("BK"))) (= (bk:f (bk:get e) "id") id) (setq r (bk:segs-grp e id)))
    r
    (progn
      (setq r (bk:segs-sort (vl-remove-if-not '(lambda (e) (= (bk:f (bk:get e) "id") id)) (bk:all-segs))))
      (if r (setq *bk:sidx* (cons (cons id (cdr (assoc 5 (entget (car r))))) (vl-remove (assoc id *bk:sidx*) *bk:sidx*))))
      r)))

(defun bk:pts (e / c l z n)
  ;; координаты LWPOLYLINE - в её ОСК; если полилиния отражена/повёрнута (нормаль не 0,0,1) - перевод в МСК
  (setq c (vlax-get (vlax-ename->vla-object e) 'Coordinates)
        n (cdr (assoc 210 (entget e))) z (cond ((cdr (assoc 38 (entget e)))) (0.0)))
  (if (or (null n) (equal n '(0.0 0.0 1.0) 1e-9))
    (while c (setq l (cons (list (car c) (cadr c)) l) c (cddr c)))
    (while c (setq l (cons (bk:2d (trans (list (car c) (cadr c) z) e 0)) l) c (cddr c))))
  (reverse l))

;; выбор кабелей: щелчок в точку -> все кабели в этой точке (в т.ч. наложенные),
;; при нескольких - окно выбора; [Рамка] - обычный выбор рамкой/щелчками.
(defun bk:pick-ids (msg / p ids id)
  (initget "Рамка")
  (setq p (getpoint (strcat msg "\nЩёлкните по кабелю (наложенные - покажу списком) или [Рамка] <Рамка>: ")))
  (cond
    ((listp p)
     (if p
       (progn
         (setq ids (bk:cables-at (trans p 1 0)))
         (cond ((null ids) (princ "\nВ этой точке нет кабелей.") nil)
               ((null (cdr ids)) ids)
               (T (bk:choose ids))))))
    (T
     (princ "\nВыберите кабели рамкой или щелчками: ")
     (foreach e (bk:ss->l (ssget '((-3 ("BK")))))
       (if (not (member (setq id (bk:f (bk:get e) "id")) ids)) (setq ids (cons id ids))))
     (reverse ids))))

;; кабели, проходящие через точку p (в пределах прицела)
(defun bk:cables-at (p / tol ids d o q)
  (setq tol (* 1.5 (getvar "PICKBOX") (/ (getvar "VIEWSIZE") (cadr (getvar "SCREENSIZE")))))
  (foreach e (bk:segs-near p tol)
    (setq o (vlax-ename->vla-object e)
          q (vlax-curve-getClosestPointToProjection o (list (car p) (cadr p) 0.0) '(0.0 0.0 1.0)))
    (if (and (<= (distance (bk:2d q) (bk:2d p)) tol)
             (not (member (setq d (bk:f (bk:get e) "id")) ids)))
      (setq ids (cons d ids))))
  (reverse ids))

;; окно выбора из наложенных кабелей
;; ПОЗИЦИЯ / этаж блока по handle для окна выбора кабеля
(defun bk:ch-dev (h) (if (and h (/= h "") (bk:hent h)) (bk:cut (bk:dev-pos h) 16) "-"))
(defun bk:ch-flr (h / s) (if (and h (/= h "") (bk:hent h) (/= (setq s (bk:attr (bk:hent h) "ЭТАЖ")) "")) (bk:cut s 9) "-"))
(defun bk:choose (ids / fn id res sel out map rows)
  (setq map (bk:cable-map))
  (setq rows (mapcar '(lambda (i / d) (setq d (cadr (assoc i map)))
                        (list i (bk:f d "pos") (bk:ch-dev (bk:f d "beg")) (bk:ch-flr (bk:f d "beg")) (bk:ch-dev (bk:f d "end")) (bk:ch-flr (bk:f d "end"))))
                     ids))
  (setq fn (bk:write-dcl "blok_kabel_choose.dcl"
             '("bk_ch : dialog { label = \"Кабели в этой точке\";"
               " : list_box { key = \"hdr\"; height = 2; width = 80; tabs = \"14 32 46 64\"; is_tab_stop = false; }"
               " : list_box { key = \"lst\"; multiple_select = true; height = 10; width = 80; tabs = \"14 32 46 64\"; }"
               " : row { : button { key = \"b_all\"; label = \"Выделить все\"; }"
               "         : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 14; }"
               "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }"))
        id (load_dialog fn))
  (if (new_dialog "bk_ch" id)
    (progn
      (start_list "hdr") (add_list "Позиция\tНачало\tЭтаж нач.\tКонец\tЭтаж кон.") (end_list)
      (start_list "lst")
      (foreach r rows (add_list (strcat (bk:cut (nth 1 r) 12) "\t" (nth 2 r) "\t" (nth 3 r) "\t" (nth 4 r) "\t" (nth 5 r))))
      (end_list)
      (bk:st "lst" "0")
      (action_tile "b_all" "(setq sel \"\") (repeat (length ids) (setq sel (strcat sel (itoa (length (bk:idxs sel))) \" \"))) (bk:st \"lst\" sel)")
      (action_tile "lst" "(if (= $reason 4) (progn (setq out (get_tile \"lst\")) (done_dialog 1)))")
      (action_tile "accept" "(setq out (get_tile \"lst\")) (done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)))
  (vl-file-delete fn)
  (if (= res 1) (mapcar '(lambda (i) (nth i ids)) (bk:idxs out))))

;; участок: (код высота точки коэф ename код_перехода коэф_перехода оформление диаметр_материала диаметр_перехода размер)
(defun bk:parts (id)
  (mapcar '(lambda (e / d) (setq d (bk:get e))
             (list (bk:f d "code") (bk:fn d "h") (bk:pts e) (bk:fn d "k") e (bk:f d "tcode") (bk:fn d "tk") (bk:look e)
                   (bk:fn d "md") (bk:fn d "tmd") (bk:f d "sz") (bk:fn d "slen") (bk:f d "sflm") (bk:f d "sfl") (bk:f d "ex")))
          (bk:segs id)))
(defun bk:pt (p n) (nth n p))

;;; ---------- приборы у концов ----------
(defun bk:attr (e tag / r)
  (if (and e (entget e) (= (cdr (assoc 0 (entget e))) "INSERT"))
    (foreach a (vlax-invoke (vlax-ename->vla-object e) 'GetAttributes)
      (if (= (strcase (vla-get-TagString a)) tag) (setq r (vla-get-TextString a)))))
  (if r r ""))

(setq *bk:brad* 10000.0)                            ; радиус поиска блока у точки (по точке вставки)
(defun bk:block-at (p / best bd o mn mx d r)
  (setq r *bk:brad*)
  (foreach e (bk:ss->l (ssget "_X" (list '(0 . "INSERT") '(66 . 1) (cons 410 (getvar "CTAB"))
                                          '(-4 . ">,>,*") (list 10 (- (car p) r) (- (cadr p) r) 0.0)
                                          '(-4 . "<,<,*") (list 10 (+ (car p) r) (+ (cadr p) r) 0.0))))
    (setq o (vlax-ename->vla-object e))
    (vla-GetBoundingBox o 'mn 'mx)
    (setq mn (vlax-safearray->list mn) mx (vlax-safearray->list mx))
    (if (and (<= (- (car mn) *bk:tol*) (car p) (+ (car mx) *bk:tol*))
             (<= (- (cadr mn) *bk:tol*) (cadr p) (+ (cadr mx) *bk:tol*)))
      (progn
        (setq d (distance (bk:2d p) (bk:2d (cdr (assoc 10 (entget e))))))
        (if (or (null bd) (< d bd)) (setq bd d best e)))))
  (if best (cdr (assoc 5 (entget best))) ""))

(defun bk:hent (h) (if (and h (/= h "")) (handent h)))
(defun bk:dev-h (h / s) (setq s (bk:attr (bk:hent h) "ВЫСОТА")) (if (/= s "") (bk:num s)))
(defun bk:dev-room (h) (bk:attr (bk:hent h) "ПОМЕЩЕНИЕ"))   ; помещение прибора, "" - нет
(defun bk:dev-pos (h / s) (setq s (bk:attr (bk:hent h) "ПОЗИЦИЯ")) (if (/= s "") s "-"))

;;; ---------- оформление участка: цвет, вес линии, глобальная ширина ----------
(defun bk:look (e)
  (if (and e (entget e))
    (vl-remove-if-not '(lambda (p) (member (car p) '(62 420 430 370 43))) (entget e))))

(defun bk:apply-look (e look / ed)
  (if look
    (progn
      (setq ed (entget e))
      (foreach p look
        (setq ed (if (assoc (car p) ed)
                   (subst p (assoc (car p) ed) ed)
                   ;; вставить сразу после слоя (группа 8), как у AutoCAD
                   (apply 'append (mapcar '(lambda (x) (if (= (car x) 8) (list x p) (list x))) ed)))))
      (entmod ed))))

;;; ---------- пересборка кабеля ----------
(defun bk:group-of (e / g)
  (foreach p (entget e)
    (if (and (= (car p) 330) (entget (cdr p)) (= (cdr (assoc 0 (entget (cdr p)))) "GROUP"))
      (setq g (cdr p))))
  g)

;; d - данные кабеля; parts - участки (код высота точки коэф ename tcode tk)
(defun bk:rebuild (d parts / g m out ss e i o prev b fls ss2 fu)
  (setq parts (vl-remove-if '(lambda (p) (or (< (length (caddr p)) 2) (< (bk:plen (caddr p)) 1e-6))) parts))
  (foreach p parts                                 ; сшить стыки
    (if prev (setq p (bk:replace-nth 2 (cons (last prev) (cdr (caddr p))) p)))
    (setq prev (caddr p) out (cons p out)))
  (setq parts (reverse out) out nil)
  (foreach p parts                                 ; слить одинаковые соседние
    (if (and out (= (car (car out)) (car p))
             (equal (cadr (car out)) (cadr p) 1e-6) (equal (cadddr (car out)) (cadddr p) 1e-6)
             (equal (bk:num (nth 8 (car out))) (bk:num (nth 8 p)) 1e-6)
             (= (bk:sz (car out)) (bk:sz p))
             (equal (bk:slen (car out)) (bk:slen p) 1e-6) (= (bk:sflm (car out)) (bk:sflm p)) (= (bk:ex (car out)) (bk:ex p))
             (not (bk:stc (car p))))
      (setq out (cons (bk:replace-nth 2 (append (caddr (car out)) (cdr (caddr p))) (car out)) (cdr out)))
      (setq out (cons p out))))
  (setq out (reverse out))
  (if out
    (progn
      ;; приборы у концов ищутся сами, если привязка не задана вручную
      (if (and (/= (bk:f d "bfix") "1") (/= (setq b (bk:block-at (car (caddr (car out))))) ""))
        (setq d (bk:setf d "beg" b)))
      (if (and (/= (bk:f d "efix") "1") (/= (setq b (bk:block-at (last (caddr (last out))))) ""))
        (setq d (bk:setf d "end" b)))))
  (foreach e (bk:segs (bk:f d "id"))
    (if (setq g (bk:group-of e)) (vl-catch-all-apply 'vla-Delete (list (vlax-ename->vla-object g))))
    (entdel e))
  (if (not (tblsearch "LAYER" (bk:f d "layer"))) (vla-Add (vla-get-Layers (bk:doc)) (bk:f d "layer")))
  ;; этажи участков и этажи кабеля (через запятую)
  (setq fls (bk:floors d out))
  (foreach f fls (if (and (/= f "") (not (member f fu))) (setq fu (append fu (list f)))))
  (setq d (bk:setf d "floors" (bk:join fu ", ")))
  (setq ss (ssadd) ss2 (ssadd) i 0)
  (foreach p out
    (setq o (vlax-invoke (bk:space) 'AddLightWeightPolyline (apply 'append (caddr p))))
    (vla-put-Layer o (if (bk:stc (car p)) (bk:stoyak-layer (car p)) (bk:f d "layer")))
    (vla-put-Linetype o (if (bk:stc (car p)) (bk:load-lt "_DASH") (bk:load-lt (car p))))
    (vla-put-LinetypeScale o (max 0.001 (bk:fn d "lts")))
    (setq e (vlax-vla-object->ename o))
    (if (bk:stc (car p))
      (ssadd e ss2)                                ; стояк: на задний план, печать - по слою
      (bk:apply-look e (nth 7 p)))                 ; вес, ширина - как были
    ;; цвет - всегда по текущему режиму (по типам / по слою), в т.ч. у стояков и переносов
    (bk:seg-color e (car p))
    (bk:put e (bk:setf (bk:setf (bk:setf (bk:setf (bk:setf (bk:setf d
                "code" (car p)) "h" (cadr p)) "k" (cadddr p))
                "tcode" (if (nth 5 p) (nth 5 p) "")) "tk" (if (nth 6 p) (nth 6 p) 0.0)) "ord" i))
    (bk:put e (bk:setf (bk:setf (bk:setf (bk:setf (bk:setf (bk:setf (bk:get e) "md" (bk:num (nth 8 p))) "tmd" (bk:num (nth 9 p)))
                "sz" (bk:sz p)) "slen" (bk:slen p)) "sflm" (bk:sflm p)) "sfl" (nth i fls)))
    (bk:put e (bk:setf (bk:get e) "ex" (bk:ex p)))
    (ssadd e ss)
    (setq i (1+ i)))
  (if (> (sslength ss) 0)                          ; безымянная группа
    (progn
      (setq m (getvar "CMDECHO"))
      (setvar "CMDECHO" 0)
      (command "_.-GROUP" "_C" "*" "" ss "")
      (if (> (sslength ss2) 0) (command "_.DRAWORDER" ss2 "" "_B"))
      (setvar "CMDECHO" m)))
  (vl-catch-all-apply 'bk:end-label (list (bk:f d "id")))
  d)

;;; ---------- подпись ПОЗИЦИИ кабеля в его конце (слой КАБЕЛИ_ПОЗ, не печатается) ----------
;; текст с XDATA "BK_EL" = id кабеля; высота = высота атрибута ПОЗИЦИЯ блока конца / 5
(setq *bk:el-layer* "КАБЕЛИ_ПОЗ")
(defun bk:el-texts (id / l)
  (foreach e (bk:ss->l (ssget "_X" '((0 . "TEXT") (-3 ("BK_EL")))))
    (if (or (null id) (= (cdr (cadr (cadr (assoc -3 (entget e '("BK_EL")))))) id)) (setq l (cons e l))))
  l)
(defun bk:pos-att-h (h / e r)
  (if (and (setq e (bk:hent h)) (entget e) (= (cdr (assoc 0 (entget e))) "INSERT"))
    (foreach a (vlax-invoke (vlax-ename->vla-object e) 'GetAttributes)
      (if (= (strcase (vla-get-TagString a)) "ПОЗИЦИЯ") (setq r (vla-get-Height a)))))
  r)
(defun bk:el-layer (/ l)
  (if (not (tblsearch "LAYER" *bk:el-layer*))
    (progn (setq l (vla-Add (vla-get-Layers (bk:doc)) *bk:el-layer*))
           (vla-put-Color l 5) (vla-put-Plottable l :vlax-false)))
  *bk:el-layer*)
(defun bk:end-label (id / segs d pt h ah o n e)
  (foreach e (bk:el-texts id) (entdel e))
  (if (and id (setq segs (bk:segs id)))
    (progn
      (setq d (bk:get (car segs)) pt (last (bk:pts (last segs)))
            ah (bk:pos-att-h (bk:f d "end"))
            h (if (and ah (> ah 0)) (/ ah 5.0) (/ (max 1.0 (getvar "TEXTSIZE")) 5.0)))
      ;; несколько кабелей в одном конце - подписи друг над другом
      (setq n 0)
      (foreach e (bk:el-texts nil)
        (if (< (distance (bk:2d (cdr (assoc 11 (entget e)))) (bk:2d pt)) (* 0.5 h)) (setq n (1+ n))))
      (setq o (vla-AddText (bk:space) (bk:f d "pos")
                           (vlax-3d-point (list (car pt) (+ (cadr pt) (* 0.4 h) (* n 1.6 h)) 0.0)) h))
      (vla-put-Alignment o acAlignmentBottomCenter)
      (vla-put-TextAlignmentPoint o (vlax-3d-point (list (car pt) (+ (cadr pt) (* 0.4 h) (* n 1.6 h)) 0.0)))
      (vla-put-Layer o (bk:el-layer))
      (regapp "BK_EL")
      (setq e (vlax-vla-object->ename o))
      (entmod (append (entget e) (list (list -3 (list "BK_EL" (cons 1000 id)))))))))
;; пересоздать подписи всех кабелей (и удалить подписи удалённых)
(defun bk:end-labels-all (/ ids)
  (foreach e (bk:el-texts nil) (entdel e))
  (foreach s (bk:all-segs) (if (not (member (bk:f (bk:get s) "id") ids)) (setq ids (cons (bk:f (bk:get s) "id") ids))))
  (foreach id ids (vl-catch-all-apply 'bk:end-label (list id)))
  (length ids))

(defun bk:sz (p) (if (nth 10 p) (nth 10 p) ""))   ; размер лотка/короба участка
(defun bk:slen (p) (bk:num (nth 11 p)))             ; длина участка вручную, м (0 - по чертежу)
(defun bk:ex (p) (if (= (nth 14 p) "1") "1" ""))    ; "1" - существующая трасса (материал прокладки не считается)
(defun bk:sflm (p) (if (nth 12 p) (nth 12 p) ""))  ; этаж участка вручную ("" - авто)
(defun bk:sfl (p) (cond ((/= (bk:sflm p) "") (bk:sflm p)) ((nth 13 p)) ("")))  ; этаж участка
;; длина участка, м: вручную; стояк по умолчанию 5 м; иначе по чертежу
(defun bk:plen-m (p)
  (cond ((> (bk:slen p) 0) (bk:slen p)) ((= (car p) "PERENOS") 0.0) ((bk:stc (car p)) *bk:stoyak-len*) (T (/ (bk:plen (caddr p)) 1000.0))))
(if (not *bk:stoyak-len*) (setq *bk:stoyak-len* 5.0))

;; внутренний диаметр трубы по номинальному (наружному), мм - типовые значения, уточняйте по каталогу
(setq *bk:dint*
  '(("GOFRA" (16 . 10.7) (20 . 14.1) (25 . 18.3) (32 . 24.3) (40 . 31.2) (50 . 39.6) (63 . 50.6))
    ("TRUBA" (16 . 13.6) (20 . 17.0) (25 . 21.4) (32 . 27.8) (40 . 35.2) (50 . 44.4) (63 . 57.0))
    ("MR"    (10 . 10.0) (12 . 12.0) (15 . 15.0) (20 . 20.0) (25 . 25.0) (32 . 32.0) (38 . 38.0))))
(setq *bk:dint-alias* '(("SKR" . "GOFRA") ("TROSG" . "GOFRA") ("GOFZP" . "GOFRA") ("POL" . "TRUBA")))
(defun bk:din (code md / g x)
  (setq g (cond ((cdr (assoc code *bk:dint-alias*))) (code)) x (cdr (assoc md (cdr (assoc g *bk:dint*)))))
  (cond ((null md) 0.0) (x x) ((= g "GOFRA") (* 0.7 md)) ((= g "TRUBA") (* 0.85 md)) (T md)))
;; заполнение трубы, %: кабели (список диаметров) в трубе с номинальным d
(defun bk:tube-fill (code md ds / di)
  (setq di (bk:din code md))
  (if (> di 0) (* 100.0 (/ (apply '+ (mapcar 'bk:csec ds)) (bk:csec di))) 0.0))
;; подобрать трубу: наименьший номинал, где заполнение не больше допустимого
(defun bk:tube-pick (code ds / g f r)
  (setq g (cond ((cdr (assoc code *bk:dint-alias*))) (code)) f (bk:type-fill code))
  (foreach x (reverse (cdr (assoc g *bk:dint*))) (if (<= (bk:tube-fill code (car x) ds) f) (setq r (car x))))
  r)
;; этаж кабеля для таблиц: этажи участков через запятую, иначе этаж по умолчанию
(defun bk:cfloor (d) (if (/= (bk:f d "floors") "") (bk:f d "floors") (bk:f d "floor")))

;;; ---------- этажи участков и стояки ----------
;; этаж блока в точке (атрибут ЭТАЖ), "" - нет
(defun bk:blk-floor (pt / h) (setq h (bk:block-at pt)) (if (/= h "") (bk:attr (bk:hent h) "ЭТАЖ") ""))
;; этажи участков out (авто): до стояка - ЭТАЖ блока-стояка в начале участка "стояк";
;; после стояка - ЭТАЖ блока-стояка в его конце; нет стояков/блоков - ЭТАЖ блока "откуда"
;; (после последнего стояка без блока - блока "куда"); стояк - "1-3"; ручной этаж участка - главнее
(defun bk:floors (d out / st i fb fe nx pv res s)
  (setq fb (bk:attr (bk:hent (bk:f d "beg")) "ЭТАЖ") fe (bk:attr (bk:hent (bk:f d "end")) "ЭТАЖ"))
  (if (= fb "") (setq fb (bk:f d "floor")))
  (if (= fe "") (setq fe fb))
  (setq i 0)
  (foreach p out
    (if (bk:stc (car p))
      (setq st (append st (list (list i (bk:blk-floor (car (caddr p))) (bk:blk-floor (last (caddr p))))))))
    (setq i (1+ i)))
  (setq i 0)
  (foreach p out
    (setq nx (vl-some '(lambda (x) (if (> (car x) i) x)) st)
          pv (vl-some '(lambda (x) (if (< (car x) i) x)) (reverse st)))
    (setq res (append res
                (list (cond ((/= (bk:sflm p) "") (bk:sflm p))
                            ((setq s (assoc i st)) (bk:join (vl-remove "" (list (cadr s) (caddr s))) "-"))
                            ((and nx (/= (cadr nx) "")) (cadr nx))
                            ((and pv (/= (caddr pv) "")) (caddr pv))
                            (pv fe)
                            (T fb))))
          i (1+ i)))
  res)

;; слой стояков: непечатаемый, бледно-жёлтый
;; слой участка-перехода: стояк - бледно-жёлтый, перенос на др. лист - бледно-зелёный; не печатаются
(defun bk:stoyak-layer (code / l nm)
  (setq nm (if (= code "PERENOS") "_ПЕРЕНОС" "_СТОЯК"))
  (if (not (tblsearch "LAYER" nm))
    (progn (setq l (vla-Add (vla-get-Layers (bk:doc)) nm))
           (vla-put-Plottable l :vlax-false)))
  ;; цвет слоя = цвет способа в ММ_КАБЕЛЬ_ТИПЫ (по умолчанию стояк 51, перенос 71)
  (vl-catch-all-apply 'vla-put-Color (list (vla-Item (vla-get-Layers (bk:doc)) nm) (bk:tcolor code)))
  nm)

(defun bk:sub (e a b / o l i)
  (setq o (vlax-ename->vla-object e) l (list (bk:2d (vlax-curve-getPointAtParam o a))) i (1+ (fix a)))
  (while (< i b) (setq l (cons (bk:2d (vlax-curve-getPointAtParam o i)) l) i (1+ i)))
  (reverse (cons (bk:2d (vlax-curve-getPointAtParam o b)) l)))

;;; ---------- расчёт длин ----------
;; строка: (вид название высота длина_м коэф код номер_участка длина_с_запасом)
;; вид: "B" опуск в начале, "E" опуск в конце, "T" переход, "S" участок
;; диаметр трубы кабеля по умолчанию (опуски, переходы): наименьший из заданных на участках, иначе 20
(defun bk:cab-md (parts / m)
  (foreach p parts (if (and (bk:md-on (car p)) (> (bk:num (nth 8 p)) 0)) (setq m (if m (min m (bk:num (nth 8 p))) (bk:num (nth 8 p))))))
  (if m m 20.0))

(defun bk:calc (d parts / rows prev hb he n c k dm bc ec)
  (setq n 0 dm (bk:cab-md parts)
        ;; опуски по умолчанию - в гофр. трубе
        bc (if (/= (bk:f d "bcode") "") (bk:f d "bcode") "GOFRA")
        ec (if (/= (bk:f d "ecode") "") (bk:f d "ecode") "GOFRA"))
  ;; высота прибора: введённая вручную (bh/eh) или атрибут ВЫСОТА блока
  (setq hb (if (/= (bk:f d "bh") "") (bk:fn d "bh") (bk:dev-h (bk:f d "beg")))
        he (if (/= (bk:f d "eh") "") (bk:fn d "eh") (bk:dev-h (bk:f d "end"))))
  (if (and parts (/= (bk:f d "beg") ""))
    (setq rows (list (list "B" (strcat "Опуск к " (bk:dev-pos (bk:f d "beg")) (if hb "" " (нет высоты)"))
                           (if hb hb 0.0)
                           (if hb (abs (- (cadr (car parts)) hb)) 0.0)
                           (if (> (bk:fn d "bk") 0) (bk:fn d "bk") (cadddr (car parts)))
                           bc nil
                           (if (bk:md-on bc) (if (> (bk:fn d "bmd") 0) (bk:fn d "bmd") dm) 0.0)
                           "" (bk:sfl (car parts)) (if (= (bk:f d "bex") "1") "1" "")))))
  (foreach p parts
    (setq n (1+ n))
    (if (and prev (not (equal (cadr prev) (cadr p) 1e-6)) (not (bk:stc (car prev))) (not (bk:stc (car p))))
      (setq rows (append rows (list (list "T" "Переход по высоте" nil (abs (- (cadr prev) (cadr p)))
                                          (if (> (bk:num (nth 6 p)) 0) (bk:num (nth 6 p)) (cadddr p))
                                          (setq c (if (/= (nth 5 p) "") (nth 5 p) "GOFRA")) n
                                          (if (bk:md-on c) (if (> (bk:num (nth 9 p)) 0) (bk:num (nth 9 p)) dm) 0.0) "" (bk:sfl p))))))
    (setq rows (append rows (list (list "S" (strcat (itoa n) ". участок") (cadr p)
                                        (bk:plen-m p) (cadddr p) (car p) n
                                        (bk:md-of (bk:num (nth 8 p)) (car p) nil) (bk:sz p) (bk:sfl p) (bk:ex p))))
          prev p))
  (if (and parts (/= (bk:f d "end") ""))
    (setq rows (append rows (list (list "E" (strcat "Опуск к " (bk:dev-pos (bk:f d "end")) (if he "" " (нет высоты)"))
                                        (if he he 0.0)
                                        (if he (abs (- (cadr (last parts)) he)) 0.0)
                                        (if (> (bk:fn d "ek") 0) (bk:fn d "ek") (cadddr (last parts)))
                                        ec nil
                                        (if (bk:md-on ec) (if (> (bk:fn d "emd") 0) (bk:fn d "emd") dm) 0.0)
                                        "" (bk:sfl (last parts)) (if (= (bk:f d "eex") "1") "1" ""))))))
  ;; строка: вид название высота длина коэф код участок С_ЗАПАСОМ диаметр_материала размер этаж
  (mapcar '(lambda (r) (list (nth 0 r) (nth 1 r) (nth 2 r) (nth 3 r) (nth 4 r) (nth 5 r) (nth 6 r)
                             (* (nth 3 r) (nth 4 r)) (nth 7 r) (if (nth 8 r) (nth 8 r) "") (if (nth 9 r) (nth 9 r) "") (if (nth 10 r) (nth 10 r) "")))
          rows))

;; диаметр материала: заданный, иначе как у соседнего участка того же способа, иначе по умолчанию
(defun bk:md-of (md code nb)
  (cond ((> md 0) md)
        ((and nb (= (car nb) code) (> (bk:num (nth 8 nb)) 0)) (bk:num (nth 8 nb)))
        (T (bk:mddef code))))

;; длина кабеля с запасом, м: по каждому способу прокладки вверх до 1 м, затем сумма -
;; итог всегда равен сумме колонок по способам (журнал, спецификация, окна)
(defun bk:total (rows / l p)
  (foreach r rows
    (if (setq p (assoc (nth 5 r) l)) (setq l (subst (cons (car p) (+ (cdr p) (nth 7 r))) p l))
      (setq l (cons (cons (nth 5 r) (nth 7 r)) l))))
  (apply '+ (mapcar '(lambda (x) (if (> (cdr x) 1e-9) (bk:ceil0 (cdr x)) 0)) l)))

(defun bk:len-text (id)
  (strcat "итого с запасом "
          (itoa (bk:ceil0 (bk:total (bk:calc (bk:get (car (bk:segs id))) (bk:parts id))))) " м"))

;;; ---------- выноски ----------
(if (not *bk:ld*) (setq *bk:ld* (list "" "" "A")))   ; высота текста, размер кружка, привязка A/B/T

(defun bk:mtx (s / r i c)
  (setq r "" i 1)
  (while (<= i (strlen s))
    (setq c (substr s i 1) i (1+ i))
    (setq r (strcat r (cond ((= c "\\") "\\\\") ((= c "{") "\\{") ((= c "}") "\\}") (T c)))))
  r)

;;; ---------- формат выносок (хранится в чертеже, ldata "BK" "ldfmt") ----------
;; (строка_кабеля объединять нижняя_строка шаблон_нижней прокл_1 прокл_2 прокл_3)
(setq *bk:ldfmt-def* '("{ПОЗ} - {НОМ}" "1" "1" "{ПРОКЛ}"
                       "{ПРОКЛ}" "%%c расч.{ОБЩ} {DРАСЧ} мм" "Заполнение {ЗАП} %"
                       "на {ЭТАЖ} этаж" "с {ЭТАЖ} этажа" "ММ_200_09" "200"))
;; 0-8 - шаблоны; 9 - текстовый стиль выносок; 10 - высота текста (пусто - из параметров выноски)
(defun bk:ldfmt (/ f)
  (setq f (vlax-ldata-get "BK" "ldfmt"))
  (cond ((= (length f) 11) f)
        ((= (length f) 9) (append f (list (nth 9 *bk:ldfmt-def*) (nth 10 *bk:ldfmt-def*))))
        ((= (length f) 7) (append f (list (nth 7 *bk:ldfmt-def*) (nth 8 *bk:ldfmt-def*) (nth 9 *bk:ldfmt-def*) (nth 10 *bk:ldfmt-def*))))
        (T *bk:ldfmt-def*)))

;; текстовый стиль ММ_200_09 (ISOCPEUR, обычный, аннотативный, высота 200, растяжение 0.9, наклон 0) - создать, если нет
(defun bk:ensure-style (nm)
  (if (and (= (strcase nm) "ММ_200_09") (not (tblsearch "STYLE" nm)))
    (progn
      (regapp "AcadAnnotative")
      (entmake (list '(0 . "STYLE") '(100 . "AcDbSymbolTableRecord") '(100 . "AcDbTextStyleTableRecord")
                     (cons 2 nm) '(70 . 0) '(40 . 200.0) '(41 . 0.9) '(50 . 0.0) '(71 . 0) '(42 . 200.0)
                     '(3 . "isocpeur.ttf") '(4 . "")
                     (list -3 (list "AcadAnnotative" '(1000 . "AnnotativeData") '(1002 . "{") '(1070 . 1) '(1070 . 1) '(1002 . "}"))
                              (list "ACAD" '(1000 . "ISOCPEUR") '(1071 . 34)))))
      (if (tblsearch "STYLE" nm) (princ (strcat "\nСоздан текстовый стиль " nm " (ISOCPEUR, аннотативный, h=200, растяжение 0.9).")))))
  (tblsearch "STYLE" nm))

;; подставить поля {ИМЯ}; strict - если поле из шаблона пустое, вся строка пустая
(defun bk:fmt (tpl vars strict / r bad)
  (setq r tpl)
  (foreach v vars
    (if (vl-string-search (strcat "{" (car v) "}") r)
      (progn (if (= (cdr v) "") (setq bad T))
             (setq r (bk:subst-all r (strcat "{" (car v) "}") (bk:mtx (cdr v)))))))
  (if (and strict bad) "" r))

;; поля кабеля
(defun bk:cvars (id d pos / r)
  (setq r (bk:cat-row (bk:f d "marka")))
  (list (cons "ПОЗ" pos) (cons "НОМ" (bk:f d "marka"))
        (cons "ТИП" (if r (nth 0 r) "")) (cons "ОБОЛ" (if r (nth 1 r) "")) (cons "ПРОВ" (if r (nth 2 r) ""))
        (cons "СЕЧ" (if r (nth 3 r) "")) (cons "D" (bk:f d "diam")) (cons "ЭТАЖ" (bk:cfloor d))
        (cons "ОТКУДА" (bk:dev-pos (bk:f d "beg"))) (cons "КУДА" (bk:dev-pos (bk:f d "end")))
        (cons "ПОМ1" (bk:dev-room (bk:f d "beg"))) (cons "ПОМ2" (bk:dev-room (bk:f d "end")))
        (cons "ДЛИНА" (if (vl-string-search "{ДЛИНА}" (car (bk:ldfmt)))
                        (itoa (bk:ceil0 (bk:total (bk:calc d (bk:parts id))))) ""))))

;; позиции через запятую с диапазонами: k1,k2,k3,k4 -> k1...k4; k1,k2 -> k1, k2 (по возрастанию)
(defun bk:pos-split (s / i)                     ; ("k" . 4) или nil, если нет числа в конце
  (setq i (strlen s))
  (while (and (> i 0) (wcmatch (substr s i 1) "#")) (setq i (1- i)))
  (if (< i (strlen s)) (cons (substr s 1 i) (atoi (substr s (1+ i))))))
;; сравнение позиций: одинаковый префикс - по числу в конце (k.П1.1-2 < k.П1.1-10)
;; сравнение позиций: одинаковый префикс - по числу в конце (k.П1.1-2 < k.П1.1-10)
(defun bk:pos-less (a b / x y)
  (setq x (bk:pos-split a) y (bk:pos-split b))
  (if (and x y (= (bk:up (car x)) (bk:up (car y)))) (< (cdr x) (cdr y)) (< (bk:up a) (bk:up b))))
(defun bk:pos-ranges (l / out run flush a b)
  (setq l (vl-sort (bk:uniq l) 'bk:pos-less))
  (defun flush ()
    (if run
      (setq out (append out
                  (if (>= (length run) 3)
                    (list (strcat (car run) "..." (last run)))
                    run))))
    (setq run nil))
  (foreach x l
    (setq a (if run (bk:pos-split (last run))) b (bk:pos-split x))
    (if (and a b (= (car a) (car b)) (= (1+ (cdr a)) (cdr b)) (= (strlen (itoa (cdr b))) (- (strlen x) (strlen (car b)))))
      (setq run (append run (list x)))
      (progn (flush) (setq run (list x)))))
  (flush)
  (bk:join out ", "))

;; перенос строки выноски: перед " - " и по ", " так, чтобы строка была не длиннее n символов
(defun bk:ld-wrap (s n / segs out cur w i j)
  (setq segs nil)
  (while (setq i (vl-string-search " - " s))
    (setq segs (append segs (list (substr s 1 i))) s (strcat "- " (substr s (+ i 4)))))
  (setq segs (append segs (list s)))
  (foreach g segs
    (setq cur "")
    (while (/= g "")
      (setq j (vl-string-search ", " g))
      (setq w (if j (substr g 1 (+ j 1)) g) g (if j (substr g (+ j 3)) ""))
      (cond ((= cur "") (setq cur w))
            ((> (+ (strlen cur) 1 (strlen w)) n) (setq out (append out (list cur)) cur w))
            (T (setq cur (strcat cur " " w)))))
    (if (/= cur "") (setq out (append out (list cur)))))
  (bk:join out "\\P"))

;; строки кабелей: по шаблону; при "объединять" одинаковые строки - в одну, {ПОЗ} через запятую
(defun bk:leader-text (ids / f grp d t1 p gr ps)
  (setq f (bk:ldfmt) gr (= (nth 1 f) "1"))
  (foreach id ids
    (setq d (bk:get (car (bk:segs id)))
          ;; кратность: кабель проходит точку выноски n раз (туда и обратно) -> «k1 (2)»
          ps (if (and (assoc id *bk:ldm*) (> (cdr (assoc id *bk:ldm*)) 1))
               (strcat (bk:f d "pos") " (" (itoa (cdr (assoc id *bk:ldm*))) ")") (bk:f d "pos"))
          t1 (bk:fmt (car f) (bk:cvars id d (if gr "\001" ps)) nil))
    (if (and gr (setq p (assoc t1 grp)))
      (setq grp (subst (append p (list ps)) p grp))
      (setq grp (append grp (list (list t1 ps))))))
  (bk:join (mapcar '(lambda (g) (bk:ld-wrap (bk:subst-all (car g) "\001" (bk:mtx (bk:pos-ranges (vl-remove "" (cdr g))))) 40)) grp)
           "\\P"))

;; ---------- кратность прохода кабеля ----------
;; сколько раз кабель id проходит через точку p (отрезки всех его участков в пределах допуска,
;; точка - внутри отрезка): 2 - туда и обратно по одной линии
(defun bk:pass-n (id p / n pts a b dx dy l2 u q tol)
  (setq n 0 tol (+ *bk:otol* 1.0) p (bk:2d p))
  (foreach e (bk:segs id)
    (setq pts (bk:pts e))
    (while (cdr pts)
      (setq a (car pts) b (cadr pts) pts (cdr pts)
            dx (- (car b) (car a)) dy (- (cadr b) (cadr a)) l2 (+ (* dx dx) (* dy dy)))
      (if (> l2 1e-12)
        (progn
          (setq u (/ (+ (* (- (car p) (car a)) dx) (* (- (cadr p) (cadr a)) dy)) l2)
                q (list (+ (car a) (* u dx)) (+ (cadr a) (* u dy))))
          (if (and (> u 1e-4) (< u (- 1.0 1e-4)) (<= (distance p q) tol)) (setq n (1+ n)))))))
  (max 1 n))
;; кратности кабелей в точке выноски e: ((id . n) ...)
(defun bk:ld-mult (e ids / v p)
  (setq v (vl-catch-all-apply 'vlax-invoke (list (vlax-ename->vla-object e) 'GetLeaderLineVertices 0)))
  (if (and (not (vl-catch-all-error-p v)) (>= (length v) 2)) (setq p (list (car v) (cadr v))))
  (if p (mapcar '(lambda (id) (cons id (bk:pass-n id p))) ids)))
;; полный текст выноски кабелей (с кратностью)
(defun bk:ld-full (e ids / r)
  (setq *bk:ldm* (vl-catch-all-apply 'bk:ld-mult (list e ids)))
  (if (vl-catch-all-error-p *bk:ldm*) (setq *bk:ldm* nil))
  (setq r (strcat (bk:leader-text ids) (bk:ld-prokl e ids)) *bk:ldm* nil)
  r)
;; все проходы кабеля id по отрезку p1-p2: ((e a b) ...) - параметры на полилиниях
(defun bk:pieces-on (id p1 p2 / out tol pts i a b dx dy l2 u1 u2 q1 q2)
  (setq tol (+ *bk:otol* 1.0) p1 (bk:2d p1) p2 (bk:2d p2))
  (foreach e (bk:segs id)
    (setq pts (bk:pts e) i 0)
    (while (cdr pts)
      (setq a (car pts) b (cadr pts) pts (cdr pts)
            dx (- (car b) (car a)) dy (- (cadr b) (cadr a)) l2 (+ (* dx dx) (* dy dy)))
      (if (> l2 1e-12)
        (progn
          (setq u1 (/ (+ (* (- (car p1) (car a)) dx) (* (- (cadr p1) (cadr a)) dy)) l2)
                u2 (/ (+ (* (- (car p2) (car a)) dx) (* (- (cadr p2) (cadr a)) dy)) l2)
                q1 (list (+ (car a) (* u1 dx)) (+ (cadr a) (* u1 dy)))
                q2 (list (+ (car a) (* u2 dx)) (+ (cadr a) (* u2 dy))))
          (if (and (<= (distance p1 q1) tol) (<= (distance p2 q2) tol)
                   (>= (min u1 u2) -1e-3) (<= (max u1 u2) 1.001) (> (abs (- u2 u1)) 1e-6))
            (setq out (cons (list e (+ i (max 0.0 (min u1 u2))) (+ i (min 1.0 (max u1 u2)))) out)))))
      (setq i (1+ i))))
  (reverse out))
;; участок уже имеет параметры r (code h k sz md ex ...)
(defun bk:seg-same (e r / d)
  (setq d (bk:get e))
  (and (= (bk:f d "code") (car r)) (equal (bk:fn d "k") (caddr r) 1e-6) (= (bk:f d "sz") (cadddr r))
       (equal (bk:fn d "md") (nth 4 r) 1e-6) (= (bk:f d "ex") (nth 5 r))
       (or (= (cadr r) "") (equal (bk:fn d "h") (bk:num (cadr r)) 1e-6))))
;; применить параметры участка r ко ВСЕМ проходам кабеля id по отрезку p1-p2 -> число изменённых
(defun bk:apply-passes (id p1 p2 r / n go c)
  (setq n 0 go T)
  (while (and go (< n 20))
    (setq c (vl-some '(lambda (x) (if (not (bk:seg-same (car x) r)) x)) (bk:pieces-on id p1 p2)))
    (if c
      (progn (bk:set-piece (car c) (cadr c) (caddr c) (car r)
                           (if (/= (cadr r) "") (bk:num (cadr r))) (caddr r) (cadddr r) (nth 4 r) (nth 5 r) (nth 6 r))
             (setq n (1+ n)))
      (setq go nil)))
  n)

;; нижняя строка выноски кабелей: в чём прокладываются кабели в точке выноски
;; (точка - начало линии выноски); если в точке их нет - способы всех участков кабелей
(defun bk:ld-prokl (e ids / v p cs names nm d f r)
  (setq v (vl-catch-all-apply 'vlax-invoke (list (vlax-ename->vla-object e) 'GetLeaderLineVertices 0)))
  (if (and (not (vl-catch-all-error-p v)) (>= (length v) 2)) (setq p (list (car v) (cadr v))))
  (if p (setq cs (vl-remove-if-not '(lambda (x) (member (car x) ids)) (bk:segs-at p))))
  (if cs
    (foreach x cs (setq nm (bk:pl-name-ex (nth 2 x) (nth 3 x) (nth 4 x) (if (nth 6 x) (nth 6 x) "")))
                  (if (not (member nm names)) (setq names (append names (list nm)))))
    (foreach id ids
      (foreach s (bk:segs id)
        (setq d (bk:get s) nm (bk:pl-name-ex (bk:f d "code") (bk:md-of (bk:fn d "md") (bk:f d "code") nil) (bk:f d "sz") (bk:f d "ex")))
        (if (not (member nm names)) (setq names (append names (list nm)))))))
  (setq f (bk:ldfmt) r (if (and (= (nth 2 f) "1") names) (bk:fmt (nth 3 f) (list (cons "ПРОКЛ" (bk:join names ", "))) T) ""))
  (if (/= r "") (strcat "\\P" r) ""))

;; параметры выноски хранятся в XDATA "BK_LD": высота, кружок, привязка
(defun bk:ld-par (e / x)
  (if (setq x (assoc -3 (entget e '("BK_LD"))))
    (mapcar 'cdr (cdr (cadr x)))
    *bk:ld*))

;; запись через ActiveX (entmod для мультивыносок ненадёжен)
(defun bk:ld-put (e par / ty va n)
  (regapp "BK_LD")
  (setq n (1+ (length par))
        ty (vlax-make-safearray vlax-vbInteger (cons 0 (1- n)))
        va (vlax-make-safearray vlax-vbVariant (cons 0 (1- n))))
  (vlax-safearray-fill ty (cons 1001 (mapcar '(lambda (x) 1000) par)))
  (vlax-safearray-fill va (mapcar 'vlax-make-variant (cons "BK_LD" (mapcar '(lambda (v) (if v v "")) par))))
  (vla-SetXData (vlax-ename->vla-object e) ty va))

;; высота текста стиля мультивыноски
(defun bk:mls-h (ml / st h)
  (setq st (vl-catch-all-apply
             '(lambda () (vla-item (vla-item (vla-get-Dictionaries (vla-get-ActiveDocument (vlax-get-acad-object)))
                                              "ACAD_MLEADERSTYLE")
                                    (vla-get-StyleName ml)))))
  (setq h (if (vl-catch-all-error-p st) nil (vl-catch-all-apply 'vla-get-TextHeight (list st))))
  (if (and (numberp h) (> h 0)) h (vla-get-TextHeight ml)))

;; выноска чёрная. Цвет текста и рамки у мультивыноски задаётся только стилем, поэтому
;; все выноски переводятся на свой стиль "БЛОК_ВЫНОСКА" (копия исходного, текст и линия RGB 0,0,0)
(defun bk:black ( / c)
  (setq c (vl-catch-all-apply 'vla-GetInterfaceObject (list (vlax-get-acad-object) "AutoCAD.AcCmColor.24")))
  (if (vl-catch-all-error-p c)
    (setq c (vl-catch-all-apply 'vla-GetInterfaceObject (list (vlax-get-acad-object) "AutoCAD.AcCmColor"))))
  (if (vl-catch-all-error-p c) nil (progn (vl-catch-all-apply 'vla-SetRGB (list c 0 0 0)) c)))

;; цвет "ПоБлоку": текст и линия выноски берут цвет самой выноски (меняется в Свойствах)
(defun bk:byblock ( / c)
  (setq c (vl-catch-all-apply 'vla-GetInterfaceObject (list (vlax-get-acad-object) "AutoCAD.AcCmColor.24")))
  (if (vl-catch-all-error-p c)
    (setq c (vl-catch-all-apply 'vla-GetInterfaceObject (list (vlax-get-acad-object) "AutoCAD.AcCmColor"))))
  (if (vl-catch-all-error-p c) nil (progn (vl-catch-all-apply 'vla-put-ColorIndex (list c 0)) c)))
(defun bk:ld-mls (ml / dict st src c)
  (setq dict (vl-catch-all-apply '(lambda () (vla-item (vla-get-Dictionaries (bk:doc)) "ACAD_MLEADERSTYLE"))))
  (if (not (vl-catch-all-error-p dict))
    (progn
      (setq st (vl-catch-all-apply 'vla-item (list dict "БЛОК_ВЫНОСКА")))
      (if (vl-catch-all-error-p st)
        (progn
          (setq src (vl-catch-all-apply 'vla-item (list dict (vla-get-StyleName ml))))
          (setq st (vl-catch-all-apply 'vla-AddObject (list dict "БЛОК_ВЫНОСКА" "AcDbMLeaderStyle")))
          (if (and (not (vl-catch-all-error-p st)) (not (vl-catch-all-error-p src)))
            (foreach pr '(TextStyle TextHeight ArrowSize ArrowSymbol LandingGap ScaleFactor Annotative
                          TextAlignmentType TextAngleType DrawLeaderOrderType ContentType)
              (vl-catch-all-apply 'vlax-put (list st pr (vl-catch-all-apply 'vlax-get (list src pr))))))))
      (if (and (not (vl-catch-all-error-p st)) (setq c (bk:byblock)))
        (progn (vl-catch-all-apply 'vla-put-TextColor (list st c))
               (vl-catch-all-apply 'vla-put-LeaderLineColor (list st c))
               (vl-catch-all-apply 'vla-put-StyleName (list ml "БЛОК_ВЫНОСКА")))))))

;; цвет ТЕКСТА мультивыноски - отдельное свойство объекта (не меняется цветом выноски).
;; Ставим его ПоБлоку (DXF 92 после данных контекста, флаг переопределения 1<<15 в 90,
;; и цвет текста контекста - 90 после 170 внутри CONTEXT_DATA) -> текст следует цвету выноски.
(defun bk:ld-text-byblock (e / ed out ctx after done90 done92 x bb)
  (setq ed (entget e) bb -1056964608)
  (foreach x ed
    (cond
      ((and (= (car x) 300) (= (cdr x) "CONTEXT_DATA{")) (setq ctx T) (setq out (cons x out)))
      ((and ctx (= (car x) 301)) (setq ctx nil after T) (setq out (cons x out)))
      ((and ctx (= (car x) 170)) (setq done90 'next) (setq out (cons x out)))
      ((and ctx (= done90 'next) (= (car x) 90)) (setq done90 T) (setq out (cons (cons 90 bb) out)))
      ((and after (not done92) (= (car x) 92)) (setq done92 T) (setq out (cons (cons 92 bb) out)))
      ((and after (= (car x) 90) (not (vl-catch-all-error-p (vl-catch-all-apply 'logior (list (cdr x) 32768)))))
       (setq out (cons (cons 90 (logior (cdr x) 32768)) out)))
      (T (setq out (cons x out)))))
  (if done92
    (if (vl-catch-all-error-p (vl-catch-all-apply 'entmod (list (reverse out))))
      (entmod ed)
      (entupd e))))

;; выноска: линия и текст - ПоБлоку, сама выноска - белая (7, печать чёрным).
;; Цвет, заданный пользователем (не ПоСлою/ПоБлоку и не прежний чёрный RGB), сохраняется.
(defun bk:ld-black (ml / c tc m)
  (if (setq c (bk:byblock)) (vl-catch-all-apply 'vla-put-LeaderLineColor (list ml c)))
  (setq tc (vl-catch-all-apply 'vla-get-TrueColor (list ml)))
  (if (not (vl-catch-all-error-p tc))
    (progn
      (setq m (vla-get-ColorMethod tc))
      (if (or (= m acColorMethodByLayer) (= m acColorMethodByBlock)
              (and (= m acColorMethodByRGB) (= (vla-get-Red tc) 0) (= (vla-get-Green tc) 0) (= (vla-get-Blue tc) 0)))
        (vla-put-Color ml 7))))
  (vl-catch-all-apply 'bk:ld-text-byblock (list (vlax-vla-object->ename ml))))

;; применить оформление: кружок, размеры, привязка текста
(defun bk:ld-style (e / ml par v up right att fm)
  (setq ml (vlax-ename->vla-object e) par (bk:ld-par e))
  (bk:ld-mls ml)
  (vl-catch-all-apply 'vla-put-ArrowheadType (list ml acArrowDot))
  ;; высота текста: заданная в параметрах, иначе высота стиля выноски минус 20 %
  ;; стиль и высота текста - из ММ_КАБЕЛЬ_ВЫНОСКА_ФОРМАТ (высота пусто - из параметров выноски / стиля)
  (setq fm (bk:ldfmt))
  (if (and (/= (nth 9 fm) "") (tblsearch "STYLE" (nth 9 fm)))
    (vl-catch-all-apply 'vla-put-TextStyleName (list ml (nth 9 fm))))
  (vl-catch-all-apply 'vla-put-TextHeight
    (list ml (cond ((> (bk:num (nth 10 fm)) 0) (bk:num (nth 10 fm)))
                   ((> (bk:num (nth 0 par)) 0) (bk:num (nth 0 par)))
                   (T (* 0.8 (bk:mls-h ml))))))
  (if (> (bk:num (nth 1 par)) 0) (vl-catch-all-apply 'vla-put-ArrowheadSize (list ml (bk:num (nth 1 par)))))
  ;; направление выноски: сравнить точку кружка и конец полки
  (setq v (vl-catch-all-apply 'vlax-invoke (list ml 'GetLeaderLineVertices 0)))
  (if (or (vl-catch-all-error-p v) (< (length v) 6)) (setq v nil))
  (setq up    (if v (>= (nth (- (length v) 2) v) (cadr v)) T)
        right (if v (>= (nth (- (length v) 3) v) (car v)) T))
  ;; выноска вправо - полка и привязка к тексту слева, влево - справа
  (vl-catch-all-apply 'vla-SetDoglegDirection
    (list ml 0 (vlax-3d-point (if right '(1.0 0.0 0.0) '(-1.0 0.0 0.0)))))
  (vl-catch-all-apply 'vla-put-TextJustify
    (list ml (if right acAttachmentPointTopLeft acAttachmentPointTopRight)))
  ;; без подчёркивания: полка - к середине нижней / верхней строки; общая рамка, маскировка фона
  ;; линия выноски - в угол рамки: вверх - нижний угол, вниз - верхний; без полки
  (setq att (cond ((= (nth 2 par) "B") acAttachmentBottomOfBottom)
                  ((= (nth 2 par) "T") acAttachmentTopOfTop)
                  (up acAttachmentBottomOfBottom)
                  (T acAttachmentTopOfTop)))
  (vl-catch-all-apply 'vla-put-EnableDogleg (list ml :vlax-false))
  (vl-catch-all-apply 'vla-put-TextFrameDisplay (list ml :vlax-true))
  (vl-catch-all-apply 'vla-put-TextBackgroundFill (list ml :vlax-true))
  ;; отступ рамки от текста - половина высоты текста
  (vl-catch-all-apply 'vla-put-LandingGap (list ml (* 0.5 (vla-get-TextHeight ml))))
  (vl-catch-all-apply 'vla-put-TextLeftAttachmentType (list ml att))
  (vl-catch-all-apply 'vla-put-TextRightAttachmentType (list ml att))
  (bk:ld-black ml))

;; выноски "все кабели на участке" (4-й параметр BK_LD = "1"): состав кабелей
;; берётся заново по точке начала выноски - новые кабели добавляются, ушедшие убираются
(defun bk:ld-auto-list (/ l v)
  (foreach e (bk:ss->l (ssget "_X" '((0 . "MULTILEADER") (-3 ("BK_LD")))))
    (if (= (nth 3 (bk:ld-par e)) "1")
      (progn
        (setq v (vl-catch-all-apply 'vlax-invoke (list (vlax-ename->vla-object e) 'GetLeaderLineVertices 0)))
        (if (and (not (vl-catch-all-error-p v)) (>= (length v) 2))
          (setq l (cons (list (cdr (assoc 5 (entget e))) (list (car v) (cadr v))) l))))))
  l)
(defun bk:ld-sync (/ al ids all hs h new)
  (if (setq al (bk:ld-auto-list))
    (progn
      (foreach s (bk:all-segs) (if (not (member (bk:f (bk:get s) "id") all)) (setq all (cons (bk:f (bk:get s) "id") all))))
      (foreach a al
        (setq h (car a)
              ids (mapcar 'car (bk:no-st (bk:segs-at (cadr a)))))
        (foreach id all
          (setq hs (bk:ld-handles (bk:get (car (bk:segs id)))))
          (cond ((and (member id ids) (not (member h hs))) (bk:set-field id "ld" (bk:join (append hs (list h)) " ")))
                ((and (not (member id ids)) (member h hs)) (bk:set-field id "ld" (bk:join (vl-remove h hs) " ")))))))))

;; у кабеля может быть несколько выносок: "ld" = хэндлы через пробел
(defun bk:ld-handles (d / s i l)
  (setq s (bk:f d "ld"))
  (while (setq i (vl-string-search " " s))
    (if (> i 0) (setq l (cons (substr s 1 i) l)))
    (setq s (substr s (+ i 2))))
  (if (/= s "") (setq l (cons s l)))
  (reverse l))

(defun bk:update-leaders (/ map d p e k)
  (bk:ld-sync)
  (foreach s (bk:all-segs)
    (setq d (bk:get s))
    (foreach h (bk:ld-handles d)
      (if (setq p (assoc h map))
        (if (not (member (bk:f d "id") (cdr p))) (setq map (subst (append p (list (bk:f d "id"))) p map)))
        (setq map (cons (list h (bk:f d "id")) map)))))
  (setq *bk:ldn* 0)
  (foreach m map
    (if (and (setq e (bk:hent (car m))) (entget e) (= (cdr (assoc 0 (entget e))) "MULTILEADER"))
      (progn
        (vl-catch-all-apply 'vla-put-ContentType (list (vlax-ename->vla-object e) acMTextContent))
        (if (not (vl-catch-all-error-p
                   (vl-catch-all-apply 'vla-put-TextString
                     (list (vlax-ename->vla-object e) (bk:ld-full e (cdr m))))))
          (setq *bk:ldn* (1+ *bk:ldn*)))
        (vl-catch-all-apply 'bk:ld-style (list e)))))
  ;; выноски стояков
  (foreach e (bk:ss->l (ssget "_X" '((0 . "MULTILEADER") (-3 ("BK_ST")))))
    (if (not (vl-catch-all-error-p
               (vl-catch-all-apply 'vla-put-TextString (list (vlax-ename->vla-object e) (bk:st-text e)))))
      (setq *bk:ldn* (1+ *bk:ldn*)))
    (vl-catch-all-apply 'bk:ld-style (list e)))
  ;; выноски прокладки (точка на кабеле хранится в XDATA "BK_PL")
  (foreach e (bk:ss->l (ssget "_X" '((0 . "MULTILEADER") (-3 ("BK_PL")))))
    (if (not (vl-catch-all-error-p
               (vl-catch-all-apply 'vla-put-TextString (list (vlax-ename->vla-object e) (bk:pl-text (bk:pl-pt e))))))
      (setq *bk:ldn* (1+ *bk:ldn*)))
    (vl-catch-all-apply 'bk:ld-style (list e)))
  *bk:ldn*)

;;; ---------- автообновление после команд: ТОЛЬКО изменённые объекты ----------
;; Реактор базы чертежа запоминает хэндлы изменённых / добавленных / удалённых объектов за команду.
;; В конце команды обрабатываются только кабели, которым принадлежат изменённые участки, кабели
;; перемещённых блоков, копии кабелей (новый id и ПОЗИЦИЯ) и связанные с ними выноски.
;; Весь чертёж - командой ММ_КАБЕЛЬ_ОБНОВИТЬ.
;; запоминать изменения только во время «наших» команд правки (не при сохранении, печати и т.п.)
(setq *bk:trk-cmds* "GRIP_*,MOVE,STRETCH,ERASE,COPY,U,UNDO,REDO,MREDO,OOPS,MIRROR,ROTATE,SCALE,PROPERTIES,PASTECLIP,PASTEORIG,EXPLODE,JOIN,PEDIT,ARRAY*,CUTCLIP,DELETE")
(defun bk:on-mod (r a / h) (if (and *bk:track* (not *bk:busy*) (setq h (cadr a)) (= (type h) 'ENAME)) (setq *bk:qm* (cons h *bk:qm*))))
(defun bk:on-app (r a / h) (if (and *bk:track* (not *bk:busy*) (setq h (cadr a)) (= (type h) 'ENAME)) (setq *bk:qa* (cons h *bk:qa*))))
(defun bk:on-era (r a / h)
  (if (and *bk:track* (not *bk:busy*) (setq h (cadr a)) (= (type h) 'ENAME))
    (progn (setq h (vl-catch-all-apply '(lambda (x) (vla-get-Handle (vlax-ename->vla-object x))) (list h)))
           (if (= (type h) 'STR) (setq *bk:qe* (cons h *bk:qe*))))))
(defun bk:on-cmd-start (r c)
  (if (not *bk:busy*)
    (setq *bk:qm* nil *bk:qa* nil *bk:qe* nil
          *bk:track* (and *bk:auto* (wcmatch (strcase (car c)) *bk:trk-cmds*)))))

;; индекс кабелей (полный перебор, строится по требованию): (участок->id  выноска->ids  блок->ids)
(defun bk:amap-add (m k v / p) (if (setq p (assoc k m)) (if (member v (cdr p)) m (subst (append p (list v)) p m)) (cons (list k v) m)))
(defun bk:cidx (/ d id h sm lm dm)
  (if (null *bk:cidx*)
    (progn
      (foreach e (bk:all-segs)
        (setq d (bk:get e) id (bk:f d "id") h (cdr (assoc 5 (entget e))))
        (setq sm (cons (cons h id) sm))
        (if (= (bk:fn d "ord") 0)
          (progn
            (setq *bk:sidx* (cons (cons id h) (vl-remove (assoc id *bk:sidx*) *bk:sidx*)))
            (foreach x (bk:ld-handles d) (setq lm (bk:amap-add lm x id)))
            (foreach x (list (bk:f d "beg") (bk:f d "end")) (if (/= x "") (setq dm (bk:amap-add dm x id)))))))
      (setq *bk:cidx* (list sm lm dm))))
  *bk:cidx*)
(defun bk:cidx-reset () (setq *bk:cidx* nil))

;; стыки и концы одного кабеля; chg - список изменённых участков (nil - все считаются неизменными)
(defun bk:fix-cable (id chg / segs a ea sb d h)
  (if (setq segs (bk:segs id))
    (progn
      (setq a segs)
      (while (cdr a)
        (setq ea (last (bk:pts (car a))) sb (car (bk:pts (cadr a))))
        (if (not (equal ea sb 1e-6))
          (if (and (member (car a) chg) (not (member (cadr a) chg)))
            (bk:set-vtx (cadr a) 0 ea)                 ; сдвинут левый участок - тянем начало правого
            (if (member (cadr a) chg)
              (bk:set-vtx (car a) -1 sb)               ; сдвинут правый - тянем конец левого
              (bk:set-vtx (cadr a) 0 ea))))
        (setq a (cdr a)))
      (setq d (bk:get (car segs)))
      (if (and (/= (bk:f d "bfix") "1") (/= (setq h (bk:block-at (car (bk:pts (car segs))))) "") (/= h (bk:f d "beg")))
        (bk:set-field id "beg" h))
      (if (and (/= (bk:f d "efix") "1") (/= (setq h (bk:block-at (last (bk:pts (last segs))))) "") (/= h (bk:f d "end")))
        (bk:set-field id "end" h))
      (vl-catch-all-apply 'bk:end-label (list id)))))

;; блок перемещён: концы привязанных к нему кабелей - в точку вставки блока
(defun bk:fix-block (h / e ip ids segs d)
  (if (and (setq e (handent h)) (entget e) (setq ids (cdr (assoc h (caddr (bk:cidx))))))
    (progn
      (setq ip (bk:2d (cdr (assoc 10 (entget e)))))
      (foreach id ids
        (if (setq segs (bk:segs id))
          (progn
            (setq d (bk:get (car segs)))
            (if (= (bk:f d "beg") h) (bk:set-vtx (car segs) 0 ip))
            (if (= (bk:f d "end") h) (bk:set-vtx (last segs) -1 ip))
            (vl-catch-all-apply 'bk:end-label (list id)))))
      ids)))

;; копии кабелей (КОПИРОВАТЬ, ВСТАВИТЬ...): новый id и свободная ПОЗИЦИЯ у каждой копии
(defun bk:fix-copies (es / grps g k id used n l d pos nid)
  (foreach e es
    (if (and (entget e) (assoc -3 (entget e '("BK"))))
      (progn (setq k (if (setq g (bk:group-of e)) (cdr (assoc 5 (entget g))) (strcat "#" (bk:f (bk:get e) "id"))))
             (setq grps (bk:amap-add grps k e)))))
  (setq n 0)
  (foreach gr grps
    (setq id (bk:f (bk:get (cadr gr)) "id"))
    ;; есть ли этот id у участков вне копии
    (if (vl-some '(lambda (x) (and (not (member x (cdr gr))) (= (bk:f (bk:get x) "id") id))) (bk:all-segs))
      (progn
        (if (null used) (setq used (bk:used-pos)))
        (setq d (bk:get (cadr gr)) pos (bk:free-pos (bk:f d "pos") used) nid (bk:newid "K") used (cons (strcase pos) used))
        (foreach x (cdr gr) (bk:put x (bk:setf (bk:setf (bk:setf (bk:get x) "id" nid) "pos" pos) "ld" "")))
        (setq *bk:sidx* (cons (cons nid (cdr (assoc 5 (entget (cadr gr))))) *bk:sidx*))
        (vl-catch-all-apply 'bk:end-label (list nid))
        (setq n (1+ n) l (cons (strcat (bk:f d "pos") " -> " pos) l)))))
  (if (> n 0) (princ (strcat "\nСкопировано кабелей: " (itoa n) " - новые ПОЗИЦИИ: " (bk:join (reverse l) ", ")))))

;; выноски кабелей ids (и автоматические выноски, стоящие на этих кабелях)
(defun bk:upd-leaders-for (ids / ix lm al hs e old new d)
  (setq ix (bk:cidx) lm (cadr ix))
  ;; автоматические выноски: состав - заново по точке, если выноска на изменённом кабеле
  (foreach a (bk:ld-auto-list)
    (setq old (cdr (assoc (car a) lm)))
    (if (or (vl-some '(lambda (i) (member i ids)) old)
            (vl-some '(lambda (i) (vl-some '(lambda (sg) (and (setq d (bk:pl-near sg (cadr a))) (<= (car d) (* 3.0 (bk:ptol))))) (bk:segs i))) ids))
      (progn
        (setq new (mapcar 'car (bk:no-st (bk:segs-at (cadr a)))))
        (foreach i new (if (not (member i old)) (bk:set-field i "ld" (bk:join (append (bk:ld-handles (bk:get (car (bk:segs i)))) (list (car a))) " "))))
        (foreach i old (if (not (member i new)) (bk:set-field i "ld" (bk:join (vl-remove (car a) (bk:ld-handles (bk:get (car (bk:segs i))))) " "))))
        (setq lm (cons (cons (car a) new) (vl-remove (assoc (car a) lm) lm)) hs (cons (car a) hs)))))
  (setq *bk:cidx* (list (car ix) lm (caddr ix)))
  ;; выноски, где упомянуты кабели ids
  (foreach m lm (if (vl-some '(lambda (i) (member i ids)) (cdr m)) (if (not (member (car m) hs)) (setq hs (cons (car m) hs)))))
  (foreach h hs
    (if (and (setq e (bk:hent h)) (entget e) (= (cdr (assoc 0 (entget e))) "MULTILEADER") (cdr (assoc h lm)))
      (progn
        (vl-catch-all-apply 'vla-put-TextString
          (list (vlax-ename->vla-object e) (bk:ld-full e (cdr (assoc h lm)))))
        (vl-catch-all-apply 'bk:ld-style (list e)))))
  (length hs))

(defun bk:after-cmd (cmd / qm qa qe segs blks ids e h id ix ers lh)
  (setq qm (bk:uniq *bk:qm*) qa (bk:uniq *bk:qa*) qe (bk:uniq *bk:qe*) *bk:qm* nil *bk:qa* nil *bk:qe* nil)
  (cond
    ;; отмена / повтор - только сбросить индекс (выноски восстановит сама отмена)
    ((wcmatch cmd "U,UNDO,REDO,MREDO,OOPS") (bk:cidx-reset))
    ;; удаление: выноски удалённых кабелей
    ((and qe (setq ix *bk:cidx*))
     (foreach h qe (if (setq id (cdr (assoc h (car ix)))) (if (not (member id ers)) (setq ers (cons id ers)))))
     (bk:cidx-reset)
     (if ers
       (progn (bk:cidx)
              (foreach m (cadr ix) (if (vl-some '(lambda (i) (member i ers)) (cdr m)) (setq lh (cons (car m) lh))))
              (foreach h lh
                (if (and (setq e (bk:hent h)) (entget e) (setq ids (cdr (assoc h (cadr *bk:cidx*)))))
                  (progn (vl-catch-all-apply 'vla-put-TextString (list (vlax-ename->vla-object e) (bk:ld-full e ids)))
                         (vl-catch-all-apply 'bk:ld-style (list e))))))))
    (qe (bk:cidx-reset))
    (T
     ;; копии кабелей
     (if qa (progn (bk:fix-copies qa) (bk:cidx-reset)))
     ;; изменённые участки и блоки
     (foreach e (append qm qa)
       (if (entget e)
         (cond ((assoc -3 (entget e '("BK"))) (setq segs (cons e segs) id (bk:f (bk:get e) "id")) (if (not (member id ids)) (setq ids (cons id ids))))
               ((= (cdr (assoc 0 (entget e))) "INSERT") (setq blks (cons (cdr (assoc 5 (entget e))) blks))))))
     (foreach h blks (foreach id (bk:fix-block h) (if (not (member id ids)) (setq ids (cons id ids)))))
     (foreach id ids (vl-catch-all-apply 'bk:fix-cable (list id segs)))
     (if ids (vl-catch-all-apply 'bk:upd-leaders-for (list ids))))))

(defun bk:on-cmd-end (r c / cmd)
  (setq cmd (strcase (car c)))
  (if (and (not *bk:busy*) *bk:auto* (or *bk:qm* *bk:qa* *bk:qe*) (wcmatch cmd *bk:trk-cmds*))
    (progn
      (setq *bk:busy* T)
      (vl-catch-all-apply 'bk:after-cmd (list cmd))
      (setq *bk:busy* nil)))
  (if (not *bk:busy*) (setq *bk:qm* nil *bk:qa* nil *bk:qe* nil *bk:track* nil)))

;;; ---------- правка кабеля в группе: стыки, концы, подпись ----------
;; снимок: ((хэндл начало конец) ...) всех участков
(defun bk:geo-snap (/ l pts)
  (foreach e (bk:all-segs)
    (setq pts (bk:pts e) l (cons (list (cdr (assoc 5 (entget e))) (car pts) (last pts)) l)))
  (setq *bk:geo* l))
(defun bk:set-vtx (e i p / c n)
  (setq c (vlax-get (vlax-ename->vla-object e) 'Coordinates) n (if (< i 0) (- (/ (length c) 2) 1) i))
  (setq c (bk:replace-nth (* 2 n) (car p) c) c (bk:replace-nth (1+ (* 2 n)) (cadr p) c))
  (vlax-put (vlax-ename->vla-object e) 'Coordinates c))
(defun bk:geo-fix (/ map d p id segs a b ea sb ca cb chg old b0 h)
  (foreach e (bk:all-segs)
    (setq d (bk:get e) id (bk:f d "id"))
    (if (setq p (assoc id map)) (setq map (subst (cons id (cons (cons (bk:fn d "ord") e) (cdr p))) p map))
      (setq map (cons (list id (cons (bk:fn d "ord") e)) map))))
  (foreach m map
    (setq segs (mapcar 'cdr (vl-sort (cdr m) '(lambda (x y) (< (car x) (car y))))) chg nil)
    ;; изменился ли кабель с прошлого снимка
    (foreach e segs
      (setq old (assoc (cdr (assoc 5 (entget e))) *bk:geo*))
      (if (or (null old) (not (equal (cadr old) (car (bk:pts e)) 1e-6)) (not (equal (caddr old) (last (bk:pts e)) 1e-6))) (setq chg T)))
    (if (and chg *bk:geo*)
      (progn
        ;; стыки: соседний участок подтягивается к сдвинутому концу
        (setq a segs)
        (while (cdr a)
          (setq ea (last (bk:pts (car a))) sb (car (bk:pts (cadr a)))
                ca (caddr (assoc (cdr (assoc 5 (entget (car a)))) *bk:geo*))
                cb (cadr (assoc (cdr (assoc 5 (entget (cadr a)))) *bk:geo*)))
          (if (not (equal ea sb 1e-6))
            (if (and cb (equal sb cb 1e-6) (not (equal ea ca 1e-6)))
              (bk:set-vtx (cadr a) 0 ea)                 ; сдвинут конец левого - тянем начало правого
              (bk:set-vtx (car a) -1 sb)))               ; иначе - конец левого к началу правого
          (setq a (cdr a)))
        ;; концы кабеля: заново к блокам (если не закреплены вручную)
        (setq d (bk:get (car segs)))
        (if (and (/= (bk:f d "bfix") "1") (/= (setq h (bk:block-at (car (bk:pts (car segs))))) "") (/= h (bk:f d "beg")))
          (bk:set-field (car m) "beg" h))
        (if (and (/= (bk:f d "efix") "1") (/= (setq h (bk:block-at (last (bk:pts (last segs))))) "") (/= h (bk:f d "end")))
          (bk:set-field (car m) "end" h))
        (vl-catch-all-apply 'bk:end-label (list (car m))))))
  (bk:geo-snap))
(if (null *bk:auto*) (setq *bk:auto* T))
;; ручки всех участков у выбранного кабеля-группы (правка без разгруппировки)
(vl-catch-all-apply 'setvar (list "GROUPDISPLAYMODE" 0))
(if *bk:creactor* (vl-catch-all-apply 'vlr-remove (list *bk:creactor*)))
(setq *bk:creactor* (vlr-command-reactor "BK" '((:vlr-commandEnded . bk:on-cmd-end) (:vlr-commandWillStart . bk:on-cmd-start))))
(if *bk:dreactor* (vl-catch-all-apply 'vlr-remove (list *bk:dreactor*)))
(setq *bk:dreactor* (vlr-acdb-reactor "BK" '((:vlr-objectModified . bk:on-mod) (:vlr-objectAppended . bk:on-app) (:vlr-objectErased . bk:on-era))))

(defun bk:set-field (id k v)
  (foreach e (bk:segs id) (bk:put e (bk:setf (bk:get e) k v))))

;; окно параметров выноски; par -> новый par или nil
(defun bk:ld-dialog (par / fn id res out)
  (setq fn (bk:write-dcl "blok_kabel_ld.dcl"
             '("bk_ld : dialog { label = \"Параметры выноски\";"
               " : edit_box { key = \"th\"; label = \"Высота текста (пусто - как в стиле):\"; edit_width = 8; allow_accept = false; }"
               " : edit_box { key = \"as\"; label = \"Размер кружка (пусто - как в стиле):\"; edit_width = 8; allow_accept = false; }"
               " : boxed_radio_column { key = \"att\"; label = \"Привязка текста\";"
               "   : radio_button { key = \"A\"; label = \"Авто: выноска вверх - к нижней строке, вниз - к верхней\"; }"
               "   : radio_button { key = \"B\"; label = \"К нижней строке\"; }"
               "   : radio_button { key = \"T\"; label = \"К верхней строке\"; } }"
               " : toggle { key = \"auto\"; label = \"Все кабели на участке (новые кабели по участку тоже попадут в выноску)\"; }"
               " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 14; }"
               "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }"))
        id (load_dialog fn))
  (if (new_dialog "bk_ld" id)
    (progn
      (bk:st "th" (nth 0 par)) (bk:st "as" (nth 1 par)) (bk:st "att" (nth 2 par))
      (bk:st "auto" (if (= (nth 3 par) "1") "1" "0"))
      (action_tile "accept" "(setq out (list (bk:trim (get_tile \"th\")) (bk:trim (get_tile \"as\")) (get_tile \"att\") (get_tile \"auto\"))) (done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)))
  (vl-file-delete fn)
  (if (= res 1) out))

;;; ---------- общие элементы окон ----------
;; тип кабеля -> список марок
(setq *bk:cfk* '("c_type" "c_sheath" "c_cond" "c_sect"))   ; фильтры: индексы 0..3 строки справочника

;; строка подходит под все фильтры, кроме skip
(defun bk:cat-match (r skip / j)
  (setq j -1)
  (vl-every '(lambda (f) (setq j (1+ j)) (or (= j skip) (= f "") (= f (nth j r)))) *bk:cf*))

;; заполнить зависимые списки: у каждого - значения, возможные при остальных фильтрах
(defun bk:cat-fill (/ i vals k)
  (if (/= (length *bk:cf*) 4) (setq *bk:cf* '("" "" "" "")))
  (setq i 0 *bk:cv* nil)
  (foreach k *bk:cfk*
    (setq vals nil)
    (foreach r (bk:cat) (if (and (bk:cat-match r i) (not (member (nth i r) vals))) (setq vals (cons (nth i r) vals))))
    (setq vals (vl-sort vals 'bk:less) *bk:cv* (append *bk:cv* (list vals)))
    (start_list k) (add_list "<все>") (foreach v vals (add_list v)) (end_list)
    (bk:st k (itoa (cond ((vl-position (nth i *bk:cf*) vals) (1+ (vl-position (nth i *bk:cf*) vals))) (0))))
    (setq i (1+ i)))
  (setq *bk:cn* (vl-remove-if-not '(lambda (r) (bk:cat-match r -1)) (bk:cat)))
  (start_list "c_nom")
  (add_list (if (bk:cat) (strcat "<выберите номенклатуру: " (itoa (length *bk:cn*)) ">") "<справочник не загружен - введите вручную>"))
  (foreach r *bk:cn* (add_list (strcat (nth 4 r) "   (d=" (bk:r (nth 5 r) 1) " мм)")))
  (end_list)
  (setq i (vl-position (bk:up (get_tile "marka")) (mapcar '(lambda (r) (bk:up (nth 4 r))) *bk:cn*)))
  (bk:st "c_nom" (itoa (if i (1+ i) 0))))

(defun bk:cat-filter (i v)
  (setq *bk:cf* (bk:pset *bk:cf* i (if (= v 0) "" (nth (1- v) (nth i *bk:cv*)))))
  (bk:cat-fill))

(defun bk:cat-pick (v / r)
  (if (and (> v 0) (setq r (nth (1- v) *bk:cn*)))
    (progn (bk:st "marka" (nth 4 r)) (bk:st "diam" (bk:r (nth 5 r) 1))
           (setq *bk:cf* (list (nth 0 r) (nth 1 r) (nth 2 r) (nth 3 r)))
           (bk:cat-fill) (bk:dstat-upd))))

;; значок у диаметра: зелёный - заполнение труб в норме, красный - превышено, серый - нет труб
(defun bk:dstat-paint (st / w h)
  (setq w (dimx_tile "dstat") h (dimy_tile "dstat"))
  (start_image "dstat")
  (fill_image 0 0 w h (cond ((= st 'ok) 3) ((= st 'bad) 1) (T 8)))
  (end_image))

;; пересчёт при изменении диаметра: окно кабеля (*bk:dmode* = 'cab) или окно создания ('dlg)
(defun bk:dstat-upd (/ code md dm)
  (cond
    ((= *bk:dmode* 'cab)
     (setq *bk:cd* (bk:setf *bk:cd* "diam" (bk:trim (get_tile "diam"))))
     (bk:cab-fill (atoi (get_tile "rows"))))
    (T nil)))

;; значок у диаметра трубы выбранной строки (окно кабеля): по полям "Прокладка", "Диаметр трубы" и диаметру кабеля
(defun bk:mdstat (/ code md dm)
  (setq code (car (nth (atoi (get_tile "prokl")) *bk:types*)) md (bk:num (get_tile "md")) dm (bk:num (get_tile "diam")))
  (if (and code (bk:md-on code) (> md 0) (> dm 0))
    (progn
      (bk:dstat-paint (if (> (bk:tube-fill code md (list dm)) (bk:type-fill code)) 'bad 'ok))
      (bk:st "kind2" (strcat "Труба d" (bk:r md 0) " (внутр. " (bk:r (bk:din code md) 1) " мм): заполнение "
                             (bk:r (bk:tube-fill code md (list dm)) 0) " % (доп. " (bk:r (bk:type-fill code) 0) " %)")))
    (progn (bk:dstat-paint nil) (bk:st "kind2" ""))))

(defun bk:cat-typed (v / r)
  (if (setq r (bk:cat-row v))
    (progn (bk:st "diam" (bk:r (nth 5 r) 1)) (setq *bk:cf* (list (nth 0 r) (nth 1 r) (nth 2 r) (nth 3 r))) (bk:cat-fill)))
  (bk:dstat-upd))

(defun bk:init-common (marka diam layer / r)
  (setq *bk:lays* (bk:layers))
  (if (setq r (bk:cat-row marka)) (setq *bk:cf* (list (nth 0 r) (nth 1 r) (nth 2 r) (nth 3 r))))
  (bk:st "marka" marka) (bk:st "diam" diam)
  (bk:cat-fill)
  (start_list "layer_l") (add_list "<выберите слой>") (foreach l *bk:lays* (add_list l)) (end_list)
  (bk:st "layer" layer)
  (setq r 0)
  (foreach k *bk:cfk* (action_tile k (strcat "(bk:cat-filter " (itoa r) " (atoi $value))")) (setq r (1+ r)))
  (action_tile "c_nom" "(bk:cat-pick (atoi $value))")
  (action_tile "diam" "(bk:dstat-upd)")
  (action_tile "b_catall" "(setq *bk:cf* (list \"\" \"\" \"\" \"\")) (bk:cat-fill)")
  (action_tile "marka" "(bk:cat-typed $value)")
  (action_tile "layer_l" "(if (> (atoi $value) 0) (bk:st \"layer\" (nth (1- (atoi $value)) *bk:lays*)))"))

(setq *bk:dcl-common*
  '(" : boxed_column { label = \"Кабель (справочник cable_type.csv; списки - фильтры, зависят друг от друга)\";"
    "  : row { : popup_list { key = \"c_type\"; label = \"Тип:\"; width = 28; }"
    "          : popup_list { key = \"c_sheath\"; label = \"Оболочка:\"; width = 30; }"
    "          : popup_list { key = \"c_cond\"; label = \"Проводник:\"; width = 28; }"
    "          : popup_list { key = \"c_sect\"; label = \"Сечение:\"; width = 26; } }"
    "  : row { : popup_list { key = \"c_nom\"; label = \"Номенклатура:\"; width = 80; }"
    "          : button { key = \"b_catall\"; label = \"Показать все\"; width = 14; fixed_width = true; }"
    "          : button { key = \"b_catupd\"; label = \"Обновить\"; width = 12; fixed_width = true; } } }"
    " : row { : column { : edit_box { key = \"marka\"; label = \"Номенклатура (вручную):\"; edit_width = 46; fixed_width = true; allow_accept = false; }"
    "                    : row { : popup_list { key = \"layer_l\"; label = \"Слой:\"; width = 34; fixed_width = true; }"
    "                            : edit_box { key = \"layer\"; label = \"или свой:\"; edit_width = 18; fixed_width = true; allow_accept = false; } } }"
    "         : column { : edit_box { key = \"diam\"; label = \"Диаметр кабеля, мм:\"; edit_width = 7; fixed_width = true; allow_accept = false; alignment = right; }"
    "                    : edit_box { key = \"lts\"; label = \"Масштаб типа линии:\"; edit_width = 7; fixed_width = true; allow_accept = false; alignment = right; } } }"))

;;; ---------- окно параметров (создание / несколько кабелей) ----------
;; par: (марка диаметр позиция прокладка высота коэф отступ слой масштаб)
(defun bk:prokl-code (i multi)
  (if multi (if (= i 0) "*" (car (nth (1- i) *bk:types*))) (car (nth i *bk:types*))))

(defun bk:dialog (par multi hdr / fn id res out tp)
  (setq res 5)
  ;; новый кабель: сразу предложить свободную позицию
  (if (not multi) (setq *bk:used* (bk:used-pos) par (if *bk:brpos* par (bk:replace-nth 2 (bk:free-pos (nth 2 par) *bk:used*) par))))
  (if *bk:brpos* (setq *bk:used* nil))   ; ветка: ПОЗИЦИЯ как у основного кабеля - занятость не проверяется
  (while (member res '(5 6))
  (setq fn (bk:write-dcl "blok_kabel.dcl"
             (append
               '("bk_dlg : dialog { label = \"Параметры кабеля\";"
                 " : text { key = \"hdr\"; width = 90; }")
               *bk:dcl-common*
               '(" : row { : edit_box { key = \"pos\"; label = \"ПОЗИЦИЯ кабеля (k1 - дальше k2...):\"; edit_width = 14; allow_accept = false; }"
                 "         : edit_box { key = \"floor\"; label = \"Этаж по умолчанию (если у блоков нет ЭТАЖ):\"; edit_width = 10; allow_accept = false; } }"
                 " : popup_list { key = \"prokl\"; label = \"В чём прокладывается:\"; width = 60; }"
                 " : row { : edit_box { key = \"h\"; label = \"Высота прокладки, м:\"; edit_width = 6; allow_accept = false; }"
                 "         : edit_box { key = \"k\"; label = \"Коэф. запаса:\"; edit_width = 5; allow_accept = false; }"
                 "         : edit_box { key = \"off\"; label = \"Отступ, мм (0 - по точкам):\"; edit_width = 6; allow_accept = false; } }"
                 " : text { key = \"info\"; width = 90; }"
                 " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 16; }"
                 "         : button { key = \"b_types\"; label = \"Способы прокладки...\"; width = 22; }"
                 "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 16; } } }")))
        id (load_dialog fn))
  (if (not (new_dialog "bk_dlg" id))
    (princ (strcat "\nОшибка загрузки диалога (" fn ")."))
    (progn
      (bk:st "hdr" hdr)
      (setq *bk:dmode* 'dlg *bk:dmulti* multi)
      (bk:init-common (nth 0 par) (nth 1 par) (nth 7 par))
      ;; прокладка: все способы; в режиме нескольких кабелей первым - <не менять>
      (start_list "prokl")
      (if multi (add_list "<не менять - участки как есть>"))
      (foreach tp *bk:types* (add_list (cadr tp)))
      (end_list)
      (bk:st "prokl" (itoa (+ (if multi 1 0) (if (and multi (= (nth 3 par) "*")) -1 (bk:tidx (nth 3 par))))))
      (action_tile "prokl" "(setq tp (bk:prokl-code (atoi $value) multi)) (if (bk:type tp) (bk:st \"h\" (rtos (nth 4 (bk:type tp)) 2 1))) (bk:dstat-upd)")
      (bk:dstat-upd)
      (bk:st "pos" (nth 2 par))
      (bk:st "floor" (nth 9 par))
      (bk:st "h" (nth 4 par)) (bk:st "k" (nth 5 par)) (bk:st "off" (nth 6 par)) (bk:st "lts" (nth 8 par))
      (if multi (progn (mode_tile "off" 1)
                       (bk:st "info" "Изменяются только поля, где нет <разные>.")))
      (setq *bk:rd* (strcat "(setq out (list (bk:trim (get_tile \"marka\")) (bk:trim (get_tile \"diam\")) (bk:trim (get_tile \"pos\"))"
                " (bk:prokl-code (atoi (get_tile \"prokl\")) multi) (bk:trim (get_tile \"h\")) (bk:trim (get_tile \"k\"))"
                " (bk:trim (get_tile \"off\")) (bk:trim (get_tile \"layer\")) (bk:trim (get_tile \"lts\")) (bk:trim (get_tile \"floor\"))))"))
      (action_tile "accept"
        (strcat *bk:rd* " (cond ((or (= (car out) \"\") (= (nth 7 out) \"\")) (bk:st \"info\" \"Укажите марку и слой.\"))"
                (if multi "" " ((or (= (nth 2 out) \"\") (member (strcase (nth 2 out)) *bk:used*)) (bk:st \"info\" (strcat \"Позиция \" (nth 2 out) \" уже есть. Предложена свободная.\")) (set_tile \"pos\" (bk:free-pos (nth 2 out) *bk:used*)))")
                " (T (done_dialog 1)))"))
      (action_tile "b_types" (strcat *bk:rd* " (setq par out) (done_dialog 5)"))
      (action_tile "b_catupd" (strcat *bk:rd* " (setq par out) (done_dialog 6)"))
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)))
  (vl-file-delete fn)
  (cond ((= res 5) (bk:types-dialog)) ((= res 6) (bk:cat-update T))))
  (if (= res 1) out))

(if (or (/= (length *bk:par*) 10) (vl-some 'null *bk:par*))
  (setq *bk:par* (list "нг(А)-FRLS 1x2x0.5" "5.4" "k1" "GOFRA" "3.0" "1.1" "0" "КАБЕЛИ" "100" "")))

;;; ---------- окно кабеля с таблицей ----------
;; *bk:cd* - данные кабеля, *bk:cp* - участки, *bk:rows* - строки расчёта
(defun bk:cab-fill (sel / st)
  (setq *bk:rows* (bk:calc *bk:cd* *bk:cp*))
  (start_list "rows")
  (foreach r *bk:rows*
    (add_list (strcat (bk:cut (nth 1 r) 18) "\t"
                      (bk:cut (strcat (bk:row-tname r *bk:cp*) (if (/= (nth 9 r) "") (strcat " " (nth 9 r)) "")
                                      (if (and (bk:md-on (nth 5 r)) (> (nth 8 r) 0)) (strcat " d" (rtos (nth 8 r) 2 0)) ""))
                              28)
                      "\t" (bk:ctr (if (= (nth 11 r) "1") "сущ." "") 5)
                      "\t" (bk:ctr (if (and (bk:md-on (nth 5 r)) (> (nth 8 r) 0) (> (bk:fn *bk:cd* "diam") 0))
                                      (bk:r (bk:tube-fill (nth 5 r) (nth 8 r) (list (bk:fn *bk:cd* "diam"))) 0) "") 6)
                      "\t" (bk:ctr (nth 10 r) 8)
                      "\t" (bk:ctr (if (nth 2 r) (bk:r (nth 2 r) 2) "") 7)
                      "\t" (bk:ctr (itoa (bk:ceil0 (nth 3 r))) 7)
                      "\t" (bk:ctr (bk:r (nth 4 r) 2) 6)
                      "\t" (bk:ctr (itoa (bk:ceil0 (nth 7 r))) 9))))
  (end_list)
  (bk:st "rows" (itoa (min sel (max 0 (1- (length *bk:rows*))))))
  (bk:st "total" (strcat "ИТОГО с запасом: " (itoa (bk:ceil0 (bk:total *bk:rows*))) " м   (без запаса: "
                         (itoa (bk:ceil0 (apply '+ (mapcar '(lambda (r) (nth 3 r)) *bk:rows*)))) " м)"))
  (bk:cab-pick sel))

(defun bk:cab-pick (row / r p)
  (if (setq r (nth row *bk:rows*))
    (progn
      (bk:st "prokl" (itoa (bk:tidx (nth 5 r))))
      (bk:st "md" (if (and (bk:md-on (nth 5 r)) (> (nth 8 r) 0)) (rtos (nth 8 r) 2 0) ""))
      (mode_tile "md" (if (bk:md-on (nth 5 r)) 0 1))
      (setq *bk:fillinfo*
            (if (and (bk:md-on (nth 5 r)) (> (nth 8 r) 0) (> (bk:fn *bk:cd* "diam") 0))
              (strcat "   Труба d" (bk:r (nth 8 r) 0) " (внутр. " (bk:r (bk:din (nth 5 r) (nth 8 r)) 1) " мм): заполнение "
                      (bk:r (bk:tube-fill (nth 5 r) (nth 8 r) (list (bk:fn *bk:cd* "diam"))) 0) " % (доп. "
                      (bk:r (bk:type-fill (nth 5 r)) 0) " %)")
              ""))
      (bk:st "h" (if (nth 2 r) (bk:r (nth 2 r) 2) ""))
      (bk:st "k" (bk:r (nth 4 r) 2))
      (mode_tile "h" (if (member (car r) '("S" "B" "E")) 0 1))
      ;; этаж и длина - только у участков
      (setq p (if (= (car r) "S") (nth (1- (nth 6 r)) *bk:cp*)))
      (bk:st "sfl" (if p (bk:sflm p) ""))
      (bk:st "slen" (if (and p (> (bk:slen p) 0)) (bk:r (bk:slen p) 1) ""))
      (bk:st "ex" (if (= (nth 11 r) "1") "1" "0"))
      (mode_tile "sfl" (if p 0 1)) (mode_tile "slen" (if p 0 1)) (mode_tile "ex" (if (member (car r) '("S" "B" "E")) 0 1))
      (bk:st "kind" (cond ((= (car r) "S") (strcat "Участок: прокладка, высота, коэф., этаж (авто: " (if p (cond ((nth 13 p)) ("")) "") "), длина"))
                          ((member (car r) '("B" "E"))
                           "Опуск: прокладка (по умолчанию гофр. труба), диаметр трубы, коэф., сущ.; Высота = высота прибора (атрибут ВЫСОТА)")
                          (T "Переход по высоте: прокладка и коэф. запаса")))
      (bk:mdstat))))

(defun bk:cab-apply (row / r code k n p i md)
  (if (setq r (nth row *bk:rows*))
    (progn
      (setq code (car (nth (atoi (get_tile "prokl")) *bk:types*))
            k (bk:num (get_tile "k")) n (nth 6 r)
            md (if (bk:md-on code) (bk:num (get_tile "md")) 0.0))
      (cond
        ((= (car r) "B") (setq *bk:cd* (bk:setf (bk:setf (bk:setf (bk:setf *bk:cd* "bcode" code) "bk" k)
                                                "bh" (bk:trim (get_tile "h"))) "bmd" md)
                                 *bk:cd* (bk:setf *bk:cd* "bex" (if (= (get_tile "ex") "1") "1" ""))))
        ((= (car r) "E") (setq *bk:cd* (bk:setf (bk:setf (bk:setf (bk:setf *bk:cd* "ecode" code) "ek" k)
                                                "eh" (bk:trim (get_tile "h"))) "emd" md)
                                 *bk:cd* (bk:setf *bk:cd* "eex" (if (= (get_tile "ex") "1") "1" ""))))
        ((= (car r) "T")
         (setq p (nth (1- n) *bk:cp*)
               *bk:cp* (bk:replace-nth (1- n) (bk:pset (bk:replace-nth 6 k (bk:replace-nth 5 code p)) 9 md) *bk:cp*)))
        (T
         (setq p (nth (1- n) *bk:cp*)
               *bk:cp* (bk:replace-nth (1- n)
                         (bk:pset (bk:pset (bk:pset (bk:pset (bk:pset (bk:replace-nth 3 k (bk:replace-nth 1 (bk:num (get_tile "h")) (bk:replace-nth 0 code p))) 8 md)
                                  10 (if (and (= code (car p)) (= (bk:type-mode code) "O")) (bk:sz p) ""))
                                  11 (bk:num (get_tile "slen"))) 12 (bk:trim (get_tile "sfl"))) 14 (if (= (get_tile "ex") "1") "1" ""))
                         *bk:cp*))))
      (bk:cab-fill row))))

;; этажи всех участков кабеля - заново автоматически (ручные этажи сбрасываются)
(defun bk:cab-flauto (row / fls i)
  (setq *bk:cp* (mapcar '(lambda (p) (bk:pset p 12 "")) *bk:cp*)
        fls (bk:floors *bk:cd* *bk:cp*) i -1)
  (setq *bk:cp* (mapcar '(lambda (p) (bk:pset p 13 (nth (setq i (1+ i)) fls))) *bk:cp*))
  (bk:cab-fill row)
  (bk:st "kind" (strcat "Этажи определены автоматически: " (bk:join (vl-remove "" fls) ", ") ". Запись - по OK.")))

(defun bk:cab-kall (row / k)
  (setq k (bk:num (get_tile "k")))
  (setq *bk:cp* (mapcar '(lambda (p) (bk:replace-nth 6 k (bk:replace-nth 3 k p))) *bk:cp*)
        *bk:cd* (bk:setf (bk:setf *bk:cd* "bk" k) "ek" k))
  (bk:cab-fill row))

(defun bk:cab-save ()
  (foreach k '("pos" "marka" "diam" "layer" "lts")
    (setq *bk:cd* (bk:setf *bk:cd* k (bk:trim (get_tile k))))))

(defun bk:cab-dialog (/ fn id res sel r e tp)
  (setq fn (bk:write-dcl "blok_kabel_cab.dcl"
             (append
               '("bk_cab : dialog { label = \"Кабель: параметры и участки\";"
                 " : row { : edit_box { key = \"pos\"; label = \"ПОЗИЦИЯ:\"; edit_width = 14; fixed_width = true; allow_accept = false; alignment = centered; }"
                 "         : text { key = \"fromto\"; width = 70; alignment = centered; } }"
                 " : text { key = \"rooms\"; width = 96; }"
                 " : row { : button { key = \"b_beg\"; label = \"Начало - указать блок <\"; }"
                 "         : button { key = \"b_end\"; label = \"Конец - указать блок <\"; }"
                 "         : button { key = \"b_auto\"; label = \"Найти по концам\"; }"
                 "         : button { key = \"b_unb\"; label = \"Отвязать\"; } }")
               *bk:dcl-common*
               '(" : list_box { key = \"hdr_r\"; height = 2; width = 104; tabs = \"20 50 57 66 76 85 94 102\"; is_tab_stop = false; }"
                 " : list_box { key = \"rows\"; height = 12; width = 104; tabs = \"20 50 57 66 76 85 94 102\"; }"
                 " : boxed_column { label = \"Выбранная строка\";"
                 "   : text { key = \"kind\"; width = 90; }"
                 "   : text { key = \"kind2\"; width = 90; }"
                 "   : row { : column { : popup_list { key = \"prokl\"; label = \"Прокладка:\"; width = 42; fixed_width = true; }"
                 "                      : edit_box { key = \"sfl\"; label = \"Этаж (пусто - авто):\"; edit_width = 8; fixed_width = true; allow_accept = false; } }"
                 "           : column { : row { : edit_box { key = \"md\"; label = \"Диаметр трубы, мм:\"; edit_width = 6; fixed_width = true; allow_accept = false; }"
                 "                               : image { key = \"dstat\"; width = 3; height = 1.2; fixed_width = true; fixed_height = true; color = 8; } }"
                 "                      : edit_box { key = \"slen\"; label = \"Длина, м (пусто - по черт.):\"; edit_width = 6; fixed_width = true; allow_accept = false; } }"
                 "           : column { : edit_box { key = \"h\"; label = \"Высота, м:\"; edit_width = 6; fixed_width = true; allow_accept = false; alignment = right; }"
                 "                      : edit_box { key = \"k\"; label = \"Коэф. запаса:\"; edit_width = 6; fixed_width = true; allow_accept = false; alignment = right; } }"
                 "           : column { : toggle { key = \"ex\"; label = \"сущ. трасса\"; }"
                 "                      : button { key = \"b_flauto\"; label = \"Этажи - автоматически\"; } } }"
                 "   : row { : button { key = \"b_apply\"; label = \"Применить к строке\"; }"
                 "           : button { key = \"b_kall\"; label = \"Коэф. - всем строкам\"; }"
                 "           : button { key = \"b_show\"; label = \"Показать участок\"; } } }"
                 " : text { key = \"total\"; width = 96; }"
                 " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 16; }"
                 "         : button { key = \"b_types\"; label = \"Способы прокладки...\"; width = 22; }"
                 "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 16; } } }")))
        res 2 sel 0)
  (while (member res '(2 3 4 5 6))
    (setq id (load_dialog fn))
    (if (not (new_dialog "bk_cab" id))
      (setq res 0)
      (progn
        (bk:st "pos" (bk:f *bk:cd* "pos"))
        (bk:fromto)
        (setq *bk:dmode* 'cab)
        (bk:init-common (bk:f *bk:cd* "marka") (bk:f *bk:cd* "diam") (bk:f *bk:cd* "layer"))
        (bk:st "lts" (bk:f *bk:cd* "lts"))
        (start_list "prokl") (foreach tp *bk:types* (add_list (cadr tp))) (end_list)
        
        (start_list "hdr_r") (add_list (strcat "Строка\tПрокладка\t" (bk:ctr "Сущ." 5) "\t" (bk:ctr "Зап.,%" 6) "\t" (bk:ctr "Этаж" 8) "\t" (bk:ctr "Выс.,м" 7) "\t"
                                  (bk:ctr "Дл.,м" 7) "\t" (bk:ctr "Коэф." 6) "\t" (bk:ctr "С запасом" 9))) (end_list)
        (bk:cab-fill sel)
        (action_tile "rows" "(setq sel (atoi $value)) (bk:cab-pick sel)")
        (action_tile "b_apply" "(setq sel (atoi (get_tile \"rows\"))) (bk:cab-apply sel)")
        (action_tile "b_kall" "(bk:cab-kall (atoi (get_tile \"rows\")))")
        (action_tile "b_flauto" "(bk:cab-flauto (atoi (get_tile \"rows\")))")
        (action_tile "md" "(bk:mdstat)")
        (action_tile "prokl" "(mode_tile \"md\" (if (bk:md-on (car (nth (atoi $value) *bk:types*))) 0 1)) (bk:mdstat)")
        (action_tile "b_show" "(setq sel (atoi (get_tile \"rows\"))) (bk:cab-save) (done_dialog 2)")
        (action_tile "accept" "(bk:cab-save) (done_dialog 1)")
        (action_tile "b_beg" "(bk:cab-save) (done_dialog 3)")
        (action_tile "b_end" "(bk:cab-save) (done_dialog 4)")
        (action_tile "b_auto" "(bk:bind-auto) (bk:fromto) (bk:cab-fill (atoi (get_tile \"rows\")))")
        (action_tile "b_unb" "(setq *bk:cd* (bk:setf (bk:setf (bk:setf (bk:setf *bk:cd* \"beg\" \"\") \"end\" \"\") \"bfix\" \"1\") \"efix\" \"1\")) (bk:fromto) (bk:cab-fill (atoi (get_tile \"rows\")))")
        (action_tile "b_types" "(bk:cab-save) (done_dialog 5)")
        (action_tile "b_catupd" "(bk:cab-save) (done_dialog 6)")
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (cond
          ((and (= res 2) (setq r (nth sel *bk:rows*)) (nth 6 r)
                (setq e (nth 4 (nth (1- (nth 6 r)) *bk:cp*))) (entget e))
           (redraw e 3) (getstring "\nУчасток подсвечен. Enter - вернуться: ") (redraw e 4))
          ((= res 3) (bk:bind-pick T))
          ((= res 4) (bk:bind-pick nil))
          ((= res 5) (bk:types-dialog))
          ((= res 6) (bk:cat-update T))))))
  (vl-file-delete fn)
  (= res 1))

;;; ---------- привязка начала / конца к блокам ----------
(defun bk:fromto ()
  (bk:st "fromto" (strcat "Откуда: " (bk:dev-pos (bk:f *bk:cd* "beg"))
                          (if (= (bk:f *bk:cd* "bfix") "1") " (вручную)" " (авто)")
                          "    Куда: " (bk:dev-pos (bk:f *bk:cd* "end"))
                          (if (= (bk:f *bk:cd* "efix") "1") " (вручную)" " (авто)")))
  (bk:st "rooms" (strcat "Помещение начала: " (bk:nz (bk:dev-room (bk:f *bk:cd* "beg")))
                         "    Помещение конца: " (bk:nz (bk:dev-room (bk:f *bk:cd* "end"))))))
(defun bk:nz (s) (if (= s "") "-" s))

;; найти приборы у концов заново (снять ручную привязку)
(defun bk:bind-auto ()
  (setq *bk:cd* (bk:setf (bk:setf *bk:cd* "bfix" "0") "efix" "0"))
  (if *bk:cp*
    (setq *bk:cd* (bk:setf (bk:setf *bk:cd*
                    "beg" (bk:block-at (car (caddr (car *bk:cp*)))))
                    "end" (bk:block-at (last (caddr (last *bk:cp*))))))))

;; указать блок на чертеже; beg=T - начало, nil - конец
(defun bk:bind-pick (beg / es e k ip p src r old)
  (setq old *bk:cd* es (entsel (strcat "\nУкажите блок " (if beg "НАЧАЛА" "КОНЦА") " кабеля (Enter - отмена): ")))
  (if (and es (= (cdr (assoc 0 (entget (setq e (car es))))) "INSERT"))
    (progn
      (setq *bk:cd* (bk:setf (bk:setf (bk:setf *bk:cd* (if beg "beg" "end") (cdr (assoc 5 (entget e))))
                                      (if beg "bfix" "efix") "1")
                             (if beg "bh" "eh") ""))
      (if beg
        (progn (initget "Образец Подтянуть Нет")
               (setq k (getkword "\nНачало: перестроить путь [Образец кабеля/Подтянуть к блоку/Нет] <Образец>: "))
               (if (null k) (setq k "Образец")))
        (progn (initget "Да Нет")
               (setq k (getkword "\nПодтянуть конец кабеля к точке вставки блока? [Да/Нет] <Да>: "))))
      (if (= k "Образец")
        (if (setq src (bk:pick-src))
          (progn
            (setq r (bk:reroute-parts *bk:cd* e (bk:net-of (list src (bk:f *bk:cd* "id"))) (bk:net-of (list src))))
            (if (= (type r) 'STR)
              (progn (setq *bk:cd* old)
                     (alert (strcat "Привязка невозможна, трассировка отсутствует:\n" r)))
              (progn (setq *bk:cp* r)
                     (princ "\nПуть перестроен по образцу. Запись - по OK в окне свойств."))))
          (setq *bk:cd* old)))
      (if (and (/= k "Нет") (/= k "Образец"))
        (progn
          (setq ip (bk:2d (trans (cdr (assoc 10 (entget e))) e 0)))
          (if beg
            (setq p (car *bk:cp*)
                  *bk:cp* (bk:replace-nth 0 (bk:replace-nth 2 (cons ip (cdr (caddr p))) p) *bk:cp*))
            (setq p (last *bk:cp*)
                  *bk:cp* (bk:replace-nth (1- (length *bk:cp*))
                            (bk:replace-nth 2 (append (reverse (cdr (reverse (caddr p)))) (list ip)) p) *bk:cp*))))))
    (if es (princ "\nЭто не блок."))))

;;; ---------- способы прокладки: окно редактирования ----------
(defun bk:type-used (code / r d)
  (foreach e (bk:all-segs)
    (setq d (bk:get e))
    (if (member code (list (bk:f d "code") (bk:f d "bcode") (bk:f d "ecode") (bk:f d "tcode"))) (setq r T)))
  r)

(defun bk:types-fill (sel)
  (start_list "lst")
  (foreach p *bk:types*
    (add_list (strcat (cadr p) "\t" (cond ((null (nth 3 p)) "штриховая") ((= (nth 3 p) "-") "сплошная") (T (strcat "-" (nth 3 p) "-")))
                      "\t" (rtos (nth 4 p) 2 1) "\t" (rtos (if (nth 5 p) (nth 5 p) 12.0) 2 1))))
  (end_list)
  (bk:st "lst" (itoa sel))
  (bk:types-pick sel))

(defun bk:types-pick (i / p)
  (if (setq p (nth i *bk:types*))
    (progn (bk:st "mode" (itoa (cond ((vl-position (bk:type-mode (car p)) '("O" "E" "N"))) (1))))
           (bk:st "fill" (rtos (bk:type-fill (car p)) 2 0))
           (bk:st "name" (cadr p))
           (bk:st "txt" (cond ((null (nth 3 p)) "") (T (nth 3 p))))
           (bk:st "h" (rtos (nth 4 p) 2 1))
           (bk:st "dash" (rtos (if (nth 5 p) (nth 5 p) 12.0) 2 1))
           (bk:st "col" (itoa (bk:tcolor (car p)))))))

;; собрать тип из полей; code - код, при изменении - новое имя типа линии
(defun bk:types-make (code / txt)
  (setq txt (bk:trim (get_tile "txt")))
  (list code (bk:lc1 (bk:trim (get_tile "name")))
        (if (= txt "-") "Continuous"
          (strcat "BK_" code "_" (vl-string-translate "." "_" (rtos (getvar "CDATE") 2 6))))
        (if (= txt "") nil txt)
        (bk:num (get_tile "h"))
        (max 1.0 (bk:num (get_tile "dash")))
        (nth (atoi (get_tile "mode")) '("O" "E" "N"))
        (max 1.0 (bk:num (get_tile "fill")))
        (max 1 (min 255 (atoi (get_tile "col"))))))

(defun bk:types-dialog (/ fn id res n c)
  (setq fn (bk:write-dcl "blok_kabel_types.dcl"
             '("bk_types : dialog { label = \"Способы прокладки (типы линий)\";"
               " : text { label = \"Название                                  Линия        Высота, м   Штрих\"; }"
               " : list_box { key = \"lst\"; height = 12; width = 76; tabs = \"42 56 66\"; }"
               " : edit_box { key = \"name\"; label = \"Название:\"; edit_width = 44; allow_accept = false; }"
               " : row { : edit_box { key = \"txt\"; label = \"Надпись в линии:\"; edit_width = 6; allow_accept = false; }"
               "         : edit_box { key = \"h\"; label = \"Высота по умолч., м:\"; edit_width = 5; allow_accept = false; }"
               "         : edit_box { key = \"dash\"; label = \"Длина штриха:\"; edit_width = 5; allow_accept = false; } }"
               " : row { : popup_list { key = \"mode\"; label = \"Учёт в спецификации:\"; width = 50; }"
               "         : edit_box { key = \"fill\"; label = \"Доп. заполнение, %:\"; edit_width = 5; allow_accept = false; }"
               "         : edit_box { key = \"col\"; label = \"Цвет (1-255):\"; edit_width = 4; allow_accept = false; }"
               "         : button { key = \"b_col\"; label = \"...\"; width = 4; fixed_width = true; } }"
               " : text { label = \"Надпись: буквы (Т, Л, Тг...);  пусто - штриховая;  знак - (минус) - сплошная.\"; }"
               " : text { key = \"info\"; width = 76; }"
               " : row { : button { key = \"b_add\"; label = \"Добавить новый\"; }"
               "         : button { key = \"b_upd\"; label = \"Изменить выбранный\"; }"
               "         : button { key = \"b_del\"; label = \"Удалить выбранный\"; }"
               "         : button { key = \"cancel\"; label = \"Закрыть\"; is_cancel = true; } } }"))
        id (load_dialog fn))
  (if (new_dialog "bk_types" id)
    (progn
      (start_list "mode")
      (foreach x '("Общий для группы кабелей (лоток, короб): наложенные - один раз" "По каждому кабелю (свой материал)" "Не считать")
        (add_list x))
      (end_list)
      (bk:types-fill 0)
      (action_tile "lst" "(bk:types-pick (atoi $value))")
      (action_tile "b_col" "(setq c (acad_colordlg (max 1 (atoi (get_tile \"col\"))) nil)) (if c (bk:st \"col\" (itoa c)))")
      (action_tile "b_add"
        "(if (= (bk:trim (get_tile \"name\")) \"\") (bk:st \"info\" \"Введите название.\") (progn (setq n 1) (while (bk:type (setq c (strcat \"U\" (itoa n)))) (setq n (1+ n))) (setq *bk:types* (append *bk:types* (list (bk:types-make c)))) (bk:save-types) (bk:types-fill (1- (length *bk:types*))) (bk:st \"info\" \"Добавлено.\")))")
      (action_tile "b_upd"
        "(setq n (atoi (get_tile \"lst\")) c (car (nth n *bk:types*))) (setq *bk:types* (bk:replace-nth n (bk:types-make c) *bk:types*)) (bk:save-types) (bk:retype c) (bk:types-fill n) (bk:st \"info\" \"Изменено, линии на чертеже обновлены.\")")
      (action_tile "b_del"
        "(setq n (atoi (get_tile \"lst\")) c (car (nth n *bk:types*))) (if (bk:type-used c) (bk:st \"info\" \"Этот способ используется в кабелях - удалить нельзя.\") (progn (setq *bk:types* (vl-remove (nth n *bk:types*) *bk:types*)) (bk:save-types) (bk:types-fill 0) (bk:st \"info\" \"Удалено.\")))")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)))
  (vl-file-delete fn))

;; обновить тип линии у всех участков с этим способом прокладки
(defun bk:retype (code / lt)
  (setq lt (bk:load-lt code))
  (foreach e (bk:all-segs)
    (if (= (bk:f (bk:get e) "code") code)
      (progn (vla-put-Linetype (vlax-ename->vla-object e) lt)
             (if (= (bk:pcolor) "T") (bk:seg-color e code))))))

;; этаж кабеля пустой -> из атрибута ЭТАЖ блока начала
(defun bk:floor-auto (d / f)
  (if (and (= (bk:f d "floor") "") (/= (setq f (bk:attr (bk:hent (bk:f d "beg")) "ЭТАЖ")) ""))
    (foreach e (bk:segs (bk:f d "id")) (bk:put e (bk:setf (bk:get e) "floor" f)))))

;;; ---------- ММ_КАБЕЛЬ ----------
(defun bk:cmd-draw (/ par p prev-e e r pts d n)
  (if (setq par (bk:dialog *bk:par* nil "После OK рисуйте кабель полилинией от прибора до прибора."))
    (progn
      (setq *bk:par* par n 0)
      (while (setq p (getpoint (strcat "\nКабель " (nth 2 *bk:par*) ": первая точка (у прибора) <выход>: ")))
        (setq prev-e (entlast))
        (command "_.PLINE" p)
        (while (> (getvar "CMDACTIVE") 0) (command pause))
        (setq e (entlast))
        (if (and e (not (eq e prev-e)) (= (cdr (assoc 0 (entget e))) "LWPOLYLINE"))
          (progn
            (if (/= (bk:num (nth 6 *bk:par*)) 0.0)
              (progn
                (setq r (vl-catch-all-apply 'vlax-invoke
                          (list (vlax-ename->vla-object e) 'Offset (bk:num (nth 6 *bk:par*)))))
                (if (and (not (vl-catch-all-error-p r)) r)
                  (progn (entdel e) (setq e (vlax-vla-object->ename (car r)))))))
            (setq pts (bk:pts e) d nil)
            (foreach kv (list (cons "id" (cdr (assoc 5 (entget e)))) (cons "marka" (nth 0 *bk:par*))
                              (cons "diam" (nth 1 *bk:par*)) (cons "pos" (nth 2 *bk:par*))
                              (cons "layer" (nth 7 *bk:par*)) (cons "lts" (nth 8 *bk:par*))
                              (cons "floor" (nth 9 *bk:par*)))
              (setq d (bk:setf d (car kv) (cdr kv))))
            (bk:put e d)
            (setq d (bk:rebuild d (list (list (nth 3 *bk:par*) (bk:num (nth 4 *bk:par*)) pts
                                              (bk:num (nth 5 *bk:par*)) nil "" 0.0 (bk:look e)))))
            (princ (strcat "\nКабель " (nth 2 *bk:par*) "  откуда: " (bk:dev-pos (bk:f d "beg"))
                           "  куда: " (bk:dev-pos (bk:f d "end")) "  " (bk:len-text (bk:f d "id"))))
            (setq n (1+ n)
                  *bk:par* (bk:replace-nth 2 (bk:free-pos (bk:incr (nth 2 *bk:par*)) nil) *bk:par*)))))
      (princ (strcat "\nНарисовано кабелей: " (itoa n) "."))))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_ИЗ_ЛИНИИ ----------
(defun bk:obj-pts (e / o n i l)                  ; точки полилинии/отрезка
  (setq o (vlax-ename->vla-object e) n (fix (vlax-curve-getEndParam o)) i 0)
  (if (= (cdr (assoc 0 (entget e))) "LINE") (setq n 1))
  (while (<= i n)
    (setq l (cons (bk:2d (vlax-curve-getPointAtParam o (if (= (cdr (assoc 0 (entget e))) "LINE")
                                                          (* i (vlax-curve-getEndParam o)) i))) l)
          i (1+ i)))
  (reverse l))

(defun bk:cmd-from (/ par l d n look pts)
  (princ "\nВыберите линии/полилинии, которые станут кабелями: ")
  (if (and (setq l (bk:ss->l (ssget '((0 . "LWPOLYLINE,LINE,POLYLINE")))))
           (setq par (bk:dialog *bk:par* nil
                       (strcat "Выбрано линий: " (itoa (length l))
                               ". Каждая станет отдельным кабелем, ПОЗИЦИЯ - по порядку."))))
    (progn
      (setq *bk:par* par n 0)
      (foreach e l
        (if (and (not (bk:get e)) (>= (length (setq pts (bk:obj-pts e))) 2))
          (progn
            (setq look (bk:look e) d nil)
            (foreach kv (list (cons "id" (cdr (assoc 5 (entget e)))) (cons "marka" (nth 0 *bk:par*))
                              (cons "diam" (nth 1 *bk:par*)) (cons "pos" (nth 2 *bk:par*))
                              (cons "layer" (nth 7 *bk:par*)) (cons "lts" (nth 8 *bk:par*))
                              (cons "floor" (nth 9 *bk:par*)))
              (setq d (bk:setf d (car kv) (cdr kv))))
            (entdel e)
            (setq d (bk:rebuild d (list (list (nth 3 *bk:par*) (bk:num (nth 4 *bk:par*)) pts
                                              (bk:num (nth 5 *bk:par*)) nil "" 0.0 look))))
            (princ (strcat "\nКабель " (nth 2 *bk:par*) "  откуда: " (bk:dev-pos (bk:f d "beg"))
                           "  куда: " (bk:dev-pos (bk:f d "end")) "  " (bk:len-text (bk:f d "id"))))
            (setq n (1+ n) *bk:par* (bk:replace-nth 2 (bk:free-pos (bk:incr (nth 2 *bk:par*)) nil) *bk:par*)))))
      (princ (strcat "\nСделано кабелей: " (itoa n) ". Уже бывшие кабелями линии пропущены."))))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_УЧАСТОК ----------
;; Участок между вершинами -> новый способ прокладки для ВСЕХ кабелей на нём.
;; Окно показывает сечения кабелей; для лотка/короба (общий для группы) -
;; сечение группы, размер Ш x В и заполнение.

;; допуск совпадения линий кабелей (ед. чертежа): кабели "на одном участке" - только точно наложенные
(if (not *bk:otol*) (setq *bk:otol* 1.0))
(defun bk:ptol () (max 1.0 (* 1.5 (getvar "PICKBOX") (/ (getvar "VIEWSIZE") (cadr (getvar "SCREENSIZE"))))))

;; все кабели, идущие по отрезку q1-q2: список (id ename a b)
(defun bk:on-piece (q1 q2 / tol out o pts a b L ux uy s1 s2 d1 d2 r1 r2 lo hi id prm)
  ;; все кабели, лежащие поверх отрезка q1-q2 (целиком или частично): (id ename a b)
  (setq tol *bk:otol* L (distance q1 q2))
  (if (> L 1e-6)
    (progn
      (setq ux (/ (- (car q2) (car q1)) L) uy (/ (- (cadr q2) (cadr q1)) L))
      (foreach e (bk:all-segs)
        (setq id (bk:f (bk:get e) "id") pts (bk:pts e) lo nil hi nil)
        (while (cdr pts)
          (setq a (car pts) b (cadr pts) pts (cdr pts)
                ;; расстояние вершин отрезка до линии q1-q2 и их положение вдоль неё
                d1 (abs (- (* (- (car a) (car q1)) uy) (* (- (cadr a) (cadr q1)) ux)))
                d2 (abs (- (* (- (car b) (car q1)) uy) (* (- (cadr b) (cadr q1)) ux)))
                s1 (+ (* (- (car a) (car q1)) ux) (* (- (cadr a) (cadr q1)) uy))
                s2 (+ (* (- (car b) (car q1)) ux) (* (- (cadr b) (cadr q1)) uy)))
          (if (and (< d1 tol) (< d2 tol))
            (progn
              (setq r1 (max 0.0 (min s1 s2)) r2 (min L (max s1 s2)))
              (if (> (- r2 r1) tol)
                (setq lo (if lo (min lo r1) r1) hi (if hi (max hi r2) r2))))))
        ;; кабель должен лежать на ВСЁМ выбранном участке (частично совпадающие - не трогаем)
        (if (and lo (<= lo tol) (>= hi (- L tol)))
          (setq out (cons (list id e
                                (list (+ (car q1) (* lo ux)) (+ (cadr q1) (* lo uy)))
                                (list (+ (car q1) (* hi ux)) (+ (cadr q1) (* hi uy))))
                          out))))))
  (reverse out))

;; найти текущий сегмент кабеля id, лежащий на точках p1-p2, и параметры: (ename a b)
(defun bk:piece-of (id p1 p2 / tol r o c1 c2 a b tmp)
  (setq tol (bk:ptol))
  (foreach e (bk:segs id)
    (if (null r)
      (progn
        (setq o (vlax-ename->vla-object e)
              c1 (vlax-curve-getClosestPointTo o (list (car p1) (cadr p1) 0.0))
              c2 (vlax-curve-getClosestPointTo o (list (car p2) (cadr p2) 0.0)))
        (if (and (< (distance (bk:2d c1) p1) tol) (< (distance (bk:2d c2) p2) tol))
          (progn (setq a (vlax-curve-getParamAtPoint o c1) b (vlax-curve-getParamAtPoint o c2))
                 (if (> a b) (setq tmp a a b b tmp))
                 (if (> (- b a) 1e-6) (setq r (list e a b))))))))
  r)

;; часть a..b участка e получает способ code, высоту h (nil - как было), коэф. k, размер sz
(defun bk:set-piece (e a b code h k sz md ex fl / d o id parts)
  (setq d (bk:get e) o (vlax-ename->vla-object e) id (bk:f d "id"))
  (foreach p (bk:parts id)
    (if (eq (nth 4 p) e)
      (setq parts (append parts
                    (list (bk:replace-nth 2 (bk:sub e (vlax-curve-getStartParam o) a) p)
                          ;; этаж участка: "" - как было, "*" - авто, иначе - заданный
                          (bk:pset (bk:pset (bk:pset (list code (if h h (cadr p)) (bk:sub e a b) k nil "" 0.0 (nth 7 p) md 0.0) 10 sz) 14 (if ex ex ""))
                                   12 (cond ((or (null fl) (= fl "")) (bk:sflm p)) ((= fl "*") "") (T fl)))
                          (bk:replace-nth 6 0.0 (bk:replace-nth 5 "" (bk:replace-nth 2 (bk:sub e b (vlax-curve-getEndParam o)) p))))))
      (setq parts (append parts (list p)))))
  (bk:rebuild d parts))

;; сечение кабеля, мм2
(defun bk:csec (dm) (/ (* pi dm dm) 4.0))

;; расчёт группы: (n SumS Dпучка dmax)
(defun bk:grp-calc (ds / n s2 dmax sS)
  (setq n (length ds) s2 0.0 dmax 0.0 sS 0.0)
  (foreach dm ds (setq s2 (+ s2 (* dm dm)) dmax (max dmax dm) sS (+ sS (bk:csec dm))))
  (list n sS (if (> n 0) (max dmax (* (bk:kpack n) (sqrt (/ s2 n)))) 0.0) dmax))

;; обновить расчёт в окне участка
(defun bk:seg-upd (/ code grp c w hh f st fill md)
  (setq code (car (nth (atoi (get_tile "prokl")) *bk:types*))
        grp (= (bk:type-mode code) "O")
        c (bk:grp-calc (mapcar 'cadr *bk:sc*)))
  (foreach k '("w" "hh" "fill") (mode_tile k (if grp 0 1)))
  (mode_tile "md" (if grp 1 0))
  (bk:st "sum" (strcat "Кабелей: " (itoa (car c)) "   сечение всех кабелей Sum S = " (bk:r (cadr c) 0)
                       " мм2   диаметр пучка D = " (bk:r (caddr c) 1) " мм"))
  (if grp
    (progn
      (setq w (bk:num (get_tile "w")) hh (bk:num (get_tile "hh")) f (max 1.0 (bk:num (get_tile "fill")))
            st (* w hh) fill (if (> st 0) (* 100.0 (/ (cadr c) st)) 0.0))
      (bk:st "res" (strcat "Группа в " (bk:spec-name (bk:tname code)) " " (bk:r w 0) "x" (bk:r hh 0)
                           ": заполнение " (bk:r fill 1) " % из допустимых " (bk:r f 0) " %"
                           (cond ((<= st 0) "  - укажите размер")
                                 ((> fill f) (strcat "  - МАЛО! нужно сечение не менее " (bk:r (/ (cadr c) (/ f 100.0)) 0) " мм2"))
                                 (T "  - достаточно")))))
    (progn
      (setq f (bk:type-fill code) md (bk:num (get_tile "md")))
      (bk:st "res" (strcat "Каждый кабель в своей трубе: наибольший d=" (bk:r (cadddr c) 1) " мм"
                           (if (> md 0)
                             (strcat ", труба d" (bk:r md 0) " (внутр. " (bk:r (bk:din code md) 1) " мм): заполнение "
                                     (bk:r (bk:tube-fill code md (list (cadddr c))) 0) " % из " (bk:r f 0) " %")
                             "")
                           (if (bk:tube-pick code (list (cadddr c)))
                             (strcat ";  подходит d" (itoa (bk:tube-pick code (list (cadddr c)))) " и больше") ""))))))

;; окно участка. *bk:sc* - кабели участка ((позиция d марка) ...). Возврат (code h k sz) или nil
(defun bk:seg-dialog (code h k sz md / fn id res out x)
  (setq x (if (wcmatch sz "*x*") (vl-string-search "x" sz)))
  (setq fn (bk:write-dcl "blok_kabel_seg.dcl"
             '("bk_seg : dialog { label = \"Участок: прокладка всех кабелей на участке\";"
               " : list_box { key = \"hdr\"; height = 2; width = 90; tabs = \"16 64 76\"; is_tab_stop = false; }"
               " : list_box { key = \"lst\"; height = 8; width = 90; tabs = \"16 64 76\"; }"
               " : text { key = \"sum\"; width = 90; }"
               " : popup_list { key = \"prokl\"; label = \"В чём прокладывается:\"; width = 60; }"
               " : row { : edit_box { key = \"h\"; label = \"Высота, м (пусто - как было):\"; edit_width = 6; allow_accept = false; }"
               "         : edit_box { key = \"k\"; label = \"Коэф. запаса:\"; edit_width = 5; allow_accept = false; }"
               "         : edit_box { key = \"md\"; label = \"Диаметр материала, мм:\"; edit_width = 5; allow_accept = false; }"
               "         : toggle { key = \"ex\"; label = \"сущ. трасса (материал не считать)\"; } }"
               " : row { : text { label = \"Этаж участка:\"; width = 14; fixed_width = true; }"
               "         : edit_box { key = \"sfl\"; edit_width = 14; fixed_width = true; allow_accept = false; }"
               "         : text { label = \"пусто - как было у каждого кабеля,  * - авто по блокам\"; } }"
               " : boxed_row { label = \"Лоток / короб (общий для группы кабелей)\";"
               "   : edit_box { key = \"w\"; label = \"Ширина, мм:\"; edit_width = 6; allow_accept = false; }"
               "   : edit_box { key = \"hh\"; label = \"Высота, мм:\"; edit_width = 6; allow_accept = false; }"
               "   : edit_box { key = \"fill\"; label = \"Доп. заполнение, %:\"; edit_width = 5; allow_accept = false; }"
               "   : button { key = \"b_calc\"; label = \"Пересчитать\"; } }"
               " : text { key = \"res\"; width = 90; }"
               " : text { label = \"D пучка = K(n) x корень(Sum d2 / n), не менее наибольшего d;  заполнение = Sum S / (Ш x В).\"; }"
               " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 16; }"
               "         : button { key = \"b_types\"; label = \"Способы прокладки...\"; width = 22; }"
               "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 16; } } }"))
        res 5)
  (while (= res 5)
    (setq id (load_dialog fn))
    (if (not (new_dialog "bk_seg" id))
      (setq res 0)
      (progn
        (start_list "hdr") (add_list "Позиция\tНоменклатура\td, мм\tS, мм2") (end_list)
        (start_list "lst")
        (foreach c *bk:sc* (add_list (strcat (car c) "\t" (caddr c) "\t" (bk:r (cadr c) 1) "\t" (bk:r (bk:csec (cadr c)) 1))))
        (end_list)
        (start_list "prokl") (foreach tp *bk:types* (add_list (cadr tp))) (end_list)
        (bk:st "prokl" (itoa (bk:tidx code)))
        (bk:st "h" h) (bk:st "k" k) (bk:st "md" (if (> (bk:num md) 0) (bk:r md 0) "")) (bk:st "ex" (if (= *bk:segex* "1") "1" "0")) (bk:st "sfl" *bk:segfl*)
        (bk:st "w" (if x (substr sz 1 x) "100")) (bk:st "hh" (if x (substr sz (+ x 2)) "50"))
        (bk:st "fill" (rtos (bk:type-fill code) 2 0))
        (bk:seg-upd)
        (action_tile "prokl" "(bk:st \"fill\" (rtos (bk:type-fill (car (nth (atoi $value) *bk:types*))) 2 0)) (bk:seg-upd)")
        (foreach t2 '("w" "hh" "fill" "b_calc" "md") (action_tile t2 "(bk:seg-upd)"))
        (action_tile "accept"
          "(setq code (car (nth (atoi (get_tile \"prokl\")) *bk:types*)) out (list code (bk:trim (get_tile \"h\")) (bk:num (get_tile \"k\")) (if (= (bk:type-mode code) \"O\") (strcat (bk:r (bk:num (get_tile \"w\")) 0) \"x\" (bk:r (bk:num (get_tile \"hh\")) 0)) \"\") (if (bk:md-on code) (bk:num (get_tile \"md\")) 0.0) (if (= (get_tile \"ex\") \"1\") \"1\" \"\") (bk:trim (get_tile \"sfl\")))) (done_dialog 1)")
        (action_tile "b_types" "(setq code (car (nth (atoi (get_tile \"prokl\")) *bk:types*)) h (get_tile \"h\") k (get_tile \"k\") md (get_tile \"md\")) (done_dialog 5)")
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (if (= res 5) (bk:types-dialog)))))
  (vl-file-delete fn)
  (if (= res 1) out))

(defun bk:do-mark (e p1 p2 seg / d o a b q1 q2 cabs r dd tmp pc ids)
  (if (not (setq d (bk:get e)))
    (princ "\nЭто не кабель.")
    (progn
      (setq o (vlax-ename->vla-object e)
            a (vlax-curve-getParamAtPoint o (vlax-curve-getClosestPointTo o p1)))
      (if seg
        (setq a (float (fix a)) b (min (1+ a) (vlax-curve-getEndParam o)))
        (progn
          (setq b (vlax-curve-getParamAtPoint o (vlax-curve-getClosestPointTo o p2)))
          (if (> a b) (setq tmp a a b b tmp))))
      (if (> (- b a) 1e-6)
        (progn
          (setq q1 (bk:2d (vlax-curve-getPointAtParam o a)) q2 (bk:2d (vlax-curve-getPointAtParam o b))
                cabs (bk:on-piece q1 q2))
          (setq *bk:sc* nil ids nil)
          (foreach c cabs
            (if (not (member (car c) ids))
              (progn
                (setq ids (cons (car c) ids) dd (bk:get (cadr c)))
                ;; кратность: кабель на участке n раз (туда и обратно) - n строк в сечении
                (repeat (bk:pass-n (car c) (bk:mid q1 q2))
                  (setq *bk:sc* (append *bk:sc* (list (list (bk:f dd "pos") (bk:fn dd "diam") (bk:f dd "marka")))))))))
          (foreach c cabs (redraw (cadr c) 3))
          (setq *bk:segex* (bk:f d "ex") *bk:segfl* "")
          (setq r (bk:seg-dialog (bk:f d "code") "" (bk:r (bk:fn d "k") 2) (bk:f d "sz") (bk:fn d "md")))
          (foreach c cabs (if (entget (cadr c)) (redraw (cadr c) 4)))
          (if r
            (progn
              ;; по каждому куску: сегмент ищется заново (после пересборки кабеля сегменты новые)
              ;; все проходы каждого кабеля (туда и обратно) - каждый свой отрезок
              (foreach i ids (bk:apply-passes i (caddr (assoc i cabs)) (cadddr (assoc i cabs)) r))
              (bk:upd-leaders-for ids)
              (princ (strcat "\nУчасток: " (bk:tname (car r)) (if (/= (cadddr r) "") (strcat " " (cadddr r)) "")
                             ", кабелей: " (itoa (length cabs)) " ("
                             (bk:join (mapcar 'car *bk:sc*) ", ") ").")))))))))

;; отрезок a-b пересекает прямоугольник lo-hi (отсечение Лианга-Барски)
(defun bk:seg-in-rect (a b lo hi / t0 t1 dx dy ok pp qq i u)
  (setq t0 0.0 t1 1.0 ok T dx (- (car b) (car a)) dy (- (cadr b) (cadr a)))
  (setq pp (list (- dx) dx (- dy) dy)
        qq (list (- (car a) (car lo)) (- (car hi) (car a)) (- (cadr a) (cadr lo)) (- (cadr hi) (cadr a))) i 0)
  (repeat 4
    (if ok
      (if (equal (nth i pp) 0.0 1e-12)
        (if (< (nth i qq) 0.0) (setq ok nil))
        (progn (setq u (/ (nth i qq) (nth i pp)))
               (if (< (nth i pp) 0.0) (setq t0 (max t0 u)) (setq t1 (min t1 u)))
               (if (> t0 t1) (setq ok nil)))))
    (setq i (1+ i)))
  ok)

;; ММ_КАБЕЛЬ_УЧАСТОК областью: все отрезки (между соседними вершинами) всех кабелей, попавшие в рамку;
;; параметры из окна - всем этим кускам; пересчитываются только затронутые кабели и их выноски
(defun bk:same-edge (x y / tol)       ; отрезки (id e a b) совпадают геометрически (в любом направлении)
  (setq tol (+ *bk:otol* 1.0))
  (or (and (< (distance (caddr x) (caddr y)) tol) (< (distance (cadddr x) (cadddr y)) tol))
      (and (< (distance (caddr x) (cadddr y)) tol) (< (distance (cadddr x) (caddr y)) tol))))
(defun bk:mid (a b) (list (/ (+ (car a) (car b)) 2.0) (/ (+ (cadr a) (cadr b)) 2.0)))
(defun bk:do-area (c1 c2 / lo hi ss pcs pts a b d id ids r pc e1 n done)
  (setq lo (list (min (car c1) (car c2)) (min (cadr c1) (cadr c2)))
        hi (list (max (car c1) (car c2)) (max (cadr c1) (cadr c2))))
  (setq ss (ssget "_C" (trans c1 0 1) (trans c2 0 1) '((-3 ("BK")))))
  (foreach e (bk:ss->l ss)
    (if (setq d (bk:get e))
      (progn
        (setq pts (bk:pts e))
        (while (cdr pts)
          (setq a (car pts) b (cadr pts) pts (cdr pts))
          (if (and (> (distance a b) 1e-6) (bk:seg-in-rect a b lo hi))
            (setq pcs (cons (list (bk:f d "id") e a b) pcs)))))))
  (setq pcs (reverse pcs))
  (if (null pcs)
    (princ "\nВ области нет кабелей.")
    (progn
      (setq *bk:sc* nil ids nil)
      (foreach c pcs
        (if (not (member (car c) ids))
          (progn
            (setq ids (cons (car c) ids) d (bk:get (cadr c)))
            ;; кратность - наибольшее число совпадающих отрезков кабеля в области
            (repeat (apply 'max (mapcar '(lambda (x) (length (vl-remove-if-not '(lambda (y) (and (= (car y) (car c)) (bk:same-edge y x))) pcs)))
                                        (vl-remove-if-not '(lambda (y) (= (car y) (car c))) pcs)))
              (setq *bk:sc* (append *bk:sc* (list (list (bk:f d "pos") (bk:fn d "diam") (bk:f d "marka")))))))))
      (setq ids (reverse ids) e1 (cadr (car pcs)) d (bk:get e1))
      (foreach c pcs (redraw (cadr c) 3))
      (setq *bk:segex* (bk:f d "ex") *bk:segfl* "")
      (setq r (bk:seg-dialog (bk:f d "code") "" (bk:r (bk:fn d "k") 2) (bk:f d "sz") (bk:fn d "md")))
      (foreach c pcs (if (entget (cadr c)) (redraw (cadr c) 4)))
      (if r
        (progn
          (setq n 0)
          ;; каждый отрезок (с учётом проходов туда и обратно) - один раз на уникальную геометрию
          (setq done nil)
          (foreach c pcs
            (if (not (vl-some '(lambda (y) (and (= (car y) (car c)) (bk:same-edge y c))) done))
              (progn (setq n (+ n (bk:apply-passes (car c) (caddr c) (cadddr c) r)) done (cons c done)))))
          (bk:upd-leaders-for ids)
          (princ (strcat "\nОбласть: " (bk:tname (car r)) (if (/= (cadddr r) "") (strcat " " (cadddr r)) "")
                         ", отрезков: " (itoa n) ", кабелей: " (itoa (length ids)) " ("
                         (bk:join (mapcar 'car *bk:sc*) ", ") ")."))))))
  (princ))

(defun bk:cmd-seg (/ es p1 p2 go k)
  (setq go T)
  (while go
    (initget "Щелчок Точки")
    (setq p1 (getpoint "\nПервый угол области [Щелчок/Точки] <выход>: "))
    (cond
      ((null p1) (setq go nil))
      ((= p1 "Щелчок")
       (if (setq es (entsel "\nЩёлкните отрезок кабеля между вершинами: "))
         (bk:do-mark (car es) (trans (cadr es) 1 0) nil T)))
      ((= p1 "Точки")
       (if (and (setq es (entsel "\nВыберите кабель: "))
                (setq p1 (getpoint "\nПервая точка на кабеле: "))
                (setq p2 (getpoint p1 "\nВторая точка на кабеле: ")))
         (bk:do-mark (car es) (trans p1 1 0) (trans p2 1 0) nil)))
      (T (if (setq p2 (getcorner p1 "\nВторой угол области: "))
           (bk:do-area (trans p1 1 0) (trans p2 1 0))))))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_СВОЙСТВА ----------
(defun bk:common (l) (if (vl-every '(lambda (x) (= x (car l))) l) (car l) "<разные>"))

(defun bk:edit-one (id)
  (setq *bk:cd* (bk:get (car (bk:segs id))) *bk:cp* (bk:parts id))
  (if (bk:cab-dialog)
    (progn
      (bk:rebuild *bk:cd* *bk:cp*)
      (bk:upd-leaders-for (list id))
      (princ (strcat "\n" (bk:f *bk:cd* "pos") ": " (bk:len-text id))))))

;; части кабеля (основной и ветки) - все кабели с той же ПОЗИЦИЕЙ; основной - первым
(defun bk:line-ids (id / pos l main)
  (setq pos (strcase (bk:f (bk:get (car (bk:segs id))) "pos")))
  (foreach m (bk:cable-map) (if (= (strcase (bk:f (cadr m) "pos")) pos) (setq l (cons (car m) l))))
  (if (null l) (setq l (list id)))
  (setq main (cond ((vl-some '(lambda (i) (if (= (bk:f (bk:get (car (bk:segs i))) "par") "") i)) l)) ((car l))))
  (cons main (vl-remove main l)))
;; окно частей кабеля: основной кабель и ветки отдельными строками; двойной щелчок / «Свойства» - окно части
(defun bk:edit-line (id / ids fn dl res sel rows n d)
  (setq res 1)
  (while (= res 1)
    (setq ids (bk:line-ids id) n 0 rows nil)
    (foreach i ids
      (setq d (bk:get (car (bk:segs i))))
      (setq rows (append rows (list (strcat (if (= n 0) "Основной кабель" (strcat "Ветка " (itoa n))) "\t" (bk:f d "pos") "\t"
                                            (bk:beg-name d) "\t" (bk:ch-flr (bk:f d "beg")) "\t"
                                            (bk:dev-pos (bk:f d "end")) "\t" (bk:ch-flr (bk:f d "end")) "\t"
                                            (itoa (bk:ceil0 (bk:total (bk:calc d (bk:parts i))))) " м")))
            n (1+ n)))
    (setq fn (bk:write-dcl "blok_kabel_line.dcl"
               '("bk_ln : dialog { label = \"Кабель и его ветки\";"
                 " : list_box { key = \"hdr\"; height = 2; width = 140; tabs = \"16 26 50 62 86 98\"; is_tab_stop = false; }"
                 " : list_box { key = \"lst\"; height = 10; width = 140; tabs = \"16 26 50 62 86 98\"; }"
                 " : row { : button { key = \"b_ed\"; label = \"Свойства выбранной части...\"; }"
                 "         : button { key = \"b_all\"; label = \"Общие свойства всех частей...\"; }"
                 "         : button { key = \"b_show\"; label = \"Показать на чертеже\"; }"
                 "         : button { key = \"cancel\"; label = \"Закрыть\"; is_cancel = true; width = 14; } } }"))
          dl (load_dialog fn) res 0)
    (if (new_dialog "bk_ln" dl)
      (progn
        (start_list "hdr") (add_list "Часть\tПозиция\tНачало\tЭтаж нач.\tКонец\tЭтаж кон.\tДлина") (end_list)
        (start_list "lst") (foreach x rows (add_list x)) (end_list)
        (bk:st "lst" (if sel sel "0"))
        (action_tile "lst" "(setq sel $value) (if (= $reason 4) (done_dialog 1))")
        (action_tile "b_ed" "(setq sel (get_tile \"lst\")) (done_dialog 1)")
        (action_tile "b_all" "(done_dialog 2)")
        (action_tile "b_show" "(setq sel (get_tile \"lst\")) (done_dialog 3)")
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))))
    (unload_dialog dl)
    (vl-file-delete fn)
    (cond ((and (= res 1) sel (/= sel "")) (bk:edit-one (nth (atoi sel) ids)))
          ((= res 1))
          ((= res 2) (bk:edit-many ids) (setq res 1))
          ((= res 3) (bk:show-cable (nth (atoi (if (and sel (/= sel "")) sel "0")) ids)) (setq res 1))))
  (princ))

(defun bk:cmd-props (/ ids)
  (setq ids (bk:pick-ids "\nВыберите кабель (или несколько): "))
  (cond ((null ids))
        ;; кабель с ветками - окно частей (основной и ветки отдельно)
        ((and (= (length ids) 1) (cdr (bk:line-ids (car ids)))) (bk:edit-line (car ids)))
        ((= (length ids) 1) (bk:edit-one (car ids)))
        (T (bk:edit-many ids)))
  (princ))

(defun bk:edit-many (ids / ds com new d ps h0 k0 hn kn)
     (setq ds (mapcar '(lambda (id) (bk:get (car (bk:segs id)))) ids)
           ps (apply 'append (mapcar 'bk:parts ids))
           ;; высота и коэф. запаса - общие по всем участкам всех кабелей
           h0 (bk:common (mapcar '(lambda (p) (bk:r (cadr p) 1)) ps))
           k0 (bk:common (mapcar '(lambda (p) (bk:r (cadddr p) 2)) ps)))
     (setq com (list (bk:common (mapcar '(lambda (d) (bk:f d "marka")) ds))
                     (bk:common (mapcar '(lambda (d) (bk:f d "diam")) ds))
                     (bk:common (mapcar '(lambda (d) (bk:f d "pos")) ds))
                     "*" h0 k0 "0"
                     (bk:common (mapcar '(lambda (d) (bk:f d "layer")) ds))
                     (bk:common (mapcar '(lambda (d) (bk:f d "lts")) ds))
                     (bk:common (mapcar '(lambda (d) (bk:f d "floor")) ds))))
     (if (setq new (bk:dialog com T (strcat "Выбрано кабелей: " (itoa (length ids))
                                            ". Прокладка <не менять> - участки сохраняются; <разные> - не менять.")))
       (progn
         ;; новые значения высоты / коэф.: nil - не менять
         (setq hn (if (and (/= (nth 4 new) "<разные>") (/= (nth 4 new) "") (/= (nth 4 new) h0)) (bk:num (nth 4 new)))
               kn (if (and (/= (nth 5 new) "<разные>") (/= (nth 5 new) "") (/= (nth 5 new) k0)) (bk:num (nth 5 new))))
         (foreach id ids
           (setq d (bk:get (car (bk:segs id))))
           (foreach k '(("marka" . 0) ("diam" . 1) ("pos" . 2) ("layer" . 7) ("lts" . 8) ("floor" . 9))
             (if (and (/= (nth (cdr k) new) "<разные>") (/= (nth (cdr k) new) ""))
               (setq d (bk:setf d (car k) (nth (cdr k) new)))))
           (bk:rebuild d
             (mapcar '(lambda (p)
                        (if (/= (nth 3 new) "*")
                          (setq p (list (nth 3 new) (cadr p) (caddr p) (cadddr p) nil "" 0.0 (nth 7 p))))
                        (if hn (setq p (bk:replace-nth 1 hn p)))
                        ;; коэф. запаса - у обычных участков (стояк/перенос - как были)
                        (if (and kn (not (bk:stc (car p)))) (setq p (bk:replace-nth 3 kn p)))
                        p)
                     (bk:parts id))))
         (bk:upd-leaders-for ids)
         (princ (strcat "\nИзменено кабелей: " (itoa (length ids)) ".")))))

;;; ---------- привязка ряда кабелей к другому началу / концу ----------
;; сеть всех кабелей (кроме skip): одинаковые отрезки - один раз -> список рёбер (a b attr этаж ka kb вес)
(defun bk:net-edges (skip / EL seen g rk)
  (foreach m (bk:cable-map)
    (if (not (member (car m) skip))
      (foreach y (car (bk:gr-build (list (car m))))
        (setq rk (bk:rkey y))
        (if (not (member rk seen)) (setq seen (cons rk seen) EL (cons y EL))))))
  (reverse EL))
;; сеть только из кабелей ids (одинаковые отрезки - один раз)
(defun bk:net-of (ids / EL seen rk)
  (foreach id ids
    (foreach y (car (bk:gr-build (list id)))
      (setq rk (bk:rkey y))
      (if (not (member rk seen)) (setq seen (cons rk seen) EL (cons y EL)))))
  (reverse EL))
;; ближайшая к p точка на обычном (не стояк) ребре этажа fl -> (i t точка расст) или nil
(defun bk:net-near (EL p fl / flu i m q r)
  (setq flu (bk:up (vl-string-trim " " (if fl fl ""))) i 0)
  (foreach y EL
    (if (and (not (bk:stc (car (caddr y)))) (or (= flu "") (= (bk:up (vl-string-trim " " (nth 3 y))) flu)))
      (progn (setq q (bk:tr-proj p (car y) (cadr y)))
             (if (or (null m) (< (caddr q) m)) (setq m (caddr q) r (list i (cadr q) (car q) m)))))
    (setq i (1+ i)))
  r)
;; путь по сети EL от точки ребра s (i t q) до точки ребра g (i t q) -> список (a b attr) или nil
(defun bk:net-path (EL s g / es eg ls lg dp r1 r2 cur root path pre x pe)
  (setq es (nth (car s) EL) eg (nth (car g) EL)
        ls (distance (car es) (cadr es)) lg (distance (car eg) (cadr eg)))
  (if (= (car s) (car g))
    (list (list (caddr s) (caddr g) (caddr es)))
    (progn
      (setq dp (bk:dij EL (list (cons (nth 4 es) (* (cadr s) ls)) (cons (nth 5 es) (* (- 1.0 (cadr s)) ls))) (list (car s) (car g)))
            r1 (if (assoc (nth 4 eg) (car dp)) (+ (cdr (assoc (nth 4 eg) (car dp))) (* (cadr g) lg)))
            r2 (if (assoc (nth 5 eg) (car dp)) (+ (cdr (assoc (nth 5 eg) (car dp))) (* (- 1.0 (cadr g)) lg))))
      (if (or r1 r2)
        (progn
          (setq cur (if (and r1 (or (null r2) (<= r1 r2))) (nth 4 eg) (nth 5 eg))
                path (bk:dij-path EL (cdr dp) cur)
                root cur)
          (while (setq pe (assoc root (cdr dp))) (setq root (caddr pe)))
          ;; начало: от точки q до вершины-корня по ребру s
          (setq pre (list (caddr s) (if (= root (nth 4 es)) (car es) (cadr es)) (caddr es)))
          (append (list pre) path
                  (list (list (if (= cur (nth 4 eg)) (car eg) (cadr eg)) (caddr g) (caddr eg)))))))))

;; перестроить кабель id от нового блока начала bn по известной трассировке -> T или текст ошибки
;; -> участки нового пути (от блока bn до конца кабеля d) или текст ошибки
(defun bk:reroute-parts (d bn EL ELo / pN pE flN flE s g path h cattr pieces e2 be)
  (setq
        pN (bk:2d (cdr (assoc 10 (entget bn)))) flN (bk:attr bn "ЭТАЖ")
        be (bk:hent (bk:f d "end")))
  (cond
    ((or (null (bk:net-near ELo pN flN)) (null (setq s (bk:net-near EL pN flN)))) (strcat "кабель-образец не проходит по этажу " (if (= flN "") "?" flN) " нового начала"))
    ((not (and be (entget be))) "у кабеля нет блока конца")
    (T
     (setq pE (bk:2d (cdr (assoc 10 (entget be)))) flE (bk:attr be "ЭТАЖ"))
     (cond
       ((null (setq g (bk:net-near EL pE flE))) "у конца кабеля нет известной трассировки")
       ((null (setq path (bk:net-path EL s g))) "по кабелю-образцу нет пути до трассы кабеля к его концу")
       (T
        (setq h (if (bk:type "GOFRA") (nth 4 (bk:type "GOFRA")) 3.0)
              cattr (list "GOFRA" h (bk:fn d "k") 20.0 "" 0.0 "")
              e2 (nth (car g) EL))
        (setq pieces (append (list (bk:tr-conn pN (caddr s) (nth (car s) EL) cattr))
                             (mapcar '(lambda (x) (list (list (car x) (cadr x)) (caddr x))) path)
                             (list (list (reverse (car (bk:tr-conn pE (caddr g) e2 cattr))) cattr))))
        (bk:tr-parts (vl-remove-if '(lambda (x) (< (bk:plen (car x)) 1e-6)) pieces)))))))
(defun bk:reroute-beg (id bn EL ELo / d r)
  (setq d (bk:get (car (bk:segs id))) r (bk:reroute-parts d bn EL ELo))
  (if (= (type r) 'STR) r
    (progn (bk:rebuild (bk:setf (bk:setf d "beg" (cdr (assoc 5 (entget bn)))) "bfix" "1") r) T)))

(defun bk:rebind (ids / kw e h d n EL ELo r bad src)
  (initget "Начало Конец")
  (setq kw (getkword "\nПривязать выбранные кабели: [Начало/Конец] <Начало>: "))
  (if (null kw) (setq kw "Начало"))
  (if (setq e (bk:tr-pick (strcat "\nУкажите блок - новое " (if (= kw "Начало") "НАЧАЛО" "КОНЕЦ") " для " (itoa (length ids)) " кабелей: ")))
    (progn
      (setq h (cdr (assoc 5 (entget e))) n 0)
      (if (= kw "Начало")
        (progn
          (if (setq src (bk:pick-src))
            (progn
              (setq ELo (bk:net-of (list src)))
              (foreach id ids
                ;; сеть: кабель-образец + сам кабель (чтобы дойти до его конца)
                (setq r (bk:reroute-beg id e (bk:net-of (list src id)) ELo))
            (if (= r T) (setq n (1+ n))
              (setq bad (cons (strcat (bk:f (bk:get (car (bk:segs id))) "pos") ": " r) bad)))))))
        (foreach id ids
          (setq d (bk:setf (bk:setf (bk:get (car (bk:segs id))) "end" h) "efix" "1"))
          (bk:rebuild d (bk:parts id))
          (setq n (1+ n))))
      (vl-catch-all-apply 'bk:update-leaders nil)
      (vl-catch-all-apply 'bk:end-labels-all nil)
      (foreach b (reverse bad) (princ (strcat "\nПривязка невозможна, трассировка отсутствует - " b)))
      (princ (strcat "\nПривязано к " (bk:dev-pos h) ": " (itoa n) " из " (itoa (length ids))
                     (if (= kw "Начало") " (кабели перестроены по существующей трассировке)." ".")))
      (if bad (alert (strcat "Привязка невозможна, трассировка отсутствует:\n" (bk:join (reverse bad) "\n")))))))

;;; ---------- все кабели чертежа за один проход ----------
;; -> список (id данные_первого_участка участки_по_порядку)
(defun bk:cable-map (/ map d p id)
  (foreach e (bk:all-segs)
    (setq d (bk:get e) id (bk:f d "id"))
    (if (setq p (assoc id map))
      (setq map (subst (cons id (cons (cons (bk:fn d "ord") e) (cdr p))) p map))
      (setq map (cons (list id (cons (bk:fn d "ord") e)) map))))
  (mapcar '(lambda (m / l)
             (setq l (mapcar 'cdr (vl-sort (cdr m) '(lambda (a b) (< (car a) (car b))))))
             (list (car m) (bk:get (car l)) l))
          map))

;;; ---------- регистр без учёта (включая кириллицу) ----------
(defun bk:up (s)
  (vl-string-translate "абвгдеёжзийклмнопрстуфхцчшщъыьэюя" "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ" (strcase (if s s ""))))

;; "естественное" сравнение строк: ШС2 < ШС10
(defun bk:numpart (s / i n c d)
  (setq i 1 n (strlen s) d "")
  (while (and (<= i n) (not (wcmatch (substr s i 1) "#"))) (setq i (1+ i)))
  (while (and (<= i n) (wcmatch (setq c (substr s i 1)) "#")) (setq d (strcat d c) i (1+ i)))
  (if (= d "") nil (atoi d)))
(defun bk:less (a b / na nb pa pb)
  (if (and (numberp a) (numberp b)) (< a b)
    (progn
      (setq pa (bk:up (if (numberp a) (rtos a 2 2) a)) pb (bk:up (if (numberp b) (rtos b 2 2) b)))
      (setq na (bk:numpart pa) nb (bk:numpart pb))
      (if (and na nb (/= na nb) (= (vl-string-right-trim "0123456789" pa) (vl-string-right-trim "0123456789" pb)))
        (< na nb)
        (< pa pb)))))

;;; ---------- CSV: без превращения чисел в даты в Excel ----------
;; числа - с запятой; тексты, похожие на дату/число (1-2, 5.4, 3/4, 01) - как ="текст"
(defun bk:csv-cell (v / s)
  (cond
    ((= (type v) 'INT) (itoa v))
    ((numberp v) (vl-string-translate "." "," (rtos v 2 2)))
    (T
      (setq s (if v v ""))
      (if (or (vl-string-search ";" s) (vl-string-search "\"" s))
        (setq s (strcat "\"" (bk:subst-all s "\"" "\"\"") "\"")))
      (cond
        ;; текст, который Excel принял бы за дату/число (1-2, 5.4, 3/4, 01) -> ="текст"
        ((and (/= s "") (wcmatch s "#*") (wcmatch s "*[-./:,]*,0#*"))
         (strcat "=\"" s "\""))
        (T s)))))

(defun bk:numstr-p (s / i c sep ok)
  (setq i 1 ok (> (strlen s) 0) sep 0)
  (while (and ok (<= i (strlen s)))
    (setq c (substr s i 1) i (1+ i))
    (cond ((wcmatch c "#")) ((member c '("." ",")) (setq sep (1+ sep))) (T (setq ok nil))))
  (and ok (<= sep 1) (wcmatch s "#*") (not (wcmatch s "0#*"))))

(defun bk:subst-all (s a b / i r)
  (setq r "")
  (while (setq i (vl-string-search a s))
    (setq r (strcat r (substr s 1 i) b) s (substr s (+ i 1 (strlen a)))))
  (strcat r s))

;; имя файла: <чертёж>_<суффикс>_ГГГГ-ММ-ДД_ЧЧ-ММ.csv; если есть - спросить
(defun bk:stamp (/ s)
  (setq s (rtos (getvar "CDATE") 2 6))
  (strcat (substr s 1 4) "-" (substr s 5 2) "-" (substr s 7 2) "_" (substr s 10 2) "-" (substr s 12 2)))

(defun bk:csv-write (suffix rows / fn f k)
  (if (= (getvar "DWGTITLED") 0)
    (progn (princ "\nЧертёж не сохранён - CSV не создан.") nil)
    (progn
      (setq fn (strcat (getvar "DWGPREFIX") (vl-filename-base (getvar "DWGNAME")) "_" suffix "_" (bk:stamp) ".csv"))
      (if (findfile fn)
        (progn (initget "Да Нет")
               (setq k (getkword (strcat "\nФайл " fn " существует. Заменить? [Да/Нет] <Нет>: ")))))
      (if (and (findfile fn) (/= k "Да"))
        (progn (princ "\nВыгрузка отменена.") nil)
        (progn
          (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom")))
          (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
          (if (null f)
            (progn (princ (strcat "\nНе удалось записать " fn " (открыт в Excel?)")) nil)
            (progn
              (foreach r rows (write-line (bk:join (mapcar 'bk:csv-cell r) ";") f))
              (close f)
              (princ (strcat "\nCSV: " fn))
              fn)))))))

;; таблица на чертёж: title, rows (первая - заголовок)
;; значение ячейки: целое - без дробной части (длины в метрах), дробное - с запятой
(defun bk:cell (v) (cond ((= (type v) 'INT) (itoa v)) ((numberp v) (vl-string-translate "." "," (rtos v 2 1))) (T v)))

;; скрыть задний фон под объектами (таблица + её линии): маскировка по рамке, объекты - поверх
(defun bk:mask (ents / mn mx a b o w ss m)
  (foreach e ents
    (vla-GetBoundingBox (vlax-ename->vla-object e) 'mn 'mx)
    (setq mn (vlax-safearray->list mn) mx (vlax-safearray->list mx)
          a (if a (mapcar 'min a mn) mn) b (if b (mapcar 'max b mx) mx)))
  (setq o (vlax-invoke (bk:space) 'AddLightWeightPolyline
            (list (car a) (cadr a) (car b) (cadr a) (car b) (cadr b) (car a) (cadr b))))
  (vla-put-Closed o :vlax-true)
  (setq m (getvar "CMDECHO")) (setvar "CMDECHO" 0)
  (command "_.WIPEOUT" "_P" (vlax-vla-object->ename o) "_Y")
  (setq w (entlast) ss (ssadd))
  (foreach e ents (ssadd e ss))
  (command "_.DRAWORDER" ss "" "_A" w "")
  (setvar "CMDECHO" m)
  w)

(defun bk:dwg-table (title rows / th pt tbl nr nc i j w widths lts)
  (setq lts (max 1.0 (bk:num (nth 8 *bk:par*))))
  (setq th (getreal (strcat "\nВысота текста таблицы <" (rtos (* 2.5 lts) 2 1) ">: ")))
  (if (null th) (setq th (* 2.5 lts)))
  (if (setq pt (getpoint "\nТочка вставки таблицы (левый верхний угол): "))
    (progn
      (setq nr (1+ (length rows)) nc (length (car rows)) widths (mapcar '(lambda (x) 4) (car rows)))
      (foreach r rows
        (setq widths (mapcar '(lambda (w v) (max w (strlen (bk:cell v)))) widths r)))
      (setq tbl (vla-AddTable (bk:space) (vlax-3d-point (trans pt 1 0)) nr nc (* 2.2 th) (* 10 th)))
      (vla-put-RegenerateTableSuppressed tbl :vlax-true)
      (vla-SetTextHeight tbl 7 th)
      (setq j 0)
      (foreach w widths (vla-SetColumnWidth tbl j (* th (+ 2 (* 0.85 (min w 60))))) (setq j (1+ j)))
      (vla-SetText tbl 0 0 title)
      (setq i 1)
      (foreach r rows
        (setq j 0)
        (foreach v r
          (vla-SetText tbl i j (bk:cell v))
          (vl-catch-all-apply 'vla-SetCellAlignment (list tbl i j acMiddleCenter))
          (setq j (1+ j)))
        (setq i (1+ i)))
      (vla-put-RegenerateTableSuppressed tbl :vlax-false)
      (bk:mask (list (vlax-vla-object->ename tbl)))
      (princ (strcat "\nТаблица \"" title "\" вставлена.")))))

;;; ---------- таблица в отдельный файл DWG, листы А3 с рамкой по ГОСТ 2.104 ----------
;; рамка А3 альбомная 420x297: поле слева 20, остальные 5; первый лист - основная надпись
;; форма 2 (185x40), последующие - форма 2а (185x15). Каждый лист - отдельная вкладка (Layout) А3
;; без полей, принтер DWG To PDF, масштаб 1:1. Текст - стиль ММ_ (ISOCPEUR, аннотативный), формат DWG 2018.
(defun bk:a3-style (d / ts arr typ val)
  (setq ts (vl-catch-all-apply 'vla-Item (list (vla-get-TextStyles d) "ММ_")))
  (if (vl-catch-all-error-p ts) (setq ts (vla-Add (vla-get-TextStyles d) "ММ_")))
  (vl-catch-all-apply 'vla-put-fontFile (list ts "isocpeur.ttf"))
  (vl-catch-all-apply 'vla-SetFont (list ts "ISOCPEUR" :vlax-false :vlax-false 0 34))
  (vl-catch-all-apply 'vla-put-ObliqueAngle (list ts 0.0))
  (vl-catch-all-apply 'vla-put-Width (list ts 1.0))
  (vl-catch-all-apply 'vla-put-Height (list ts 0.0))
  ;; аннотативность - XDATA AcadAnnotative
  (vl-catch-all-apply 'vla-Add (list (vla-get-RegisteredApplications d) "AcadAnnotative"))
  (setq typ (vlax-make-safearray vlax-vbInteger '(0 . 5)) val (vlax-make-safearray vlax-vbVariant '(0 . 5)))
  (vlax-safearray-fill typ '(1001 1000 1002 1070 1070 1002))
  (vlax-safearray-fill val (list "AcadAnnotative" "AnnotativeData" "{" 1 1 "}"))
  (vl-catch-all-apply 'vla-SetXData (list ts typ val))
  (vl-catch-all-apply 'vla-put-ActiveTextStyle (list d ts))
  "ММ_")
(defun bk:a3-layout (d nm / lay)
  (setq lay (vla-Add (vla-get-Layouts d) nm))
  (vl-catch-all-apply 'vla-put-ConfigName (list lay "DWG To PDF.pc3"))
  (vl-catch-all-apply 'vla-RefreshPlotDeviceInfo (list lay))
  (vl-catch-all-apply 'vla-put-CanonicalMediaName (list lay "ISO_full_bleed_A3_(420.00_x_297.00_MM)"))
  (vl-catch-all-apply 'vla-put-PaperUnits (list lay acMillimeters))
  (vl-catch-all-apply 'vla-put-PlotRotation (list lay ac0degrees))
  (vl-catch-all-apply 'vla-put-PlotType (list lay acLayout))
  (vl-catch-all-apply 'vla-put-UseStandardScale (list lay :vlax-true))
  (vl-catch-all-apply 'vla-put-StandardScale (list lay ac1_1))
  (vl-catch-all-apply 'vla-put-CenterPlot (list lay :vlax-false))
  (vl-catch-all-apply 'vla-put-PlotWithLineweights (list lay :vlax-true))
  lay)
(defun bk:a3-ln (ms x1 y1 x2 y2 w / o)
  (setq o (vla-AddLine ms (vlax-3d-point (list x1 y1 0.0)) (vlax-3d-point (list x2 y2 0.0))))
  (vl-catch-all-apply 'vla-put-Lineweight (list o (if w acLnWt050 acLnWt018)))
  o)
(defun bk:a3-tx (ms sty x y h s / o)
  (if (/= s "")
    (progn
      (setq o (vla-AddText ms s (vlax-3d-point (list x y 0.0)) h))
      (if sty (vl-catch-all-apply 'vla-put-StyleName (list o sty)))
      (vla-put-Alignment o acAlignmentMiddleCenter)
      (vla-put-TextAlignmentPoint o (vlax-3d-point (list x y 0.0)))
      o)))
;; основная надпись. x0 - правый край рамки, y0 - низ рамки
(defun bk:a3-stamp (ms sty x0 y0 first title sh nsh / xl xs i)
  (setq xl (- x0 185.0))
  (if first
    (progn
      ;; форма 2: 185 x 40; слева графы 7/10/23/15/10 и 8 строк по 5
      (bk:a3-ln ms xl y0 xl (+ y0 40) T) (bk:a3-ln ms xl (+ y0 40) x0 (+ y0 40) T)
      (setq xs (list 7 17 40 55 65))
      (foreach x xs (bk:a3-ln ms (+ xl x) (+ y0 (if (> x 40) 0 25)) (+ xl x) (+ y0 40) T))
      (foreach x '(17 40) (bk:a3-ln ms (+ xl x) y0 (+ xl x) (+ y0 25) T))
      (setq i 1) (repeat 7 (bk:a3-ln ms xl (+ y0 (* 5 i)) (+ xl 65) (+ y0 (* 5 i)) (= i 5)) (setq i (1+ i)))
      ;; справа: обозначение (15), наименование 70 / Лит.-Лист-Листов, организация
      (bk:a3-ln ms (+ xl 65) (+ y0 25) x0 (+ y0 25) T)
      (bk:a3-ln ms (+ xl 135) y0 (+ xl 135) (+ y0 25) T)
      (bk:a3-ln ms (+ xl 135) (+ y0 20) x0 (+ y0 20) T)
      (bk:a3-ln ms (+ xl 135) (+ y0 15) x0 (+ y0 15) T)
      (foreach x '(150 165) (bk:a3-ln ms (+ xl x) (+ y0 15) (+ xl x) (+ y0 25) T))
      (foreach x '(140 145) (bk:a3-ln ms (+ xl x) (+ y0 15) (+ xl x) (+ y0 20) nil))
      (bk:a3-tx ms sty (+ xl 3.5) (+ y0 22.5) 2.5 "Изм.")
      (bk:a3-tx ms sty (+ xl 12) (+ y0 22.5) 2.5 "Кол.уч")
      (bk:a3-tx ms sty (+ xl 28.5) (+ y0 22.5) 2.5 "Лист")
      (bk:a3-tx ms sty (+ xl 47.5) (+ y0 22.5) 2.5 "№ док.")
      (bk:a3-tx ms sty (+ xl 60) (+ y0 22.5) 2.5 "Подп.")
      (bk:a3-tx ms sty (+ xl 70) (+ y0 22.5) 2.5 "Дата")
      (setq i 0)
      (foreach lb '("Разраб." "Пров." "" "Н.контр." "Утв.")
        (bk:a3-tx ms sty (+ xl 8.5) (+ y0 17.5 (* -5 i)) 2.5 lb) (setq i (1+ i)))
      (bk:a3-tx ms sty (+ xl 100) (+ y0 12.5) 5.0 title)
      (bk:a3-tx ms sty (+ xl 142.5) (+ y0 22.5) 2.5 "Лит.")
      (bk:a3-tx ms sty (+ xl 157.5) (+ y0 22.5) 2.5 "Лист")
      (bk:a3-tx ms sty (+ xl 175) (+ y0 22.5) 2.5 "Листов")
      (bk:a3-tx ms sty (+ xl 157.5) (+ y0 17.5) 2.5 (itoa sh))
      (bk:a3-tx ms sty (+ xl 175) (+ y0 17.5) 2.5 (itoa nsh)))
    (progn
      ;; форма 2а: 185 x 15; графы 7/10/23/15/10, обозначение 110, лист 10 (7+8)
      (bk:a3-ln ms xl y0 xl (+ y0 15) T) (bk:a3-ln ms xl (+ y0 15) x0 (+ y0 15) T)
      (foreach x '(7 17 40 55 65 175) (bk:a3-ln ms (+ xl x) y0 (+ xl x) (+ y0 15) T))
      (foreach yy '(5 10) (bk:a3-ln ms xl (+ y0 yy) (+ xl 65) (+ y0 yy) (= yy 5)))
      (bk:a3-ln ms (+ xl 175) (+ y0 8) x0 (+ y0 8) T)
      (bk:a3-tx ms sty (+ xl 3.5) (+ y0 2.5) 2.5 "Изм.")
      (bk:a3-tx ms sty (+ xl 12) (+ y0 2.5) 2.5 "Кол.уч")
      (bk:a3-tx ms sty (+ xl 28.5) (+ y0 2.5) 2.5 "Лист")
      (bk:a3-tx ms sty (+ xl 47.5) (+ y0 2.5) 2.5 "№ док.")
      (bk:a3-tx ms sty (+ xl 60) (+ y0 2.5) 2.5 "Подп.")
      (bk:a3-tx ms sty (+ xl 70) (+ y0 2.5) 2.5 "Дата")
      (bk:a3-tx ms sty (+ xl 120) (+ y0 7.5) 3.5 title)
      (bk:a3-tx ms sty (+ xl 180) (+ y0 11.5) 2.5 "Лист")
      (bk:a3-tx ms sty (+ xl 180) (+ y0 4) 2.5 (itoa sh)))))

(defun bk:a3-table (title rows / head data acad src d ms fn sty th rh hh nc widths tot k per nsh sh x0 y0 top bot tbl i j part o)
  (setq head (car rows) data (cdr rows) nc (length head) th 2.5 rh 8.0 hh 15.0)
  (if (= (getvar "DWGTITLED") 0)
    (alert "Сначала сохраните чертёж: файл таблицы создаётся в его папке.")
    (progn
      (setq fn (strcat (getvar "DWGPREFIX") (vl-filename-base (getvar "DWGNAME")) "_" title "_" (bk:stamp) ".dwg"))
      ;; ширины колонок по содержимому, затем вписываются в ширину поля 395 мм
      (setq widths (mapcar '(lambda (x) 4) head))
      (foreach r data (setq widths (mapcar '(lambda (w v) (max w (min 40 (strlen (bk:cell v))))) widths r)))
      (setq widths (mapcar '(lambda (w h) (max w (min 14 (strlen h)))) widths head))
      (setq tot (apply '+ widths) widths (mapcar '(lambda (w) (* 395.0 (/ (float w) tot))) widths))
      ;; строк на листе: первый - над формой 2 (40), остальные - над формой 2а (15)
      (defun per (first) (fix (/ (- 287.0 (if first 40.0 15.0) 5.0 hh) rh)))
      (setq nsh 1 k (length data))
      (if (> k (per T)) (setq nsh (+ 1 (fix (/ (+ (- k (per T)) (per nil) -1) (per nil))))))
      (setq acad (vlax-get-acad-object) src (vla-get-ActiveDocument acad))
      (setq d (vl-catch-all-apply 'vla-Add (list (vla-get-Documents acad))))
      (vl-catch-all-apply 'vla-Activate (list src))
      (if (vl-catch-all-error-p d)
        (alert "Не удалось создать новый чертёж.")
        (progn
          (setq sty (bk:a3-style d) sh 1 i 0)
          (while (<= sh nsh)
            ;; лист - отдельная вкладка А3 без полей (DWG To PDF), рисуем в его пространстве листа
            (setq ms (vla-get-Block (bk:a3-layout d (strcat "Лист " (itoa sh)))) x0 0.0 y0 0.0)
            ;; внешняя рамка (тонкая) и внутренняя (основная)
            (bk:a3-ln ms x0 0 (+ x0 420) 0 nil) (bk:a3-ln ms (+ x0 420) 0 (+ x0 420) 297 nil)
            (bk:a3-ln ms (+ x0 420) 297 x0 297 nil) (bk:a3-ln ms x0 297 x0 0 nil)
            (bk:a3-ln ms (+ x0 20) 5 (+ x0 415) 5 T) (bk:a3-ln ms (+ x0 415) 5 (+ x0 415) 292 T)
            (bk:a3-ln ms (+ x0 415) 292 (+ x0 20) 292 T) (bk:a3-ln ms (+ x0 20) 292 (+ x0 20) 5 T)
            (bk:a3-stamp ms sty (+ x0 415) 5.0 (= sh 1) title sh nsh)
            ;; часть строк на этот лист
            (setq part nil j 0)
            (while (and (< j (per (= sh 1))) (< i k)) (setq part (append part (list (nth i data))) i (1+ i) j (1+ j)))
            (setq tbl (vla-AddTable ms (vlax-3d-point (list (+ x0 20) 292 0.0)) (1+ (length part)) nc rh 20.0))
            (vla-put-RegenerateTableSuppressed tbl :vlax-true)
            (vl-catch-all-apply 'vla-UnmergeCells (list tbl 0 0 0 (1- nc)))
            (vl-catch-all-apply 'vla-put-VertCellMargin (list tbl 0.8))
            (vl-catch-all-apply 'vla-put-HorzCellMargin (list tbl 0.8))
            (vla-SetTextHeight tbl 7 th)
            (if sty (vl-catch-all-apply 'vla-SetTextStyle (list tbl 7 sty)))
            (setq j 0) (foreach w widths (vla-SetColumnWidth tbl j w) (setq j (1+ j)))
            (setq j 0)
            (foreach h head (vla-SetText tbl 0 j h) (vl-catch-all-apply 'vla-SetCellAlignment (list tbl 0 j acMiddleCenter)) (setq j (1+ j)))
            (vl-catch-all-apply 'vla-SetRowHeight (list tbl 0 hh))
            (setq o 1)
            (foreach r part
              (setq j 0)
              (foreach v r
                (vla-SetText tbl o j (bk:cell v))
                (vl-catch-all-apply 'vla-SetCellAlignment (list tbl o j acMiddleCenter))
                (setq j (1+ j)))
              (vl-catch-all-apply 'vla-SetRowHeight (list tbl o rh))
              (setq o (1+ o)))
            (vla-put-RegenerateTableSuppressed tbl :vlax-false)
            (setq sh (1+ sh)))
          ;; пустые стандартные вкладки - убрать
          (vlax-for l (vla-get-Layouts d)
            (if (and (/= (vla-get-ModelType l) :vlax-true) (not (wcmatch (vla-get-Name l) "Лист #*")))
              (vl-catch-all-apply 'vla-Delete (list l))))
          ;; формат DWG 2018 (не ниже 2007)
          (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-SaveAs (list d fn (cond (ac2018_dwg) (64)))))
            (alert (strcat "Не удалось сохранить файл:\n" fn))
            (princ (strcat "\nТаблица \"" title "\": листов А3 - " (itoa nsh) ", файл " fn " (открыт в AutoCAD, вкладки Лист 1..N).")))))))
  (princ))

;;; ---------- данные для таблиц ----------
;; c: (id данные участки строки_расчёта итого)
(defun bk:cable-info (m / d parts rows)
  (setq d (cadr m)
        parts (mapcar '(lambda (e / x) (setq x (bk:get e))
                         (list (bk:f x "code") (bk:fn x "h") (bk:pts e) (bk:fn x "k") e (bk:f x "tcode") (bk:fn x "tk") nil
                               (bk:fn x "md") (bk:fn x "tmd") (bk:f x "sz") (bk:fn x "slen") (bk:f x "sflm") (bk:f x "sfl") (bk:f x "ex")))
                      (caddr m))
        rows (bk:calc d parts))
  (list (car m) d parts rows (bk:total rows)))

;; поля для поиска/сортировки: позиция этаж марка диаметр откуда куда длина слой
(setq *bk:fnames* '("Все поля" "Позиция" "Этаж" "Номенклатура" "Диаметр" "Откуда" "Куда" "Длина" "Слой" "Помещение начала" "Помещение конца" "Сущ."))
(defun bk:cfields (c / d)
  (setq d (cadr c))
  (list (bk:f d "pos") (bk:cfloor d) (bk:f d "marka") (bk:f d "diam")
        (bk:dev-pos (bk:f d "beg")) (bk:end-name d) (nth 4 c) (bk:f d "layer")
        (bk:dev-room (bk:f d "beg")) (bk:dev-room (bk:f d "end"))
        ;; существующая трасса: да - все участки, част. - часть участков
        (cond ((null (nth 2 c)) "")
              ((vl-every '(lambda (p) (= (bk:ex p) "1")) (vl-remove-if '(lambda (p) (bk:stc (car p))) (nth 2 c))) "да")
              ((vl-some '(lambda (p) (= (bk:ex p) "1")) (nth 2 c)) "част.")
              (T ""))))

;; таблица кабелей (без нулевых колонок): список строк, первая - заголовок
;; сортировка списков: числа - как числа, строки - естественный порядок (k2 < k10)
(defun bk:sort-less (a b)
  (if (and (numberp a) (numberp b)) (< a b)
    (bk:nat-less (if (numberp a) (rtos a 2 2) a) (if (numberp b) (rtos b 2 2) b))))
;; естественное сравнение строк: числа внутри сравниваются как числа (k2 < k10, k.8.1-2 < k.8.1-10)
(defun bk:nat-tok (s / out i c cur dig)
  (setq i 1 cur "" dig nil)
  (while (<= i (strlen s))
    (setq c (substr s i 1))
    (if (and (/= cur "") (not (eq dig (wcmatch c "#"))))
      (setq out (cons (if dig (atoi cur) cur) out) cur ""))
    (setq dig (wcmatch c "#") cur (strcat cur c) i (1+ i)))
  (if (/= cur "") (setq out (cons (if dig (atoi cur) cur) out)))
  (reverse out))
(defun bk:nat-less (a b / x y r)
  (setq x (bk:nat-tok (bk:up a)) y (bk:nat-tok (bk:up b)))
  (while (and x y (null r))
    (cond ((equal (car x) (car y)) (setq x (cdr x) y (cdr y)))
          ((and (numberp (car x)) (numberp (car y))) (setq r (if (< (car x) (car y)) 1 2)))
          ((numberp (car x)) (setq r 1))
          ((numberp (car y)) (setq r 2))
          (T (setq r (if (< (car x) (car y)) 1 2)))))
  (cond (r (= r 1)) (T (and (null x) (not (null y))))))

;; ---------- кабель с ветками = одна строка ----------
;; c: (id d parts rows total [члены]). Группа - корень и все ветки (ключ lin). d - корня, с ключами
;; ends (концы всех веток и корня через запятую), efl / erm (их этажи / помещения); строки расчёта и длины суммируются.
;; блоки стояков и переносов на др. лист (на концах участков STOYAK / PERENOS) - не приборы:
;; на схеме, в журнале и в участках не учитываются
(defun bk:special-blocks (cs / l h)
  (foreach c cs
    (foreach p (nth 2 c)
      (if (bk:stc (car p))
        (foreach q (list (car (caddr p)) (last (caddr p)))
          (foreach h (list (bk:block-at q) (bk:dev-at-vtx (bk:2d q)))
            (if (and h (/= h "") (not (member h l))) (setq l (cons h l))))))))
  l)
(defun bk:merge-lines (cs / g k p out d m ends fls rms begs hs h)
  (bk:bbx-init)
  (setq *bk:spech* (bk:special-blocks cs))
  (foreach c cs
    ;; группа - кабели с одной ПОЗИЦИЕЙ (ветки имеют ПОЗИЦИЮ основного кабеля)
    (setq k (if (/= (bk:f (cadr c) "pos") "") (strcase (bk:f (cadr c) "pos")) (car c)))
    (if (setq p (assoc k g)) (setq g (subst (append p (list c)) p g)) (setq g (cons (list k c) g))))
  (foreach x (reverse g)
    (setq m (cdr x)
          ;; основной - без родителя (par), иначе самый длинный
          d (cadr (cond ((vl-some '(lambda (c) (if (= (bk:f (cadr c) "par") "") c)) m))
                        ((car (vl-sort m '(lambda (a b) (> (nth 4 a) (nth 4 b)))))))))
    ;; приборы линии: концы частей и приборы в вершинах (печатаемый габарит), кроме начал частей (щит, коробка ответвления)
    (setq begs (vl-remove "" (mapcar '(lambda (c) (bk:f (cadr c) "beg")) m)) hs nil)
    ;; и блок в первой вершине каждой части (коробка ответвления, даже если не привязана как начало)
    (foreach c m (if (and (nth 2 c) (setq h (bk:dev-at-vtx (bk:2d (car (caddr (car (nth 2 c)))))))) (setq begs (cons h begs))))
    (foreach c m
      (foreach pr (nth 2 c)
        (if (not (bk:stc (car pr)))
          (foreach v (caddr pr)
            (if (and (setq h (bk:dev-at-vtx (bk:2d v))) (/= (bk:dev-pos h) "") (not (member h begs)) (not (member h hs)) (not (member h *bk:spech*)))
              (setq hs (cons h hs))))))
      (if (and (/= (setq h (bk:f (cadr c) "end")) "") (not (member h begs)) (not (member h hs)) (not (member h *bk:spech*))) (setq hs (cons h hs))))
    (setq hs (reverse hs))
    (if (and (null (cdr m)) (or (null hs) (and (null (cdr hs)) (= (car hs) (bk:f d "end")))))
      (setq out (cons (car m) out))            ; обычный кабель без промежуточных приборов - как было
      (progn
        (setq ends (mapcar 'bk:dev-pos hs)
              fls (mapcar '(lambda (h) (bk:attr (bk:hent h) "ЭТАЖ")) hs)
              rms (mapcar 'bk:dev-room hs))
        (setq d (bk:setf (bk:setf (bk:setf d "ends" (bk:pos-ranges (vl-remove "" ends)))
                                  "efl" (bk:join (bk:uniq (vl-remove "" fls)) ", "))
                         "erm" (bk:join (bk:uniq (vl-remove "" rms)) ", ")))
        (setq out (cons (list (bk:f d "id") d (apply 'append (mapcar 'caddr m)) (apply 'append (mapcar 'cadddr m))
                              (apply '+ (mapcar '(lambda (c) (nth 4 c)) m)) m)
                        out)))))
  (reverse out))
;; обратно в отдельные кабели (для спецификации, правки, участков)
(defun bk:unmerge (cs) (apply 'append (mapcar '(lambda (c) (if (nth 5 c) (nth 5 c) (list c))) cs)))
(defun bk:end-name (d) (if (/= (bk:f d "ends") "") (bk:f d "ends") (bk:dev-pos (bk:f d "end"))))
(defun bk:end-x (d k v) (if (/= (bk:f d "ends") "") (bk:f d k) v))
;; ПОЗИЦИЯ веток = ПОЗИЦИЯ корня (после переименования)
(defun bk:sync-branch-pos (/ rd)
  (foreach e (bk:all-segs)
    (if (and (/= (bk:f (bk:get e) "lin") "") (setq rd (bk:get (car (bk:segs (bk:f (bk:get e) "lin")))))
             (/= (bk:f rd "pos") (bk:f (bk:get e) "pos")))
      (bk:put e (bk:setf (bk:get e) "pos" (bk:f rd "pos"))))))

;; ---------- участки между устройствами (по вершинам кабеля) ----------
;; устройство в вершине: блок, внутри габарита которого вершина; из нескольких - чей центр ближе
;; после переименования объединённой строки: всем частям - ПОЗИЦИЯ основного кабеля
(defun bk:sync-members (cs / np)
  (foreach c cs
    (if (nth 5 c)
      (progn
        (setq np (bk:f (bk:get (car (bk:segs (car c)))) "pos"))
        (foreach m (nth 5 c) (if (/= (car m) (car c)) (bk:set-field (car m) "pos" np)))))))
;; габарит блока только по ПЕЧАТАЕМЫМ примитивам (зона действия на непечатаемом слое не учитывается);
;; атрибуты не учитываются. Кэш по имени определения: (minx miny maxx maxy) в координатах блока или nil.
(defun bk:lay-plot (nm / r)
  (if (setq r (assoc (strcase nm) *bk:lpl*)) (cdr r)
    (progn
      (setq r (vl-catch-all-apply '(lambda () (= (vla-get-Plottable (vla-Item (vla-get-Layers (bk:doc)) nm)) :vlax-true))))
      (if (vl-catch-all-error-p r) (setq r T))
      (setq *bk:lpl* (cons (cons (strcase nm) r) *bk:lpl*))
      r)))
(defun bk:pbox-def (nm / r e d mn mx bx o)
  (if (setq r (assoc nm *bk:pbb*)) (cdr r)
    (progn
      (setq e (tblobjname "BLOCK" nm))
      (while (setq e (entnext e))
        (setq d (entget e))
        (if (and (not (member (cdr (assoc 0 d)) '("ATTDEF" "ENDBLK" "SEQEND")))
                 (bk:lay-plot (cdr (assoc 8 d))))
          (progn
            (setq o (vlax-ename->vla-object e))
            (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-GetBoundingBox (list o 'mn 'mx))))
              (progn (setq mn (vlax-safearray->list mn) mx (vlax-safearray->list mx))
                     (setq bx (if bx (list (min (car bx) (car mn)) (min (cadr bx) (cadr mn)) (max (caddr bx) (car mx)) (max (cadddr bx) (cadr mx)))
                                (list (car mn) (cadr mn) (car mx) (cadr mx)))))))))
      (setq *bk:pbb* (cons (cons nm bx) *bk:pbb*))
      bx)))
;; печатаемый габарит вставки в МСК: (mn mx центр) или nil
(defun bk:pbox-ins (e / d bx bp ip sx sy a pts xs ys)
  (setq d (entget e))
  (if (setq bx (bk:pbox-def (cdr (assoc 2 d))))
    (progn
      (setq bp (cdr (assoc 10 (entget (tblobjname "BLOCK" (cdr (assoc 2 d))))))
            ip (cdr (assoc 10 d)) sx (cond ((cdr (assoc 41 d))) (1.0)) sy (cond ((cdr (assoc 42 d))) (1.0))
            a (cond ((cdr (assoc 50 d))) (0.0)))
      (setq pts (mapcar '(lambda (q / x y)
                           (setq x (* sx (- (car q) (car bp))) y (* sy (- (cadr q) (cadr bp))))
                           (list (+ (car ip) (- (* x (cos a)) (* y (sin a)))) (+ (cadr ip) (+ (* x (sin a)) (* y (cos a))))))
                        (list (list (car bx) (cadr bx)) (list (caddr bx) (cadr bx)) (list (caddr bx) (cadddr bx)) (list (car bx) (cadddr bx)))))
      (setq xs (mapcar 'car pts) ys (mapcar 'cadr pts))
      (list (list (apply 'min xs) (apply 'min ys)) (list (apply 'max xs) (apply 'max ys))
            (list (/ (+ (apply 'min xs) (apply 'max xs)) 2.0) (/ (+ (apply 'min ys) (apply 'max ys)) 2.0))))))
(defun bk:bbx-init (/ b)
  (setq *bk:bbx* nil *bk:pbb* nil *bk:lpl* nil)
  (foreach e (bk:ss->l (ssget "_X" (list '(0 . "INSERT") (cons 410 (getvar "CTAB")))))
    (if (setq b (vl-catch-all-apply 'bk:pbox-ins (list e)))
      (if (not (vl-catch-all-error-p b))
        (setq *bk:bbx* (cons (list (cdr (assoc 5 (entget e))) (car b) (cadr b) (caddr b)) *bk:bbx*))))))
(defun bk:dev-at-vtx (p / best bd dd)
  (foreach b *bk:bbx*
    (if (and (<= (car (cadr b)) (car p) (car (caddr b))) (<= (cadr (cadr b)) (cadr p) (cadr (caddr b))))
      (progn (setq dd (distance p (cadddr b)))
             (if (or (null bd) (< dd bd)) (setq bd dd best (car b))))))
  best)
;; участки одного кабеля (группы полилиний): ((h1 h2 длина_м) ...); h - хэндл блока или nil (точка без устройства)
(defun bk:dev-pieces (id / out cur len pa h first)
  (setq len 0.0 first T)
  (foreach p (bk:parts id)
    (if (bk:stc (car p))
      (progn (setq len (+ len (bk:plen-m p)))
             (if (and (setq h (bk:dev-at-vtx (bk:2d (last (caddr p))))) (not (member h *bk:spech*)))
               (if (/= h cur) (setq out (cons (list cur h len) out) cur h len 0.0))))
      (foreach v (caddr p)
        (setq v (bk:2d v))
        (if pa (setq len (+ len (/ (distance pa v) 1000.0))))
        (setq pa v h (bk:dev-at-vtx v))
        (if (member h *bk:spech*) (setq h nil))   ; стояк / перенос - не прибор
        (cond (first (setq cur h first nil))
              ((and h (/= h cur)) (setq out (cons (list cur h len) out) cur h len 0.0))))))
  (if (> len 0.0005) (setq out (cons (list cur nil len) out)))
  (reverse out))
(defun bk:pieces-table (cs / rows n d fl nm)
  (bk:bbx-init)
  (setq *bk:spech* (bk:special-blocks (bk:unmerge cs)))
  (defun fl (h) (if h (bk:attr (bk:hent h) "ЭТАЖ") ""))
  (defun nm (h) (if h (bk:dev-pos h) "точка без устройства"))
  (setq rows (list '("№" "ПОЗИЦИЯ" "НОМЕНКЛАТУРА" "ОТ" "ЭТАЖ (ОТ)" "ПОМЕЩЕНИЕ (ОТ)" "ДО" "ЭТАЖ (ДО)" "ПОМЕЩЕНИЕ (ДО)" "ДЛИНА ПО ЧЕРТЕЖУ, м"))
        n 0)
  (foreach c (bk:unmerge cs)
    (setq d (cadr c))
    (foreach q (bk:dev-pieces (car c))
      (setq rows (cons (list (itoa (setq n (1+ n))) (bk:f d "pos") (bk:f d "marka")
                             (nm (car q)) (fl (car q)) (if (car q) (bk:dev-room (car q)) "")
                             (nm (cadr q)) (fl (cadr q)) (if (cadr q) (bk:dev-room (cadr q)) "")
                             (bk:ceil0 (caddr q)))
                       rows))))
  (reverse rows))

;; порядок для журнала: корни линий по ПОЗИЦИИ, под каждым - его ветки (рекурсивно, тоже по ПОЗИЦИИ)
(defun bk:tree-order (cs / ids kids roots out walk pl srt)
  (defun srt (l) (vl-sort l '(lambda (m n) (bk:nat-less (bk:f (cadr m) "pos") (bk:f (cadr n) "pos")))))
  (setq ids (mapcar 'car cs))
  (foreach c cs
    (setq pl (bk:f (cadr c) "par"))
    (if (and (/= pl "") (member pl ids) (/= pl (car c)))
      (setq kids (cons (cons pl c) kids))
      (setq roots (cons c roots))))
  (defun walk (c / ch)
    (if (not (member c out))
      (progn
        (setq out (cons c out))
        (foreach k (srt (mapcar 'cdr (vl-remove-if-not '(lambda (x) (= (car x) (car c))) kids))) (walk k)))))
  (foreach c (srt roots) (walk c))
  ;; на случай циклических ссылок - оставшиеся в конце
  (foreach c (srt cs) (if (not (member c out)) (setq out (cons c out))))
  (reverse out))
;; ПОЗИЦИЯ корня линии (у обычного кабеля - своя)
(defun bk:line-pos (d / rd)
  (if (and (/= (bk:f d "par") "") (setq rd (bk:get (car (bk:segs (bk:root-of (bk:f d "id")))))))
    (bk:f rd "pos")
    (bk:f d "pos")))
(defun bk:cables-table (cs / head rows r sum used d fl)
  ;; строки - по ПОЗИЦИИ (естественный порядок: 1, 2, ... 10); ветки - сразу под своим кабелем (дерево линии)
  (setq cs (bk:tree-order cs))
  (foreach tp *bk:types*
    (if (vl-some '(lambda (c) (vl-some '(lambda (x) (and (= (nth 5 x) (car tp)) (> (nth 3 x) 0))) (nth 3 c))) cs)
      (setq used (append used (list tp)))))
  (defun fl (h / v) (if (and h (/= h "") (bk:hent h)) (bk:attr (bk:hent h) "ЭТАЖ") ""))
  ;; №, ПОЗИЦИЯ, НОМЕНКЛАТУРА, начало (этаж, помещение), конец (этаж, помещение), общая длина, длины по способам прокладки
  (setq head (append '("№" "ПОЗИЦИЯ" "НОМЕНКЛАТУРА" "НАЧАЛО" "ЭТАЖ (НАЧАЛО)" "ПОМЕЩЕНИЕ (НАЧАЛО)"
                       "КОНЕЦ" "ЭТАЖ (КОНЕЦ)" "ПОМЕЩЕНИЕ (КОНЕЦ)" "ОБЩАЯ ДЛИНА, м")
                     (mapcar '(lambda (tp) (strcat (cadr tp) ", м")) used)))
  (setq r 0)
  (foreach c cs
    (setq r (1+ r) d (cadr c))
    (setq rows (cons (append (list (itoa r) (bk:f d "pos") (bk:f d "marka")
                                   (bk:beg-name d) (fl (bk:f d "beg")) (bk:dev-room (bk:f d "beg"))
                                   (bk:end-name d) (bk:end-x d "efl" (fl (bk:f d "end"))) (bk:end-x d "erm" (bk:dev-room (bk:f d "end")))
                                   (bk:total (nth 3 c)))
                             (mapcar '(lambda (tp)
                                        (setq sum (apply '+ (mapcar '(lambda (x) (if (= (nth 5 x) (car tp)) (nth 7 x) 0.0)) (nth 3 c))))
                                        (if (> sum 0) (bk:ceil0 sum) ""))
                                     used))
                     rows)))
  (cons head (reverse rows)))

;; длина по способу без двойного счёта наложенных кабелей:
;; отрезки на одной прямой (допуск 5 мм) объединяются
(defun bk:route-len (segs / lines a key p q t1 t2 l iv res tot k)
  (foreach sg segs
    (setq p (car sg) q (cadr sg) k (if (caddr sg) (caddr sg) 1.0))
    (if (> (distance p q) 1e-6)
      (progn
        (setq a (atan (- (cadr q) (cadr p)) (- (car q) (car p))))
        (if (< a 0) (setq a (+ a pi)))
        (if (>= a (- pi 1e-4)) (setq a 0.0))
        (setq key (list (fix (/ a 0.001))
                        (fix (/ (+ (* (- (sin a)) (car p)) (* (cos a) (cadr p))) 5.0)))
              t1 (+ (* (cos a) (car p)) (* (sin a) (cadr p)))
              t2 (+ (* (cos a) (car q)) (* (sin a) (cadr q))))
        (if (setq l (assoc key lines))
          (setq lines (subst (cons key (cons (list (min t1 t2) (max t1 t2) k) (cdr l))) l lines))
          (setq lines (cons (list key (list (min t1 t2) (max t1 t2) k)) lines))))))
  (setq tot 0.0)
  (foreach l lines
    (setq iv (vl-sort (cdr l) '(lambda (x y) (< (car x) (car y)))) res nil)
    (foreach x iv
      (if (and res (<= (car x) (cadr (car res))))
        (setq res (cons (list (car (car res)) (max (cadr (car res)) (cadr x)) (max (caddr (car res)) (caddr x))) (cdr res)))
        (setq res (cons x res))))
    ;; длина объединённого отрезка x коэф. запаса (наибольший из наложенных участков)
    (foreach x res (setq tot (+ tot (* (- (cadr x) (car x)) (caddr x))))))
  (/ tot 1000.0))

;; спецификация: кабели по маркам (с запасом) + материалы прокладки по способу:
;;  O - общий для группы (лоток, короб, трос): по размеру, наложенные участки - один раз;
;;  E - свой материал каждого кабеля: по каждому кабелю; N - не считать.
;;  Опуски к приборам - по каждому кабелю. Всё с коэф. запаса.
(defun bk:spec-table (cs / mk p segs drops rows n pts mode len vs rm per one)
  ;; марка: (марка длина кол-во помещения)
  (foreach c cs
    (setq rm (vl-remove "" (list (bk:dev-room (bk:f (cadr c) "beg")) (bk:dev-room (bk:f (cadr c) "end")))))
    (if (setq p (assoc (bk:f (cadr c) "marka") mk))
      (setq mk (subst (list (car p) (+ (cadr p) (nth 4 c)) (1+ (caddr p))
                            (append (cadddr p) (vl-remove-if '(lambda (x) (member x (cadddr p))) rm))) p mk))
      (setq mk (append mk (list (list (bk:f (cadr c) "marka") (nth 4 c) 1 rm))))))
  (setq n 0 rows (list '("№" "Наименование" "Ед. изм." "Кол-во" "Примечание")))
  (foreach m mk
    (setq rows (append rows (list (list (itoa (setq n (1+ n))) (strcat "Кабель " (car m)) "м"
                                        (bk:ceil0 (cadr m))
                                        (strcat (itoa (caddr m)) " шт. кабелей"
                                                (if (cadddr m) (strcat "; помещения: " (bk:join (cadddr m) ", ")) "")))))))
  (foreach tp *bk:types*
    (setq mode (bk:type-mode (car tp)) vs nil)
    (if (/= mode "N")
      (progn
        ;; варианты материала: (диаметр размер)
        (foreach c cs
          (foreach x (nth 3 c)
            (if (and (= (nth 5 x) (car tp)) (/= (nth 11 x) "1") (not (member (list (nth 8 x) (nth 9 x)) vs)))
              (setq vs (cons (list (nth 8 x) (nth 9 x)) vs)))))
        (foreach v (reverse vs)
          (setq segs nil drops 0.0 len 0.0 per nil)
          (foreach c cs
            (setq one 0.0)
            (foreach x (nth 3 c)
              (if (and (= (nth 5 x) (car tp)) (equal (nth 8 x) (car v) 1e-6) (= (nth 9 x) (cadr v)) (/= (nth 11 x) "1"))
                (progn (setq one (+ one (nth 7 x)))
                (if (= (car x) "S")
                  (progn (setq pts (caddr (nth (1- (nth 6 x)) (nth 2 c))))
                         (setq len (+ len (nth 7 x)))
                         (while (cdr pts) (setq segs (cons (list (car pts) (cadr pts) (nth 4 x)) segs) pts (cdr pts))))
                  (setq drops (+ drops (nth 7 x)))))))
            (if (> one 0) (setq per (append per (list (strcat (bk:f (cadr c) "pos") " " (bk:r one 1)))))))
          (setq len (+ drops (if (= mode "O") (bk:route-len segs) len)))
          (if (> len 0.0001)
            (setq rows (append rows (list (list (itoa (setq n (1+ n)))
                                                (strcat (bk:spec-name (cadr tp))
                                                        (if (/= (cadr v) "") (strcat " " (cadr v)) "")
                                                        (if (> (car v) 0) (strcat " d" (rtos (car v) 2 0)) ""))
                                                "м" (bk:ceil0 len)
                                                (if (= mode "O") "общий для группы кабелей, наложенные участки - один раз, с запасом"
                                                  (strcat "по каждому кабелю, с запасом: " (bk:join per "; "))))))))))))
  ;; коробки ответвлений на приборах (ПРИМ-1 «с коробкой [марка]»): одна на каждую ветку
  (setq vs nil)
  (foreach c cs
    (if (and (/= (bk:f (cadr c) "par") "") (setq mode (bk:box-mark (bk:f (cadr c) "beg"))))
      (if (setq p (assoc mode vs))
        (setq vs (subst (list mode (1+ (cadr p)) (append (caddr p) (list (bk:f (cadr c) "pos")))) p vs))
        (setq vs (append vs (list (list mode 1 (list (bk:f (cadr c) "pos")))))))))
  (foreach v vs
    (setq rows (append rows (list (list (itoa (setq n (1+ n))) (if (= (car v) "") "Коробка ответвительная" (strcat "Коробка " (car v)))
                                        "шт." (cadr v) (strcat "ответвления на приборах: " (bk:pos-ranges (caddr v))))))))
  rows)

(defun bk:ceil1 (x) (/ (fix (+ (* x 10.0) 0.999)) 10.0))

(defun bk:spec-name (nm / l)                     ; "В лотке" -> "Лоток"; иначе как есть
  (setq l nm)
  (foreach p (reverse '(("На тросе в гофр. трубе" . "Гофр. труба на тросе") ("В гофр. трубе" . "Гофр. труба")
                        ("В гофротрубе" . "Гофротруба") ("В лотке" . "Лоток") ("В кабель-канале" . "Кабель-канал")
                        ("В трубе жёсткой" . "Труба жёсткая") ("В трубе" . "Труба") ("В металлорукаве" . "Металлорукав")))
    (if (wcmatch (bk:up nm) (strcat (bk:up (car p)) "*"))
      (setq l (strcat (cdr p) (substr nm (1+ (strlen (car p))))))))
  l)

;;; ---------- ММ_КАБЕЛЬ_ВСЕ ----------
(defun bk:list-rows (/ l fi m)
  (if (not *bk:all*) (setq *bk:all* (bk:merge-lines (mapcar 'bk:cable-info (bk:cable-map)))))
  (setq fi *bk:lfld* m (bk:up *bk:lflt*))
  (setq l (vl-remove-if-not
            '(lambda (c / f)
               (setq f (mapcar '(lambda (v) (bk:up (if (numberp v) (rtos v 2 1) v))) (bk:cfields c)))
               (or (= m "*")
                   (if (= fi 0) (vl-some '(lambda (v) (wcmatch v m)) f) (wcmatch (nth (1- fi) f) m))))
            *bk:all*))
  (setq *bk:lst* (vl-sort l '(lambda (a b / x y)
                               (setq x (nth *bk:lsort* (bk:cfields a)) y (nth *bk:lsort* (bk:cfields b)))
                               (if *bk:ldesc* (bk:sort-less y x) (bk:sort-less x y))))))

;; ПОЗИЦИЯ блоков-стояков у концов участка "стояк": "СТ1" или "СТ1/СТ2"
(defun bk:stoyak-pos (p / a b)
  (setq a (bk:dev-pos (bk:block-at (car (caddr p)))) b (bk:dev-pos (bk:block-at (last (caddr p)))))
  (cond ((and (= a "-") (= b "-")) "") ((= a b) a) ((= a "-") b) ((= b "-") a) (T (strcat a "/" b))))
;; название способа строки с позицией стояка
(defun bk:row-tname (r parts / p)
  (if (and (bk:stc (nth 5 r)) (nth 6 r) (setq p (nth (1- (nth 6 r)) parts)) (/= (bk:stoyak-pos p) ""))
    (strcat (bk:tname (nth 5 r)) " " (bk:stoyak-pos p))
    (bk:tname (nth 5 r))))

(defun bk:ctr (s n / k)                               ; по центру колонки шириной n (пробелами)
  (setq s (bk:cut s n) k (/ (- n (strlen s)) 2))
  (while (> k 0) (setq s (strcat " " s) k (1- k)))
  s)

(defun bk:cut (s n) (if (> (strlen s) n) (strcat (substr s 1 (1- n)) "~") s))

(defun bk:list-fill (/ f mk p tot)
  (bk:list-rows)
  (start_list "lst")
  (foreach c *bk:lst*
    (setq f (bk:cfields c))
    ;; каждое поле обрезается по ширине колонки, чтобы колонки не съезжали относительно заголовка
    ;; ширина колонки = разница табуляций минус запас (пропорциональный шрифт)
    (add_list (strcat (bk:cut (nth 0 f) 9) "\t" (bk:cut (nth 2 f) 32) "\t" (bk:cut (nth 3 f) 5) "\t"
                      (bk:cut (nth 4 f) 12) "\t" (bk:ch-flr (bk:f (cadr c) "beg")) "\t"
                      (bk:cut (nth 5 f) 12) "\t" (bk:ch-flr (bk:f (cadr c) "end")) "\t"
                      (bk:cut (strcat (bk:nz (nth 8 f)) " -> " (bk:nz (nth 9 f))) 20)
                      "\t" (itoa (bk:ceil0 (nth 6 f))) "\t" (bk:cut (nth 7 f) 14) "\t" (nth 10 f))))
  (end_list)
  ;; итоги по маркам в отобранных
  (setq tot 0.0)
  (foreach c *bk:lst*
    (setq tot (+ tot (nth 4 c)))
    (if (setq p (assoc (bk:f (cadr c) "marka") mk))
      (setq mk (subst (list (car p) (1+ (cadr p)) (+ (caddr p) (nth 4 c))) p mk))
      (setq mk (append mk (list (list (bk:f (cadr c) "marka") 1 (nth 4 c)))))))
  (start_list "sum")
  (foreach m mk (add_list (strcat (car m) "\t" (itoa (cadr m)) " шт.\t" (itoa (bk:ceil0 (caddr m))) " м")))
  (end_list)
  (bk:st "info" (strcat "Отобрано кабелей: " (itoa (length *bk:lst*)) "   общая длина с запасом: " (itoa (bk:ceil0 tot)) " м")))

(defun bk:cmd-list (/ fn id res sel ids e cs)
  (if (not *bk:lflt*) (setq *bk:lflt* "*"))
  (if (not *bk:lfld*) (setq *bk:lfld* 0))
  (if (not *bk:lsort*) (setq *bk:lsort* 0))
  (setq *bk:all* nil)
  (setq fn (bk:write-dcl "blok_kabel_list.dcl"
             '("bk_list : dialog { label = \"Все кабели чертежа\";"
               " : row { : popup_list { key = \"fld\"; label = \"Искать в:\"; width = 26; }"
               "         : edit_box { key = \"flt\"; label = \"Маска (* ?):\"; edit_width = 24; allow_accept = false; }"
               "         : button { key = \"b_flt\"; label = \"Применить\"; width = 12; fixed_width = true; }"
               "         : popup_list { key = \"srt\"; label = \"Сортировка:\"; width = 26; }"
               "         : toggle { key = \"desc\"; label = \"по убыванию\"; } }"
               " : list_box { key = \"hdr_l\"; height = 2; width = 190; tabs = \"12 50 58 74 86 102 114 140 148 166\"; is_tab_stop = false; }"
               " : list_box { key = \"lst\"; multiple_select = true; height = 18; width = 190; tabs = \"12 50 58 74 86 102 114 140 148 166\"; }"
               " : row { : button { key = \"b_all\"; label = \"Выделить все\"; }"
               "         : button { key = \"b_none\"; label = \"Снять выделение\"; }"
               "         : button { key = \"b_edit\"; label = \"Свойства выделенных...\"; }"
               "         : button { key = \"b_show\"; label = \"Показать на чертеже\"; }"
               "         : button { key = \"b_ren\"; label = \"Переименовать...\"; }"
               "         : button { key = \"b_bind\"; label = \"Новое начало/конец...\"; } }"
               " : text { key = \"info\"; width = 128; }"
               " : text { label = \"Итоги по маркам (отобранные):\"; }"
               " : list_box { key = \"sum\"; height = 5; width = 140; tabs = \"70 82\"; }"
               " : text { label = \"Выгрузка - выделенные кабели, а если ничего не выделено - все отобранные:\"; }"
               " : row { : button { key = \"b_csv\"; label = \"Таблица кабелей в CSV\"; }"
               "         : button { key = \"b_tbl\"; label = \"Таблица кабелей в DWG (листы А3)\"; }"
               "         : button { key = \"b_scsv\"; label = \"Спецификация в CSV\"; }"
               "         : button { key = \"b_stbl\"; label = \"Спецификация на чертёж\"; }"
               "         : button { key = \"b_pcsv\"; label = \"Участки между устройствами в CSV\"; } }"
               " : row { : spacer { width = 1; } : button { key = \"cancel\"; label = \"Закрыть\"; is_cancel = true; width = 16; fixed_width = true; } } }"))
        res 2 sel "")
  (while (member res '(2 3 6 7 8 9 10 12))
    (setq id (load_dialog fn))
    (if (not (new_dialog "bk_list" id))
      (setq res 0)
      (progn
        (start_list "fld") (foreach x *bk:fnames* (add_list x)) (end_list)
        (start_list "srt") (foreach x (cdr *bk:fnames*) (add_list x)) (end_list)
        (bk:st "fld" (itoa *bk:lfld*)) (bk:st "srt" (itoa *bk:lsort*)) (bk:st "desc" (if *bk:ldesc* "1" "0"))
        (bk:st "flt" *bk:lflt*)
        (start_list "hdr_l") (add_list "Позиция\tНоменклатура\tДиам.\tОткуда\tЭт. нач.\tКуда\tЭт. кон.\tПомещения\tДл., м\tСлой\tСущ.") (end_list)
        (bk:list-fill)
        (bk:st "lst" sel)
        (action_tile "flt" "(setq *bk:lflt* (if (= $value \"\") \"*\" $value) sel \"\") (bk:list-fill)")
        (action_tile "b_flt" "(setq *bk:lflt* (if (= (get_tile \"flt\") \"\") \"*\" (get_tile \"flt\")) sel \"\") (bk:list-fill)")
        (action_tile "fld" "(setq *bk:lfld* (atoi $value) sel \"\") (bk:list-fill)")
        (action_tile "srt" "(setq *bk:lsort* (atoi $value) sel \"\") (bk:list-fill)")
        (action_tile "desc" "(setq *bk:ldesc* (= $value \"1\") sel \"\") (bk:list-fill)")
        (action_tile "b_all" "(setq sel \"\") (repeat (length *bk:lst*) (setq sel (strcat sel (itoa (length (bk:idxs sel))) \" \"))) (bk:st \"lst\" sel)")
        (action_tile "b_none" "(setq sel \"\") (bk:st \"lst\" \"\")")
        (action_tile "lst" "(setq sel $value) (if (= $reason 4) (done_dialog 3))")
        (action_tile "b_edit" "(setq sel (get_tile \"lst\")) (done_dialog 3)")
        (action_tile "b_show" "(setq sel (get_tile \"lst\")) (done_dialog 2)")
        (action_tile "b_ren" "(setq sel (get_tile \"lst\")) (done_dialog 10)")
        (action_tile "b_bind" "(setq sel (get_tile \"lst\")) (done_dialog 11)")
        (foreach k '(("b_csv" . 6) ("b_tbl" . 7) ("b_scsv" . 8) ("b_stbl" . 9) ("b_pcsv" . 12))
          (action_tile (car k) (strcat "(setq sel (get_tile \"lst\")) (done_dialog " (itoa (cdr k)) ")")))
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (setq ids (mapcar '(lambda (i) (car (nth i *bk:lst*))) (bk:idxs sel))
              cs  (if (bk:idxs sel) (mapcar '(lambda (i) (nth i *bk:lst*)) (bk:idxs sel)) *bk:lst*))
        (cond
          ((and (= res 2) ids) (bk:show-cable (car ids)))
          ;; правка кабеля с ветками - всех его частей
          ((and (= res 3) ids (= (length ids) 1) (cdr (bk:line-ids (car ids)))) (bk:edit-line (car ids)) (setq *bk:all* nil))
          ((and (= res 3) ids) (setq ids (mapcar 'car (bk:unmerge (mapcar '(lambda (i) (nth i *bk:lst*)) (bk:idxs sel)))))
                               (if (cdr ids) (bk:edit-many ids) (bk:edit-one (car ids))) (setq *bk:all* nil))
          ((= res 10) (if (bk:ren-dialog cs) (progn (bk:sync-members cs) (bk:sync-branch-pos) (setq *bk:all* nil sel ""))))
          ((= res 12) (bk:csv-write "участки" (bk:pieces-table cs)))
          ((and (= res 11) ids) (bk:rebind ids) (setq *bk:all* nil))
          ((= res 11) (princ "\nСначала выделите кабели в списке."))
          ((= res 6) (bk:csv-write "кабели" (bk:cables-table cs)))
          ((= res 7) (bk:a3-table "Кабельный журнал" (bk:cables-table cs)))
          ((= res 8) (bk:csv-write "спецификация" (bk:spec-table (bk:unmerge cs))))
          ((= res 9) (bk:dwg-table "Спецификация кабелей и материалов прокладки" (bk:spec-table (bk:unmerge cs))))))))
  (vl-file-delete fn)
  (princ))

;;; ---------- быстрое переименование кабелей (ПОЗИЦИЯ) по маске ----------
;; поля маски: {#} {##} {###} - счётчик; {ПОЗ} - текущая ПОЗИЦИЯ; поля выносок ({НОМ} {ТИП} {ЭТАЖ} {ПОМ1} {ПОМ2} ...);
;; {Н.ИМЯ} / {К.ИМЯ} - атрибут блока начала / конца; {ЭТ1} {ЭТ2} - этаж начала / конца; {Э1} {Э2} - коротко (ММ_ЭТАЖИ)
(defun bk:ren-attrs (s pref h / i j tag)
  (while (setq i (vl-string-search (strcat "{" pref ".") s))
    (setq j (vl-string-search "}" s i))
    (if (null j) (setq j (strlen s)))
    (setq tag (strcase (substr s (+ i 4) (- j i 3))))
    (setq s (strcat (substr s 1 i) (bk:attr (bk:hent h) tag) (substr s (+ j 2)))))
  s)
(defun bk:fl-short (h / v) (setq v (bk:attr (bk:hent h) "ЭТАЖ")) (if bn:short (bn:short v) v))
(defun bk:ren-name (c mask n / d s i j k num)
  (setq d (cadr c) s mask)
  (setq s (bk:ren-attrs s "Н" (bk:f d "beg")) s (bk:ren-attrs s "К" (bk:f d "end")))
  ;; счётчик {#...}
  (while (and (setq i (vl-string-search "{#" s)) (setq j (vl-string-search "}" s i)))
    (setq k (- j i 1) num (itoa n))
    (while (< (strlen num) k) (setq num (strcat "0" num)))
    (setq s (strcat (substr s 1 i) num (substr s (+ j 2)))))
  (foreach v (append (list (cons "ПОЗ" (bk:f d "pos"))
                           (cons "ЭТ1" (bk:attr (bk:hent (bk:f d "beg")) "ЭТАЖ"))
                           (cons "ЭТ2" (bk:attr (bk:hent (bk:f d "end")) "ЭТАЖ"))
                           (cons "Э1" (bk:fl-short (bk:f d "beg"))) (cons "Э2" (bk:fl-short (bk:f d "end"))))
                     (bk:cvars (car c) d (bk:f d "pos")))
    (setq s (bk:subst-all s (strcat "{" (car v) "}") (cdr v))))
  (bk:trim s))

;; план: ((кабель старое новое) ...)
;; точка вставки блока конца кабеля c (или nil)
(defun bk:end-ip (c / e) (if (and (setq e (bk:hent (bk:f (cadr c) "end"))) (entget e)) (bk:2d (cdr (assoc 10 (entget e))))))
;; авто-порядок: сверху вниз рядами (допуск tol по высоте), в ряду - слева направо
(defun bk:ren-auto-order (cs tol / l rows row y0 out)
  (setq l (vl-sort (mapcar '(lambda (c) (cons (cond ((bk:end-ip c)) ('(0.0 0.0))) c)) cs)
                   '(lambda (a b) (> (cadr (car a)) (cadr (car b))))))
  (foreach x l
    (if (and row (<= (abs (- y0 (cadr (car x)))) tol))
      (setq row (cons x row))
      (progn (if row (setq rows (cons row rows))) (setq row (list x) y0 (cadr (car x))))))
  (if row (setq rows (cons row rows)))
  (foreach r (reverse rows)
    (setq out (append out (mapcar 'cdr (vl-sort r '(lambda (a b) (< (car (car a)) (car (car b)))))))))
  out)
;; номер конечного устройства: число в конце его ПОЗИЦИИ (AS-8.4 -> 4)
(defun bk:end-num (c / x) (if (setq x (bk:pos-split (bk:dev-pos (bk:f (cadr c) "end")))) (cdr x)))
;; план: ((кабель старое новое) ...); нумерация: 0 - по порядку списка, 1 - по номеру конечного устройства, 2 - авто (план)
(defun bk:ren-plan (cs / n sp out m k)
  (setq n (atoi (get_tile "r_st")) sp (max 1 (atoi (get_tile "r_sp"))) m (substr (get_tile "r_nm") 2))
  (if (= m "2") (setq cs (bk:ren-auto-order cs (max 0.0 (bk:num (get_tile "r_tol"))))))
  (foreach c cs
    (setq k (if (and (= m "1") (bk:end-num c)) (bk:end-num c) n))
    (setq out (append out (list (list c (bk:f (cadr c) "pos") (bk:ren-name c (get_tile "r_mask") k)))) n (+ n sp)))
  out)
(defun bk:ren-show (cs / pl news others d)
  (setq pl (bk:ren-plan cs) news (mapcar '(lambda (p) (strcase (caddr p))) pl))
  ;; позиции кабелей, которые не переименовываются
  (setq others (vl-remove-if '(lambda (x) (member x (mapcar '(lambda (c) (strcase (bk:f (cadr c) "pos"))) cs))) (bk:used-pos)))
  (start_list "r_lst")
  (foreach p pl
    (setq d (cadr (car p)))
    (add_list (strcat (bk:cut (caddr p) 14) "\t" (bk:cut (cadr p) 12) "\t" (bk:cut (bk:f d "marka") 30) "\t"
                      (bk:cut (bk:dev-pos (bk:f d "beg")) 12) "\t" (bk:ch-flr (bk:f d "beg")) "\t"
                      (bk:cut (bk:dev-pos (bk:f d "end")) 12) "\t" (bk:ch-flr (bk:f d "end")) "\t"
                      (if (numberp (nth 4 (car p))) (itoa (bk:ceil0 (nth 4 (car p)))) "") "\t"
                      (cond ((= (caddr p) "") "пусто!")
                            ((member (strcase (caddr p)) others) "занято другим кабелем!")
                            ((> (length (vl-remove-if-not '(lambda (x) (= x (strcase (caddr p)))) news)) 1) "повтор")
                            (T "")))))
  (end_list)
  pl)

;; конструктор маски галочками: префикс + отмеченные части через разделитель + суффикс
(setq *bk:rparts* '(("c_e" "p_e" ("{Э2}" "{Э1}" "{ЭТ2}" "{ЭТ1}" "{ЭТАЖ}"))
                    ("c_k" "p_k" ("{К.ПОЗИЦИЯ}" "{Н.ПОЗИЦИЯ}"))
                    ("c_m" "p_m" ("{ПОМ2}" "{ПОМ1}"))
                    ("c_o" "p_o" ("{ПОЗ}" "{НОМ}"))
                    ("c_n" "p_n" ("{#}" "{##}" "{###}"))))
(defun bk:ren-build (cs / l)
  (foreach r *bk:rparts*
    (if (= (get_tile (car r)) "1") (setq l (append l (list (nth (atoi (get_tile (cadr r))) (caddr r)))))))
  (set_tile "r_mask" (strcat (get_tile "r_pre") (bk:join l (get_tile "r_sep")) (get_tile "r_suf")))
  (bk:ren-show cs))
(defun bk:ren-keys () (append '("r_pre" "r_sep" "r_suf") (apply 'append (mapcar '(lambda (r) (list (car r) (cadr r))) *bk:rparts*))))

;; id кабеля НЕ из переименования, у которого ПОЗИЦИЯ = новому имени строки p (или nil)
(defun bk:ren-occ (p pl / ids nm r)
  (setq ids (mapcar '(lambda (x) (car (car x))) pl) nm (strcase (caddr p)))
  (if (/= nm "")
    (foreach m (bk:cable-map)
      (if (and (null r) (not (member (car m) ids)) (= (strcase (bk:f (cadr m) "pos")) nm)) (setq r (car m)))))
  r)
;; занятые имена (через запятую) или nil
(defun bk:ren-conf (pl / mine others l)
  (setq mine (mapcar '(lambda (x) (strcase (bk:f (cadr (car x)) "pos"))) pl)
        others (vl-remove-if '(lambda (x) (member x mine)) (bk:used-pos)))
  (foreach p pl (if (and (member (strcase (caddr p)) others) (not (member (caddr p) l))) (setq l (append l (list (caddr p))))))
  (if l (bk:join l ", ")))
(defun bk:ren-dialog (cs / fn id res pl warn sel)
  (if (not *bk:rchk*) (setq *bk:rchk* '("k" "." "" "1" "0" "0" "0" "0" "0" "0" "0" "1" "0")))
  (if (not *bk:rmask*) (setq *bk:rmask* "k{Э2}.{#}" *bk:rst* "1" *bk:rsp* "1"))
  (setq fn (bk:write-dcl "blok_kabel_ren.dcl"
    '("bk_ren : dialog { label = \"Переименование кабелей (ПОЗИЦИЯ)\";"
      " : text { key = \"r_hdr\"; width = 120; }"
      " : boxed_column { label = \"Конструктор (галочки) - собирает маску; маску можно и дописать вручную\";"
      "  : row { : edit_box { key = \"r_pre\"; label = \"Префикс:\"; edit_width = 8; allow_accept = false; }"
      "          : edit_box { key = \"r_sep\"; label = \"Разделитель:\"; edit_width = 3; allow_accept = false; }"
      "          : edit_box { key = \"r_suf\"; label = \"Суффикс:\"; edit_width = 8; allow_accept = false; } }"
      "  : row { : toggle { key = \"c_e\"; label = \"Этаж\"; } : popup_list { key = \"p_e\"; width = 26; }"
      "          : toggle { key = \"c_k\"; label = \"ПОЗИЦИЯ блока\"; } : popup_list { key = \"p_k\"; width = 26; }"
      "          : toggle { key = \"c_m\"; label = \"Помещение\"; } : popup_list { key = \"p_m\"; width = 22; } }"
      "  : row { : toggle { key = \"c_o\"; label = \"Текущее\"; } : popup_list { key = \"p_o\"; width = 26; }"
      "          : toggle { key = \"c_n\"; label = \"Номер по порядку\"; } : popup_list { key = \"p_n\"; width = 18; } : spacer { } } }"
      " : row { : edit_box { key = \"r_mask\"; label = \"Маска:\"; edit_width = 50; allow_accept = false; }"
      "         : edit_box { key = \"r_st\"; label = \"Начать с:\"; edit_width = 5; allow_accept = false; }"
      "         : edit_box { key = \"r_sp\"; label = \"Шаг:\"; edit_width = 4; allow_accept = false; } }"
      " : text { label = \"{#} {##} {###} - номер по порядку (1 / 01 / 001);  {ПОЗ} - текущая ПОЗИЦИЯ;  {НОМ} - номенклатура;  {ЭТАЖ} - этаж кабеля\"; }"
      " : text { label = \"{Н.ИМЯ} / {К.ИМЯ} - атрибут блока начала / конца, напр. {Н.ПОЗИЦИЯ}, {К.ПОЗИЦИЯ};  {ЭТ1} {ЭТ2} - этаж начала / конца;  {Э1} {Э2} - коротко\"; }"
      " : text { label = \"{ПОМ1} {ПОМ2} - помещение начала / конца;  {ОТКУДА} {КУДА} - ПОЗИЦИИ блоков.   Примеры:  k{Э2}.{#}  ->  k8.1      {К.ПОЗИЦИЯ}-{##}  ->  AS-8.1-01\"; }"
      " : row { : radio_row { key = \"r_nm\"; label = \"Нумерация {#}\";"
      "   : radio_button { key = \"n0\"; label = \"по порядку списка\"; } : radio_button { key = \"n1\"; label = \"по номеру конечного устройства\"; }"
      "   : radio_button { key = \"n2\"; label = \"авто: слева направо, сверху вниз\"; } }"
      "   : edit_box { key = \"r_tol\"; label = \"Допуск ряда:\"; edit_width = 7; allow_accept = false; } }"
      " : list_box { key = \"r_hdl\"; height = 2; width = 140; tabs = \"16 30 64 78 90 104 116 124\"; is_tab_stop = false; }"
      " : list_box { key = \"r_lst\"; height = 20; width = 140; tabs = \"16 30 64 78 90 104 116 124\"; }"
      " : text { key = \"r_info\"; width = 120; }"
      " : row { : button { key = \"accept\"; label = \"Переименовать\"; is_default = true; width = 18; }"
      "         : button { key = \"b_occ\"; label = \"Показать занятый\"; width = 18; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }")))
  (setq res 2)
  (while (= res 2)
  (setq id (load_dialog fn))
  (if (new_dialog "bk_ren" id)
    (progn
      (bk:st "r_hdr" (strcat "Кабелей: " (itoa (length cs)) " (выделенные, а если ничего не выделено - все отобранные), в порядке списка. Предпросмотр меняется сразу."))
      (bk:st "r_mask" *bk:rmask*) (bk:st "r_st" *bk:rst*) (bk:st "r_sp" *bk:rsp*)
      (if (not *bk:rnm*) (setq *bk:rnm* "n0" *bk:rtol* "1000"))
      (set_tile "r_nm" *bk:rnm*) (bk:st "r_tol" *bk:rtol*)
      (start_list "r_hdl") (add_list "Новое имя\tСейчас\tНоменклатура\tОткуда\tЭт. нач.\tКуда\tЭт. кон.\tДл., м\tПроверка") (end_list)
      (foreach r *bk:rparts*
        (start_list (cadr r))
        (foreach x (caddr r) (add_list (cdr (assoc x '(("{Э2}" . "конца, коротко (8)") ("{Э1}" . "начала, коротко") ("{ЭТ2}" . "конца, полностью")
                                                     ("{ЭТ1}" . "начала, полностью") ("{ЭТАЖ}" . "кабеля") ("{К.ПОЗИЦИЯ}" . "конца (AS-8.1)")
                                                     ("{Н.ПОЗИЦИЯ}" . "начала (CAB-8.1)") ("{ПОМ2}" . "конца") ("{ПОМ1}" . "начала")
                                                     ("{ПОЗ}" . "ПОЗИЦИЯ кабеля") ("{НОМ}" . "номенклатура") ("{#}" . "1") ("{##}" . "01") ("{###}" . "001"))))))
        (end_list))
      (mapcar 'set_tile (bk:ren-keys) *bk:rchk*)
      (foreach k (bk:ren-keys) (action_tile k "(bk:ren-build cs)"))
      (bk:ren-show cs)
      (foreach k '("r_mask" "r_st" "r_sp" "r_nm" "r_tol") (action_tile k "(bk:ren-show cs)"))
      (if sel (set_tile "r_lst" sel))
      ;; показать кабель, который уже носит новое имя выбранной строки
      (action_tile "b_occ" "(setq *bk:rnm* (get_tile \"r_nm\") *bk:rtol* (get_tile \"r_tol\") *bk:rchk* (mapcar 'get_tile (bk:ren-keys)) *bk:rmask* (get_tile \"r_mask\") *bk:rst* (get_tile \"r_st\") *bk:rsp* (get_tile \"r_sp\") sel (get_tile \"r_lst\") pl (bk:ren-show cs)) (if (and (/= sel \"\") (bk:ren-occ (nth (atoi sel) pl) pl)) (done_dialog 2) (bk:st \"r_info\" \"Выберите строку с пометкой «занято другим кабелем».\"))")
      (action_tile "accept" "(setq *bk:rnm* (get_tile \"r_nm\") *bk:rtol* (get_tile \"r_tol\") *bk:rchk* (mapcar 'get_tile (bk:ren-keys)) *bk:rmask* (get_tile \"r_mask\") *bk:rst* (get_tile \"r_st\") *bk:rsp* (get_tile \"r_sp\") pl (bk:ren-show cs)) (cond ((vl-some '(lambda (p) (= (caddr p) \"\")) pl) (bk:st \"r_info\" \"Есть пустые имена - измените маску.\")) ((and (not warn) (setq warn (bk:ren-conf pl))) (bk:st \"r_info\" (strcat \"ВНИМАНИЕ: имена уже заняты другими кабелями: \" warn \". Ещё раз «Переименовать» - всё равно записать; «Показать занятый» - посмотреть.\"))) (T (done_dialog 1)))")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))))
  (unload_dialog id)
  (if (= res 2) (bk:show-cable (bk:ren-occ (nth (atoi sel) pl) pl))))
  (vl-file-delete fn)
  (if (= res 1)
    (progn
      (foreach p pl (if (/= (cadr p) (caddr p)) (bk:set-field (car (car p)) "pos" (caddr p))))
      (vl-catch-all-apply 'bk:update-leaders nil)
      (vl-catch-all-apply 'bk:end-labels-all nil)
      (princ (strcat "\nПереименовано кабелей: " (itoa (length (vl-remove-if '(lambda (p) (= (cadr p) (caddr p))) pl))) "."))
      T)))

;;; ---------- ММ_КАБЕЛЬ_ПЕРЕИМЕНОВАТЬ: кабели выделенных устройств ----------
;; окно типов блоков: types = ((имя блоков кабелей) ...), none = ((ПОЗИЦИЯ имя этаж) ...) -> выбранные имена
(defun bk:rn-types (types none / fn id res sel out i)
  (setq fn (bk:write-dcl "blok_kabel_rnt.dcl"
    '("bk_rnt : dialog { label = \"Переименование кабелей: типы устройств\";"
      " : text { label = \"Типы блоков среди выделенного (кабели - подходящие началом или концом):\"; }"
      " : list_box { key = \"hdr\"; height = 2; width = 90; tabs = \"50 62 74\"; is_tab_stop = false; }"
      " : list_box { key = \"lst\"; multiple_select = true; height = 12; width = 90; tabs = \"50 62 74\"; }"
      " : row { : button { key = \"b_all\"; label = \"Выделить все\"; } : button { key = \"b_none\"; label = \"Снять выделение\"; } : spacer { } }"
      " : text { key = \"t_none\"; width = 90; }"
      " : list_box { key = \"lnone\"; height = 8; width = 90; tabs = \"18 60\"; }"
      " : row { : button { key = \"accept\"; label = \"Далее\"; is_default = true; width = 14; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }")))
  (setq id (load_dialog fn))
  (if (new_dialog "bk_rnt" id)
    (progn
      (start_list "hdr") (add_list "Блок\tШт.\tс кабелями\tКабелей") (end_list)
      (start_list "lst") (foreach t1 types (add_list (strcat (bk:cut (car t1) 46) "\t" (itoa (cadr t1)) "\t" (itoa (caddr t1)) "\t" (itoa (cadddr t1))))) (end_list)
      (setq sel "" i 0) (repeat (length types) (setq sel (strcat sel (itoa i) " ") i (1+ i)))
      (set_tile "lst" sel)
      (set_tile "t_none" (if none (strcat "Без кабелей - " (itoa (length none)) " блок(ов): ПОЗИЦИЯ / блок / этаж") "Кабели есть у всех выделенных блоков."))
      (start_list "lnone") (foreach x none (add_list (strcat (bk:cut (car x) 16) "\t" (bk:cut (cadr x) 40) "\t" (caddr x)))) (end_list)
      (action_tile "b_all" "(set_tile \"lst\" sel)")
      (action_tile "b_none" "(set_tile \"lst\" \"\")")
      (action_tile "accept" "(setq out (mapcar '(lambda (i) (car (nth i types))) (bk:idxs (get_tile \"lst\")))) (done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))))
  (unload_dialog id) (vl-file-delete fn)
  (if (= res 1) out))

(defun bk:cmd-rename (/ ss i e h hs names map ms types none t1 n c k sel cs bn)
  (princ "\nВыделите устройства (рамкой): ")
  (if (setq ss (ssget '((0 . "INSERT"))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq e (ssname ss i) i (1+ i) h (cdr (assoc 5 (entget e))))
        (setq hs (cons (list h (vla-get-EffectiveName (vlax-ename->vla-object e)) e) hs)))
      (setq map (bk:cable-map))
      ;; кабели каждого блока
      (foreach b hs
        (setq ms (vl-remove-if-not '(lambda (m) (or (= (bk:f (cadr m) "beg") (car b)) (= (bk:f (cadr m) "end") (car b)))) map))
        (setq b (append b (list ms)))
        (if (setq t1 (assoc (cadr b) types))
          (setq types (subst (list (car t1) (1+ (cadr t1)) (+ (caddr t1) (if ms 1 0)) (+ (cadddr t1) (length ms))) t1 types))
          (setq types (append types (list (list (cadr b) 1 (if ms 1 0) (length ms))))))
        (if (null ms) (setq none (cons (list (bk:dev-pos (car b)) (cadr b) (bk:attr (caddr b) "ЭТАЖ")) none)))
        (setq names (cons b names)))
      (setq types (vl-sort types '(lambda (a b) (< (car a) (car b)))))
      (foreach x none (princ (strcat "\nНет кабелей: " (car x) " (" (cadr x) ")")))
      (if (setq sel (bk:rn-types types (reverse none)))
        (progn
          ;; кабели выбранных типов, без повторов
          (foreach b names
            (if (member (cadr b) sel)
              (foreach m (cadddr b) (if (not (assoc (car m) cs)) (setq cs (cons m cs))))))
          (if (null cs)
            (princ "\nУ выбранных типов устройств нет кабелей.")
            (progn
              (setq cs (mapcar 'bk:cable-info cs))
              (bk:ren-dialog cs)))))))
  (princ))

(defun bk:idxs (s) (if (and s (/= s "")) (read (strcat "(" s ")"))))

(defun bk:show-cable (id / l mn mx a b o p1 p2 ss)
  (setq l (bk:segs id) ss (ssadd))
  (foreach e l
    (setq o (vlax-ename->vla-object e))
    (vla-GetBoundingBox o 'a 'b)
    (setq a (vlax-safearray->list a) b (vlax-safearray->list b)
          mn (if mn (mapcar 'min mn a) a) mx (if mx (mapcar 'max mx b) b))
    (ssadd e ss))
  (if mn
    (progn
      (setq p1 (mapcar '- mn '(1000.0 1000.0 0.0)) p2 (mapcar '+ mx '(1000.0 1000.0 0.0)))
      (vla-ZoomWindow (vlax-get-acad-object) (vlax-3d-point p1) (vlax-3d-point p2))
      (sssetfirst nil ss)
      (getstring "\nКабель показан. Enter - вернуться к списку: ")
      (sssetfirst nil nil))))

;;; ---------- ММ_КАБЕЛЬ_ЛЕГЕНДА: таблица условных обозначений ----------
;; "В лотке" -> "Кабель в лотке"; "На тросе" -> "Кабель на тросе"; иначе "Кабель в ..."
(defun bk:legend-name (nm / l)
  (setq l (strcase nm T))
  (if (wcmatch l "в *,во *,на *,за *,под *,по *,открыто*,скрыто*")
    (strcat "Кабель " l)
    (strcat "Кабель в " l)))

(defun bk:cmd-legend (/ used len e d th pt tbl n i y x1 x2 c1 c2 rh o ss lts m lay)
  ;; способы прокладки, реально нарисованные на чертеже (длина > 0)
  (foreach e (bk:all-segs)
    (setq d (bk:get e)
          len (vlax-curve-getDistAtParam (vlax-ename->vla-object e) (vlax-curve-getEndParam (vlax-ename->vla-object e))))
    (if (and (> len 1e-6) (not (member (bk:f d "code") used)) (bk:type (bk:f d "code")))
      (setq used (append used (list (bk:f d "code"))) lts (bk:fn d "lts") lay (bk:f d "layer"))))
  (setq used (vl-remove-if-not '(lambda (c) (member c used)) (mapcar 'car *bk:types*)))
  (if (null used)
    (princ "\nНа чертеже нет кабелей.")
    (progn
      (setq th (getreal (strcat "\nВысота текста таблицы <" (rtos (* 2.5 (max lts 1.0)) 2 1) ">: ")))
      (if (null th) (setq th (* 2.5 (max lts 1.0))))
      (if (setq pt (getpoint "\nТочка вставки таблицы (левый верхний угол): "))
        (progn
          (setq pt (trans pt 1 0) c1 (* 12.0 th) c2 (* 32.0 th) rh (* 2.4 th) n (length used))
          (setq tbl (vla-AddTable (bk:space) (vlax-3d-point pt) (+ 2 n) 2 rh c1))
          (vla-SetColumnWidth tbl 0 c1)
          (vla-SetColumnWidth tbl 1 c2)
          (vla-SetTextHeight tbl 7 th)
          (vla-SetText tbl 0 0 "Условные обозначения")
          (vla-SetText tbl 1 0 "Обозначение")
          (vla-SetText tbl 1 1 "Наименование")
          (setq i 2)
          (foreach c used
            (vla-SetText tbl i 1 (bk:legend-name (cadr (bk:type c))))
            (vl-catch-all-apply 'vla-SetCellAlignment (list tbl i 1 acMiddleCenter))
            (setq i (1+ i)))
          (vl-catch-all-apply 'vla-put-HorzCellMargin (list tbl (* 0.6 th)))
          (vla-RecomputeTableBlock tbl :vlax-true)
          ;; образцы линий поверх первой колонки
          (setq ss (ssadd) i 0 y (cadr pt) x1 (+ (car pt) (* 0.1 c1)) x2 (+ (car pt) (* 0.9 c1)))
          (ssadd (vlax-vla-object->ename tbl) ss)
          (repeat 2 (setq y (- y (vla-GetRowHeight tbl i)) i (1+ i)))
          (foreach c used
            (setq rh (vla-GetRowHeight tbl i)
                  o (vlax-invoke (bk:space) 'AddLightWeightPolyline
                      (list x1 (- y (* 0.5 rh)) x2 (- y (* 0.5 rh)))))
            (vla-put-Linetype o (bk:load-lt c))
            (vla-put-LinetypeScale o (max 0.001 lts))
            (if (tblsearch "LAYER" lay) (vla-put-Layer o lay))
            (ssadd (vlax-vla-object->ename o) ss)
            (setq y (- y rh) i (1+ i)))
          (ssadd (bk:mask (bk:ss->l ss)) ss)
          (setq m (getvar "CMDECHO")) (setvar "CMDECHO" 0)
          (command "_.-GROUP" "_C" "*" "" ss "")
          (setvar "CMDECHO" m)
          (princ (strcat "\nТаблица условных обозначений: " (itoa n) " способ(ов) прокладки."))))))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_ПЕРЕСОБРАТЬ ----------
(defun bk:cmd-heal (/ ids)
  (foreach id (setq ids (bk:pick-ids "\nВыберите кабели для пересборки: "))
    (bk:rebuild (bk:get (car (bk:segs id))) (bk:parts id)))
  (bk:update-leaders)
  (princ (strcat "\nПересобрано кабелей: " (itoa (length ids)) ".")))

;;; ---------- ММ_КАБЕЛЬ_ВЫНОСКА ----------
(defun bk:cmd-leader (/ ids ap lp arr ml e p lts par h hs ka es)
  (if (/= (length *bk:ld*) 4) (setq *bk:ld* (list (nth 0 *bk:ld*) (nth 1 *bk:ld*) (nth 2 *bk:ld*) "0")))
  ;; режим: все кабели на участке (галочка, запоминается) или выбор кабелей
  (initget "Да Нет")
  (setq ka (getkword (strcat "\nВсе кабели на участке (и новые по нему)? [Да/Нет] <"
                             (if (= (nth 3 *bk:ld*) "1") "Да" "Нет") ">: ")))
  (if ka (setq *bk:ld* (bk:replace-nth 3 (if (= ka "Да") "1" "0") *bk:ld*)))
  (if (if (= (nth 3 *bk:ld*) "1") T (setq ids (bk:pick-ids "\nВыберите кабели для общей выноски: ")))
    (progn
      (while (progn (initget "Параметры Формат")
                    (member (setq ap (getpoint "\nТочка на кабеле (начало выноски) [Параметры/Формат]: ")) '("Параметры" "Формат")))
        (if (= ap "Формат") (bk:cmd-ldfmt)
          (if (setq p (bk:ld-dialog *bk:ld*)) (setq *bk:ld* p))))
      (if (and ap (= (nth 3 *bk:ld*) "1"))
        (progn
          (setq ids (bk:segs-at (trans ap 1 0)))
          (setq ids (mapcar 'car (bk:no-st ids)))
          ;; не попали точно - щелчок по самому кабелю, точка выноски - ближайшая на нём
          (while (and (null ids) (setq es (entsel "\nВ точке нет кабелей. Щёлкните по кабелю (Enter - выход): ")))
            (if (bk:get (car es))
              (setq ap (trans (vlax-curve-getClosestPointTo (vlax-ename->vla-object (car es)) (trans (cadr es) 1 0)) 0 1)
                    ids (mapcar 'car (bk:no-st (bk:segs-at (trans ap 1 0)))))
              ;; на крайний случай - хотя бы выбранный кабель
              (if (null ids) (setq ids (list (bk:f (bk:get (car es)) "id"))))))
          (if (null ids) (setq ap nil))))
      (if (and ap (setq lp (getpoint ap "\nПоложение текста: ")))
        (progn
          (setq arr (vlax-make-safearray vlax-vbDouble '(0 . 5)))
          (vlax-safearray-fill arr (append (trans ap 1 0) (trans lp 1 0)))
          (setq ml (vla-AddMLeader (bk:space) arr 'li) e (vlax-vla-object->ename ml))
          ;; пустые размеры -> по масштабу кабеля: текст 2.5 x масштаб, кружок 1.0 x масштаб
          (setq lts (max 0.001 (bk:fn (bk:get (car (bk:segs (car ids)))) "lts"))
                par (list (if (= (nth 0 *bk:ld*) "") (rtos (* 2.5 lts) 2 2) (nth 0 *bk:ld*))
                          (if (= (nth 1 *bk:ld*) "") (rtos (* 1.0 lts) 2 2) (nth 1 *bk:ld*))
                          (nth 2 *bk:ld*) (nth 3 *bk:ld*))
                h (vla-get-Handle ml))
          (bk:ld-put e par)
          ;; добавить выноску к списку выносок каждого кабеля
          (foreach id ids
            (setq hs (vl-remove-if-not '(lambda (x) (and (handent x) (entget (handent x))))
                                       (bk:ld-handles (bk:get (car (bk:segs id))))))
            (bk:set-field id "ld" (bk:join (append hs (list h)) " ")))
          ;; только новая выноска (не все выноски чертежа)
          (bk:ensure-style (nth 9 (bk:ldfmt)))
          (vla-put-ContentType ml acMTextContent)
          (vl-catch-all-apply 'vla-put-TextString (list ml (bk:ld-full e ids)))
          (vl-catch-all-apply 'bk:ld-style (list e))
          (princ (strcat "\nВыноска создана для кабелей: " (itoa (length ids))
                         ". Параметры: ММ_КАБЕЛЬ_ВЫНОСКА_ПАРАМ."))))))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_ВЫНОСКА_ПРОКЛ: в чём идёт кабель, расчётный диаметр, заполнение ----------
;; кабели в точке p: ((id d_кабеля код d_материала размер позиция) ...)
;; ближайшая точка кривой к p в плане (проекция по Z, как в выборе наложенных кабелей); nil при ошибке
(defun bk:cpt (o p / q)
  (setq q (vl-catch-all-apply 'vlax-curve-getClosestPointToProjection
            (list o (list (car p) (cadr p) 0.0) '(0.0 0.0 1.0))))
  (if (vl-catch-all-error-p q)
    (setq q (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list o (list (car p) (cadr p) 0.0)))))
  (if (vl-catch-all-error-p q) (list 1e20 1e20 0.0) q))

;; убрать стояки из найденного, если есть обычные участки (на самом стояке - оставить)
(defun bk:no-st (l / r)
  (setq r (vl-remove-if '(lambda (x) (bk:stc (nth 2 x))) l))
  (if r r l))

;; ближайшая к p точка полилинии кабеля (чистая геометрия по вершинам, в плане): (расстояние точка)
(defun bk:pl-near (e p / pts a b dx dy l2 u q d best bq)
  (setq pts (bk:pts e) p (bk:2d p))
  (while (cdr pts)
    (setq a (car pts) b (cadr pts) pts (cdr pts)
          dx (- (car b) (car a)) dy (- (cadr b) (cadr a)) l2 (+ (* dx dx) (* dy dy))
          u (if (> l2 1e-12) (max 0.0 (min 1.0 (/ (+ (* (- (car p) (car a)) dx) (* (- (cadr p) (cadr a)) dy)) l2))) 0.0)
          q (list (+ (car a) (* u dx)) (+ (cadr a) (* u dy)))
          d (distance p q))
    (if (or (null best) (< d best)) (setq best d bq q)))
  (if best (list best bq)))

;; участки кабелей рядом с точкой p (МСК): если точка на экране - выбор секущей рамкой ±r (быстро),
;; иначе - все участки чертежа
(defun bk:segs-near (p r / c h w u)
  (setq c (getvar "VIEWCTR") h (/ (getvar "VIEWSIZE") 2.0)
        w (* h (/ (car (getvar "SCREENSIZE")) (cadr (getvar "SCREENSIZE"))))
        u (trans p 0 1))
  (if (and (= (getvar "WORLDUCS") 1) (< (abs (- (car u) (car c))) (- w r)) (< (abs (- (cadr u) (cadr c))) (- h r)))
    (bk:ss->l (ssget "_C" (list (- (car u) r) (- (cadr u) r)) (list (+ (car u) r) (+ (cadr u) r)) '((-3 ("BK")))))
    (bk:all-segs)))
(defun bk:segs-at (p / tol out r d id best bq bs)
  ;; 1) ближайший к точке кабель в пределах прицела (не стояк, если рядом есть обычный участок);
  ;; 2) все кабели, точно наложенные на него в этой точке (допуск *bk:otol*)
  (setq tol (* 3.0 (bk:ptol)))
  (foreach e (bk:segs-near p tol)
    (if (and (setq r (bk:pl-near e p)) (<= (car r) tol))
      (progn
        (setq bs (bk:stc (bk:f (bk:get e) "code")))
        (if (or (null best)
                (and (cadr best) (not bs))                         ; обычный участок важнее стояка
                (and (eq (cadr best) bs) (< (car r) (car best))))
          (setq best (list (car r) bs) bq (cadr r))))))
  ;; запасной путь: выбор рамкой мог не сработать (вид, ПСК) - проверить все участки чертежа
  (if (null bq)
    (foreach e (bk:all-segs)
      (if (and (setq r (bk:pl-near e p)) (<= (car r) tol))
        (progn
          (setq bs (bk:stc (bk:f (bk:get e) "code")))
          (if (or (null best) (and (cadr best) (not bs)) (and (eq (cadr best) bs) (< (car r) (car best))))
            (setq best (list (car r) bs) bq (cadr r)))))))
  (if (null bq)
    (princ (strcat "\nВ точке нет кабелей (прицел " (rtos tol 2 2) ").")))
  (foreach e (if bq (bk:segs-near bq (+ *bk:otol* 1.0)))
    (setq d (bk:get e) id (bk:f d "id"))
    (if (and (not (assoc id out))
             (or (cadr best) (not (bk:stc (bk:f d "code"))))           ; у обычного участка стояки в точке не берутся
             (setq r (bk:pl-near e bq)) (<= (car r) *bk:otol*))
      (setq out (cons (list id (bk:fn d "diam") (bk:f d "code") (bk:md-of (bk:fn d "md") (bk:f d "code") nil)
                            (bk:f d "sz") (bk:f d "pos") (bk:f d "ex"))
                      out))))
  (reverse out))

(defun bk:pl-name (code md sz / ex)
  (bk:pl-name-ex code md sz ""))
;; ex = "1" - существующий материал прокладки: к названию добавляется "(сущ.)"
(defun bk:pl-name-ex (code md sz ex)
  (strcat (bk:spec-name (bk:tname code)) (if (/= sz "") (strcat " " sz) "")
          (if (and (= sz "") (bk:md-on code) (> md 0)) (strcat " d" (rtos md 2 0)) "")
          (if (= ex "1") " (сущ.)" "")))

;; текст: способ(ы) / расчётный диаметр (у нескольких кабелей - общий диаметр пучка) / заполнение
(defun bk:pl-text (p / cs c nm names md sz sm vars)
  (if (and p (setq cs (bk:segs-at p)))
    (progn
      ;; кратность: кабель, проходящий точку n раз (туда и обратно), - n кабелей в пучке
      (setq cs (apply 'append (mapcar '(lambda (x / l) (repeat (bk:pass-n (car x) p) (setq l (cons x l))) l) cs)))
      (setq c (bk:grp-calc (mapcar 'cadr cs)) md (nth 3 (car cs)) sz (nth 4 (car cs)))
      (foreach x cs
        (setq nm (bk:pl-name-ex (nth 2 x) (nth 3 x) (nth 4 x) (if (nth 6 x) (nth 6 x) "")))
        (if (not (member nm names)) (setq names (append names (list nm)))))
      (setq sm (cond ((wcmatch sz "*x*") (* (bk:num sz) (bk:num (substr sz (+ 2 (vl-string-search "x" sz))))))
                     ((and (bk:md-on (nth 2 (car cs))) (> md 0)) (bk:csec (bk:din (nth 2 (car cs)) md)))
                     (T 0.0)))
      (setq vars (list (cons "ПРОКЛ" (bk:join names ", ")) (cons "DРАСЧ" (bk:r (caddr c) 1))
                       (cons "ОБЩ" (if (cdr cs) (strcat " общий (" (itoa (length cs)) " каб.)") " "))
                       (cons "N" (itoa (length cs))) (cons "SUMS" (bk:r (cadr c) 0))
                       (cons "ЗАП" (if (> sm 0) (bk:r (* 100.0 (/ (cadr c) sm)) 0) ""))))
      (bk:join (vl-remove "" (mapcar '(lambda (tp) (bk:fmt tp vars T)) (list (nth 4 (bk:ldfmt)) (nth 5 (bk:ldfmt)) (nth 6 (bk:ldfmt)))))
               "\\P"))
    "кабелей нет"))

(defun bk:pl-put (e p / ty va)
  (regapp "BK_PL")
  (setq ty (vlax-make-safearray vlax-vbInteger '(0 . 1)) va (vlax-make-safearray vlax-vbVariant '(0 . 1)))
  (vlax-safearray-fill ty '(1001 1000))
  (vlax-safearray-fill va (list (vlax-make-variant "BK_PL")
                                (vlax-make-variant (strcat (rtos (car p) 2 6) "," (rtos (cadr p) 2 6)))))
  (vla-SetXData (vlax-ename->vla-object e) ty va))

(defun bk:pl-pt (e / x s i)
  (if (and (setq x (assoc -3 (entget e '("BK_PL")))) (setq s (cdr (assoc 1000 (cdr (cadr x)))))
           (setq i (vl-string-search "," s)))
    (list (atof (substr s 1 i)) (atof (substr s (+ i 2))))))

(defun bk:cmd-pl-leader (/ ap lp arr ml e p cs lts par)
  (while (progn (initget "Параметры Формат")
                (member (setq ap (getpoint "\nТочка на кабеле / наложенных кабелях [Параметры/Формат]: ")) '("Параметры" "Формат")))
    (if (= ap "Формат") (bk:cmd-ldfmt)
      (if (setq p (bk:ld-dialog *bk:ld*)) (setq *bk:ld* p))))
  (if ap
    (if (null (setq cs (bk:segs-at (trans ap 1 0))))
      (princ "\nВ этой точке нет кабелей.")
      (if (setq lp (getpoint ap "\nПоложение текста: "))
        (progn
          (setq arr (vlax-make-safearray vlax-vbDouble '(0 . 5)))
          (vlax-safearray-fill arr (append (trans ap 1 0) (trans lp 1 0)))
          (setq ml (vla-AddMLeader (bk:space) arr 'li) e (vlax-vla-object->ename ml)
                lts (max 0.001 (bk:fn (bk:get (car (bk:segs (car (car cs))))) "lts"))
                par (list (if (= (nth 0 *bk:ld*) "") (rtos (* 2.5 lts) 2 2) (nth 0 *bk:ld*))
                          (if (= (nth 1 *bk:ld*) "") (rtos (* 1.0 lts) 2 2) (nth 1 *bk:ld*))
                          (nth 2 *bk:ld*)))
          (bk:ld-put e par)
          (bk:pl-put e (bk:2d (trans ap 1 0)))
          (vla-put-ContentType ml acMTextContent)
          (vla-put-TextString ml (bk:pl-text (bk:pl-pt e)))
          (bk:ld-style e)
          (princ (strcat "\nВыноска прокладки: кабелей в точке " (itoa (length cs))
                         ". Обновляется вместе с выносками кабелей."))))))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_ВЫНОСКА_ФОРМАТ: формат записи всех выносок ----------
(defun bk:cmd-ldfmt (/ fn id res f n sts)
  (setq f (bk:ldfmt)
        fn (bk:write-dcl "blok_kabel_fmt.dcl"
             '("bk_fmt : dialog { label = \"Формат выносок (все выноски чертежа)\";"
               " : boxed_column { label = \"Выноска кабелей (ММ_КАБЕЛЬ_ВЫНОСКА)\";"
               "   : edit_box { key = \"f0\"; label = \"Строка кабеля:\"; edit_width = 70; allow_accept = false; }"
               "   : toggle { key = \"f1\"; label = \"Объединять кабели с одинаковой строкой ({ПОЗ} - через запятую)\"; }"
               "   : toggle { key = \"f2\"; label = \"Нижняя строка - в чём прокладывается\"; }"
               "   : edit_box { key = \"f3\"; label = \"Нижняя строка:\"; edit_width = 70; allow_accept = false; } }"
               " : boxed_column { label = \"Выноска прокладки (ММ_КАБЕЛЬ_ВЫНОСКА_ПРОКЛ)\";"
               "   : edit_box { key = \"f4\"; label = \"Строка 1:\"; edit_width = 70; allow_accept = false; }"
               "   : edit_box { key = \"f5\"; label = \"Строка 2:\"; edit_width = 70; allow_accept = false; }"
               "   : edit_box { key = \"f6\"; label = \"Строка 3:\"; edit_width = 70; allow_accept = false; } }"
               " : boxed_column { label = \"Выноска стояка (ММ_КАБЕЛЬ_ВЫНОСКА_СТОЯК): нижняя строка\";"
               "   : edit_box { key = \"f7\"; label = \"У начала стояка (куда идёт):\"; edit_width = 40; allow_accept = false; }"
               "   : edit_box { key = \"f8\"; label = \"У конца стояка (не используется - всегда «на»):\"; edit_width = 40; allow_accept = false; } }"
               " : boxed_row { label = \"Текст всех выносок\";"
               "   : popup_list { key = \"f9\"; label = \"Текстовый стиль:\"; width = 40; }"
               "   : edit_box { key = \"f10\"; label = \"Высота текста (пусто - из параметров выноски):\"; edit_width = 8; allow_accept = false; } }"
               " : text { label = \"Поля кабеля: {ПОЗ} {НОМ} {ТИП} {ОБОЛ} {ПРОВ} {СЕЧ} {D} {ЭТАЖ} {ОТКУДА} {КУДА} {ПОМ1} {ПОМ2} {ДЛИНА}\"; }"
               " : text { label = \"Нижняя строка: {ПРОКЛ}.  Прокладка: {ПРОКЛ} {DРАСЧ} {ОБЩ} {N} {SUMS} {ЗАП}\"; }"
               " : text { label = \"Стояк: {ЭТАЖ} - этаж другого конца стояка (атрибут ЭТАЖ блока-стояка). %%c - знак диаметра. Строка прокладки, в которой поле пустое (нет заполнения и т.п.), не выводится.\"; }"
               " : text { key = \"info\"; width = 90; }"
               " : row { : button { key = \"accept\"; label = \"OK - обновить все выноски\"; is_default = true; width = 28; }"
               "         : button { key = \"b_def\"; label = \"По умолчанию\"; width = 16; }"
               "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }"))
        id (load_dialog fn))
  (if (new_dialog "bk_fmt" id)
    (progn
      ;; список текстовых стилей чертежа (+ ММ_200_09 - будет создан)
      (setq sts (list "ММ_200_09"))
      (vlax-for x (vla-get-TextStyles (bk:doc)) (if (and (/= (vla-get-Name x) "") (not (member (vla-get-Name x) sts))) (setq sts (append sts (list (vla-get-Name x))))))
      (start_list "f9") (foreach x sts (add_list x)) (end_list)
      (defun bk:fmt-set (f) (setq n 0) (foreach k '("f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8") (bk:st k (nth n f)) (setq n (1+ n)))
        (set_tile "f9" (itoa (cond ((vl-position (nth 9 f) sts)) (0)))) (bk:st "f10" (nth 10 f)))
      (bk:fmt-set f)
      (action_tile "b_def" "(bk:fmt-set *bk:ldfmt-def*)")
      (action_tile "accept"
        "(setq f (append (mapcar 'get_tile '(\"f0\" \"f1\" \"f2\" \"f3\" \"f4\" \"f5\" \"f6\" \"f7\" \"f8\")) (list (nth (atoi (get_tile \"f9\")) sts) (bk:trim (get_tile \"f10\"))))) (if (= (bk:trim (car f)) \"\") (bk:st \"info\" \"Строка кабеля не может быть пустой.\") (done_dialog 1))")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)))
  (vl-file-delete fn)
  (if (= res 1)
    (progn
      (bk:ensure-style (nth 9 f))
      (vlax-ldata-put "BK" "ldfmt" f)
      (princ (strcat "\nФормат выносок сохранён в чертеже. Обновлено выносок: " (itoa (bk:update-leaders)) "."))))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_ВЫНОСКА_СТОЯК: подпись стояка ----------
;; выноска у конца участка "стояк": строки кабелей стояка + "на N этаж" (у начала) / "с N этажа" (у конца).
;; В XDATA "BK_ST": концы стояка и какой конец (0 - начало, 1 - конец).
(defun bk:st-put (e q1 q2 k / ty va)
  (regapp "BK_ST")
  (setq ty (vlax-make-safearray vlax-vbInteger '(0 . 1)) va (vlax-make-safearray vlax-vbVariant '(0 . 1)))
  (vlax-safearray-fill ty '(1001 1000))
  (vlax-safearray-fill va (list (vlax-make-variant "BK_ST")
                                (vlax-make-variant (strcat (rtos (car q1) 2 6) "," (rtos (cadr q1) 2 6) ","
                                                           (rtos (car q2) 2 6) "," (rtos (cadr q2) 2 6) "," (itoa k)))))
  (vla-SetXData (vlax-ename->vla-object e) ty va))

(defun bk:st-get (e / x s l)
  (if (and (setq x (assoc -3 (entget e '("BK_ST")))) (setq s (cdr (assoc 1000 (cdr (cadr x))))))
    (progn (setq l (mapcar 'atof (bk:csv-split s ",")))
           (list (list (nth 0 l) (nth 1 l)) (list (nth 2 l) (nth 3 l)) (fix (nth 4 l))))))

;; если в шаблоне уже есть слово "этаж", из значения этажа оно убирается ("9 этаж" -> "9")
(defun bk:fl-bare (fl tpl / u i)
  (if (wcmatch (bk:up (bk:subst-all tpl "{ЭТАЖ}" "")) "*ЭТАЖ*")
    (progn
      (foreach w '(" ЭТАЖА" " ЭТАЖ" "ЭТАЖ ")
        (if (setq i (vl-string-search w (bk:up fl)))
          (setq fl (bk:trim (strcat (substr fl 1 i) (substr fl (+ i 1 (strlen w))))))))
      fl)
    fl))

;; кабели, у которых участок "стояк" идёт по отрезку q1-q2
(defun bk:st-ids (q1 q2)
  (mapcar 'car (vl-remove-if-not '(lambda (x) (bk:stc (bk:f (bk:get (cadr x)) "code"))) (bk:on-piece q1 q2))))

(defun bk:st-text (e / g ids fl r)
  (if (and (setq g (bk:st-get e)) (setq ids (bk:st-ids (car g) (cadr g))))
    (progn
      ;; кратность: один кабель несколькими участками-стояками (кольцо) -> «k1 (2)»
      (setq *bk:ldm* nil)
      (foreach i ids (setq *bk:ldm* (if (assoc i *bk:ldm*) (subst (cons i (1+ (cdr (assoc i *bk:ldm*)))) (assoc i *bk:ldm*) *bk:ldm*) (cons (cons i 1) *bk:ldm*))))
      (setq ids (bk:uniq ids))
      (setq fl (bk:blk-floor (if (= (caddr g) 0) (cadr g) (car g))))
      (if (= fl "") (setq fl "?"))
      (setq r (strcat (bk:leader-text ids) "\\P"
              ;; всегда «на … этаж» (этаж другого конца стояка), направление не определяется
              (bk:fmt (nth 7 (bk:ldfmt)) (list (cons "ЭТАЖ" (bk:fl-bare fl (nth 7 (bk:ldfmt))))) nil))
            *bk:ldm* nil)
      r)
    "стояк: кабелей нет"))

(defun bk:st-make (pt lp q1 q2 k lts / arr ml e par)
  (setq arr (vlax-make-safearray vlax-vbDouble '(0 . 5)))
  (vlax-safearray-fill arr (list (car pt) (cadr pt) 0.0 (car lp) (cadr lp) 0.0))
  (setq ml (vla-AddMLeader (bk:space) arr 'li) e (vlax-vla-object->ename ml)
        par (list (if (= (nth 0 *bk:ld*) "") (rtos (* 2.5 lts) 2 2) (nth 0 *bk:ld*))
                  (if (= (nth 1 *bk:ld*) "") (rtos (* 1.0 lts) 2 2) (nth 1 *bk:ld*))
                  (nth 2 *bk:ld*)))
  (bk:ld-put e par)
  (bk:st-put e q1 q2 k)
  (vla-put-ContentType ml acMTextContent)
  (vla-put-TextString ml (bk:st-text e))
  (bk:ld-style e)
  e)

(defun bk:st-ask (anchor q1 q2 k lts / lp fl)
  (setq fl (bk:blk-floor (if (= k 0) q2 q1)))
  (if (setq lp (getpoint (trans (list (car anchor) (cadr anchor) 0.0) 0 1)
                         (strcat "\nПоложение текста выноски (на " (if (= fl "") "?" fl)
                                 " этаж): ")))
    (bk:st-make anchor (bk:2d (trans lp 1 0)) q1 q2 k lts)))

(defun bk:cmd-st-leader (/ es ed d o q1 q2 lp dx dy lts ids k h grp key n g)
  (while (progn (initget "Параметры Формат")
                (member (setq es (entsel "\nВыберите блок-стояк или участок-стояк кабеля [Параметры/Формат]: ")) '("Параметры" "Формат")))
    (if (= es "Формат") (bk:cmd-ldfmt) (if (setq k (bk:ld-dialog *bk:ld*)) (setq *bk:ld* k))))
  (cond
    ((null es))
    ;; выбран БЛОК-стояк: все участки "стояк" кабелей, концы которых у этого блока;
    ;; по выноске на каждое направление (проходной стояк - вверх и вниз - две выноски)
    ((= (cdr (assoc 0 (setq ed (entget (car es))))) "INSERT")
     (setq h (cdr (assoc 5 ed)) n 0)
     (foreach s (bk:all-segs)
       (setq d (bk:get s))
       (if (bk:stc (bk:f d "code"))
         (progn
           (setq o (vlax-ename->vla-object s) q1 (bk:2d (vlax-curve-getStartPoint o)) q2 (bk:2d (vlax-curve-getEndPoint o))
                 ;; ключ - только ДРУГОЙ конец стояка (куда/откуда), направление - по большинству кабелей
                 key (cond ((= (bk:block-at q1) h) (list 0 (mapcar '(lambda (x) (fix (/ x 10.0))) q2) q1 q2))
                           ((= (bk:block-at q2) h) (list 1 (mapcar '(lambda (x) (fix (/ x 10.0))) q1) q2 q1))))
           (if key
             (if (setq g (assoc (cadr key) grp))
               (setq grp (subst (if (= (car key) 0) (bk:replace-nth 4 (1+ (nth 4 g)) g) (bk:replace-nth 5 (1+ (nth 5 g)) g)) g grp))
               ;; (другой_конец ближний дальний lts на_число с_число)
               (setq grp (append grp (list (list (cadr key) (caddr key) (cadddr key) (max 0.001 (bk:fn d "lts"))
                                                 (if (= (car key) 0) 1 0) (if (= (car key) 1) 1 0))))))))))
     (if (null grp)
       (princ "\nК этому блоку не подходит ни один участок \"стояк\" / \"перенос на др. лист\" (конец такого участка должен быть у блока).")
       (progn
         ;; одна выноска на каждый другой конец стояка: «на N этаж»
         (foreach g grp
           (if (bk:st-ask (nth 1 g) (nth 1 g) (nth 2 g) 0 (nth 3 g)) (setq n (1+ n))))
         (princ (strcat "\nВыносок стояка создано: " (itoa n) (if (cdr grp) " (стояк проходной)" "") ".")))))
    ;; выбран участок-стояк: выноски у обоих концов
    ((and (setq d (bk:get (car es))) (bk:stc (bk:f d "code")))
     (setq o (vlax-ename->vla-object (car es))
           q1 (bk:2d (vlax-curve-getStartPoint o)) q2 (bk:2d (vlax-curve-getEndPoint o))
           ids (bk:st-ids q1 q2) lts (max 0.001 (bk:fn d "lts")))
     (if (setq lp (getpoint (trans (list (car q1) (cadr q1) 0.0) 0 1) "\nПоложение текста у НАЧАЛА стояка: "))
       (progn
         (setq lp (bk:2d (trans lp 1 0)) dx (- (car lp) (car q1)) dy (- (cadr lp) (cadr q1)))
         (bk:st-make q1 lp q1 q2 0 lts)
         (bk:st-make q2 (list (+ (car q2) dx) (+ (cadr q2) dy)) q2 q1 0 lts)
         (princ (strcat "\nВыноски стояка созданы (2): кабелей " (itoa (length ids)) ".")))))
    (T (princ "\nВыберите блок-стояк / блок переноса (с атрибутом ЭТАЖ) или участок кабеля со способом \"стояк\" или \"перенос на др. лист\".")))
  (princ))

(defun bk:cmd-ldpar (/ ss l p)
  (princ "\nВыберите выноски (кабелей): ")
  (if (setq l (bk:ss->l (ssget '((0 . "MULTILEADER")))))
    (if (setq p (bk:ld-dialog (bk:ld-par (car l))))
      (progn
        (setq *bk:ld* p)
        (foreach e l (bk:ld-put e p) (bk:ld-style e))
        (princ (strcat "\nИзменено выносок: " (itoa (length l)) ".")))))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_ЖУРНАЛ ----------
(defun bk:num-str (x) (vl-string-translate "." "," (rtos x 2 1)))

(defun bk:cmd-journal (/ k cs)
  (setq cs (vl-sort (bk:merge-lines (mapcar 'bk:cable-info (bk:cable-map)))
                    '(lambda (a b) (bk:less (bk:f (cadr a) "pos") (bk:f (cadr b) "pos")))))
  (if (null cs)
    (princ "\nНа чертеже нет кабелей.")
    (progn
      (initget "Таблица Csv")
      (setq k (getkword "\nКабельный журнал (кабели и ветки), Таблица - файл DWG с листами А3 [Таблица/Csv] <Csv>: "))
      (if (= k "Таблица")
        (bk:a3-table "Кабельный журнал" (bk:cables-table cs))
        (bk:csv-write "кабели" (bk:cables-table cs)))))
  (princ))

;;; ======================================================================
;;;  ТРАССЫ: несколько кабелей в одной трубе / коробе / лотке
;;; ======================================================================
;;; ---------- служебное ----------
(defun bk:newid (pfx)
  (setq *bk:idn* (1+ (if *bk:idn* *bk:idn* 0)))
  (strcat pfx (vl-string-translate "." "_" (rtos (getvar "CDATE") 2 8)) "_" (itoa *bk:idn*)))

;;; ---------- общий диаметр пучка круглых кабелей ----------
;; D = K(n) * sqrt(Sum d2/n), не менее наибольшего d.
;; K(n) - отношение диаметра описанной окружности к диаметру круга при
;; плотной укладке n одинаковых кругов в круг (известные значения).
(setq *bk:kpack* '((1 . 1.0) (2 . 2.0) (3 . 2.155) (4 . 2.414) (5 . 2.701) (6 . 3.0) (7 . 3.0)
                   (8 . 3.305) (9 . 3.613) (10 . 3.813) (11 . 3.923) (12 . 4.029) (13 . 4.236)
                   (14 . 4.328) (15 . 4.521) (16 . 4.615) (17 . 4.792) (18 . 4.863) (19 . 4.863)))
(defun bk:kpack (n) (cond ((cdr (assoc n *bk:kpack*))) (T (sqrt (/ n 0.8)))))

;; допустимое заполнение и режим учёта способа прокладки:
;; O - общий для группы кабелей (лоток, короб, трос), E - свой у каждого кабеля, N - не считать
(defun bk:type-fill (code / p) (if (and (setq p (bk:type code)) (nth 7 p)) (nth 7 p) (if (= (bk:type-mode code) "O") 40.0 35.0)))
(defun bk:type-mode (code / p)
  (cond ((and (setq p (bk:type code)) (nth 6 p)) (nth 6 p))
        ((cdr (assoc code '(("LOTOK" . "O") ("KOROB" . "O") ("TROS" . "O") ("SKR" . "E") ("OTKR" . "N")))))
        (T "E")))

;;; ---------- ММ_КАБЕЛЬ_ЕЩЕ: ещё кабель по пути выбранного ----------
(defun bk:cmd-more (/ es d src parts par go nd k)
  (if (and (setq es (car (bk:pick-ids "\nВыберите кабель, по пути которого проложить новый.")))
           (setq d (bk:get (car (bk:segs es)))))
    (progn
      (setq src (bk:f d "id") parts (mapcar '(lambda (p) (bk:replace-nth 4 nil p)) (bk:parts src)) go T)
      (setq par (list (bk:f d "marka") (bk:f d "diam") (bk:incr (bk:f d "pos")) (car (car parts))
                      (rtos (cadr (car parts)) 2 2) (rtos (cadddr (car parts)) 2 2) "0"
                      (bk:f d "layer") (bk:f d "lts") (bk:f d "floor")))
      (while (and go (setq par (bk:dialog par nil
                                 (strcat "Новый кабель по пути кабеля " (bk:f d "pos")
                                         ": участки, прокладка, опуски и привязки копируются."))))
        (setq nd d)
        (foreach kv (list (cons "id" (bk:newid "K")) (cons "marka" (nth 0 par)) (cons "diam" (nth 1 par))
                          (cons "pos" (nth 2 par)) (cons "layer" (nth 7 par)) (cons "lts" (nth 8 par))
                          (cons "floor" (nth 9 par)) (cons "ld" ""))
          (setq nd (bk:setf nd (car kv) (cdr kv))))
        (bk:rebuild nd parts)
        (princ (strcat "\nКабель " (nth 2 par) " проложен по пути " (bk:f d "pos") ": " (bk:len-text (bk:f nd "id"))))
        (setq par (bk:replace-nth 2 (bk:free-pos (bk:incr (nth 2 par)) nil) par))
        (initget "Да Нет")
        (setq go (= (getkword "\nЕщё кабель по этому пути? [Да/Нет] <Нет>: ") "Да")))
      (bk:update-leaders)))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_ВЕТКА: ответвление от кабеля (дерево СОУЭ, ответвления шлейфов) ----------
;; Ветка - отдельная группа полилиний с той же ПОЗИЦИЕЙ, маркой и прокладкой, что у основного кабеля;
;; в ММ_КАБЕЛЬ_ВСЕ и журнале кабель с ветками - одна строка (bk:merge-lines). Ключи XDATA: par - id родительского кабеля, lin - id корня линии (у корня = свой id).
;; Начало ветки - блок в точке ответвления (коробка, поставленная вручную, или прибор); если блока нет -
;; в таблицах «Начало» = «отв. от <ПОЗИЦИЯ родителя>».
(defun bk:root-of (id / d n)
  (setq n 0)
  (while (and (setq d (bk:get (car (bk:segs id)))) (/= (bk:f d "par") "") (< n 50) (bk:segs (bk:f d "par")))
    (setq id (bk:f d "par") n (1+ n)))
  id)
(defun bk:cmd-branch (/ es e d o p par prev-e ne pts nd pid n go)
  (setq go T n 0)
  (while (and go (setq es (entsel "\nЩёлкните кабель в точке ответвления <выход>: ")))
    (if (not (setq d (bk:get (setq e (car es)))))
      (princ "\nЭто не кабель.")
      (progn
        (setq o (vlax-ename->vla-object e)
              p (vlax-curve-getClosestPointTo o (trans (cadr es) 1 0))
              pid (bk:f d "id"))
        (setq *bk:brpos* T)
        (setq par (list (bk:f d "marka") (bk:f d "diam") (bk:f d "pos")
                        (bk:f d "code") (rtos (bk:fn d "h") 2 2) (rtos (max 1.0 (bk:fn d "k")) 2 2) "0"
                        (bk:f d "layer") (bk:f d "lts") (bk:f d "floor")))
        (setq par (bk:dialog par nil (strcat "Ветка кабеля " (bk:f d "pos")
                                             " (та же ПОЗИЦИЯ). После OK рисуйте полилинию от точки ответвления до прибора."))
              *bk:brpos* nil)
        (if par
          (progn
            (setq prev-e (entlast))
            (command "_.PLINE" (trans p 0 1))
            (while (> (getvar "CMDACTIVE") 0) (command pause))
            (setq ne (entlast))
            (if (and ne (not (eq ne prev-e)) (= (cdr (assoc 0 (entget ne))) "LWPOLYLINE"))
              (progn
                (setq pts (bk:pts ne) nd nil)
                (foreach kv (list (cons "id" (cdr (assoc 5 (entget ne)))) (cons "marka" (nth 0 par))
                                  (cons "diam" (nth 1 par)) (cons "pos" (nth 2 par))
                                  (cons "layer" (nth 7 par)) (cons "lts" (nth 8 par)) (cons "floor" (nth 9 par))
                                  (cons "par" pid) (cons "lin" (bk:root-of pid)))
                  (setq nd (bk:setf nd (car kv) (cdr kv))))
                (bk:put ne nd)
                (setq nd (bk:rebuild nd (list (list (nth 3 par) (bk:num (nth 4 par)) pts
                                                    (bk:num (nth 5 par)) nil "" 0.0 (bk:look ne)))))
                (setq n (1+ n))
                (princ (strcat "\nВетка " (nth 2 par) " от " (bk:f d "pos")
                               "  откуда: " (bk:beg-name nd) "  куда: " (bk:dev-pos (bk:f nd "end"))
                               (if (bk:box-mark (bk:f nd "beg")) "  (коробка учитывается)" "")
                               "  " (bk:len-text (bk:f nd "id"))))
                (bk:upd-leaders-for (list pid (bk:f nd "id")))))))))
    (initget "Да Нет")
    (setq go (/= (getkword "\nЕщё ветка? [Да/Нет] <Да>: ") "Нет")))
  (princ (strcat "\nНарисовано веток: " (itoa n) "."))
  (princ))
;; начало для таблиц: ПОЗИЦИЯ блока или «отв. от <родитель>»
(defun bk:beg-name (d / pd)
  (cond ((/= (bk:dev-pos (bk:f d "beg")) "") (bk:dev-pos (bk:f d "beg")))
        ((and (/= (bk:f d "par") "") (setq pd (bk:get (car (bk:segs (bk:f d "par"))))))
         (strcat "отв. от " (bk:f pd "pos")))
        (T "")))
;; коробка на приборе: атрибут ПРИМ-1 содержит «с коробкой» -> марка коробки ("" - без марки), иначе nil
(defun bk:box-mark (h / s i)
  (if (and h (/= h "") (bk:hent h))
    (progn
      (setq s (bk:attr (bk:hent h) "ПРИМ-1"))
      (if (setq i (vl-string-search "С КОРОБКОЙ" (bk:up s)))
        (vl-string-trim " ,;:()" (substr s (+ i 11)))))))

;;; ---------- ММ_КАБЕЛЬ_ЛИНИИ: обозначения типов прокладки вкл/выкл ----------
(defun bk:cmd-lines (/ k lt c)
  (initget "Типы Сплошная Штриховая")
  (setq k (getkword (strcat "\nЛинии кабелей сейчас: "
                            (cond ((= (bk:plain) "C") "все сплошные") ((= (bk:plain) "D") "все штриховые") (T "по типам прокладки"))
                            ". [Типы/Сплошная/Штриховая] <Типы>: ")))
  (initget "ПоСлою ПоТипам Оставить")
  (setq c (getkword (strcat "\nЦвет линий сейчас: "
                            (if (= (bk:pcolor) "L") "по слою" "по типам прокладки")
                            " (режим хранится в чертеже и действует на новые кабели). [ПоСлою/ПоТипам/Оставить] <Оставить>: ")))
  (vlax-ldata-put "BK" "plain" (cond ((= k "Сплошная") "C") ((= k "Штриховая") "D") (T nil)))
  (cond ((= c "ПоСлою") (vlax-ldata-put "BK" "pcolor" "L"))
        ((= c "ПоТипам") (vlax-ldata-put "BK" "pcolor" "T")))
  (foreach e (bk:all-segs)
    (vla-put-Linetype (vlax-ename->vla-object e) (bk:load-lt (bk:f (bk:get e) "code")))
    (if c (bk:seg-color e (bk:f (bk:get e) "code"))))
  (princ (strcat "\nЛинии кабелей: " (cond ((= k "Сплошная") "все сплошные") ((= k "Штриховая") "все штриховые") (T "по типам прокладки"))
                 (cond ((= (bk:pcolor) "L") ", цвет - по слою") ((= (bk:pcolor) "T") ", цвет - по типам прокладки (задаётся в ММ_КАБЕЛЬ_ТИПЫ)") (T ""))
                 ". Способы прокладки у участков сохранены (длины, спецификация, выноски - как прежде).")))

;;; ---------- ММ_КАБЕЛЬ_ЭЛ: потери напряжения ----------
;; Параметры кабеля (XDATA): et - род тока DC / AC1 (однофазный) / AC3 (трёхфазный),
;; eu - напряжение, В (для AC3 - линейное); ei - ток, А или ep - мощность, Вт;
;; ecos - cos fi; edu - допустимые потери, %; esec - сечение жилы, мм2 (пусто - из справочника);
;; emat - материал жилы Cu / Al (пусто - авто по справочнику / марке).
;; dU: DC - 2*I*L*rho/S;  AC1 - 2*I*L*rho*cos/S;  AC3 - корень(3)*I*L*rho*cos/S  (без учёта реактивного сопротивления).
;; rho, Ом*мм2/м: медь 0,0175; алюминий 0,028 (при 20 C). L - длина кабеля с запасом, м.
(setq *bk:etypes* '(("DC" . "постоянный") ("AC1" . "~1ф") ("AC3" . "~3ф")))

;; сечение жилы из текста: число после последнего "х"/"x" ("3х95" -> 95, "1x2x0.5" -> 0.5)
(defun bk:sec-parse (s / i j c r)
  (setq i 1 r nil)
  (while (<= i (strlen s))
    (setq c (substr s i 1))
    (if (member c '("x" "X" "х" "Х" "*")) (setq j i))
    (setq i (1+ i)))
  (if j (bk:num (substr s (1+ j))) 0.0))

(defun bk:el-sec (d / r)
  (cond ((> (bk:fn d "esec") 0) (bk:fn d "esec"))
        ((and (setq r (bk:cat-row (bk:f d "marka"))) (> (bk:sec-parse (nth 3 r)) 0)) (bk:sec-parse (nth 3 r)))
        (T (bk:sec-parse (bk:f d "marka")))))

(defun bk:el-mat (d / r)
  (cond ((member (bk:f d "emat") '("Cu" "Al")) (bk:f d "emat"))
        ((and (setq r (bk:cat-row (bk:f d "marka"))) (wcmatch (bk:up (nth 2 r)) "*АЛЮМ*")) "Al")
        ((wcmatch (bk:up (bk:f d "marka")) "А[ВПКС]*") "Al")
        (T "Cu")))

;; ток, А: заданный или из мощности
(defun bk:el-i (d / u c p)
  (setq u (bk:fn d "eu") c (if (> (bk:fn d "ecos") 0) (bk:fn d "ecos") 1.0) p (bk:fn d "ep"))
  (cond ((> (bk:fn d "ei") 0) (bk:fn d "ei"))
        ((and (> p 0) (> u 0))
         (cond ((= (bk:f d "et") "AC3") (/ p (* (sqrt 3.0) u c))) ((= (bk:f d "et") "AC1") (/ p (* u c))) (T (/ p u))))
        (T 0.0)))

;; падение напряжения, В, на длине L, м
(defun bk:el-du (d L i / s rho c k)
  (if (null i) (setq i (bk:el-i d)))
  (setq s (bk:el-sec d) rho (if (= (bk:el-mat d) "Al") 0.028 0.0175)
        c (if (> (bk:fn d "ecos") 0) (bk:fn d "ecos") 1.0)
        k (cond ((= (bk:f d "et") "AC3") (* (sqrt 3.0) c)) ((= (bk:f d "et") "AC1") (* 2.0 c)) (T 2.0)))
  (if (and (> s 0) (> i 0)) (/ (* k i L rho) s) 0.0))

;; расчёт кабеля c (из cable-info): (сечение материал ток L dU dU% допуск статус)
;; статус: "OK", "ПРЕВЫШЕНИЕ", "нет данных"
;; участок кабеля для строки расчёта (опуск - первый/последний участок)
(defun bk:row-part (r parts)
  (cond ((= (car r) "B") (car parts)) ((= (car r) "E") (last parts)) ((nth 6 r) (nth (1- (nth 6 r)) parts))))

;; мощность участка, Вт (задаётся в окне потерь по участкам; 0 - как у кабеля)
(defun bk:row-p (r parts / p)
  (if (and (setq p (bk:row-part r parts)) (nth 4 p) (entget (nth 4 p))) (bk:fn (bk:get (nth 4 p)) "sp") 0.0))

;; ток строки: от мощности участка, иначе ток кабеля
(defun bk:row-i (d r parts / pw u c)
  (setq pw (bk:row-p r parts) u (bk:fn d "eu") c (if (> (bk:fn d "ecos") 0) (bk:fn d "ecos") 1.0))
  (if (and (> pw 0) (> u 0))
    (cond ((= (bk:f d "et") "AC3") (/ pw (* (sqrt 3.0) u c))) ((= (bk:f d "et") "AC1") (/ pw (* u c))) (T (/ pw u)))
    (bk:el-i d)))

(defun bk:el-calc (c / d L du u pc dop imax i)
  (setq d (cadr c) L (apply '+ (mapcar '(lambda (r) (nth 7 r)) (nth 3 c))) du 0.0 imax 0.0
        u (bk:fn d "eu") dop (if (> (bk:fn d "edu") 0) (bk:fn d "edu") 5.0))
  ;; потери - сумма по строкам с током каждой строки (мощность участка или кабеля)
  (foreach r (nth 3 c)
    (setq i (bk:row-i d r (nth 2 c)) imax (max imax i) du (+ du (bk:el-du d (nth 7 r) i))))
  (setq pc (if (> u 0) (* 100.0 (/ du u)) 0.0))
  (list (bk:el-sec d) (bk:el-mat d) (if (> (bk:el-i d) 0) (bk:el-i d) imax) L du pc dop
        (cond ((or (<= u 0) (<= imax 0) (<= (bk:el-sec d) 0)) "нет данных")
              ((> pc dop) "ПРЕВЫШЕНИЕ") (T "OK"))))

(defun bk:el-type-name (d) (cond ((cdr (assoc (bk:f d "et") *bk:etypes*))) ("-")))

;; строки таблицы кабелей
(defun bk:el-table (cs / rows n x d)
  (setq n 0 rows (list '("№" "Позиция" "Номенклатура" "Сечение, мм2" "Материал" "Длина, м" "Ток" "U, В" "I, А"
                         "cos fi" "dU, В" "dU, %" "Доп., %" "Результат")))
  (foreach c cs
    (setq d (cadr c) x (bk:el-calc c))
    (setq rows (append rows (list (list (itoa (setq n (1+ n))) (bk:f d "pos") (bk:f d "marka") (nth 0 x)
                                        (if (= (nth 1 x) "Al") "алюминий" "медь") (bk:ceil0 (nth 3 x))
                                        (bk:el-type-name d) (bk:fn d "eu") (bk:ceil1 (nth 2 x))
                                        (if (> (bk:fn d "ecos") 0) (bk:fn d "ecos") "") (bk:ceil1 (nth 4 x))
                                        (bk:ceil1 (nth 5 x)) (nth 6 x) (nth 7 x))))))
  rows)

;; строки таблицы кабелей по участкам: нарастающие потери
(defun bk:el-seg-table (cs / rows n d acc du u i)
  (setq rows (list '("Позиция" "Строка" "Прокладка" "Этаж" "Длина с запасом, м" "P, Вт" "I, А" "dU, В" "dU нараст., В" "dU нараст., %")))
  (foreach c cs
    (setq d (cadr c) acc 0.0 u (bk:fn d "eu"))
    (setq rows (append rows (list (list (bk:f d "pos") (strcat (bk:f d "marka") " - " (bk:el-type-name d) " "
                                                                (bk:r u 0) " В, I=" (bk:r (bk:el-i d) 2) " А")
                                        "" "" "" "" "" "" "" ""))))
    (foreach r (nth 3 c)
      (setq i (bk:row-i d r (nth 2 c)) du (bk:el-du d (nth 7 r) i) acc (+ acc du))
      (setq rows (append rows (list (list "" (nth 1 r) (bk:row-tname r (nth 2 c)) (nth 10 r) (bk:ceil1 (nth 7 r))
                                          (if (> (bk:row-p r (nth 2 c)) 0) (bk:r (bk:row-p r (nth 2 c)) 0) "") (bk:r i 2)
                                          (bk:r du 2) (bk:r acc 2) (if (> u 0) (bk:r (* 100.0 (/ acc u)) 2) "")))))))
  rows)

;; окно участков кабеля с потерями
;; заполнить список участков с потерями
(defun bk:els-fill (c sel / d u acc i du x)
  (setq d (cadr c) u (bk:fn d "eu") acc 0.0)
  (start_list "lst")
  (foreach r (nth 3 c)
    (setq i (bk:row-i d r (nth 2 c)) du (bk:el-du d (nth 7 r) i) acc (+ acc du))
    (add_list (strcat (bk:cut (nth 1 r) 20) "\t" (bk:cut (bk:row-tname r (nth 2 c)) 26) "\t" (bk:cut (nth 10 r) 9) "\t"
                      (bk:r (nth 7 r) 1) "\t" (if (> (bk:row-p r (nth 2 c)) 0) (bk:r (bk:row-p r (nth 2 c)) 0) "-") "\t"
                      (bk:r i 2) "\t" (bk:r du 2) "\t" (bk:r acc 2) "\t"
                      (if (> u 0) (bk:r (* 100.0 (/ acc u)) 2) "-"))))
  (end_list)
  (bk:st "lst" (itoa sel))
  (bk:els-pick c sel)
  (setq x (bk:el-calc c))
  (bk:st "tot" (strcat "Итого: dU = " (bk:r (nth 4 x) 2) " В = " (bk:r (nth 5 x) 2) " %  (допустимо "
                       (bk:r (nth 6 x) 1) " %)  -  " (nth 7 x))))

(defun bk:els-pick (c sel / r p)
  (if (setq r (nth sel (nth 3 c)))
    (progn (setq p (bk:row-part r (nth 2 c)))
           (bk:st "sp" (if (> (bk:row-p r (nth 2 c)) 0) (bk:r (bk:row-p r (nth 2 c)) 0) ""))
           (bk:st "spinfo" (if p (strcat "Мощность задаётся участку: " (nth 1 r)
                                         (if (member (car r) '("B" "E")) " (опуск - вместе с соседним участком)" ""))
                             "")))))

;; мощность участка строки sel: записать в участок кабеля
(defun bk:els-setp (c sel / r p v)
  (if (and (setq r (nth sel (nth 3 c))) (setq p (bk:row-part r (nth 2 c))) (nth 4 p) (entget (nth 4 p)))
    (progn (setq v (bk:trim (get_tile "sp")))
           (bk:put (nth 4 p) (bk:setf (bk:get (nth 4 p)) "sp" (if (= v "") "" (vl-string-translate "," "." v))))
           (bk:els-fill c sel))))

;; окно участков кабеля с потерями; мощность можно задать отдельно по участкам
(defun bk:el-show (c / fn id d u res sel)
  (setq d (cadr c) u (bk:fn d "eu") sel 0)
  (setq fn (bk:write-dcl "blok_kabel_elseg.dcl"
             '("bk_els : dialog { label = \"Потери напряжения по участкам кабеля\";"
               " : text { key = \"hdr\"; width = 135; }"
               " : list_box { key = \"h2\"; height = 2; width = 135; tabs = \"22 50 60 68 78 88 98 110 122\"; is_tab_stop = false; }"
               " : list_box { key = \"lst\"; height = 14; width = 135; tabs = \"22 50 60 68 78 88 98 110 122\"; }"
               " : text { key = \"tot\"; width = 135; }"
               " : boxed_row { label = \"Мощность на участке (пусто - как у кабеля)\";"
               "   : edit_box { key = \"sp\"; label = \"P, Вт:\"; edit_width = 9; fixed_width = true; allow_accept = false; }"
               "   : button { key = \"b_sp\"; label = \"Применить к строке\"; width = 22; fixed_width = true; }"
               "   : button { key = \"b_spall\"; label = \"Сбросить у всех участков\"; width = 26; fixed_width = true; }"
               "   : text { key = \"spinfo\"; width = 60; } }"
               " : row { : button { key = \"b_prop\"; label = \"Свойства кабеля...\"; }"
               "         : button { key = \"cancel\"; label = \"Закрыть\"; is_cancel = true; width = 14; } } }"))
        id (load_dialog fn))
  (if (new_dialog "bk_els" id)
    (progn
      (bk:st "hdr" (strcat (bk:f d "pos") "  " (bk:f d "marka") "   " (bk:el-type-name d) " " (bk:r u 0) " В,  I кабеля = "
                           (bk:r (bk:el-i d) 2) " А,  S = " (bk:r (bk:el-sec d) 2) " мм2 ("
                           (if (= (bk:el-mat d) "Al") "алюминий" "медь") ")"
                           (if (> (bk:fn d "ecos") 0) (strcat ",  cos fi = " (bk:r (bk:fn d "ecos") 2)) "")))
      (start_list "h2") (add_list "Строка\tПрокладка\tЭтаж\tL, м\tP, Вт\tI, А\tdU, В\tНараст., В\tНараст., %") (end_list)
      (bk:els-fill c 0)
      (action_tile "lst" "(setq sel (atoi $value)) (bk:els-pick c sel)")
      (action_tile "b_sp" "(setq sel (atoi (get_tile \"lst\"))) (bk:els-setp c sel)")
      (action_tile "b_spall" "(foreach p (nth 2 c) (if (and (nth 4 p) (entget (nth 4 p))) (bk:put (nth 4 p) (bk:setf (bk:get (nth 4 p)) \"sp\" \"\")))) (bk:els-fill c (atoi (get_tile \"lst\")))")
      (action_tile "b_prop" "(done_dialog 2)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)))
  (vl-file-delete fn)
  (if (= res 2) (bk:edit-one (car c))))

(defun bk:el-fill (/ f x d mark nbad)
  (bk:list-rows)
  (setq nbad 0)
  (start_list "lst")
  (foreach c *bk:lst*
    (setq d (cadr c) x (bk:el-calc c) mark (= (nth 7 x) "ПРЕВЫШЕНИЕ"))
    (if mark (setq nbad (1+ nbad)))
    (add_list (strcat (if mark "!! " "") (bk:cut (bk:f d "pos") 9) "\t" (bk:cut (bk:f d "marka") 32) "\t"
                      (if (> (nth 0 x) 0) (bk:r (nth 0 x) 2) "-") " " (nth 1 x) "\t" (itoa (bk:ceil0 (nth 3 x))) "\t"
                      (bk:el-type-name d) "\t" (if (> (bk:fn d "eu") 0) (bk:r (bk:fn d "eu") 0) "-") "\t"
                      (if (> (nth 2 x) 0) (bk:r (nth 2 x) 2) "-") "\t"
                      (if (> (bk:fn d "ecos") 0) (bk:r (bk:fn d "ecos") 2) "-") "\t"
                      (bk:r (nth 4 x) 2) "\t" (bk:r (nth 5 x) 2) "\t" (bk:r (nth 6 x) 1) "\t"
                      (if mark "!! ПРЕВЫШЕНИЕ" (nth 7 x)))))
  (end_list)
  (bk:st "info" (strcat "Кабелей: " (itoa (length *bk:lst*)) ",  не проходят по потерям: " (itoa nbad)
                        (if (> nbad 0) "  (помечены !!)" ""))))

;; параметры из полей окна -> выделенным кабелям
(defun bk:el-apply (ids / v)
  (foreach id ids
    (bk:set-field id "et" (car (nth (atoi (get_tile "et")) *bk:etypes*)))
    (foreach k '("eu" "ei" "ep" "ecos" "edu" "esec")
      (setq v (bk:trim (get_tile k)))
      (bk:set-field id k (if (= v "") "" (vl-string-translate "," "." v))))
    (bk:set-field id "emat" (nth (atoi (get_tile "emat")) '("" "Cu" "Al")))))

(defun bk:el-pick (i / d)
  (if (setq d (cadr (nth i *bk:lst*)))
    (progn
      (bk:st "et" (itoa (cond ((vl-position (bk:f d "et") (mapcar 'car *bk:etypes*))) (0))))
      (foreach k '("eu" "ei" "ep" "ecos" "edu" "esec") (bk:st k (bk:f d k)))
      (bk:st "emat" (itoa (cond ((vl-position (bk:f d "emat") '("" "Cu" "Al"))) (0)))))))

(defun bk:cmd-el (/ fn id res sel ids cs)
  (if (not *bk:lflt*) (setq *bk:lflt* "*"))
  (if (not *bk:lfld*) (setq *bk:lfld* 0))
  (if (not *bk:lsort*) (setq *bk:lsort* 0))
  (setq fn (bk:write-dcl "blok_kabel_el.dcl"
             '("bk_el : dialog { label = \"Потери напряжения в кабелях (ММ_КАБЕЛЬ_ЭЛ)\";"
               " : row { : popup_list { key = \"fld\"; label = \"Искать в:\"; width = 26; }"
               "         : edit_box { key = \"flt\"; label = \"Маска (* ?):\"; edit_width = 24; allow_accept = false; }"
               "         : button { key = \"b_flt\"; label = \"Применить\"; width = 12; fixed_width = true; } }"
               " : list_box { key = \"hdr\"; height = 2; width = 150; tabs = \"12 46 60 66 72 78 86 92 100 108 115\"; is_tab_stop = false; }"
               " : list_box { key = \"lst\"; multiple_select = true; height = 16; width = 150; tabs = \"12 46 60 66 72 78 86 92 100 108 115\"; }"
               " : text { key = \"info\"; width = 150; }"
               " : boxed_column { label = \"Параметры выделенных кабелей (двойной щелчок по кабелю - потери по участкам)\";"
               "  : row { : popup_list { key = \"et\"; label = \"Род тока:\"; width = 30; fixed_width = true; }"
               "          : edit_box { key = \"eu\"; label = \"U, В:\"; edit_width = 7; fixed_width = true; allow_accept = false; }"
               "          : edit_box { key = \"ei\"; label = \"I, А:\"; edit_width = 7; fixed_width = true; allow_accept = false; }"
               "          : edit_box { key = \"ep\"; label = \"или P, Вт:\"; edit_width = 8; fixed_width = true; allow_accept = false; }"
               "          : edit_box { key = \"ecos\"; label = \"cos fi:\"; edit_width = 5; fixed_width = true; allow_accept = false; }"
               "          : edit_box { key = \"edu\"; label = \"Доп. потери, %:\"; edit_width = 5; fixed_width = true; allow_accept = false; } : spacer { } }"
               "  : row { : edit_box { key = \"esec\"; label = \"Сечение жилы, мм2 (пусто - из справочника):\"; edit_width = 7; fixed_width = true; allow_accept = false; }"
               "          : popup_list { key = \"emat\"; label = \"Материал жилы:\"; width = 44; fixed_width = true; }"
               "          : spacer { } : button { key = \"b_apply\"; label = \"Применить к выделенным\"; width = 26; fixed_width = true; } }"
               "  : text { label = \"dU: пост. - 2*I*L*rho/S; ~1ф - 2*I*L*rho*cos/S; ~3ф - корень(3)*I*L*rho*cos/S; rho: медь 0,0175, алюминий 0,028; L - длина с запасом.\"; } }"
               " : row { : button { key = \"b_all\"; label = \"Выделить все\"; }"
               "         : button { key = \"b_csv1\"; label = \"Кабели в CSV\"; }"
               "         : button { key = \"b_tbl1\"; label = \"Кабели на чертёж\"; }"
               "         : button { key = \"b_csv2\"; label = \"По участкам в CSV\"; }"
               "         : button { key = \"b_tbl2\"; label = \"По участкам на чертёж\"; }"
               "         : button { key = \"cancel\"; label = \"Закрыть\"; is_cancel = true; width = 14; } } }"))
        res 2 sel "")
  (while (member res '(2 3 6 7 8 9))
    (setq *bk:all* nil id (load_dialog fn))
    (if (not (new_dialog "bk_el" id))
      (setq res 0)
      (progn
        (start_list "fld") (foreach x *bk:fnames* (add_list x)) (end_list)
        (bk:st "fld" (itoa *bk:lfld*)) (bk:st "flt" *bk:lflt*)
        (start_list "hdr") (add_list "Позиция\tНоменклатура\tS, мм2 мат.\tL, м\tТок\tU, В\tI, А\tcos fi\tdU, В\tdU, %\tДоп.,%\tРезультат") (end_list)
        (start_list "et") (foreach x *bk:etypes* (add_list (strcat (car x) " - " (cdr x)))) (end_list)
        (start_list "emat") (foreach x '("авто (по справочнику/марке)" "медь" "алюминий") (add_list x)) (end_list)
        (bk:el-fill)
        (bk:st "lst" sel)
        (if (bk:first sel) (bk:el-pick (bk:first sel)))
        (action_tile "flt" "(setq *bk:lflt* (if (= $value \"\") \"*\" $value) sel \"\") (bk:el-fill)")
        (action_tile "b_flt" "(setq *bk:lflt* (if (= (get_tile \"flt\") \"\") \"*\" (get_tile \"flt\")) sel \"\") (bk:el-fill)")
        (action_tile "fld" "(setq *bk:lfld* (atoi $value) sel \"\") (bk:el-fill)")
        (action_tile "lst" "(setq sel $value) (if (bk:idxs sel) (bk:el-pick (car (bk:idxs sel)))) (if (= $reason 4) (done_dialog 3))")
        (action_tile "b_all" "(setq sel \"\") (repeat (length *bk:lst*) (setq sel (strcat sel (itoa (length (bk:idxs sel))) \" \"))) (bk:st \"lst\" sel)")
        (action_tile "b_apply" "(setq sel (get_tile \"lst\")) (if (bk:idxs sel) (progn (bk:el-apply (mapcar '(lambda (i) (car (nth i *bk:lst*))) (bk:idxs sel))) (setq *bk:all* nil) (bk:el-fill) (bk:st \"lst\" sel)) (bk:st \"info\" \"Выделите кабели в списке.\"))")
        (foreach k '(("b_csv1" . 6) ("b_tbl1" . 7) ("b_csv2" . 8) ("b_tbl2" . 9))
          (action_tile (car k) (strcat "(setq sel (get_tile \"lst\")) (done_dialog " (itoa (cdr k)) ")")))
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (setq ids (mapcar '(lambda (i) (car (nth i *bk:lst*))) (bk:idxs sel))
              cs  (if (bk:idxs sel) (mapcar '(lambda (i) (nth i *bk:lst*)) (bk:idxs sel)) *bk:lst*))
        (cond
          ((and (= res 3) ids) (bk:el-show (nth (car (bk:idxs sel)) *bk:lst*)))
          ((= res 6) (bk:csv-write "потери" (bk:el-table cs)))
          ((= res 7) (bk:dwg-table "Потери напряжения в кабелях" (bk:el-table cs)))
          ((= res 8) (bk:csv-write "потери_участки" (bk:el-seg-table cs)))
          ((= res 9) (bk:dwg-table "Потери напряжения по участкам" (bk:el-seg-table cs)))))))
  (vl-file-delete fn)
  (princ))
(defun bk:first (s) (car (bk:idxs s)))

;; отрезки кабеля с отметкой "сущ." участка (7-й элемент attr)
(defun bk:tr-edges-ex (id / out pts a)
  (foreach p (bk:parts id)
    (setq pts (caddr p) a (list (car p) (cadr p) (cadddr p) (bk:num (nth 8 p)) (bk:sz p) (bk:slen p) (bk:ex p)))
    (while (cdr pts) (setq out (cons (list (car pts) (cadr pts) a) out) pts (cdr pts))))
  (reverse out))

;;; ---------- ММ_КАБЕЛЬ_ТРАССИРОВКА_УСТРОЙСТВО: новый кабель по пути существующего ----------
;; кабели, уже подключённые к блоку h (начало или конец): список ПОЗИЦИЙ
(defun bk:dev-cables (h / l d)
  (foreach m (bk:cable-map)
    (setq d (cadr m))
    (if (and (or (= (bk:f d "beg") h) (= (bk:f d "end") h)) (not (member (bk:f d "pos") l)))
      (setq l (append l (list (bk:f d "pos"))))))
  l)
;; предупреждение: блок уже подключён -> T продолжать
(defun bk:conn-ok (e / l)
  (if (setq l (bk:dev-cables (cdr (assoc 5 (entget e)))))
    (progn (initget "Да Нет")
           (= (getkword (strcat "\nУстройство " (bk:dev-pos (cdr (assoc 5 (entget e)))) " уже подключено: " (bk:join l ", ")
                                ". Всё равно проложить ещё кабель? [Да/Нет] <Нет>: ")) "Да"))
    T))

;; кабель-образец: щелчок по кабелю (наложенные - выбор из списка); -> id или nil
(defun bk:pick-src (/ es ids sid)
  (while (and (null sid) (setq es (entsel "\nЩёлкните ранее созданный кабель (образец пути): ")))
    (setq ids (bk:cables-at (trans (cadr es) 1 0)))
    (setq sid (cond ((null ids) (princ "\nЗдесь нет кабеля.") nil) ((null (cdr ids)) (car ids)) (T (car (bk:choose ids))))))
  sid)

;; новый кабель от начала кабеля sid по его пути до блока b2; par - параметры окна; -> данные нового кабеля или nil
;;; ---------- кратчайший путь по сети кабелей одного начала ----------
;; все кабели sids объединяются в граф (общие вершины - по координатам, стояк = его длина),
;; от начала до ближайшей к устройству точки НА ЕГО ЭТАЖЕ ищется кратчайший путь (Дейкстра).
;; -> (рёбра_пути i_последнего t точка_на_пути длина_мм) или nil
(defun bk:gk (p) (strcat (rtos (car p) 2 0) "," (rtos (cadr p) 2 0)))
(defun bk:gw (a pa pb / c sl)
  (setq c (car a) sl (nth 5 a))
  (if (bk:stc c)
    (+ 1.0 (if (and sl (> sl 0)) (* 1000.0 sl) (if (= c "STOYAK") 5000.0 0.0)))
    (distance pa pb)))
;; граф кабелей sids: (рёбра . начала); ребро = (a b attr этаж ka kb вес)
(defun bk:gr-build (sids / EL ed fls st i)
  (foreach sid sids
    (setq ed (bk:tr-edges-ex sid) fls (bk:tr-edge-floors sid) i 0)
    (if ed (setq st (cons (bk:gk (car (car ed))) st)))
    (foreach x ed
      (setq EL (cons (list (car x) (cadr x) (caddr x) (nth i fls) (bk:gk (car x)) (bk:gk (cadr x)) (bk:gw (caddr x) (car x) (cadr x))) EL)
            i (1+ i))))
  (cons (reverse EL) st))
;; ключ стояка (не зависит от направления)
(defun bk:rkey (x) (if (< (nth 4 x) (nth 5 x)) (strcat (nth 4 x) "|" (nth 5 x)) (strcat (nth 5 x) "|" (nth 4 x))))
;; Дейкстра: starts = ((ключ . длина) ...), ban - номера запрещённых рёбер -> (dist . prev)
(defun bk:dij (EL starts ban / dist done prev u du x k w i)
  (setq dist starts)
  (while (setq u nil du nil x (vl-remove-if '(lambda (z) (member (car z) done)) dist))
    (foreach z x (if (or (null du) (< (cdr z) du)) (setq u (car z) du (cdr z))))
    (setq done (cons u done) i 0)
    (foreach y EL
      (cond ((member i ban) (setq k nil))
            ((= (nth 4 y) u) (setq k (nth 5 y)))
            ((= (nth 5 y) u) (setq k (nth 4 y)))
            (T (setq k nil)))
      (if (and k (not (member k done)))
        (progn (setq w (+ du (nth 6 y)))
               (if (or (null (assoc k dist)) (< w (cdr (assoc k dist))))
                 (setq dist (cons (cons k w) (vl-remove (assoc k dist) dist))
                       prev (cons (list k i u) (vl-remove (assoc k prev) prev))))))
      (setq i (1+ i))))
  (cons dist prev))
;; рёбра (a b attr) от начала до ключа cur по prev
(defun bk:dij-path (EL prev cur / pe x path)
  (while (setq pe (assoc cur prev))
    (setq x (nth (cadr pe) EL)
          path (cons (if (= (nth 5 x) cur) (list (car x) (cadr x) (caddr x)) (list (cadr x) (car x) (caddr x))) path)
          cur (caddr pe)))
  path)

;;; Путь от начала до устройства: через выбранные стояки *bk:rseq* (по порядку; прочие стояки запрещены),
;;; иначе - кратчайший. Конец - ближайшая к устройству точка на ЕГО этаже.
;;; -> (рёбра_пути i_последнего t точка длина_мм) или nil
(defun bk:gr-route (sids p fl / g EL st ban flu m q tg i dp starts path tot r y ka kb da db e1 d r1 r2 cur ok)
  (setq g (bk:gr-build sids) EL (car g) st (cdr g) i 0 ok T)
  (setq *bk:rerr* nil)
  (setq flu (bk:up (vl-string-trim " " (if fl fl ""))))
  (if (not (vl-some '(lambda (y) (and (not (bk:stc (car (caddr y)))) (= (bk:up (vl-string-trim " " (nth 3 y))) flu))) EL))
    (setq flu nil))
  ;; цель
  (setq i 0 m nil)
  (foreach y EL
    (if (and (not (bk:stc (car (caddr y)))) (or (null flu) (= (bk:up (vl-string-trim " " (nth 3 y))) flu)))
      (progn (setq q (bk:tr-proj p (car y) (cadr y)))
             (if (or (null m) (< (caddr q) m)) (setq m (caddr q) tg (list i (cadr q) (car q))))))
    (setq i (1+ i)))
  (setq starts (mapcar '(lambda (k) (cons k 0.0)) st) tot 0.0)
  ;; участки до каждого выбранного стояка
  (foreach rk *bk:rseq*
    (if ok
      (progn
        (setq i 0 r nil)
        (foreach y EL (if (and (null r) (bk:stc (car (caddr y))) (= (bk:rkey y) rk)) (setq r i)) (setq i (1+ i)))
        (if (null r) (setq ok nil *bk:rerr* "выбранного стояка нет у кабелей этого начала")
          (progn
            (setq dp (bk:dij EL starts (cons r ban)) y (nth r EL)
                  da (cdr (assoc (nth 4 y) (car dp))) db (cdr (assoc (nth 5 y) (car dp))))
            (cond ((and (null da) (null db)) (setq ok nil *bk:rerr* "до выбранного стояка нет пути по кабелям этого начала"))
                  ((and da (or (null db) (<= da db)))
                   (setq path (append path (bk:dij-path EL (cdr dp) (nth 4 y)) (list (list (car y) (cadr y) (caddr y))))
                         tot (+ da (nth 6 y)) starts (list (cons (nth 5 y) tot))))
                  (T
                   (setq path (append path (bk:dij-path EL (cdr dp) (nth 5 y)) (list (list (cadr y) (car y) (caddr y))))
                         tot (+ db (nth 6 y)) starts (list (cons (nth 4 y) tot))))))))))
  ;; последний участок - до цели
  (if (and ok (null tg)) (setq *bk:rerr* "у кабелей начала нет участков (кроме стояков)"))
  (if (and ok tg)
    (progn
      (setq dp (bk:dij EL starts ban) e1 (nth (car tg) EL) d (distance (car e1) (cadr e1))
            r1 (if (assoc (nth 4 e1) (car dp)) (+ (cdr (assoc (nth 4 e1) (car dp))) (* (cadr tg) d)))
            r2 (if (assoc (nth 5 e1) (car dp)) (+ (cdr (assoc (nth 5 e1) (car dp))) (* (- 1.0 (cadr tg)) d))))
      (if (not (or r1 r2)) (setq *bk:rerr* "от последнего стояка нет пути до этажа устройства"))
      (if (or r1 r2)
        (progn
          (if (and r1 (or (null r2) (<= r1 r2)))
            (setq path (append path (bk:dij-path EL (cdr dp) (nth 4 e1)) (list (list (car e1) (cadr e1) (caddr e1)))) cur (list (cadr tg) r1))
            (setq path (append path (bk:dij-path EL (cdr dp) (nth 5 e1)) (list (list (cadr e1) (car e1) (caddr e1)))) cur (list (- 1.0 (cadr tg)) r2)))
          (list path (1- (length path)) (car cur) (caddr tg) (cadr cur)))))))

;;; ---------- выбор последовательности стояков ----------
;; стояки кабелей sids: ((ключ подпись) ...), подпись: ПОЗИЦИЯ (этаж) блоков на концах стояка, кабели
(defun bk:riser-list (sids / out lab pos h1 h2 rk d)
  (foreach sid sids
    (setq pos (bk:f (bk:get (car (bk:segs sid))) "pos"))
    (foreach y (car (bk:gr-build (list sid)))
      (if (bk:stc (car (caddr y)))
        (if (setq d (assoc (setq rk (bk:rkey y)) out))
          (if (not (member pos (caddr d))) (setq out (subst (list rk (cadr d) (append (caddr d) (list pos))) d out)))
          (progn
            (setq h1 (bk:block-at (car y)) h2 (bk:block-at (cadr y)))
            (setq out (cons (list rk (strcat (bk:rs-lab h1 (car y)) "  ->  " (bk:rs-lab h2 (cadr y))
                                             (if (= (car (caddr y)) "PERENOS") "  [перенос]" ""))
                                  (list pos))
                            out)))))))
  (reverse out))
(defun bk:rs-lab (h p / s f)
  (if (and h (/= h "") (bk:hent h))
    (progn (setq s (bk:dev-pos h) f (bk:attr (bk:hent h) "ЭТАЖ"))
           (strcat s " (эт. " (if (= f "") "?" f) ")"))
    (strcat "точка " (rtos (car p) 2 0) "," (rtos (cadr p) 2 0))))
;; окно: доступные стояки -> последовательность. -> список ключей, nil (авто) или 'cancel
(defun bk:riser-dialog (sids / rl fn id res seq av upd i)
  (setq rl (bk:riser-list sids) seq (vl-remove-if-not '(lambda (k) (assoc k rl)) *bk:rseq*))
  (if (null rl) nil
    (progn
      (defun upd ()
        (setq av (vl-remove-if '(lambda (r) (member (car r) seq)) rl))
        (start_list "r_av") (foreach r av (add_list (strcat (cadr r) "\t" (bk:join (caddr r) ", ")))) (end_list)
        (start_list "r_sq") (setq i 0) (foreach k seq (add_list (strcat (itoa (setq i (1+ i))) ". " (cadr (assoc k rl))))) (end_list)
        (set_tile "r_inf" (if seq "Кабель пройдёт через выбранные стояки в указанном порядке (между ними - кратчайшим путём)."
                                    "Последовательность пуста - путь кратчайший (стояки выбираются автоматически).")))
      (setq fn (bk:write-dcl "blok_kabel_rs.dcl"
        '("bk_rs : dialog { label = \"По каким стоякам пройдёт кабель\";"
          " : row {"
          "  : column { : text { label = \"Стояки кабелей этого начала (ПОЗИЦИЯ и этаж блоков на концах; кабели):\"; }"
          "   : list_box { key = \"r_av\"; height = 18; width = 70; tabs = \"52\"; } }"
          "  : column { : spacer { } : button { key = \"b_add\"; label = \"Добавить >>\"; } : button { key = \"b_del\"; label = \"<< Убрать\"; }"
          "   : button { key = \"b_up\"; label = \"Выше\"; } : button { key = \"b_dn\"; label = \"Ниже\"; } : button { key = \"b_clr\"; label = \"Очистить\"; } : spacer { } }"
          "  : column { : text { label = \"Последовательность (от начала кабеля):\"; }"
          "   : list_box { key = \"r_sq\"; height = 18; width = 60; } } }"
          " : text { key = \"r_inf\"; width = 130; }"
          " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 12; }"
          "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 12; } } }")))
      (setq id (load_dialog fn))
      (if (new_dialog "bk_rs" id)
        (progn
          (upd)
          (action_tile "r_av" "(if (= $reason 4) (progn (setq seq (append seq (list (car (nth (atoi $value) av))))) (upd)))")
          (action_tile "b_add" "(if (/= (get_tile \"r_av\") \"\") (progn (setq seq (append seq (list (car (nth (atoi (get_tile \"r_av\")) av))))) (upd)))")
          (action_tile "b_del" "(if (/= (get_tile \"r_sq\") \"\") (progn (setq seq (vl-remove (nth (atoi (get_tile \"r_sq\")) seq) seq)) (upd)))")
          (action_tile "b_up" "(bk:rs-move -1)")
          (action_tile "b_dn" "(bk:rs-move 1)")
          (action_tile "b_clr" "(setq seq nil) (upd)")
          (action_tile "accept" "(done_dialog 1)")
          (action_tile "cancel" "(done_dialog 0)")
          (setq res (start_dialog))))
      (unload_dialog id) (vl-file-delete fn)
      (if (= res 1) seq 'cancel))))
;; сдвиг выбранного в последовательности (переменные seq, upd - из bk:riser-dialog)
(defun bk:rs-move (dl / s i j a)
  (if (/= (setq s (get_tile "r_sq")) "")
    (progn (setq i (atoi s) j (+ i dl))
           (if (and (>= j 0) (< j (length seq)))
             (progn (setq a (nth i seq) seq (bk:replace-nth i (nth j seq) seq) seq (bk:replace-nth j a seq))
                    (upd) (set_tile "r_sq" (itoa j)))))))
;; все кабели с тем же началом, что у sid
(defun bk:same-beg (sid / b r)
  (setq b (bk:f (bk:get (car (bk:segs sid))) "beg"))
  (if (and b (/= b "") (setq r (cdr (assoc b (bk:beg-list))))) r (list sid)))

(defun bk:trdev-one (sid b2 par / sd edges p2 n2 h cattr pieces parts d)
  (if (atom sid) (setq sid (list sid)))
  (setq sd (bk:get (car (bk:segs (car sid))))
        p2 (bk:2d (cdr (assoc 10 (entget b2))))
        n2 (bk:gr-route sid p2 (bk:attr b2 "ЭТАЖ"))
        edges (car n2) n2 (cdr n2)
        h (if (bk:type "GOFRA") (nth 4 (bk:type "GOFRA")) 3.0)
        cattr (list "GOFRA" h (bk:fn sd "k") 20.0 "" 0.0 ""))
  (if n2
    (progn
      (setq pieces (append (bk:tr-sub edges 0 0.0 (car n2) (cadr n2))
                           (list (list (reverse (car (bk:tr-conn p2 (caddr n2) (nth (car n2) edges) cattr))) cattr))))
      (setq pieces (vl-remove-if '(lambda (x) (< (bk:plen (car x)) 1e-6)) pieces))
      (setq parts (bk:tr-parts pieces) d nil)
      (foreach kv (list (cons "id" (bk:newid "K")) (cons "marka" (nth 0 par)) (cons "diam" (nth 1 par))
                        (cons "pos" (nth 2 par)) (cons "layer" (nth 7 par)) (cons "lts" (nth 8 par))
                        (cons "floor" (nth 9 par)) (cons "beg" (bk:f sd "beg")) (cons "bfix" (bk:f sd "bfix"))
                        (cons "bh" (bk:f sd "bh")) (cons "bmd" (bk:f sd "bmd")) (cons "bcode" (bk:f sd "bcode"))
                        (cons "bk" (bk:f sd "bk")) (cons "bex" (bk:f sd "bex"))
                        ;; конец - указанное устройство
                        (cons "end" (cdr (assoc 5 (entget b2)))) (cons "efix" "1"))
        (setq d (bk:setf d (car kv) (cdr kv))))
      (bk:rebuild d parts))))

;; параметры окна по образцу (ПОЗИЦИЯ - следующая)
(defun bk:par-from (sd)
  (list (bk:f sd "marka") (bk:f sd "diam") (bk:incr (bk:f sd "pos")) "GOFRA"
        (rtos (if (bk:type "GOFRA") (nth 4 (bk:type "GOFRA")) 3.0) 2 2)
        (rtos (bk:fn sd "k") 2 2) "0" (bk:f sd "layer") (bk:f sd "lts") (bk:f sd "floor")))

;;; ---------- ММ_КАБЕЛЬ_ТРАССИРОВКА_УСТРОЙСТВО: новый кабель по пути существующего ----------
(defun bk:cmd-trace-dev (/ b2 sid sids kw sd par d n go)
  (setq go T n 0)
  (while (and go (setq b2 (bk:tr-pick (if sid "\nСледующее устройство (конец нового кабеля) <выход>: " "\nНовое устройство (конец кабеля) <выход>: "))))
    (if sid
      (progn (initget "Другой")
             (initget "Другой Стояки")
             (setq kw (getkword (strcat "\nПо кабелю " (bk:f sd "pos") " [Другой/Стояки] <тот же>: ")))
             (cond ((= kw "Другой") (setq sid nil))
                   ((= kw "Стояки") (setq sids (bk:same-beg sid) kw (bk:riser-dialog sids))
                                    (if (/= kw 'cancel) (setq *bk:rseq* kw))))))
    (if (null sid)
      (if (setq sid (bk:pick-src))
        (progn (setq sids (bk:same-beg sid) kw (bk:riser-dialog sids))
               (setq *bk:rseq* (if (= kw 'cancel) nil kw)))))
    (cond ((null sid) (setq go nil))
          ((not (bk:conn-ok b2)) (princ "\nПропущено."))
          (T
      (progn
        (setq sd (bk:get (car (bk:segs sid))))
        (if (setq par (bk:dialog (bk:par-from sd) nil (strcat "Новый кабель из начала кабеля " (bk:f sd "pos") " по его пути до указанного устройства.")))
          (if (setq d (bk:trdev-one sids b2 par))
            (progn (setq n (1+ n))
                   (princ (strcat "\nКабель " (nth 2 par) " проложен по пути " (bk:f sd "pos") ": " (bk:len-text (bk:f d "id")))))
            (princ (strcat "\nПуть не найден: " (if *bk:rerr* *bk:rerr* "нет участков") ".")))
          (setq go nil))))))
  (princ (strcat "\nСоздано кабелей: " (itoa n) "."))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_ТРАССИРОВКА_ГРУППА: кабели к нескольким устройствам по пути существующего ----------
;; окно выбора устройств: ((ename ПОЗИЦИЯ блок этаж расстояние_вдоль_пути) ...) -> выбранные
;; окно выбора устройств: фильтры (текст, блок, этаж, подключение), сортировка, выделение сохраняется при смене фильтра
(defun bk:grp-uniq (l / o) (foreach x l (if (not (member x o)) (setq o (cons x o)))) (vl-sort o '<))
(defun bk:grp-key (r k)
  (cond ((= k 1) (bk:up (nth 1 r))) ((= k 2) (bk:up (nth 2 r))) ((= k 3) (bk:up (nth 3 r))) (T (nth 4 r))))
(defun bk:grp-fill (/ txt bl fl cn k l i sel)
  (setq txt (bk:up (get_tile "f_txt")) bl (atoi (get_tile "f_blk")) fl (atoi (get_tile "f_flr"))
        cn (get_tile "f_con") k (atoi (get_tile "f_srt")))
  (setq *bk:gview*
    (vl-remove-if-not
      '(lambda (r)
         (and (or (= txt "") (vl-string-search txt (bk:up (strcat (nth 1 r) " " (nth 2 r) " " (nth 3 r) " " (nth 5 r)))))
              (or (= bl 0) (= (nth 2 r) (nth (1- bl) *bk:gblks*)))
              (or (= fl 0) (= (nth 3 r) (nth (1- fl) *bk:gflrs*)))
              (cond ((= cn "1") (= (nth 5 r) "")) ((= cn "2") (/= (nth 5 r) "")) (T T))))
      *bk:grecs*))
  (setq *bk:gview* (vl-sort *bk:gview* '(lambda (a b) (< (bk:grp-key a k) (bk:grp-key b k)))))
  (if (= (get_tile "f_rev") "1") (setq *bk:gview* (reverse *bk:gview*)))
  (start_list "lst")
  (foreach r *bk:gview* (add_list (strcat (if (/= (nth 5 r) "") "! " "") (bk:cut (nth 1 r) 12) "\t" (bk:cut (nth 2 r) 42) "\t" (bk:cut (nth 3 r) 14) "\t"
                                          (itoa (bk:ceil0 (/ (nth 4 r) 1000.0))) "\t" (bk:cut (nth 5 r) 30))))
  (end_list)
  (setq sel "" i 0)
  (foreach r *bk:gview* (if (member (car r) *bk:gsel*) (setq sel (strcat sel (itoa i) " "))) (setq i (1+ i)))
  (set_tile "lst" sel)
  (bk:grp-info))
(defun bk:grp-info () (set_tile "g_info" (strcat "Показано: " (itoa (length *bk:gview*)) " из " (itoa (length *bk:grecs*)) ";  выбрано всего: " (itoa (length *bk:gsel*)))))
;; щелчок по списку: выбор среди показанных заменяется, скрытые не трогаются
(defun bk:grp-pick (/ vis)
  (setq vis (mapcar 'car *bk:gview*)
        *bk:gsel* (vl-remove-if '(lambda (e) (member e vis)) *bk:gsel*))
  (foreach i (bk:idxs (get_tile "lst")) (setq *bk:gsel* (cons (car (nth i *bk:gview*)) *bk:gsel*)))
  (bk:grp-info))
(defun bk:grp-mark (mode / vis)
  (setq vis (mapcar 'car *bk:gview*)
        *bk:gsel* (vl-remove-if '(lambda (e) (member e vis)) *bk:gsel*))
  (foreach r *bk:gview*
    (if (or (= mode 1) (and (= mode 2) (= (nth 5 r) ""))) (setq *bk:gsel* (cons (car r) *bk:gsel*))))
  (bk:grp-fill))

(defun bk:grp-dialog (recs / fn id res out)
  (setq *bk:grecs* recs *bk:gview* recs
        *bk:gsel* (mapcar 'car (vl-remove-if-not '(lambda (r) (= (nth 5 r) "")) recs))
        *bk:gblks* (bk:grp-uniq (mapcar '(lambda (r) (nth 2 r)) recs))
        *bk:gflrs* (bk:grp-uniq (mapcar '(lambda (r) (nth 3 r)) recs)))
  (setq fn (bk:write-dcl "blok_kabel_grp.dcl"
    '("bk_grp : dialog { label = \"Кабели по пути образца: до каких устройств\";"
      " : boxed_row { label = \"Фильтр и сортировка\";"
      "  : edit_box { key = \"f_txt\"; label = \"Текст:\"; edit_width = 14; allow_accept = false; }"
      "  : popup_list { key = \"f_blk\"; label = \"Блок:\"; width = 34; }"
      "  : popup_list { key = \"f_flr\"; label = \"Этаж:\"; width = 18; }"
      "  : popup_list { key = \"f_con\"; label = \"Подключение:\"; width = 30; } }"
      " : row { : popup_list { key = \"f_srt\"; label = \"Сортировка:\"; width = 36; } : toggle { key = \"f_rev\"; label = \"Обратный порядок\"; }"
      "         : button { key = \"f_clr\"; label = \"Сбросить фильтр\"; } : spacer { } }"
      " : list_box { key = \"hdr\"; height = 2; width = 120; tabs = \"16 60 76 90\"; is_tab_stop = false; }"
      " : list_box { key = \"lst\"; multiple_select = true; height = 18; width = 120; tabs = \"16 60 76 90\"; }"
      " : text { key = \"g_info\"; width = 120; }"
      " : row { : button { key = \"b_all\"; label = \"Выделить показанные\"; } : button { key = \"b_free\"; label = \"Только неподключённые\"; }"
      "         : button { key = \"b_none\"; label = \"Снять с показанных\"; } }"
      " : text { label = \"«!» - устройство уже подключено (указаны его кабели); по умолчанию такие не выделены. Выбор сохраняется при смене фильтра.\"; }"
      " : text { label = \"Кабели создаются по порядку вдоль пути образца. ПОЗИЦИИ - подряд, начиная с заданной в следующем окне.\"; }"
      " : row { : button { key = \"accept\"; label = \"Далее\"; is_default = true; width = 14; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }")))
  (setq id (load_dialog fn))
  (if (new_dialog "bk_grp" id)
    (progn
      (start_list "hdr") (add_list "ПОЗИЦИЯ\tБлок\tЭтаж\tОт начала, м\tУже подключено") (end_list)
      (start_list "f_blk") (add_list "(все)") (foreach x *bk:gblks* (add_list x)) (end_list)
      (start_list "f_flr") (add_list "(все)") (foreach x *bk:gflrs* (add_list (if (= x "") "(без этажа)" x))) (end_list)
      (start_list "f_con") (foreach x '("(все)" "только неподключённые" "только подключённые") (add_list x)) (end_list)
      (start_list "f_srt") (foreach x '("по пути (от начала)" "по ПОЗИЦИИ" "по блоку" "по этажу") (add_list x)) (end_list)
      (foreach k '("f_blk" "f_flr" "f_con" "f_srt") (set_tile k "0"))
      (set_tile "f_srt" "0")
      (bk:grp-fill)
      (foreach k '("f_txt" "f_blk" "f_flr" "f_con" "f_rev") (action_tile k "(bk:grp-fill)"))
      (action_tile "f_srt" "(bk:grp-fill)")
      (action_tile "f_clr" "(set_tile \"f_txt\" \"\") (foreach k '(\"f_blk\" \"f_flr\" \"f_con\") (set_tile k \"0\")) (bk:grp-fill)")
      (action_tile "lst" "(bk:grp-pick)")
      (action_tile "b_all" "(bk:grp-mark 1)")
      (action_tile "b_free" "(bk:grp-mark 2)")
      (action_tile "b_none" "(bk:grp-mark 0)")
      (action_tile "accept" "(done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))))
  (unload_dialog id) (vl-file-delete fn)
  ;; результат - в порядке вдоль пути (как в исходном списке)
  (if (= res 1) (vl-remove-if-not '(lambda (r) (member (car r) *bk:gsel*)) recs)))

;; расстояние от начала кабеля sid до точки пути, ближайшей к p (мм)
(defun bk:dist-along (edges n2 / l i)
  (setq l 0.0 i 0)
  (while (< i (car n2)) (setq l (+ l (distance (car (nth i edges)) (cadr (nth i edges)))) i (1+ i)))
  (+ l (* (cadr n2) (distance (car (nth i edges)) (cadr (nth i edges))))))

;; уникальные начала кабелей: ((beg-handle id1 id2 ...) ...)
(defun bk:beg-list (/ r h p)
  (foreach m (bk:cable-map)
    (setq h (bk:f (cadr m) "beg"))
    (if (and h (/= h "") (bk:hent h) (entget (bk:hent h)))
      (if (setq p (assoc h r)) (setq r (subst (append p (list (car m))) p r)) (setq r (cons (list h (car m)) r)))))
  (vl-sort r '(lambda (a b) (< (bk:up (bk:dev-pos (car a))) (bk:up (bk:dev-pos (car b)))))))
;; окно: откуда вести кабели -> список id кабелей-образцов (все кабели этого начала) или nil
(defun bk:pick-beg (/ bl fn id res i out sid)
  (setq bl (bk:beg-list))
  (setq fn (bk:write-dcl "blok_kabel_beg.dcl"
    '("bk_beg : dialog { label = \"Откуда вести новые кабели\";"
      " : list_box { key = \"hdr\"; height = 2; width = 90; tabs = \"18 58 72\"; is_tab_stop = false; }"
      " : list_box { key = \"lst\"; height = 16; width = 90; tabs = \"18 58 72\"; }"
      " : text { label = \"Начала существующих кабелей. Путь - кратчайший по сети кабелей этого начала до этажа устройства.\"; }"
      " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 12; }"
      "         : button { key = \"b_pick\"; label = \"Указать кабель на плане...\"; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 12; } } }")))
  (setq id (load_dialog fn))
  (if (new_dialog "bk_beg" id)
    (progn
      (start_list "hdr") (add_list "ПОЗИЦИЯ\tБлок\tЭтаж\tКабелей") (end_list)
      (start_list "lst")
      (foreach r bl (add_list (strcat (bk:cut (bk:dev-pos (car r)) 16) "\t"
                                      (bk:cut (vla-get-EffectiveName (vlax-ename->vla-object (bk:hent (car r)))) 38) "\t"
                                      (bk:cut (bk:attr (bk:hent (car r)) "ЭТАЖ") 12) "\t" (itoa (length (cdr r))))))
      (end_list)
      (if bl (set_tile "lst" "0"))
      (action_tile "lst" "(if (= $reason 4) (progn (setq i (get_tile \"lst\")) (done_dialog 1)))")
      (action_tile "accept" "(setq i (get_tile \"lst\")) (done_dialog 1)")
      (action_tile "b_pick" "(done_dialog 2)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))))
  (unload_dialog id) (vl-file-delete fn)
  (cond ((and (= res 1) i (/= i "")) (cdr (nth (atoi i) bl)))
        ((= res 2) (if (setq sid (bk:pick-src)) (list sid)))))
;; ближайший к точке p кабель из списка: (sid edges n2 dist) или nil
;; кабель id проходит по этажу fl
(defun bk:has-fl (id fl)
  (setq fl (bk:up (vl-string-trim " " (if fl fl ""))))
  (and (/= fl "") (vl-some '(lambda (x) (= (bk:up (vl-string-trim " " x)) fl)) (bk:tr-edge-floors id))))
(defun bk:best-src (p sids fl / best e n2 dd l)
  ;; сначала - только кабели, проходящие по этажу устройства
  (if (setq l (vl-remove-if-not '(lambda (x) (bk:has-fl x fl)) sids)) (setq sids l))
  (foreach sid sids
    (setq e (bk:tr-edges-ex sid))
    (if (and (setq n2 (bk:tr-near-fl p e sid fl))
             (or (null best) (< (setq dd (distance p (caddr n2))) (nth 3 best))))
      (setq best (list sid e n2 (distance p (caddr n2))))))
  best)

(defun bk:cmd-trace-grp (/ ss i e sids sd beg recs bs p sel par d n pos)
  (princ "\nВыделите устройства (рамкой): ")
  (if (and (setq ss (ssget '((0 . "INSERT"))))
           (setq sids (bk:pick-beg)))
    (progn
      (setq *bk:rseq* (bk:riser-dialog sids))
      (if (= *bk:rseq* 'cancel) (progn (setq *bk:rseq* nil) (exit)))
      (setq sd (bk:get (car (bk:segs (car sids)))) beg (bk:f sd "beg") i 0)
      (repeat (sslength ss)
        (setq e (ssname ss i) i (1+ i) p (bk:2d (cdr (assoc 10 (entget e)))))
        (if (and (/= (cdr (assoc 5 (entget e))) beg)
                 (or (setq bs (bk:gr-route sids p (bk:attr e "ЭТАЖ")))
                     (progn (princ (strcat "\n" (bk:dev-pos (cdr (assoc 5 (entget e)))) ": путь не найден - " (if *bk:rerr* *bk:rerr* "?"))) nil)))
          (setq recs (cons (list e (bk:dev-pos (cdr (assoc 5 (entget e))))
                                 (vla-get-EffectiveName (vlax-ename->vla-object e))
                                 (bk:attr e "ЭТАЖ") (nth 4 bs)
                                 (bk:join (bk:dev-cables (cdr (assoc 5 (entget e)))) ", ")
                                 sids)
                           recs))))
      (setq recs (vl-sort recs '(lambda (a b) (< (nth 4 a) (nth 4 b)))))
      (cond
        ((null recs) (princ "\nНет устройств, до которых найден путь (см. причины выше)."))
        ((setq sel (bk:grp-dialog recs))
         (if (setq par (bk:dialog (bk:par-from sd) nil
                         (strcat "Кабели из " (bk:dev-pos beg) " к выбранным устройствам: " (itoa (length sel))
                                 " шт. ПОЗИЦИЯ - первого, дальше по порядку.")))
           (progn
             (setq n 0 pos (nth 2 par))
             (foreach r sel
               (setq pos (bk:free-pos pos nil) par (bk:replace-nth 2 pos par))
               (if (setq d (bk:trdev-one (nth 6 r) (car r) par))
                 (progn (setq n (1+ n))
                        (princ (strcat "\n" pos " -> " (nth 1 r) ": " (bk:len-text (bk:f d "id"))))))
               (setq pos (bk:incr pos)))
             (princ (strcat "\nСоздано кабелей: " (itoa n) "."))))))))
  (princ))

;;; ---------- ММ_КАБЕЛЬ_ТРАССИРОВКА: кабель по указанной трассе ----------
;; Блок начала -> блок конца -> кабель-трасса (щелчок по существующему кабелю) или [Нет].
;; С трассой: от блока начала - подводка по горизонтали/вертикали (гофр. труба d20) к ближайшей
;; точке трассы, далее ПО ТРАССЕ (её участки, способы прокладки, высоты, диаметры, стояки) до
;; точки, ближайшей к блоку конца, и подводка к нему. Без трассы - подводка напрямую (Г-образно).
(defun bk:tr-proj (p a b / dx dy l2 u q)
  (setq dx (- (car b) (car a)) dy (- (cadr b) (cadr a)) l2 (+ (* dx dx) (* dy dy)))
  (setq u (if (> l2 1e-9) (/ (+ (* (- (car p) (car a)) dx) (* (- (cadr p) (cadr a)) dy)) l2) 0.0))
  (setq u (max 0.0 (min 1.0 u)) q (list (+ (car a) (* u dx)) (+ (cadr a) (* u dy))))
  (list q u (distance (bk:2d p) q)))

;; Г-образная подводка p -> q; hor-first - сначала по горизонтали
(defun bk:tr-corner (p q hor-first)
  (if (or (< (abs (- (car p) (car q))) 1e-6) (< (abs (- (cadr p) (cadr q))) 1e-6)) nil
    (list (if hor-first (list (car q) (cadr p)) (list (car p) (cadr q))))))

(defun bk:uniq (l / r) (foreach x l (if (not (member x r)) (setq r (cons x r)))) (reverse r))

(defun bk:tr-pick (msg / es)
  (while (and (setq es (entsel msg)) (/= (cdr (assoc 0 (entget (car es)))) "INSERT"))
    (princ "\nЭто не блок."))
  (if es (car es)))

;; отрезки трассы-кабеля по порядку: ((a b attr) ...), attr = (код высота коэф d_мат размер длина_стояка)
(defun bk:tr-edges (id / out pts a)
  (foreach p (bk:parts id)
    (setq pts (caddr p) a (list (car p) (cadr p) (cadddr p) (bk:num (nth 8 p)) (bk:sz p) (bk:slen p)))
    (while (cdr pts) (setq out (cons (list (car pts) (cadr pts) a) out) pts (cdr pts))))
  (reverse out))

;; ближайшая точка трассы к p: (номер_отрезка параметр точка)
;; этажи рёбер кабеля id (в порядке bk:tr-edges-ex)
(defun bk:tr-edge-floors (id / out pts)
  (foreach p (bk:parts id)
    (setq pts (caddr p))
    (while (cdr pts) (setq out (cons (if (nth 13 p) (nth 13 p) "") out) pts (cdr pts))))
  (reverse out))
;; ближайшая точка пути НА ЭТАЖЕ fl (рёбра с другим этажом пропускаются); нет такого этажа - по всем
(defun bk:tr-near-fl (p edges id fl / fls i best r q)
  (setq fls (bk:tr-edge-floors id) fl (bk:up (vl-string-trim " " (if fl fl ""))))
  (if (or (= fl "") (not (vl-some '(lambda (x) (= (bk:up (vl-string-trim " " x)) fl)) fls)))
    (bk:tr-near-edge p edges)
    (progn
      (setq i 0)
      (foreach e edges
        (if (and (not (bk:stc (car (caddr e)))) (= (bk:up (vl-string-trim " " (nth i fls))) fl))
          (progn (setq q (bk:tr-proj p (car e) (cadr e)))
                 (if (or (null best) (< (caddr q) best)) (setq best (caddr q) r (list i (cadr q) (car q))))))
        (setq i (1+ i)))
      r)))

(defun bk:tr-near-edge (p edges / i best r q)
  (setq i 0)
  (foreach e edges
    (if (not (bk:stc (car (caddr e))))                ; на стояк не заходим подводкой
      (progn (setq q (bk:tr-proj p (car e) (cadr e)))
             (if (or (null best) (< (caddr q) best)) (setq best (caddr q) r (list i (cadr q) (car q))))))
    (setq i (1+ i)))
  r)

;; ближайшие точки двух трасс: (iA tA ptA iB tB ptB) - вершины одной против отрезков другой
(defun bk:tr-closest (ea eb / best r q i j)
  (setq i 0)
  (foreach a ea
    (if (not (bk:stc (car (caddr a))))
      (foreach v (list (list (car a) 0.0) (list (cadr a) 1.0))
        (setq j 0)
        (foreach b eb
          (if (not (bk:stc (car (caddr b))))
            (progn (setq q (bk:tr-proj (car v) (car b) (cadr b)))
                   (if (or (null best) (< (caddr q) best))
                     (setq best (caddr q) r (list i (cadr v) (car v) j (cadr q) (car q))))))
          (setq j (1+ j)))))
    (setq i (1+ i)))
  (setq i 0)
  (foreach b eb
    (if (not (bk:stc (car (caddr b))))
      (foreach v (list (list (car b) 0.0) (list (cadr b) 1.0))
        (setq j 0)
        (foreach a ea
          (if (not (bk:stc (car (caddr a))))
            (progn (setq q (bk:tr-proj (car v) (car a) (cadr a)))
                   (if (or (null best) (< (caddr q) best))
                     (setq best (caddr q) r (list j (cadr q) (car q) i (cadr v) (car v))))))
          (setq j (1+ j)))))
    (setq i (1+ i)))
  r)

(defun bk:tr-lerp (a b u) (list (+ (car a) (* u (- (car b) (car a)))) (+ (cadr a) (* u (- (cadr b) (cadr a))))))

;; кусок трассы от точки A (i1 t1) до B (i2 t2): список ((точки) attr) по отрезкам
(defun bk:tr-sub (edges i1 t1 i2 t2 / out rev e i a b tmp)
  (if (or (> i1 i2) (and (= i1 i2) (> t1 t2)))
    (setq rev T tmp i1 i1 i2 i2 tmp tmp t1 t1 t2 t2 tmp))
  (setq i i1)
  (while (<= i i2)
    (setq e (nth i edges)
          a (if (= i i1) (bk:tr-lerp (car e) (cadr e) t1) (car e))
          b (if (= i i2) (bk:tr-lerp (car e) (cadr e) t2) (cadr e)))
    (if (> (distance a b) 1e-6) (setq out (cons (list (list a b) (caddr e)) out)))
    (setq i (1+ i)))
  (setq out (reverse out))
  (if rev (reverse (mapcar '(lambda (x) (list (reverse (car x)) (cadr x))) out)) out))

;; один способ прокладки (тип, диаметр, сущ.) - одна полилиния; мелкие отличия (длины, заполнение) не делят
(defun bk:tr-same (a b)
  (and (= (nth 0 a) (nth 0 b)) (equal (nth 3 a) (nth 3 b) 1e-6)
       (= (if (nth 6 a) (nth 6 a) "") (if (nth 6 b) (nth 6 b) ""))))

;; куски ((точки) attr) -> участки кабеля; одинаковые соседние сливаются (стояки - отдельно)
(defun bk:tr-parts (pieces / parts cur)
  (foreach pc pieces
    (if (and cur (bk:tr-same (cadr cur) (cadr pc)) (not (bk:stc (car (cadr pc))))
             (equal (last (car cur)) (car (car pc)) 1e-6))
      (setq cur (list (append (car cur) (cdr (car pc))) (cadr cur)))
      (progn (if cur (setq parts (cons cur parts))) (setq cur pc))))
  (if cur (setq parts (cons cur parts)))
  (mapcar '(lambda (c / a)
             (setq a (cadr c))
             (list (nth 0 a) (nth 1 a) (car c) (nth 2 a) nil "" 0.0 nil (nth 3 a) 0.0 (nth 4 a) (nth 5 a) "" "" (if (nth 6 a) (nth 6 a) "")))
          (reverse parts)))

;; подводка от блока p к точке трассы q (на отрезке e): подходит перпендикулярно отрезку
(defun bk:tr-conn (p q e cattr / hor)
  (setq hor (and e (> (abs (- (cadr (car e)) (cadr (cadr e)))) (abs (- (car (car e)) (car (cadr e)))))))
  (list (append (list p) (bk:tr-corner p q hor) (list q)) cattr))

(defun bk:cmd-trace (/ par b1 b2 p1 p2 es tid tids ids edges tr i n1 n2 cl cattr h pieces parts d n lnet lnew nst ex cur)
  (if (setq par (bk:dialog *bk:par* nil
                  "Трассировка: блок начала, блок конца, затем кабели-трассы по порядку (или Нет). Подводки - гофр. труба d20."))
    (progn
      (setq *bk:par* par n 0)
      (while (and (setq b1 (bk:tr-pick (strcat "\nКабель " (nth 2 *bk:par*) ": блок НАЧАЛА <выход>: ")))
                  (setq b2 (bk:tr-pick "\nБлок КОНЦА: ")))
        (setq p1 (bk:2d (cdr (assoc 10 (entget b1)))) p2 (bk:2d (cdr (assoc 10 (entget b2))))
              h (if (bk:type "GOFRA") (nth 4 (bk:type "GOFRA")) 3.0)
              cattr (list "GOFRA" h (bk:num (nth 5 *bk:par*)) 20.0 "" 0.0 "") tids nil es (list nil))
        ;; трассы по порядку: щелчки по существующим кабелям, Enter - закончить
        (while (and es (listp es))
          (initget "Нет Готово")
          (setq es (entsel (if tids (strcat "\nСледующая кабель-трасса (выбрано " (itoa (length tids)) ") [Готово] <Готово>: ")
                             "\nЩёлкните кабель-трассу, по которой вести [Нет] <Нет>: ")))
          (if (and es (listp es))
            (progn
              ;; наложенные кабели в точке щелчка - выбор из списка (иначе можно попасть в чужую линию сверху)
              (setq ids (vl-remove-if '(lambda (x) (member x tids)) (bk:cables-at (trans (cadr es) 1 0))))
              (setq tid (cond ((null ids) nil) ((null (cdr ids)) (car ids)) (T (car (bk:choose ids)))))
              (if tid
                (progn (setq tids (append tids (list tid)))
                       (foreach e (bk:segs tid) (redraw e 3))
                       (princ (strcat "\nТрасса " (itoa (length tids)) ": " (bk:f (bk:get (car (bk:segs tid))) "pos") " - "
                                      (bk:join (bk:uniq (mapcar '(lambda (p) (bk:tname (car p))) (bk:parts tid))) ", "))))
                (princ "\nЗдесь нет кабеля (или он уже выбран).")))))
        (foreach tid tids (foreach e (bk:segs tid) (redraw e 4)))
        (setq ex "")
        (if tids
          (progn (initget "Да Нет")
                 (if (= (getkword "\nТрасса существующая (материал прокладки по ней не считать)? [Да/Нет] <Нет>: ") "Да")
                   (setq ex "1"))))
        (if tids
          (progn
            ;; от блока начала на первую трассу; по каждой трассе до перехода на следующую; с последней - к блоку конца
            (setq tr (mapcar '(lambda (id) (mapcar '(lambda (e) (list (car e) (cadr e) (append (caddr e) (list ex)))) (bk:tr-edges id))) tids)
                  n1 (bk:tr-near-edge p1 (car tr))
                  pieces (list (bk:tr-conn p1 (caddr n1) (nth (car n1) (car tr)) cattr))
                  cur n1 i 0)
            (while (< i (length tr))
              (setq edges (nth i tr))
              (if (< i (1- (length tr)))
                (progn
                  (setq cl (bk:tr-closest edges (nth (1+ i) tr)))
                  (setq pieces (append pieces (bk:tr-sub edges (car cur) (cadr cur) (nth 0 cl) (nth 1 cl))))
                  ;; переход между трассами - подводка (если трассы не касаются)
                  (if (> (distance (nth 2 cl) (nth 5 cl)) 1e-6)
                    (setq pieces (append pieces (list (list (append (list (nth 2 cl)) (bk:tr-corner (nth 2 cl) (nth 5 cl) T) (list (nth 5 cl))) cattr)))))
                  (setq cur (list (nth 3 cl) (nth 4 cl))))
                (progn
                  (setq n2 (bk:tr-near-edge p2 edges))
                  (setq pieces (append pieces (bk:tr-sub edges (car cur) (cadr cur) (car n2) (cadr n2))
                                       (list (list (reverse (car (bk:tr-conn p2 (caddr n2) (nth (car n2) edges) cattr))) cattr))))))
              (setq i (1+ i))))
          (setq pieces (list (list (append (list p1) (bk:tr-corner p1 p2 T) (list p2)) cattr))))
        (setq pieces (vl-remove-if '(lambda (x) (< (bk:plen (car x)) 1e-6)) pieces))
        (setq lnet 0.0 lnew 0.0 nst 0)
        (foreach pc pieces
          (cond ((bk:stc (car (cadr pc))) (setq nst (1+ nst)))
                ((eq (cadr pc) cattr) (setq lnew (+ lnew (bk:plen (car pc)))))
                (T (setq lnet (+ lnet (bk:plen (car pc)))))))
        (setq parts (bk:tr-parts pieces) d nil)
        (foreach kv (list (cons "id" (bk:newid "K")) (cons "marka" (nth 0 *bk:par*)) (cons "diam" (nth 1 *bk:par*))
                          (cons "pos" (nth 2 *bk:par*)) (cons "layer" (nth 7 *bk:par*)) (cons "lts" (nth 8 *bk:par*))
                          (cons "floor" (nth 9 *bk:par*)))
          (setq d (bk:setf d (car kv) (cdr kv))))
        (setq d (bk:rebuild d parts))
        (princ (strcat "\nКабель " (nth 2 *bk:par*) " проложен" (if tids (strcat " по трассам: " (itoa (length tids))) " без трассы")
                       (if (= ex "1") " (существующие)" "") ": по трассам " (itoa (bk:ceil0 (/ lnet 1000.0)))
                       " м, подводки (гофр. труба d20) " (itoa (bk:ceil0 (/ lnew 1000.0))) " м"
                       (if (> nst 0) (strcat ", стояков/переносов " (itoa nst)) "") ";  " (bk:len-text (bk:f d "id"))))
        (setq n (1+ n) *bk:par* (bk:replace-nth 2 (bk:free-pos (bk:incr (nth 2 *bk:par*)) nil) *bk:par*)))
      (princ (strcat "\nПроложено кабелей: " (itoa n) "."))))
  (princ))

;;; ---------- обёртка команд ----------
(defun bk:run (fun / *error* doc)
  (setq doc (bk:doc))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*"))
      (princ (strcat "\nОшибка: " m)))
    (setq *bk:busy* nil)
    (vla-EndUndoMark doc)
    (princ))
  (bk:load-types)
  (setq *bk:busy* T)
  (vla-StartUndoMark doc)
  (apply fun nil)
  (bk:cidx-reset)
  (if (and (member fun '(bk:cmd-draw bk:cmd-trace bk:cmd-trace-dev bk:cmd-trace-grp bk:cmd-from bk:cmd-more bk:cmd-heal))
           (bk:ld-auto-list))
    (vl-catch-all-apply 'bk:update-leaders))
  (setq *bk:busy* nil)
  (vla-EndUndoMark doc)
  (princ))

(defun bk:cmd-refresh (/ k n)
  (initget "Авто")
  (setq k (getkword (strcat "\nОбновить выноски [Авто - автообновление "
                            (if *bk:auto* "ВКЛ" "ВЫКЛ") "] <обновить все сейчас>: ")))
  (if (= k "Авто")
    (progn (setq *bk:auto* (not *bk:auto*))
           (princ (strcat "\nАвтообновление выносок " (if *bk:auto* "включено." "выключено."))))
    (progn
      (princ "\nОбновление всего чертежа...")
      (bk:cidx-reset)
      ;; дубли (копии кабелей с тем же id) - новые id и ПОЗИЦИИ
      (vl-catch-all-apply 'bk:fix-copies (list (bk:dup-segs)))
      (bk:cidx-reset)
      ;; стыки и привязка концов у всех кабелей
      (foreach m (bk:cable-map) (vl-catch-all-apply 'bk:fix-cable (list (car m) nil)))
      (setq n (bk:update-leaders))
      (bk:cidx-reset)
      (princ (strcat "\nОбновлено выносок: " (itoa n) ", подписей кабелей: " (itoa (bk:end-labels-all)) ".")))))
;; участки копий: у кабеля с одним id несколько групп - все группы, кроме первой
(defun bk:dup-segs (/ m d id g k p out)
  (foreach e (bk:all-segs)
    (setq id (bk:f (bk:get e) "id") g (bk:group-of e) k (if g (cdr (assoc 5 (entget g))) "-"))
    (if (setq p (assoc id m)) (setq m (subst (bk:amap-add-pair p k e) p m)) (setq m (cons (list id (list k e)) m))))
  (foreach x m (foreach gr (cddr x) (setq out (append out (cdr gr)))))
  out)
(defun bk:amap-add-pair (p k e / q)
  (if (setq q (assoc k (cdr p))) (subst (append q (list e)) q p) (append p (list (list k e)))))

(defun c:мм_кабель ()               (bk:run 'bk:cmd-draw))
(defun c:ММ_КАБЕЛЬ ()               (bk:run 'bk:cmd-draw))
(defun c:MM_CABLE ()                (bk:run 'bk:cmd-draw))
(defun c:мм_кабель_участок ()       (bk:run 'bk:cmd-seg))
(defun c:ММ_КАБЕЛЬ_УЧАСТОК ()       (bk:run 'bk:cmd-seg))
(defun c:MM_CABLE_SEGMENT ()            (bk:run 'bk:cmd-seg))
(defun c:мм_кабель_свойства ()      (bk:run 'bk:cmd-props))
(defun c:ММ_КАБЕЛЬ_СВОЙСТВА ()      (bk:run 'bk:cmd-props))
(defun c:MM_CABLE_PROPS ()             (bk:run 'bk:cmd-props))
(defun c:мм_кабель_пересобрать ()   (bk:run 'bk:cmd-heal))
(defun c:ММ_КАБЕЛЬ_ПЕРЕСОБРАТЬ ()   (bk:run 'bk:cmd-heal))
(defun c:мм_кабель_из_линии ()      (bk:run 'bk:cmd-from))
(defun c:ММ_КАБЕЛЬ_ИЗ_ЛИНИИ ()      (bk:run 'bk:cmd-from))
(defun c:MM_CABLE_FROM_LINE ()             (bk:run 'bk:cmd-from))
(defun c:MM_CABLE_REBUILD ()            (bk:run 'bk:cmd-heal))
(defun c:мм_кабель_выноска ()       (bk:run 'bk:cmd-leader))
(defun c:ММ_КАБЕЛЬ_ВЫНОСКА ()       (bk:run 'bk:cmd-leader))
(defun c:MM_CABLE_LEADER ()            (bk:run 'bk:cmd-leader))
(defun c:мм_кабель_выноска_парам () (bk:run 'bk:cmd-ldpar))
(defun c:ММ_КАБЕЛЬ_ВЫНОСКА_ПАРАМ () (bk:run 'bk:cmd-ldpar))
(defun c:MM_CABLE_LEADER_PARAMS ()           (bk:run 'bk:cmd-ldpar))
(defun c:мм_кабель_выноска_прокл () (bk:run 'bk:cmd-pl-leader))
(defun c:ММ_КАБЕЛЬ_ВЫНОСКА_ПРОКЛ () (bk:run 'bk:cmd-pl-leader))
(defun c:MM_CABLE_LEADER_ROUTE ()            (bk:run 'bk:cmd-pl-leader))
(defun c:мм_кабель_трассировка ()   (bk:run 'bk:cmd-trace))
(defun c:мм_кабель_трассировка_устройство () (bk:run 'bk:cmd-trace-dev))
(defun c:ММ_КАБЕЛЬ_ТРАССИРОВКА_УСТРОЙСТВО () (bk:run 'bk:cmd-trace-dev))
(defun c:MM_CABLE_TRACE_DEVICE ()          (bk:run 'bk:cmd-trace-dev))
(defun c:мм_кабель_трассировка_группа () (bk:run 'bk:cmd-trace-grp))
(defun c:ММ_КАБЕЛЬ_ТРАССИРОВКА_ГРУППА () (bk:run 'bk:cmd-trace-grp))
(defun c:MM_CABLE_TRACE_GROUP ()          (bk:run 'bk:cmd-trace-grp))
(defun c:ММ_КАБЕЛЬ_ТРАССИРОВКА ()   (bk:run 'bk:cmd-trace))
(defun c:MM_CABLE_TRACE ()          (bk:run 'bk:cmd-trace))
(defun c:мм_кабель_эл ()            (bk:run 'bk:cmd-el))
(defun c:ММ_КАБЕЛЬ_ЭЛ ()            (bk:run 'bk:cmd-el))
(defun c:MM_CABLE_POWER ()             (bk:run 'bk:cmd-el))
(defun c:мм_кабель_выноска_стояк () (bk:run 'bk:cmd-st-leader))
(defun c:ММ_КАБЕЛЬ_ВЫНОСКА_СТОЯК () (bk:run 'bk:cmd-st-leader))
(defun c:MM_CABLE_LEADER_RISER ()            (bk:run 'bk:cmd-st-leader))
(defun c:мм_кабель_выноска_формат () (bk:run 'bk:cmd-ldfmt))
(defun c:ММ_КАБЕЛЬ_ВЫНОСКА_ФОРМАТ () (bk:run 'bk:cmd-ldfmt))
(defun c:MM_CABLE_LEADER_FORMAT ()            (bk:run 'bk:cmd-ldfmt))
(defun c:мм_кабель_справочник ()    (bk:run 'bk:cmd-catupd))
(defun c:ММ_КАБЕЛЬ_СПРАВОЧНИК ()    (bk:run 'bk:cmd-catupd))
(defun c:MM_CABLE_CATALOG ()            (bk:run 'bk:cmd-catupd))
(defun bk:cmd-catupd () (bk:cat-update T) (princ))
(defun c:мм_кабель_линии ()         (bk:run 'bk:cmd-lines))
(defun c:ММ_КАБЕЛЬ_ЛИНИИ ()         (bk:run 'bk:cmd-lines))
(defun c:MM_CABLE_LINES ()            (bk:run 'bk:cmd-lines))
(defun c:мм_кабель_обновить ()      (bk:run 'bk:cmd-refresh))
(defun c:ММ_КАБЕЛЬ_ОБНОВИТЬ ()      (bk:run 'bk:cmd-refresh))
(defun c:MM_CABLE_UPDATE ()            (bk:run 'bk:cmd-refresh))
(defun c:мм_кабель_переименовать () (bk:run 'bk:cmd-rename))
(defun c:ММ_КАБЕЛЬ_ПЕРЕИМЕНОВАТЬ () (bk:run 'bk:cmd-rename))
(defun c:MM_CABLE_RENAME ()         (bk:run 'bk:cmd-rename))
(defun c:мм_кабель_все ()           (bk:run 'bk:cmd-list))
(defun c:ММ_КАБЕЛЬ_ВСЕ ()           (bk:run 'bk:cmd-list))
(defun c:MM_CABLE_ALL ()            (bk:run 'bk:cmd-list))
(defun c:мм_кабель_легенда ()       (bk:run 'bk:cmd-legend))
(defun c:ММ_КАБЕЛЬ_ЛЕГЕНДА ()       (bk:run 'bk:cmd-legend))
(defun c:MM_CABLE_LEGEND ()            (bk:run 'bk:cmd-legend))
(defun c:мм_кабель_типы ()          (bk:run 'bk:types-dialog))
(defun c:ММ_КАБЕЛЬ_ТИПЫ ()          (bk:run 'bk:types-dialog))
(defun c:MM_CABLE_TYPES ()           (bk:run 'bk:types-dialog))
(defun c:мм_кабель_еще ()           (bk:run 'bk:cmd-more))
(defun c:ММ_КАБЕЛЬ_ЕЩЕ ()           (bk:run 'bk:cmd-more))
(defun c:MM_CABLE_MORE ()           (bk:run 'bk:cmd-more))
(defun c:мм_кабель_ветка ()         (bk:run 'bk:cmd-branch))
(defun c:ММ_КАБЕЛЬ_ВЕТКА ()         (bk:run 'bk:cmd-branch))
(defun c:MM_CABLE_BRANCH ()         (bk:run 'bk:cmd-branch))
(defun c:мм_кабель_журнал ()        (bk:run 'bk:cmd-journal))
(defun c:ММ_КАБЕЛЬ_ЖУРНАЛ ()        (bk:run 'bk:cmd-journal))
(defun c:MM_CABLE_LOG ()             (bk:run 'bk:cmd-journal))

;;; ---------- сообщение при загрузке ----------
(princ "\n==================================================================")
(princ "\n MM_CABLE.LSP загружен: кабели из участков")
(princ "\n  ММ_КАБЕЛЬ               - нарисовать кабель (прокладка по умолчанию)")
(princ "\n  ММ_КАБЕЛЬ_ИЗ_ЛИНИИ      - сделать кабелем готовую линию/полилинию")
(princ "\n  ММ_КАБЕЛЬ_УЧАСТОК       - участок: прокладка всех кабелей, сечения [Точки]")
(princ "\n  ММ_КАБЕЛЬ_СВОЙСТВА      - окно: опуски, участки, переходы, коэф. запаса")
(princ "\n  ММ_КАБЕЛЬ_ПЕРЕСОБРАТЬ   - после правки ручками: сшить стыки, найти приборы")
(princ "\n  ММ_КАБЕЛЬ_ВЫНОСКА       - общая выноска (кружок, привязка текста)")
(princ "\n  ММ_КАБЕЛЬ_ВЫНОСКА_ПАРАМ - высота текста, кружок, привязка готовых выносок")
(princ "\n  ММ_КАБЕЛЬ_ТРАССИРОВКА   - блок начала -> блок конца -> по указанному кабелю-трассе")
(princ "\n  ММ_КАБЕЛЬ_ЭЛ            - потери напряжения: все кабели, параметры, по участкам, экспорт")
(princ "\n  ММ_КАБЕЛЬ_ВЫНОСКА_СТОЯК - подпись стояка / переноса на др. лист: кабели + куда/откуда (2 выноски)")
(princ "\n  ММ_КАБЕЛЬ_ВЫНОСКА_ФОРМАТ - формат записи всех выносок (шаблоны с полями)")
(princ "\n  ММ_КАБЕЛЬ_СПРАВОЧНИК    - обновить справочник кабелей из cable_type.csv")
(princ "\n  ММ_КАБЕЛЬ_ВЫНОСКА_ПРОКЛ - в чём идёт кабель, расчётный диаметр, заполнение")
(princ "\n  ММ_КАБЕЛЬ_ПЕРЕИМЕНОВАТЬ  - кабели выделенных устройств: новые ПОЗИЦИИ по маске")
(princ "\n  ММ_КАБЕЛЬ_ОБНОВИТЬ      - обновить весь чертёж (после правок обновляются только изменённые кабели);  ММ_КАБЕЛЬ_ЖУРНАЛ - CSV")
(princ "\n  ММ_КАБЕЛЬ_ВСЕ           - все кабели чертежа: просмотр и свойства")
(princ "\n  ММ_КАБЕЛЬ_ЛЕГЕНДА       - таблица условных обозначений линий")
(princ "\n  ММ_КАБЕЛЬ_ЛИНИИ         - линии по типам прокладки / все сплошные / все штриховые")
(princ "\n  ММ_КАБЕЛЬ_ТИПЫ          - добавить / изменить способы прокладки")
(princ "\n  ММ_КАБЕЛЬ_ЕЩЕ           - ещё кабель по пути выбранного, те же параметры")
(princ "\n  ММ_КАБЕЛЬ_ВЕТКА         - ветка кабеля (та же ПОЗИЦИЯ, в журнале - одна строка)")
(princ "\n==================================================================")
(princ)
