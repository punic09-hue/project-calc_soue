;;; ======================================================================
;;;  MM_SCHEME.LSP  —  поэтажная структурная схема по кабелям плана
;;;  AutoCAD 2024. Кодировка файла: Windows-1251 (ANSI).
;;;  Требует blok_kabel.lsp (данные кабелей, этажи, стояки, формат подписей):
;;;  если он не загружен - подгружается из той же папки.
;;; ----------------------------------------------------------------------
;;;  КОМАНДА:
;;;   ММ_СХЕМА (MM_SCHEME) - окно параметров -> схема рисуется в
;;;     отдельный файл (по умолчанию "схема.dwg" в папке чертежа; если файл
;;;     открыт в AutoCAD - прямо в нём, иначе через ObjectDBX без открытия).
;;;   Вид: поэтажная схема. Этажи - горизонтальные полосы сверху вниз (атрибут
;;;     ЭТАЖ блоков / этажи участков). Приборы - те же блоки, что на планах,
;;;     с теми же значениями атрибутов. Шлейф = кабели с одной ПОЗИЦИЕЙ;
;;;     приборы шлейфа идут слева направо в порядке прохождения кабеля.
;;;     Стояки (участки "стояк") - вертикальные линии, каждый стояк (по
;;;     ПОЗИЦИИ блока-стояка) - своя колонка со смещением; шлейфы внутри
;;;     стояка - со сдвигом, чтобы линии не сливались.
;;;   Опции окна: файл, удалить прежнюю схему, формат (A4...A0, A4x3, A3x3),
;;;     ориентация, рамка ГОСТ 2.301 (поля 20/5 мм), вписать в формат,
;;;     масштаб блоков, шаги, высоты текста, стиль, маска кабелей, этажи;
;;;     сворачивание: одинаковые подряд в шлейфе / в шлейфе на этаже / на
;;;     этаже из разных шлейфов ("xN"); подписи кабелей: вкл/выкл, шаблон,
;;;     группировка. "Блоки на схеме..." - выбор имён блоков (фильтр,
;;;     сортировка); выбранные блоки без кабелей тоже рисуются; блоки без
;;;     ЭТАЖ - в отдельной полосе "Этаж не указан". "Кабели и цвета..." -
;;;     какие шлейфы показывать и каким цветом (фильтр, сортировка); линии
;;;     кабелей штриховые (DASHED), легенда цветов под схемой.
;;;   Подписи кабелей - у вертикали подвода к каждому прибору. Блоки переноса на др. лист
;;;     на схеме не показываются. В окне вертикалей - "Показывать блоки стояков".
;;;   Под схемой: "Условные обозначения" (цвета кабелей и символы блоков: обозначение -
;;;     наименование, марка) и "Ведомость потребности оборудования" - таблица AutoCAD
;;;     (№, Обозначение, Наименование, Тип/марка, Производитель, Кол.).
;;;   Всё построенное - на слоях "СХ_*"; "Удалить прежнюю" стирает их.
;;;   Параметры запоминаются в текущем чертеже.
;;; ======================================================================

(vl-load-com)

;;; ---------- зависимость от blok_kabel.lsp ----------
(defun sc:need-kabel (/ fn)
  (if (not bk:cable-map)
    (progn
      (setq fn (findfile (strcat (vl-filename-directory (cond ((findfile "blok_schema.lsp")) (""))) "\\blok_kabel.lsp")))
      (if (not fn) (setq fn (findfile "blok_kabel.lsp")))
      (if fn (load fn))))
  (if bk:cable-map T
    (progn (alert "Для ММ_СХЕМА нужен blok_kabel.lsp.\nЗагрузите его (APPLOAD) и повторите команду.") nil)))

;;; ---------- параметры (хранятся в чертеже: ldata "BK" "sch") ----------
(setq *sc:formats* '(("A4" 210 297) ("A3" 297 420) ("A2" 420 594) ("A1" 594 841) ("A0" 841 1189)
                     ("A4x3" 297 630) ("A3x3" 420 891)))
(setq *sc:def*
  '(("file" . "") ("clear" . "1") ("fmt" . "1") ("orient" . "0") ("frame" . "1") ("fit" . "1")
    ("bscale" . "1") ("dx" . "30") ("hf" . "60") ("rdx" . "12") ("th" . "3.5") ("style" . "")
    ("coll" . "0") ("leg" . "1") ("lts" . "0.5") ("lab" . "1") ("tpl" . "{ПОЗ} - {НОМ}") ("grp" . "1") ("lth" . "2.5")
    ("flab" . "Этаж {ЭТАЖ}") ("xoff" . "0") ("vtol" . "1500") ("pah" . "") ("rpath" . "0")))
(defun sc:par () (cond ((vlax-ldata-get "BK" "sch")) (*sc:def*)))
(defun sc:g (k) (cond ((cdr (assoc k *sc:p*))) ((cdr (assoc k *sc:def*))) ("")))
(defun sc:set (k v) (setq *sc:p* (if (assoc k *sc:p*) (subst (cons k v) (assoc k *sc:p*) *sc:p*) (cons (cons k v) *sc:p*))))
;; выбранные блоки ("blks" - список имён, nil - все, подключённые к кабелям) и кабели ("cabs": ((ПОЗИЦИЯ вкл цвет) ...))
(defun sc:blks () (cdr (assoc "blks" *sc:p*)))
(defun sc:cabs () (cdr (assoc "cabs" *sc:p*)))
(setq *sc:colors* '(1 5 3 6 30 4 140 200 2 12 92 172 222 42))
(defun sc:gn (k) (bk:num (sc:g k)))

;;; ---------- окно ----------
(setq *sc:keys* '("file" "clear" "fmt" "orient" "frame" "fit" "bscale" "dx" "hf" "rdx" "th" "style"
                  "coll" "leg" "lts" "lab" "tpl" "grp" "lth" "flab" "xoff" "pah"))

(defun sc:read-tiles (/ keep)
  ;; всё, что не поля окна (блоки, кабели, этажи, цвета, вертикали...), сохраняется
  (setq keep (vl-remove-if '(lambda (x) (member (car x) *sc:keys*)) *sc:p*))
  (setq *sc:p* (append (mapcar '(lambda (k) (cons k (get_tile k))) *sc:keys*) keep)
        *sc:p* (subst (cons "style" (nth (atoi (get_tile "style")) *sc:stys*)) (assoc "style" *sc:p*) *sc:p*)))

(defun sc:dialog (/ fn id res)
  (setq *sc:p* (sc:par) *sc:stys* nil)
  (if (= (sc:g "file") "") (setq *sc:p* (cons (cons "file" (strcat (getvar "DWGPREFIX") "схема.dwg")) *sc:p*)))
  (vlax-for s (vla-get-TextStyles (bk:doc)) (setq *sc:stys* (cons (vla-get-Name s) *sc:stys*)))
  (setq *sc:stys* (vl-sort *sc:stys* '<))
  (setq fn (bk:write-dcl "blok_schema.dcl"
             '("bk_sch : dialog { label = \"Структурная схема (поэтажная) - ММ_СХЕМА\";"
               " : boxed_column { label = \"Файл схемы\";"
               "  : row { : edit_box { key = \"file\"; label = \"Файл:\"; edit_width = 60; allow_accept = false; }"
               "          : button { key = \"b_file\"; label = \"Обзор...\"; width = 12; fixed_width = true; } }"
               "  : row { : toggle { key = \"clear\"; label = \"Удалить прежнюю схему в файле (слои СХ_*)\"; }"
               "          : edit_box { key = \"xoff\"; label = \"Смещение по X, мм:\"; edit_width = 7; fixed_width = true; allow_accept = false; } } }"
               " : boxed_column { label = \"Лист\";"
               "  : row { : popup_list { key = \"fmt\"; label = \"Формат:\"; width = 22; fixed_width = true; }"
               "          : popup_list { key = \"orient\"; label = \"Ориентация:\"; width = 28; fixed_width = true; }"
               "          : toggle { key = \"frame\"; label = \"Рамка (ГОСТ 2.301, поля 20/5 мм)\"; }"
               "          : toggle { key = \"fit\"; label = \"Вписать схему в формат\"; } } }"
               " : boxed_column { label = \"Размеры (мм на листе)\";"
               "  : row { : edit_box { key = \"bscale\"; label = \"Масштаб блоков:\"; edit_width = 6; fixed_width = true; allow_accept = false; }"
               "          : edit_box { key = \"dx\"; label = \"Шаг приборов:\"; edit_width = 6; fixed_width = true; allow_accept = false; }"
               "          : edit_box { key = \"hf\"; label = \"Высота этажа:\"; edit_width = 6; fixed_width = true; allow_accept = false; }"
               "          : edit_box { key = \"rdx\"; label = \"Смещение стояков:\"; edit_width = 6; fixed_width = true; allow_accept = false; }"
               "          : edit_box { key = \"pah\"; label = \"Высота ПОЗИЦИИ блоков (пусто - как текст этажей):\"; edit_width = 6; fixed_width = true; allow_accept = false; } : spacer { } }"
               "  : row { : edit_box { key = \"th\"; label = \"Текст этажей/стояков:\"; edit_width = 6; fixed_width = true; allow_accept = false; }"
               "          : popup_list { key = \"style\"; label = \"Стиль текста:\"; width = 36; fixed_width = true; }"
               "          : edit_box { key = \"flab\"; label = \"Подпись этажа:\"; edit_width = 18; fixed_width = true; allow_accept = false; } : spacer { } } }"
               " : boxed_column { label = \"Кабели и приборы\";"
               "  : row { : button { key = \"b_blk\"; label = \"Блоки на схеме...\"; width = 22; fixed_width = true; }"
               "          : button { key = \"b_cab\"; label = \"Кабели...\"; width = 22; fixed_width = true; }"
               "          : button { key = \"b_flr\"; label = \"Этажи...\"; width = 16; fixed_width = true; }"
               "          : button { key = \"b_colr\"; label = \"Цвета...\"; width = 16; fixed_width = true; }"
               "          : button { key = \"b_vert\"; label = \"Вертикали...\"; width = 16; fixed_width = true; }"
               "          : text { key = \"selinfo\"; width = 60; } }"
               "  : row { : popup_list { key = \"coll\"; label = \"Сворачивание приборов:\"; width = 62; fixed_width = true; }"
               "          : toggle { key = \"leg\"; label = \"Легенда цветов кабелей\"; }"
               "          : edit_box { key = \"lts\"; label = \"Масштаб штриховки:\"; edit_width = 5; fixed_width = true; allow_accept = false; } : spacer { } } }"
               " : boxed_column { label = \"Подписи кабелей\";"
               "  : row { : toggle { key = \"lab\"; label = \"Подписывать кабели\"; }"
               "          : toggle { key = \"grp\"; label = \"Группировать одинаковые (позиции через запятую)\"; }"
               "          : edit_box { key = \"lth\"; label = \"Высота текста:\"; edit_width = 6; fixed_width = true; allow_accept = false; } : spacer { } }"
               "  : row { : edit_box { key = \"tpl\"; label = \"Шаблон:\"; edit_width = 40; fixed_width = true; allow_accept = false; } : spacer { } }"
               "  : text { label = \"Поля: {ПОЗ} {НОМ} {ТИП} {ОБОЛ} {ПРОВ} {СЕЧ} {D} {ЭТАЖ} {ОТКУДА} {КУДА} {ПОМ1} {ПОМ2} {ДЛИНА}\"; } }"
               " : text { key = \"info\"; width = 100; }"
               " : row { : button { key = \"accept\"; label = \"Построить схему\"; is_default = true; width = 22; }"
               "         : button { key = \"b_def\"; label = \"По умолчанию\"; width = 16; }"
               "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }"))
        res 2)
  (while (= res 2)
    (setq id (load_dialog fn))
    (if (not (new_dialog "bk_sch" id))
      (setq res 0)
      (progn
        (start_list "fmt") (foreach f *sc:formats* (add_list (strcat (car f) "  " (itoa (cadr f)) "x" (itoa (caddr f))))) (end_list)
        (start_list "orient") (foreach x '("альбомная (горизонтально)" "книжная (вертикально)") (add_list x)) (end_list)
        (start_list "coll") (foreach x '("не сворачивать" "одинаковые подряд в шлейфе (xN)" "одинаковые в шлейфе на этаже (xN)" "одинаковые на этаже из разных шлейфов (xN)") (add_list x)) (end_list)
        (start_list "style") (foreach x *sc:stys* (add_list x)) (end_list)
        (foreach k *sc:keys* (if (/= k "style") (bk:st k (sc:g k))))
        (bk:st "style" (itoa (cond ((vl-position (sc:g "style") *sc:stys*)) ((vl-position (getvar "TEXTSTYLE") *sc:stys*)) (0))))
        (bk:st "info" "Схема строится в отдельный файл; если он открыт в AutoCAD - правится напрямую.")
        (bk:st "selinfo" (strcat "Блоков: " (if (sc:blks) (strcat (itoa (length (sc:blks))) " имён выбрано") "все подключённые к кабелям")
                                 ";  кабелей: " (itoa (length (vl-remove-if-not 'cadr (sc:cab-state)))) " из " (itoa (length (sc:cab-state)))))
        (action_tile "b_blk" "(sc:read-tiles) (done_dialog 4)")
        (action_tile "b_cab" "(sc:read-tiles) (done_dialog 5)")
        (action_tile "b_flr" "(sc:read-tiles) (done_dialog 6)")
        (action_tile "b_colr" "(sc:read-tiles) (done_dialog 7)")
        (action_tile "b_vert" "(sc:read-tiles) (done_dialog 8)")
        (action_tile "b_file" "(sc:read-tiles) (done_dialog 3)")
        (action_tile "b_def" "(setq *sc:p* *sc:def*) (foreach k *sc:keys* (if (/= k \"style\") (bk:st k (sc:g k)))) (bk:st \"file\" (strcat (getvar \"DWGPREFIX\") \"схема.dwg\"))")
        (action_tile "accept" "(sc:read-tiles) (if (= (bk:trim (sc:g \"file\")) \"\") (bk:st \"info\" \"Укажите файл схемы.\") (done_dialog 1))")
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (cond
          ((= res 3)
           (setq fn2 (getfiled "Файл схемы" (sc:g "file") "dwg" 1))
           (if fn2 (sc:set "file" fn2))
           (setq res 2))
          ((= res 4) (sc:blk-dialog) (setq res 2))
          ((= res 5) (sc:cab-dialog) (setq res 2))
          ((= res 6) (sc:flr-dialog) (setq res 2))
          ((= res 7) (sc:col-dialog) (setq res 2))
          ((= res 8) (sc:v-dialog) (setq res 2))))))
  (vl-file-delete fn)
  (if (= res 1) (progn (vlax-ldata-put "BK" "sch" *sc:p*) T)))

;;; ---------- выбор блоков ----------
;; все блоки с атрибутами в Модели: ((имя число подключено_к_кабелям) ...)
(defun sc:blk-inv (/ l nm p ends)
  (foreach m (bk:cable-map) (foreach k '("beg" "end") (if (/= (bk:f (cadr m) k) "") (setq ends (cons (bk:f (cadr m) k) ends)))))
  (foreach e (bk:ss->l (ssget "_X" '((0 . "INSERT") (66 . 1) (410 . "Model"))))
    (setq nm (sc:bname (cdr (assoc 5 (entget e)))))
    (if (setq p (assoc nm l))
      (setq l (subst (list nm (1+ (cadr p)) (or (caddr p) (member (cdr (assoc 5 (entget e))) ends))) p l))
      (setq l (cons (list nm 1 (if (member (cdr (assoc 5 (entget e))) ends) T nil)) l))))
  l)

(defun sc:blk-fill (/ m l)
  (setq m (bk:up (if (= *sc:bf* "") "*" *sc:bf*))
        l (vl-remove-if-not '(lambda (x) (wcmatch (bk:up (car x)) m)) *sc:bi*))
  (setq *sc:bl* (vl-sort l (cond ((= *sc:bsort* 1) '(lambda (a b) (> (cadr a) (cadr b))))
                                 ((= *sc:bsort* 2) '(lambda (a b) (and (caddr a) (not (caddr b)))))
                                 (T '(lambda (a b) (bk:less (car a) (car b)))))))
  (start_list "lst")
  (foreach x *sc:bl* (add_list (strcat (bk:cut (car x) 40) "\t" (itoa (cadr x)) "\t" (if (caddr x) "да" "нет"))))
  (end_list)
  (bk:st "lst" (apply 'strcat (mapcar '(lambda (x / i) (if (member (car x) *sc:bs*) (strcat (itoa (vl-position x *sc:bl*)) " ") "")) *sc:bl*)))
  (bk:st "info" (strcat "Выбрано имён блоков: " (itoa (length *sc:bs*)) " из " (itoa (length *sc:bi*)))))

(defun sc:blk-pick (v / vis)
  (setq vis (mapcar 'car *sc:bl*)
        *sc:bs* (append (vl-remove-if '(lambda (n) (member n vis)) *sc:bs*) (mapcar '(lambda (i) (car (nth i *sc:bl*))) (bk:idxs v))))
  (bk:st "info" (strcat "Выбрано имён блоков: " (itoa (length *sc:bs*)) " из " (itoa (length *sc:bi*)))))

(defun sc:blk-dialog (/ fn id res)
  (setq *sc:bi* (sc:blk-inv) *sc:bf* "*" *sc:bsort* (if *sc:bsort* *sc:bsort* 0)
        *sc:bs* (cond ((sc:blks)) (T (mapcar 'car (vl-remove-if-not 'caddr *sc:bi*)))))
  (setq fn (bk:write-dcl "blok_schema_blk.dcl"
             '("bk_scb : dialog { label = \"Блоки на схеме\";"
               " : row { : edit_box { key = \"flt\"; label = \"Фильтр (маска * ? ,):\"; edit_width = 20; fixed_width = true; allow_accept = false; }"
               "         : popup_list { key = \"srt\"; label = \"Сортировка:\"; width = 36; fixed_width = true; } : spacer { } }"
               " : list_box { key = \"hdr\"; height = 2; width = 70; tabs = \"44 54\"; is_tab_stop = false; }"
               " : list_box { key = \"lst\"; multiple_select = true; height = 18; width = 70; tabs = \"44 54\"; }"
               " : text { key = \"info\"; width = 70; }"
               " : text { label = \"Выбранные блоки показываются на схеме, даже если к ним нет кабелей.\"; }"
               " : row { : button { key = \"b_all\"; label = \"Выделить видимые\"; } : button { key = \"b_none\"; label = \"Снять все\"; }"
               "         : button { key = \"b_con\"; label = \"Только подключённые\"; } }"
               " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 14; }"
               "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }"))
        id (load_dialog fn))
  (if (new_dialog "bk_scb" id)
    (progn
      (start_list "hdr") (add_list "Имя блока\tКол-во\tС кабелями") (end_list)
      (start_list "srt") (foreach x '("по имени" "по количеству" "сначала подключённые") (add_list x)) (end_list)
      (bk:st "srt" (itoa *sc:bsort*)) (bk:st "flt" *sc:bf*)
      (sc:blk-fill)
      (action_tile "flt" "(setq *sc:bf* $value) (sc:blk-fill)")
      (action_tile "srt" "(setq *sc:bsort* (atoi $value)) (sc:blk-fill)")
      (action_tile "lst" "(sc:blk-pick $value)")
      (action_tile "b_all" "(foreach x *sc:bl* (if (not (member (car x) *sc:bs*)) (setq *sc:bs* (cons (car x) *sc:bs*)))) (sc:blk-fill)")
      (action_tile "b_none" "(setq *sc:bs* nil) (sc:blk-fill)")
      (action_tile "b_con" "(setq *sc:bs* (mapcar 'car (vl-remove-if-not 'caddr *sc:bi*))) (sc:blk-fill)")
      (action_tile "accept" "(done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)))
  (vl-file-delete fn)
  (if (= res 1) (sc:set "blks" *sc:bs*)))

;;; ---------- кабели и цвета ----------
;; состояние: ((ПОЗИЦИЯ вкл цвет номенклатура число) ...) - все шлейфы чертежа
(defun sc:cab-state (/ inv st i p)
  (foreach m (bk:cable-map)
    (if (setq p (assoc (bk:f (cadr m) "pos") inv)) (setq inv (subst (list (car p) (cadr p) (1+ (caddr p))) p inv))
      (setq inv (cons (list (bk:f (cadr m) "pos") (bk:f (cadr m) "marka") 1) inv))))
  (setq inv (vl-sort inv '(lambda (a b) (bk:less (car a) (car b)))) i 0)
  (foreach x inv
    (setq p (assoc (car x) (sc:cabs))
          st (append st (list (list (car x) (if p (if (member (cadr p) '(1 T)) T nil) T) (if p (caddr p) (nth (rem i (length *sc:colors*)) *sc:colors*))
                                    (cadr x) (caddr x))))
          i (1+ i)))
  st)

(defun sc:cab-fill (/ m l)
  (setq m (bk:up (if (= *sc:cf* "") "*" *sc:cf*))
        l (vl-remove-if-not '(lambda (x) (or (wcmatch (bk:up (car x)) m) (wcmatch (bk:up (nth 3 x)) m))) *sc:cst*))
  (setq *sc:cl* (vl-sort l (cond ((= *sc:csort* 1) '(lambda (a b) (bk:less (nth 3 a) (nth 3 b))))
                                 ((= *sc:csort* 2) '(lambda (a b) (> (nth 4 a) (nth 4 b))))
                                 ((= *sc:csort* 3) '(lambda (a b) (< (caddr a) (caddr b))))
                                 (T '(lambda (a b) (bk:less (car a) (car b)))))))
  (start_list "lst")
  (foreach x *sc:cl* (add_list (strcat (if (cadr x) "да" "-") "\t" (bk:cut (car x) 12) "\t" (bk:cut (nth 3 x) 40) "\t"
                                       (itoa (nth 4 x)) "\t" (itoa (caddr x)))))
  (end_list)
  (bk:st "info" (strcat "На схеме: " (itoa (length (vl-remove-if-not 'cadr *sc:cst*))) " из " (itoa (length *sc:cst*))
                        " шлейфов (кабели с одной ПОЗИЦИЕЙ). Цвет - номер цвета AutoCAD.")))

(defun sc:cab-set (v f / sel)
  (setq sel (mapcar '(lambda (i) (car (nth i *sc:cl*))) (bk:idxs v)))
  (setq *sc:cst* (mapcar '(lambda (x) (if (member (car x) sel) (apply f (list x)) x)) *sc:cst*))
  (sc:cab-fill) (bk:st "lst" v))

(defun sc:cab-dialog (/ fn id res sel c)
  (setq *sc:cst* (sc:cab-state) *sc:cf* "*" *sc:csort* (if *sc:csort* *sc:csort* 0) res 2 sel "")
  (setq fn (bk:write-dcl "blok_schema_cab.dcl"
             '("bk_scc : dialog { label = \"Кабели на схеме и их цвета (линии - штриховые)\";"
               " : row { : edit_box { key = \"flt\"; label = \"Фильтр (ПОЗИЦИЯ или номенклатура, * ? ,):\"; edit_width = 20; fixed_width = true; allow_accept = false; }"
               "         : popup_list { key = \"srt\"; label = \"Сортировка:\"; width = 32; fixed_width = true; } : spacer { } }"
               " : list_box { key = \"hdr\"; height = 2; width = 90; tabs = \"6 20 64 72\"; is_tab_stop = false; }"
               " : list_box { key = \"lst\"; multiple_select = true; height = 18; width = 90; tabs = \"6 20 64 72\"; }"
               " : text { key = \"info\"; width = 90; }"
               " : row { : button { key = \"b_on\"; label = \"Показывать\"; } : button { key = \"b_off\"; label = \"Не показывать\"; }"
               "         : button { key = \"b_col\"; label = \"Цвет...\"; } : button { key = \"b_auto\"; label = \"Цвета по порядку\"; }"
               "         : button { key = \"b_all\"; label = \"Выделить видимые\"; } }"
               " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 14; }"
               "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }")))
  (while (= res 2)
    (setq id (load_dialog fn))
    (if (not (new_dialog "bk_scc" id)) (setq res 0)
      (progn
        (start_list "hdr") (add_list "Вкл\tПОЗИЦИЯ\tНоменклатура\tКабелей\tЦвет") (end_list)
        (start_list "srt") (foreach x '("по ПОЗИЦИИ" "по номенклатуре" "по количеству" "по цвету") (add_list x)) (end_list)
        (bk:st "srt" (itoa *sc:csort*)) (bk:st "flt" *sc:cf*)
        (sc:cab-fill) (bk:st "lst" sel)
        (action_tile "flt" "(setq *sc:cf* $value) (sc:cab-fill)")
        (action_tile "srt" "(setq *sc:csort* (atoi $value)) (sc:cab-fill)")
        (action_tile "lst" "(setq sel $value)")
        (action_tile "b_on" "(sc:cab-set (get_tile \"lst\") '(lambda (x) (bk:replace-nth 1 T x)))")
        (action_tile "b_off" "(sc:cab-set (get_tile \"lst\") '(lambda (x) (bk:replace-nth 1 nil x)))")
        (action_tile "b_auto" "(setq c -1) (setq *sc:cst* (mapcar '(lambda (x) (bk:replace-nth 2 (nth (rem (setq c (1+ c)) (length *sc:colors*)) *sc:colors*) x)) *sc:cst*)) (sc:cab-fill)")
        (action_tile "b_all" "(setq sel \"\") (repeat (length *sc:cl*) (setq sel (strcat sel (itoa (length (bk:idxs sel))) \" \"))) (bk:st \"lst\" sel)")
        (action_tile "b_col" "(setq sel (get_tile \"lst\")) (if (bk:idxs sel) (done_dialog 3) (bk:st \"info\" \"Выделите кабели в списке.\"))")
        (action_tile "accept" "(done_dialog 1)")
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (if (= res 3)
          (progn
            (if (setq c (acad_colordlg (caddr (nth (car (bk:idxs sel)) *sc:cl*)) nil))
              (setq *sc:cst* (mapcar '(lambda (x) (if (member (car x) (mapcar '(lambda (i) (car (nth i *sc:cl*))) (bk:idxs sel)))
                                                    (bk:replace-nth 2 c x) x)) *sc:cst*)))
            (setq res 2))))))
  (vl-file-delete fn)
  (if (= res 1) (sc:set "cabs" (mapcar '(lambda (x) (list (car x) (if (cadr x) 1 0) (caddr x))) *sc:cst*))))

;;; ---------- данные: приборы, шлейфы, переходы по стоякам ----------
(defun sc:floor-top (s / i) (if (setq i (vl-string-search "-" s)) (substr s (+ i 2)) s))
;; этаж прибора - только атрибут ЭТАЖ блока; нет - "" (рисуется в отдельной полосе "этаж не указан")
(defun sc:dev-floor (h fl) (bk:attr (bk:hent h) "ЭТАЖ"))
(defun sc:bname (h / o r)
  (setq o (vlax-ename->vla-object (bk:hent h)) r (vl-catch-all-apply 'vla-get-EffectiveName (list o)))
  (if (vl-catch-all-error-p r) (vla-get-Name o) r))

;; кабель -> (id позиция начало конец этаж_начала этаж_конца переходы)
;; переходы: ((стояк этаж_после) ...) по участкам "стояк"
;;; ---------- вертикали схемы ----------
;; X точки вставки блока на плане
(defun sc:bx (h / e) (if (setq e (bk:hent h)) (car (cdr (assoc 10 (entget e)))) 0.0))
(defun sc:is-riser (h) (and *sc:rcol* (assoc h *sc:rcol*)))
;; вертикаль каждого блока: заданная вручную ("vcol"), иначе авто - блоки с близким X (допуск "vtol");
;; блоки одного стояка - всегда в одной вертикали
(defun sc:vcols (hs / man tol out auto cur x0 n r k nm)
  (setq man (cdr (assoc "vcol" *sc:p*)) tol (max 1.0 (sc:gn "vtol")) n 0)
  ;; авто-кластеры по X; имена В1, В2 ... не совпадают с уже заданными (заданные не меняются)
  (foreach h (vl-sort (bk:uniq hs) '(lambda (a b) (< (sc:bx a) (sc:bx b))))
    (if (or (null x0) (> (- (sc:bx h) x0) tol))
      (progn (setq n (1+ n) x0 (sc:bx h))
             (while (member (strcat "В" (itoa n)) (mapcar 'cdr man)) (setq n (1+ n)))))
    (setq auto (cons (cons h (strcat "В" (itoa n))) auto)))
  (foreach h (bk:uniq hs)
    (setq out (cons (cons h (cond ((cdr (assoc h man)))
                                  ;; авто-кластер, в котором есть блок с ручной вертикалью - взять её
                                  ((vl-some '(lambda (x) (if (and (= (cdr x) (cdr (assoc h auto))) (assoc (car x) man)) (cdr (assoc (car x) man)))) auto))
                                  ((cdr (assoc h auto)))))
                    out)))
  ;; стояки: все блоки цепочки - в вертикали первого блока
  (foreach r (bk:uniq (mapcar 'cdr *sc:rcol*))
    (setq k (vl-some '(lambda (h) (cdr (assoc h out))) (sc:rcol-blocks r)))
    (if k (foreach h (sc:rcol-blocks r) (setq out (cons (cons h k) (vl-remove (assoc h out) out))))))
  out)
;; порядок вертикалей - по среднему X их блоков
(defun sc:col-x (c / l)
  (setq l (mapcar '(lambda (x) (sc:bx (car x))) (vl-remove-if-not '(lambda (x) (= (cdr x) c)) *sc:vc*)))
  (if l (/ (apply '+ l) (length l)) 0.0))

;; блоки схемы: концы выбранных кабелей и блоки-стояки
(defun sc:schema-blocks (/ cs l)
  (setq *sc:cst* (sc:cab-state) *sc:bsel* (sc:blks))
  (foreach c (mapcar 'bk:cable-info (bk:cable-map))
    (if (cadr (assoc (bk:f (cadr c) "pos") *sc:cst*)) (setq cs (cons c cs))))
  (sc:risers-init cs)
  (foreach c cs
    (foreach h (list (bk:f (cadr c) "beg") (bk:f (cadr c) "end"))
      (if (and (/= h "") *sc:bsel* (not (sc:blk-ok h))) (setq h (sc:sub-end h)))
      (if (/= h "") (setq l (cons h l)))))
  ;; выбранные блоки ("Блоки на схеме...") - и без кабелей
  (if *sc:bsel*
    (foreach e (bk:ss->l (ssget "_X" '((0 . "INSERT") (66 . 1) (410 . "Model"))))
      (if (member (sc:bname (cdr (assoc 5 (entget e)))) *sc:bsel*) (setq l (cons (cdr (assoc 5 (entget e))) l)))))
  (bk:uniq (append l (mapcar 'car *sc:rcol*))))

;; порядок вертикалей: заданный ("vord"), остальные - по X на плане
(defun sc:col-order (cols / ord)
  (setq ord (cdr (assoc "vord" *sc:p*)))
  (vl-sort cols '(lambda (a b / ia ib)
                   (setq ia (vl-position a ord) ib (vl-position b ord))
                   (cond ((and ia ib) (< ia ib)) (ia T) (ib nil) (T (< (sc:col-x a) (sc:col-x b)))))))
;; расстояние после вертикали, мм ("vgap"), по умолчанию - половина шага приборов
(defun sc:col-gap (c) (cond ((cdr (assoc c (cdr (assoc "vgap" *sc:p*))))) ((* 0.5 (sc:gn "dx")))))

(defun sc:v-cols () (sc:col-order (bk:uniq (mapcar 'cdr *sc:vl*))))
;; таблица: столбцы - вертикали, строки - этажи (сверху вниз), в ячейках - ПОЗИЦИИ блоков
(defun sc:v-fill (/ cols fls row nb)
  (setq *sc:vc* *sc:vl* cols (sc:v-cols) *sc:vcl* cols)
  (setq fls (sc:order-floors (bk:uniq (mapcar '(lambda (x) (sc:dev-floor (car x) "")) *sc:vl*))))
  (start_list "ghdr")
  (add_list (strcat "Этаж" (apply 'strcat (mapcar '(lambda (c) (strcat "\t" (bk:cut (strcat c "  +" (rtos (sc:col-gap c) 2 0)) 15))) cols))))
  (end_list)
  (start_list "grid")
  (foreach f fls
    (setq row (bk:cut (sc:flabel f) 15))
    (foreach c cols
      (setq nb (vl-remove-if-not '(lambda (x) (and (= (cdr x) c) (= (sc:dev-floor (car x) "") f))) *sc:vl*))
      (setq row (strcat row "\t" (bk:cut (bk:pos-ranges (mapcar '(lambda (x) (strcat (if (sc:is-riser (car x)) "*" "") (bk:dev-pos (car x)))) nb)) 15))))
    (add_list row))
  (end_list)
  (start_list "vc") (foreach c cols (add_list c)) (end_list)
  (start_list "to") (add_list "<новая вертикаль>") (foreach c cols (add_list c)) (end_list)
  (if (>= *sc:vi* (length cols)) (setq *sc:vi* (max 0 (1- (length cols)))))
  (bk:st "vc" (itoa *sc:vi*))
  (sc:v-blk))
;; блоки выбранной вертикали
(defun sc:v-blk (/ c m srt)
  (setq c (nth *sc:vi* *sc:vcl*)
        m (bk:up (if (or (null *sc:vflt*) (= *sc:vflt* "")) "*" *sc:vflt*)) srt (if *sc:vsrt* *sc:vsrt* 0))
  ;; все блоки схемы или только выбранной вертикали; фильтр по ПОЗИЦИИ / имени блока
  (setq *sc:vb* (vl-remove-if-not
                  '(lambda (x) (and (or (= *sc:vall* "1") (= (cdr x) c))
                                    (or (wcmatch (bk:up (bk:dev-pos (car x))) m) (wcmatch (bk:up (sc:bname (car x))) m))))
                  *sc:vl*))
  (setq *sc:vb* (vl-sort *sc:vb*
                  (cond ((= srt 1) '(lambda (a b) (bk:less (bk:dev-pos (car a)) (bk:dev-pos (car b)))))
                        ((= srt 2) '(lambda (a b) (if (= (sc:bname (car a)) (sc:bname (car b))) (bk:less (bk:dev-pos (car a)) (bk:dev-pos (car b)))
                                                      (< (bk:up (sc:bname (car a))) (bk:up (sc:bname (car b)))))))
                        ((= srt 3) '(lambda (a b) (bk:less (cdr a) (cdr b))))
                        (T '(lambda (a b) (sc:fl< (sc:dev-floor (car b) "") (sc:dev-floor (car a) "")))))))
  (start_list "blk")
  (foreach x *sc:vb*
    (add_list (strcat (bk:cut (bk:dev-pos (car x)) 12) "\t" (bk:cut (sc:dev-floor (car x) "") 10) "\t" (bk:cut (cdr x) 8) "\t"
                      (bk:cut (sc:bname (car x)) 34) (if (sc:is-riser (car x)) " (стояк)" ""))))
  (end_list)
  (bk:st "gap" (rtos (sc:col-gap c) 2 0)))

;; по типам блоков: каждый тип - своя вертикаль; имя - уже существующей вертикали, где больше всего
;; блоков этого типа (если она ещё не занята другим типом), иначе новое В<n>
(defun sc:v-bytype (/ types used out nm cnt best n i)
  (foreach x *sc:vl* (if (not (member (sc:bname (car x)) types)) (setq types (append types (list (sc:bname (car x)))))))
  (foreach ty types
    (setq cnt nil best nil)
    (foreach x *sc:vl* (if (= (sc:bname (car x)) ty)
                         (setq cnt (if (assoc (cdr x) cnt) (subst (cons (cdr x) (1+ (cdr (assoc (cdr x) cnt)))) (assoc (cdr x) cnt) cnt) (cons (cons (cdr x) 1) cnt)))))
    (foreach c (vl-sort cnt '(lambda (a b) (> (cdr a) (cdr b)))) (if (and (null best) (not (member (car c) used))) (setq best (car c))))
    (if (null best)
      (progn (setq i 1) (while (or (member (strcat "В" (itoa i)) used) (member (strcat "В" (itoa i)) (mapcar 'cdr *sc:vl*))) (setq i (1+ i)))
             (setq best (strcat "В" (itoa i)))))
    (setq used (cons best used) out (cons (cons ty best) out)))
  (setq *sc:vl* (mapcar '(lambda (x) (cons (car x) (cdr (assoc (sc:bname (car x)) out)))) *sc:vl*) *sc:vi* 0))

;; сдвиг вертикали в порядке
(defun sc:v-move (d / l i a)
  (setq l *sc:vcl* i *sc:vi*)
  (if (and (>= (+ i d) 0) (< (+ i d) (length l)))
    (progn (setq a (nth i l) l (bk:replace-nth i (nth (+ i d) l) l) l (bk:replace-nth (+ i d) a l))
           (sc:set "vord" l) (setq *sc:vi* (+ i d)) (sc:v-fill))))
;; перенести выделенные блоки в вертикаль (0 - новая)
(defun sc:v-moveblk (sel to / nm)
  (setq nm (if (= to 0) (strcat "В" (itoa (1+ (length *sc:vcl*)))) (nth (1- to) *sc:vcl*)))
  (while (and (= to 0) (member nm *sc:vcl*)) (setq nm (strcat nm "'")))
  (foreach i sel (setq *sc:vl* (subst (cons (car (nth i *sc:vb*)) nm) (nth i *sc:vb*) *sc:vl*)))
  (if (= to 0) (sc:set "vord" (append *sc:vcl* (list nm))))
  (sc:v-fill))

;; окно вертикалей: столбцы - вертикали
(defun sc:v-dialog (/ hs)
  (if (setq hs (sc:schema-blocks)) (sc:v-dialog2 hs)
    (alert "Нет блоков для схемы: выберите их в «Блоки на схеме...» (или проложите кабели).")))
(defun sc:v-dialog2 (hs / fn id res tabs n old nm)
  (setq *sc:vc* nil *sc:vl* (sc:vcols hs) *sc:vi* 0
        old (list (assoc "vord" *sc:p*) (assoc "vgap" *sc:p*)))
  (setq tabs "16" n 16)
  (repeat 30 (setq n (+ n 16) tabs (strcat tabs " " (itoa n))))
  (setq fn (bk:write-dcl "blok_schema_v.dcl"
    (list "sc_v : dialog { label = \"Вертикали схемы (столбцы - вертикали, строки - этажи; * - стояк/перенос)\";"
      (strcat " : list_box { key = \"ghdr\"; height = 2; width = 170; tabs = \"" tabs "\"; is_tab_stop = false; }")
      (strcat " : list_box { key = \"grid\"; height = 14; width = 170; tabs = \"" tabs "\"; }")
      " : row { : boxed_column { label = \"Вертикаль\";"
      "   : row { : popup_list { key = \"vc\"; width = 24; }"
      "           : button { key = \"b_l\"; label = \"<< Левее\"; } : button { key = \"b_r\"; label = \"Правее >>\"; } }"
      "   : row { : edit_box { key = \"gap\"; label = \"Расстояние после неё, мм:\"; edit_width = 6; allow_accept = false; }"
      "           : button { key = \"b_gap\"; label = \"Задать\"; } } }"
      "  : boxed_column { label = \"Блоки выбранной вертикали (или все)\";"
      "   : row { : toggle { key = \"vall\"; label = \"Все блоки\"; }"
      "           : edit_box { key = \"vflt\"; label = \"Фильтр (ПОЗИЦИЯ / имя блока):\"; edit_width = 14; allow_accept = false; }"
      "           : popup_list { key = \"vsrt\"; label = \"Сортировка:\"; width = 30; } }"
      "   : list_box { key = \"bhd\"; height = 2; width = 80; tabs = \"14 26 36\"; is_tab_stop = false; }"
      "   : list_box { key = \"blk\"; multiple_select = true; height = 8; width = 80; tabs = \"14 26 36\"; }"
      "   : row { : popup_list { key = \"to\"; label = \"Перенести в:\"; width = 34; }"
      "           : button { key = \"b_mv\"; label = \"Перенести выделенные\"; } } } }"
      " : boxed_row { label = \"Указать на плане\";"
      "   : button { key = \"b_pick\"; label = \"Собрать в одну вертикаль <\"; }"
      "   : button { key = \"b_add\"; label = \"Добавить к вертикали <\"; }"
      "   : button { key = \"b_sep\"; label = \"Отделить в новую <\"; }"
      "   : button { key = \"b_one\"; label = \"Всё на одну вертикаль\"; }"
      "   : button { key = \"b_type\"; label = \"По типам блоков\"; } }"
      " : text { label = \"Собрать: рамкой/щелчками выбрать блоки на плане - они станут одной новой вертикалью.  Добавить: выбрать блоки, затем щёлкнуть блок нужной вертикали.\"; }"
      " : row { : edit_box { key = \"vtol\"; label = \"Авто: допуск по X на плане:\"; edit_width = 8; allow_accept = false; }"
      "         : button { key = \"b_auto\"; label = \"Авто (сбросить ручные)\"; }"
      "         : toggle { key = \"vris\"; label = \"Показывать блоки стояков\"; }"
      "         : toggle { key = \"rpath\"; label = \"Прокладка с учетом стояков\"; } }"
      " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 14; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }")))
  (setq res 2)
  (while (= res 2)
  (setq id (load_dialog fn))
  (if (new_dialog "sc_v" id)
    (progn
      (bk:st "vtol" (sc:g "vtol"))
      (bk:st "vris" (if (= (sc:g "vris") "0") "0" "1"))
      (action_tile "vris" "(sc:set \"vris\" $value)")
      (bk:st "rpath" (sc:g "rpath"))
      (action_tile "rpath" "(sc:set \"rpath\" $value)")
      (if (not *sc:vall*) (setq *sc:vall* "0" *sc:vflt* "*" *sc:vsrt* 0))
      (bk:st "vall" *sc:vall*) (bk:st "vflt" *sc:vflt*)
      (start_list "vsrt") (foreach x '("по этажу" "по ПОЗИЦИИ" "по имени блока" "по вертикали") (add_list x)) (end_list)
      (bk:st "vsrt" (itoa *sc:vsrt*))
      (start_list "bhd") (add_list "ПОЗИЦИЯ	Этаж	Вертикаль	Блок") (end_list)
      (action_tile "vall" "(setq *sc:vall* $value) (sc:v-blk)")
      (action_tile "vflt" "(setq *sc:vflt* $value) (sc:v-blk)")
      (action_tile "vsrt" "(setq *sc:vsrt* (atoi $value)) (sc:v-blk)")
      (sc:v-fill)
      (action_tile "vc" "(setq *sc:vi* (atoi $value)) (sc:v-blk)")
      (action_tile "b_l" "(sc:v-move -1)")
      (action_tile "b_r" "(sc:v-move 1)")
      (action_tile "b_gap" "(sc:set \"vgap\" (cons (cons (nth *sc:vi* *sc:vcl*) (bk:num (get_tile \"gap\"))) (vl-remove (assoc (nth *sc:vi* *sc:vcl*) (cdr (assoc \"vgap\" *sc:p*))) (cdr (assoc \"vgap\" *sc:p*))))) (sc:v-fill)")
      (action_tile "b_mv" "(if (bk:idxs (get_tile \"blk\")) (sc:v-moveblk (bk:idxs (get_tile \"blk\")) (atoi (get_tile \"to\"))))")
      (action_tile "b_auto" "(sc:set \"vtol\" (get_tile \"vtol\")) (sc:set \"vcol\" nil) (sc:set \"vord\" nil) (setq *sc:vl* (sc:vcols hs) *sc:vi* 0) (sc:v-fill)")
      (action_tile "b_pick" "(setq *sc:vact* \"P\") (done_dialog 2)")
      (action_tile "b_add" "(setq *sc:vact* \"A\") (done_dialog 2)")
      (action_tile "b_sep" "(setq *sc:vact* \"S\") (done_dialog 2)")
      (action_tile "b_type" "(sc:v-bytype) (sc:v-fill)")
      (action_tile "b_one" "(setq nm (nth *sc:vi* *sc:vcl*) *sc:vl* (mapcar '(lambda (x) (cons (car x) nm)) *sc:vl*)) (setq *sc:vi* 0) (sc:v-fill)")
      (action_tile "accept" "(sc:set \"vtol\" (get_tile \"vtol\")) (done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))))
  (unload_dialog id)
  (if (= res 2) (sc:v-onplan *sc:vact*)))
  (vl-file-delete fn)
  (if (= res 1) (sc:set "vcol" *sc:vl*)
    (progn (sc:set "vord" (cdr (car old))) (sc:set "vgap" (cdr (cadr old)))))
  (princ))

;; действия на плане: P - выбранные в новую вертикаль, A - добавить к вертикали блока-образца,
;; S - каждый выбранный в свою новую вертикаль. Учитываются только блоки схемы
(defun sc:v-onplan (act / ss hs e nm i tg)
  (princ (if (= act "S") "\nВыберите блоки, которые нужно отделить: " "\nВыберите блоки (рамкой или щелчками): "))
  (if (setq ss (ssget '((0 . "INSERT"))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq e (cdr (assoc 5 (entget (ssname ss i)))) i (1+ i))
        (if (assoc e *sc:vl*) (setq hs (cons e hs))))
      (cond
        ((null hs) (princ "\nСреди выбранных нет блоков схемы."))
        ((= act "A")
         (if (and (setq e (entsel "\nЩёлкните блок вертикали, к которой добавить: "))
                  (setq tg (cdr (assoc (cdr (assoc 5 (entget (car e)))) *sc:vl*))))
           (foreach h hs (setq *sc:vl* (subst (cons h tg) (assoc h *sc:vl*) *sc:vl*)))
           (princ "\nЭто не блок схемы.")))
        (T
         (foreach h hs
           (setq i 1)
           (while (member (setq nm (strcat "В" (itoa i))) (mapcar 'cdr *sc:vl*)) (setq i (1+ i)))
           (if (or (= act "S") (null tg)) (setq tg nm))
           (setq *sc:vl* (subst (cons h tg) (assoc h *sc:vl*) *sc:vl*))))))
    (princ "\nНичего не выбрано."))
  ;; порядок вертикалей сохраняется; новые встают по X
  (princ))

;; выбранный блок, на котором (в габарите которого) стоит блок h; "" - нет
(defun sc:sub-end (h / e p best bd o mn mx d)
  (if (and (setq e (bk:hent h)) (entget e))
    (progn
      (setq p (cdr (assoc 10 (entget e))))
      (foreach b (bk:ss->l (ssget "_X" '((0 . "INSERT") (410 . "Model"))))
        (if (and (not (eq b e)) (member (sc:bname (cdr (assoc 5 (entget b)))) *sc:bsel*))
          (progn
            (setq o (vlax-ename->vla-object b))
            (vla-GetBoundingBox o 'mn 'mx)
            (setq mn (vlax-safearray->list mn) mx (vlax-safearray->list mx)
                  d (distance (bk:2d p) (bk:2d (cdr (assoc 10 (entget b))))))
            (if (and (<= (car mn) (car p) (car mx)) (<= (cadr mn) (cadr p) (cadr mx)) (or (null bd) (< d bd)))
              (setq bd d best b)))))))
  (if best (cdr (assoc 5 (entget best))) ""))
(defun sc:fix-ends (c / h f)
  (foreach k '(2 3)
    (setq h (nth k c))
    (if (and (/= h "") (not (sc:blk-ok h)))
      (progn (setq h (sc:sub-end h) c (bk:replace-nth k h c))
             (if (and (/= h "") (/= (setq f (sc:dev-floor h "")) "")) (setq c (bk:replace-nth (+ k 2) f c))))))
  c)

;;; ---------- стояки: колонки по блокам-стоякам ----------
;; блоки на концах участков "стояк" одной цепочки = одна вертикаль схемы
(defun sc:rcol-of (h) (cdr (assoc h *sc:rcol*)))
(defun sc:risers-init (cs / ha hb ka kb pts)
  (setq *sc:rcol* nil *sc:pblk* nil)
  (foreach c cs
    (foreach p (nth 2 c)
      (if (= (car p) "PERENOS")
        ;; перенос на др. лист: его блоки на схеме не нужны
        (foreach h (list (bk:block-at (car (caddr p))) (bk:block-at (last (caddr p)))) (if (/= h "") (setq *sc:pblk* (cons h *sc:pblk*)))))
      (if (= (car p) "STOYAK")
        (progn
          (setq pts (caddr p) ha (bk:block-at (car pts)) hb (bk:block-at (last pts)))
          (foreach h (list ha hb) (if (and (/= h "") (not (assoc h *sc:rcol*))) (setq *sc:rcol* (cons (cons h h) *sc:rcol*))))
          (if (and (/= ha "") (/= hb "") (/= (setq ka (sc:rcol-of ha)) (setq kb (sc:rcol-of hb))))
            ;; слить колонки
            (setq *sc:rcol* (mapcar '(lambda (x) (if (= (cdr x) kb) (cons (car x) ka) x)) *sc:rcol*)))))))
  *sc:rcol*)
;; блоки колонки и её подпись (ПОЗИЦИИ блоков сверху вниз через /)
(defun sc:rcol-blocks (k) (mapcar 'car (vl-remove-if-not '(lambda (x) (= (cdr x) k)) *sc:rcol*)))
(defun sc:rcol-label (k / l)
  (setq l (vl-sort (sc:rcol-blocks k) '(lambda (a b) (sc:fl< (sc:dev-floor b "") (sc:dev-floor a "")))))
  (bk:join (bk:uniq (vl-remove "-" (mapcar 'bk:dev-pos l))) "/"))

(defun sc:cable (c / d parts hops pr fb fe hk fl)
  (setq d (cadr c) parts (nth 2 c))
  ;; переход по стояку: (колонка этаж_после); этаж после - ЭТАЖ блока-стояка в конце участка
  (defun hk (pr nxt / ha hb k f)
    (setq ha (bk:block-at (car (caddr pr))) hb (bk:block-at (last (caddr pr)))
          k (cond ((sc:rcol-of hb)) ((sc:rcol-of ha)) (T (strcat "Ст " (bk:stoyak-pos pr))))
          f (if (/= hb "") (sc:dev-floor hb "") ""))
    (if (= f "") (setq f (sc:floor-top (bk:sfl nxt))))
    (list k f))
  (foreach p parts
    (if (= (car p) "STOYAK") (setq pr p)
      (if pr (setq hops (append hops (list (hk pr p))) pr nil))))
  (if pr (setq hops (append hops (list (hk pr pr)))))
  ;; прокладка с учётом стояков: переходы - по всем блокам-стоякам, через которые проходит кабель на плане
  (if (= (sc:g "rpath") "1")
    (progn (setq hops (sc:geo-hops parts))
           (princ (strcat "\n  " (bk:f d "pos") ": стояки " (bk:join (mapcar '(lambda (x) (strcat (sc:rcol-label (car x)) " -> " (cadr x))) hops) "; ")))))
  (setq fb (sc:floor-top (bk:sfl (car parts))) fe (sc:floor-top (bk:sfl (last parts))))
  (list (car c) (bk:f d "pos") (bk:f d "beg") (bk:f d "end")
        (sc:dev-floor (bk:f d "beg") fb) (sc:dev-floor (bk:f d "end") fe)
        hops))

;; переходы по геометрии: блок-стояк засчитывается, если вершина кабельной линии лежит внутри
;; его габарита -> ((колонка этаж) ...) по ходу кабеля; подряд одна колонка сливается (этаж - последний)
(defun sc:rpts-init (/ e b)
  ;; габарит блока-стояка - по печатаемым примитивам (зона действия не учитывается)
  (setq *sc:rpts* nil *bk:pbb* nil *bk:lpl* nil)
  (foreach x *sc:rcol*
    (if (and (setq e (bk:hent (car x))) (setq b (bk:pbox-ins e)))
      (setq *sc:rpts* (cons (list (car x) (car b) (cadr b)) *sc:rpts*)))))
(defun sc:in-box (p b)
  (and (<= (car (cadr b)) (car p) (car (caddr b))) (<= (cadr (cadr b)) (cadr p) (cadr (caddr b)))))
(defun sc:geo-hops (parts / out add)
  (defun add (h / k f lh)
    (setq k (sc:rcol-of h) f (if k (sc:dev-floor h "") ""))
    (if (and k (/= f ""))
      (progn (setq lh (last out))
             (if (and lh (= (car lh) k))
               (setq out (append (reverse (cdr (reverse out))) (list (list k f))))
               (setq out (append out (list (list k f))))))))
  (foreach p parts
    (if (= (car p) "STOYAK")
      ;; участок-стояк: блоки начала и конца (как без флажка)
      (foreach h (list (bk:block-at (car (caddr p))) (bk:block-at (last (caddr p)))) (if (/= h "") (add h)))
      (foreach pt (caddr p)
        (foreach rb *sc:rpts* (if (sc:in-box pt rb) (add (car rb)))))))
  out)

;; промежуточный прибор в вершине кабеля: блок с ПОЗИЦИЕЙ (вершина внутри габарита, ближайший центр),
;; не стояк, не перенос, не начало/конец кабеля
(defun sc:mid-dev (v ends / h)
  (setq h (bk:dev-at-vtx v))
  (if (and h (not (member h ends)) (/= (bk:dev-pos h) "") (not (sc:is-riser h)) (not (member h *sc:pblk*))) h))
;; кабель -> список кусков в формате sc:cable: (id pos начало конец этаж_нач этаж_кон переходы)
(defun sc:hop (pr nxt / ha hb k f)      ; то же, что hk в sc:cable
  (setq ha (bk:block-at (car (caddr pr))) hb (bk:block-at (last (caddr pr)))
        k (cond ((sc:rcol-of hb)) ((sc:rcol-of ha)) (T (strcat "Ст " (bk:stoyak-pos pr))))
        f (if (/= hb "") (sc:dev-floor hb "") ""))
  (if (= f "") (setq f (sc:floor-top (bk:sfl nxt))))
  (list k f))
(defun sc:cable-split (c / base d parts ends cur hops out h pr)
  (setq base (sc:cable c) d (cadr c) parts (nth 2 c)
        ends (vl-remove "" (list (bk:f d "beg") (bk:f d "end"))) cur (nth 2 base))
  (foreach p parts
    (if (= (car p) "STOYAK")
      (setq pr p)
      (progn
       (if pr (setq hops (append hops (list (sc:hop pr p))) pr nil))
       (foreach v (caddr p)
        (if (and (setq h (sc:mid-dev (bk:2d v) ends)) (/= h cur))
          (setq out (append out (list (list (car c) (nth 1 base) cur h
                                            (if (= cur (nth 2 base)) (nth 4 base) (sc:dev-floor cur ""))
                                            (sc:dev-floor h "") hops)))
                cur h hops nil))))))
  (if pr (setq hops (append hops (list (sc:hop pr pr)))))
  (if (null out)
    (list base)
    (append out (list (list (car c) (nth 1 base) cur (nth 3 base) (sc:dev-floor cur "") (nth 5 base) hops)))))

;; порядок приборов шлейфа: обход от начала (узел, входящий в несколько шлейфов, или конец цепочки)
(defun sc:chain (cabs shared / adj a b start order stack n nb)
  (foreach c cabs
    (setq a (nth 2 c) b (nth 3 c))
    (if (and (/= a "") (/= b ""))
      (progn (setq adj (sc:adj-add (sc:adj-add adj a b) b a)))
      (foreach x (list a b) (if (and (/= x "") (not (assoc x adj))) (setq adj (cons (list x) adj))))))
  (setq start (cond ((vl-some '(lambda (x) (if (member (car x) shared) (car x))) (reverse adj)))
                    ((vl-some '(lambda (x) (if (= (length (cdr x)) 1) (car x))) (reverse adj)))
                    ((car (car adj)))))
  (while start
    (setq stack (list start))
    (while stack
      (setq n (car stack) stack (cdr stack))
      (if (not (member n order))
        (progn (setq order (append order (list n)))
               (foreach nb (reverse (cdr (assoc n adj))) (if (not (member nb order)) (setq stack (cons nb stack)))))))
    (setq start (vl-some '(lambda (x) (if (not (member (car x) order)) (car x))) (reverse adj))))
  order)
(defun sc:adj-add (adj a b / p)
  (if (setq p (assoc a adj)) (if (member b (cdr p)) adj (subst (append p (list b)) p adj)) (cons (list a b) adj)))

;;; ---------- примитивы схемы (в мм, затем масштабируются) ----------
;; (L слой точки) (T слой точка высота текст выравн) (M слой точка высота текст) (B слой точка масштаб хэндл_источника)
;; группа цвета кабеля: префикс ПОЗИЦИИ (буквы до цифр: k, km) + марка
(defun sc:pfx (pos / i) (setq i 1) (while (and (<= i (strlen pos)) (not (wcmatch (substr pos i 1) "#"))) (setq i (1+ i))) (substr pos 1 (1- i)))
(defun sc:pfx-of (k) (substr k 1 (vl-string-search " | " k)))
(defun sc:ckey (d) (strcat " | " (bk:f d "marka")))  ; цвет - по типу (марке) кабеля
(defun sc:loop-marka (l) (sc:ckey (bk:get (car (bk:segs (car (cadr l)))))))
;; цвет группы: заданный пользователем ("mcol"), иначе по палитре по порядку групп
(defun sc:mcol (m / p i)
  (cond ((setq p (assoc m (cdr (assoc "mcol" *sc:p*)))) (cdr p))
        (T (setq i (cond ((vl-position m *sc:markas*)) (0))) (nth (rem i (length *sc:colors*)) *sc:colors*))))
;; все группы цвета в чертеже
(defun sc:all-ckeys (/ l k)
  (foreach m (bk:cable-map) (if (not (member (setq k (sc:ckey (cadr m))) l)) (setq l (cons k l))))
  (vl-sort l 'bk:less))

(defun sc:col-fill (sel)
  (start_list "lst")
  (foreach k *sc:ck* (add_list (strcat k "\t" (itoa (sc:mcol k)) (if (assoc k *sc:mc*) "" "  (авто)"))))
  (end_list) (bk:st "lst" sel))
;; окно цветов: группа = префикс позиции + марка
(defun sc:col-dialog (/ fn id res c i old)
  (setq *sc:ck* (sc:all-ckeys) *sc:markas* *sc:ck* old (cdr (assoc "mcol" *sc:p*)) *sc:mc* old)
  (setq fn (bk:write-dcl "blok_schema_col.dcl"
    '("sc_col : dialog { label = \"Цвета кабелей на схеме (префикс позиции | марка)\";"
      " : list_box { key = \"lst\"; height = 14; width = 90; tabs = \"70\"; }"
      " : row { : button { key = \"b_col\"; label = \"Цвет...\"; } : button { key = \"b_def\"; label = \"Авто\"; } }"
      " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 14; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }")))
  (setq res 2 i "0")
  (while (= res 2)
    (setq id (load_dialog fn))
    (if (new_dialog "sc_col" id)
      (progn
        (setq *sc:p* (if (assoc "mcol" *sc:p*) (subst (cons "mcol" *sc:mc*) (assoc "mcol" *sc:p*) *sc:p*) (cons (cons "mcol" *sc:mc*) *sc:p*)))
        (sc:col-fill i)
        (action_tile "lst" "(setq i $value) (if (= $reason 4) (done_dialog 2))")
        (action_tile "b_col" "(setq i (get_tile \"lst\")) (done_dialog 2)")
        (action_tile "b_def" "(setq i (get_tile \"lst\") *sc:mc* (vl-remove (assoc (nth (atoi i) *sc:ck*) *sc:mc*) *sc:mc*)) (sc:set \"mcol\" *sc:mc*) (sc:col-fill i)")
        (action_tile "accept" "(done_dialog 1)")
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (if (and (= res 2) (nth (atoi i) *sc:ck*)
                 (setq c (acad_colordlg (sc:mcol (nth (atoi i) *sc:ck*)) nil)))
          (setq *sc:mc* (cons (cons (nth (atoi i) *sc:ck*) c) (vl-remove (assoc (nth (atoi i) *sc:ck*) *sc:mc*) *sc:mc*)))))
      (setq res 0)))
  (vl-file-delete fn)
  (sc:set "mcol" (if (= res 1) *sc:mc* old))
  (princ))
(defun sc:prim (x) (setq *sc:out* (cons x *sc:out*)))

(defun sc:build (/ rc cols dcol cs cabs loops shared floors fidx risers ridx cnt p hf dx rdx th lth lane ymax x y
                   disp dkey place xr k i a b pts yl pos ids key edges e lbl ni nodes xc loop-i f tpl placed xfree h yl2)
  (setq hf (sc:gn "hf") dx (sc:gn "dx") rdx (sc:gn "rdx") th (sc:gn "th") lth (sc:gn "lth")
        lane (* 1.8 lth) *sc:out* nil *sc:disp* nil)
  ;; кабели по маске
  (setq *sc:cst* (sc:cab-state) *sc:bsel* (sc:blks))
  (setq *sc:diag* (list 0 0 0 0))
  (foreach c (mapcar 'bk:cable-info (bk:cable-map))
    (setq *sc:diag* (bk:replace-nth 0 (1+ (nth 0 *sc:diag*)) *sc:diag*))
    (if (cadr (assoc (bk:f (cadr c) "pos") *sc:cst*)) (setq cs (cons c cs))))
  (setq *sc:diag* (bk:replace-nth 1 (length cs) *sc:diag*))
  (setq *sc:stage* "разбор кабелей")
  (sc:risers-init cs)
  (sc:rpts-init)
  ;; кабель, проходящий через приборы (вершина внутри блока прибора), делится на куски между приборами;
  ;; кабель без промежуточных приборов - как раньше, один кусок от начала до конца
  (bk:bbx-init)
  (setq cabs (apply 'append (mapcar 'sc:cable-split cs)))
  ;; конец кабеля на невыбранном блоке (напр. зона обзора поверх камеры) - выбранный блок в том же месте
  (if *sc:bsel* (setq cabs (mapcar 'sc:fix-ends cabs)))
  ;; кабель показывается, если хотя бы один его конец - выбранный блок; второй конец
  ;; (щит, коммутатор) рисуется тоже, даже если не выбран
  (if *sc:bsel*
    (setq cabs (vl-remove-if-not '(lambda (c) (or (and (/= (nth 2 c) "") (sc:blk-ok (nth 2 c)))
                                                  (and (/= (nth 3 c) "") (sc:blk-ok (nth 3 c)))))
                 cabs)))
  (setq *sc:diag* (bk:replace-nth 2 (length cabs) *sc:diag*))
  ;; шлейфы: кабели с одной ПОЗИЦИЕЙ
  (foreach c cabs
    (if (setq p (assoc (nth 1 c) loops)) (setq loops (subst (append p (list c)) p loops))
      (setq loops (cons (list (nth 1 c) c) loops))))
  (setq loops (vl-sort loops '(lambda (a b) (bk:less (car a) (car b)))))
  ;; цвета - по марке кабеля (одна марка - один цвет)
  (setq *sc:markas* (sc:all-ckeys) *sc:used* nil)
  (foreach l loops (if (not (member (sc:loop-marka l) *sc:used*)) (setq *sc:used* (append *sc:used* (list (sc:loop-marka l))))))
  ;; узлы, входящие в несколько шлейфов (приборы, щиты)
  (foreach l loops
    (foreach h (vl-remove "" (apply 'append (mapcar '(lambda (c) (list (nth 2 c) (nth 3 c))) (cdr l))))
      (if (setq p (assoc h cnt)) (if (not (member (car l) (cdr p))) (setq cnt (subst (append p (list (car l))) p cnt)))
        (setq cnt (cons (list h (car l)) cnt)))))
  (setq shared (mapcar 'car (vl-remove-if-not '(lambda (x) (> (length (cdr x)) 1)) cnt)))
  ;; этажи (сверху вниз) и стояки
  (foreach c cabs
    (foreach f (append (list (nth 4 c) (nth 5 c)) (mapcar 'cadr (nth 6 c)))
      (if (not (member f floors)) (setq floors (cons f floors))))
    (foreach r (mapcar 'car (nth 6 c)) (if (not (member r risers)) (setq risers (cons r risers)))))
  ;; этажи выбранных блоков без кабелей - тоже полосы
  (if *sc:bsel*
    (foreach e (bk:ss->l (ssget "_X" '((0 . "INSERT") (66 . 1) (410 . "Model"))))
      (if (and (member (sc:bname (cdr (assoc 5 (entget e)))) *sc:bsel*) (not (member (cdr (assoc 5 (entget e))) *sc:pblk*)))
        (progn (setq f (sc:dev-floor (cdr (assoc 5 (entget e))) "")) (if (not (member f floors)) (setq floors (cons f floors)))))))
  (foreach f (mapcar 'car (sc:flr)) (if (not (member f floors)) (setq floors (cons f floors))))
  ;; этажи блоков-стояков
  (foreach r risers (foreach h (sc:rcol-blocks r) (if (not (member (setq f (sc:dev-floor h "")) floors)) (setq floors (cons f floors)))))
  (setq floors (sc:order-floors floors) risers (vl-sort risers '(lambda (a b) (bk:less (sc:rcol-label a) (sc:rcol-label b)))))
  (defun fidx (f) (cond ((vl-position f floors)) (0)))
  (defun ybase (f) (- (* (fidx f) hf)))                     ; верх полосы этажа
  (defun ydev (f) (+ (- (ybase f) (* 0.78 hf)) (* 2.0 *sc:pah*)))   ; ряд приборов (выше на 2 высоты ПОЗИЦИИ)
  (defun ylane (f li) (- (ybase f) (* 0.18 hf) (* lane (rem li (max 1 (fix (/ (* 0.45 hf) lane)))))))
  ;; ---- узлы отображения (приборы / свёрнутые группы) без координат ----
  (setq *sc:edges* nil)
  (foreach l loops
    (setq *sc:stage* (strcat "раскладка шлейфа " (car l)))
    (setq nodes (sc:chain (cdr l) shared) *sc:map* nil key nil)
    (foreach h nodes
      (setq f (sc:node-floor h (cdr l)))
      (setq dkey (cond ((or (member h shared) (= (sc:g "coll") "0")) h)
                       ((= (sc:g "coll") "1")
                        (if (and key (= (car key) (sc:bname h)) (= (cadr key) f)) (caddr key) h))
                       ((= (sc:g "coll") "2") (strcat (car l) "|" (sc:bname h) "|" f))
                       (T (strcat "ЭТ|" (sc:bname h) "|" f))))
      (setq key (list (sc:bname h) f dkey))
      (setq *sc:map* (cons (cons h dkey) *sc:map*))
      (if (setq p (assoc dkey *sc:disp*))
        (if (not (member h (nth 5 p))) (setq *sc:disp* (subst (bk:replace-nth 5 (append (nth 5 p) (list h)) p) p *sc:disp*)))
        (setq *sc:disp* (cons (list dkey 0.0 0.0 f h (list h)) *sc:disp*))))
    ;; рёбра шлейфа (рисуются после расстановки): ((a b переходы) цвет ids...)
    (foreach c (cdr l)
      (if (and (/= (nth 2 c) "") (/= (nth 3 c) ""))
        (progn
          (setq a (cdr (assoc (nth 2 c) *sc:map*)) b (cdr (assoc (nth 3 c) *sc:map*)))
          (if (/= a b)
            (progn
              (setq key (list (list a b (nth 6 c)) (sc:loop-marka l)))
              (if (setq p (assoc key *sc:edges*)) (setq *sc:edges* (subst (append p (list (car c))) p *sc:edges*))
                (setq *sc:edges* (append *sc:edges* (list (list key (car c))))))))))))
  ;; блоки-стояки
  (foreach r risers
    (foreach h (sc:rcol-blocks r)
      (if (not (vl-some '(lambda (d) (member h (nth 5 d))) *sc:disp*))
        (setq *sc:disp* (cons (list h 0.0 0.0 (sc:dev-floor h "") h (list h)) *sc:disp*)))))
  ;; выбранные блоки без кабелей
  (if *sc:bsel*
    (progn
      (setq placed (apply 'append (mapcar '(lambda (d) (nth 5 d)) *sc:disp*)))
      (foreach e (bk:ss->l (ssget "_X" '((0 . "INSERT") (66 . 1) (410 . "Model"))))
        (setq h (cdr (assoc 5 (entget e))))
        (if (and (member (sc:bname h) *sc:bsel*) (not (member h placed)) (not (member h *sc:pblk*)))
          (progn
            (setq f (sc:dev-floor h "") dkey (if (= (sc:g "coll") "3") (strcat "ЭТ|" (sc:bname h) "|" f) h))
            (if (setq p (assoc dkey *sc:disp*))
              (setq *sc:disp* (subst (bk:replace-nth 5 (append (nth 5 p) (list h)) p) p *sc:disp*))
              (setq *sc:disp* (cons (list dkey 0.0 0.0 f h (list h)) *sc:disp*)))
            (setq placed (cons h placed)))))))
  (foreach d *sc:disp* (if (not (member (nth 3 d) floors)) (setq floors (append floors (list (nth 3 d))))))
  (setq floors (sc:order-floors floors))
  ;; ---- вертикали: блоки, расположенные на плане примерно друг под другом (или как задано вручную) ----
  (setq *sc:pah* (sc:pos-h))
  (setq *sc:vc* (sc:vcols (apply 'append (mapcar '(lambda (d) (nth 5 d)) *sc:disp*))))
  (defun dcol (d) (cdr (assoc (nth 4 d) *sc:vc*)))
  (setq cols nil)
  (foreach d *sc:disp* (if (not (member (dcol d) cols)) (setq cols (cons (dcol d) cols))))
  (setq cols (sc:col-order cols))
  ;; x: вертикаль шириной в наибольшее число узлов на одном этаже; стояк - первый в вертикали
  (setq xc (+ 40.0 dx) *sc:cx* nil)
  (foreach c cols
    (setq k 1 rc (vl-some '(lambda (d) (and (= (dcol d) c) (sc:is-riser (nth 4 d)))) *sc:disp*))
    (foreach f floors
      ;; в вертикали со стояком приборы - правее линии стояка (место 0 - только блок стояка)
      (setq i (if (and rc (not (vl-some '(lambda (d) (and (= (dcol d) c) (= (nth 3 d) f) (sc:is-riser (nth 4 d)))) *sc:disp*))) 1 0))
      (foreach d (vl-sort (vl-remove-if-not '(lambda (d) (and (= (dcol d) c) (= (nth 3 d) f))) *sc:disp*)
                          '(lambda (a b) (cond ((sc:is-riser (nth 4 a)) T) ((sc:is-riser (nth 4 b)) nil)
                                               (T (< (sc:bx (nth 4 a)) (sc:bx (nth 4 b)))))))
        (setq *sc:disp* (subst (bk:replace-nth 2 (ydev f) (bk:replace-nth 1 (+ xc (* i dx)) d)) d *sc:disp*) i (1+ i)))
      (setq k (max k i)))
    (setq *sc:cx* (cons (cons c xc) *sc:cx*) xc (+ xc (* k dx) (sc:col-gap c))))
  ;; вертикаль стояка = вертикаль его блоков; линии одного цвета - на одной дорожке
  ;; линия по стояку: первый цвет - точно по блоку стояка, другие цвета - рядом, каждый своей линией
  (setq *sc:rcl* nil)
  (foreach e *sc:edges*
    (foreach hp (caddr (car (car e)))
      (setq p (assoc (car hp) *sc:rcl*))
      (if (not (member (cadr (car e)) (cdr p)))
        (setq *sc:rcl* (if p (subst (append p (list (cadr (car e)))) p *sc:rcl*) (cons (list (car hp) (cadr (car e))) *sc:rcl*))))))
  (defun xris (r li / h)
    (setq h (car (sc:rcol-blocks r)))
    (+ (cond ((if h (cdr (assoc (cdr (assoc h *sc:vc*)) *sc:cx*)))) (40.0))
       (* 1.2 lth (cond ((vl-position *sc:ckcur* (cdr (assoc r *sc:rcl*)))) (0)))))
  (setq *sc:lbl* nil)
  (foreach e *sc:edges*
    (setq *sc:col* (sc:mcol (cadr (car e))) *sc:ckcur* (cadr (car e)))
    (sc:draw-edge (car (car e)) (cdr e) (cond ((vl-position (cadr (car e)) *sc:used*)) (0))))
  ;; подписи: по одной на цвет и этаж (позиции объединены)
  (foreach lb *sc:lbl*
    (sc:prim (list "T" "СХ_ПОДПИСИ" (car (cadr lb)) (sc:gn "lth") (sc:label (cddr lb)) (cadr (cadr lb)))))
  (setq *sc:stage* "приборы, этажи, легенда")
  ;; приборы
  (foreach d (if (= (sc:g "vris") "0") (vl-remove-if '(lambda (d) (sc:is-riser (nth 4 d))) *sc:disp*) *sc:disp*)
    (sc:prim (list "B" "СХ_ПРИБОРЫ" (list (nth 1 d) (nth 2 d)) (sc:gn "bscale") (nth 4 d)
                   (if (> (length (nth 5 d)) 1) (bk:pos-ranges (mapcar 'bk:dev-pos (nth 5 d))))
                   (itoa (length (nth 5 d)))))
    (if (> (length (nth 5 d)) 1)
      (sc:prim (list "T" "СХ_ТЕКСТ" (list (+ (nth 1 d) (* 0.3 dx)) (- (nth 2 d) (* 0.5 lth))) lth
                     (strcat "x" (itoa (length (nth 5 d)))) 0))))
  ;; этажи: линии полос и подписи; стояки: подписи
  (setq x (max xc (+ 40.0 dx)))
  (foreach f floors
    (sc:prim (list "P" "СХ_ЭТАЖИ" (list (list 0.0 (ybase f)) (list x (ybase f)))))
    (sc:prim (list "T" "СХ_ТЕКСТ" (list 3.0 (- (ybase f) (* 0.5 hf))) th
                   (sc:flabel f) 0)))
  (sc:prim (list "P" "СХ_ЭТАЖИ" (list (list 0.0 (- (* (length floors) hf))) (list x (- (* (length floors) hf))))))
  ;; легенда цветов кабелей - под схемой
  (if (= (sc:g "leg") "1")
    (progn
      (setq yl2 (- (- (* (length floors) hf)) (* 2.0 th)) i 0)
      (sc:prim (list "T" "СХ_ТЕКСТ" (list 3.0 yl2) th "Условные обозначения:" 0))
      ;; по марке кабеля: цвет, марка, позиции (k1...k4)
      (foreach m *sc:used*
        (setq yl2 (- yl2 (* 1.8 lth)))
        (sc:prim (list "P" "СХ_СВЯЗИ" (list (list 3.0 (+ yl2 (* 0.4 lth))) (list 23.0 (+ yl2 (* 0.4 lth))))
                       (sc:mcol m) "DASHED"))
        (sc:prim (list "T" "СХ_ТЕКСТ" (list 26.0 yl2) lth
                       (strcat (vl-string-left-trim " |" (substr m (+ 4 (strlen (sc:pfx-of m))))) " - " (bk:pos-ranges (mapcar 'car (vl-remove-if-not '(lambda (l) (= (sc:loop-marka l) m)) loops)))) 0)))
      ;; блоки схемы: символ (ПОЗИЦИЯ пустая) и «обозначение - наименование, марка»
      (foreach g (sc:ved-rows)
        (setq yl2 (- yl2 (* 0.6 dx)))
        (sc:prim (list "B" "СХ_ПРИБОРЫ" (list 13.0 yl2) (sc:gn "bscale") (nth 3 g) "" ""))
        (sc:prim (list "T" "СХ_ТЕКСТ" (list 26.0 yl2) lth
                       (strcat (sc:desig (cddddr g)) " - " (nth 0 (car g)) (if (/= (nth 1 (car g)) "") (strcat ", " (nth 1 (car g))) "")) 2)))))
  ;; ведомость потребности оборудования (без кабелей, прокладки, стояков и переносов)
  (sc:vedom (if yl2 (- yl2 (* 3.0 th)) (- (- (* (length floors) hf)) (* 2.0 th))) th lth)
  (list (length cabs) (length loops) (length *sc:disp*) (length floors) (length risers)))

;; стиль текста атрибута ПОЗИЦИЯ первого блока схемы ("" - нет)
(defun sc:pos-style (/ r)
  (foreach x *sc:out*
    (if (and (null r) (= (car x) "B") (bk:hent (nth 4 x)))
      (foreach a (vlax-invoke (vlax-ename->vla-object (bk:hent (nth 4 x))) 'GetAttributes)
        (if (= (strcase (vla-get-TagString a)) "ПОЗИЦИЯ") (setq r (vla-get-StyleName a))))))
  (if r r ""))
;; группы оборудования: ((наименование марка производитель) позиции...)
(defun sc:ved-rows (/ hs g k p e nm)
  (foreach d *sc:disp* (foreach h (nth 5 d) (if (and (not (sc:is-riser h)) (not (member h *sc:pblk*)) (not (member h hs))) (setq hs (cons h hs)))))
  (foreach h hs
    (setq e (bk:hent h) nm (bk:attr e "НАИМЕНОВАНИЕ"))
    (setq k (list (if (= nm "") (sc:bname h) nm) (bk:attr e "МАРКА") (bk:attr e "ПРОИЗВОДИТЕЛЬ")))
    ;; (ключ число "" первый_хэндл позиции...)
    (if (setq p (assoc k g)) (setq g (subst (bk:replace-nth 1 (1+ (cadr p)) (append p (list (bk:dev-pos h)))) p g))
      (setq g (append g (list (list k 1 "" h (bk:dev-pos h)))))))
  (vl-sort g '(lambda (a b) (bk:less (car (car a)) (car (car b))))))
;; обозначение группы: часть ПОЗИЦИИ до «-» (AS-1.1 -> AS), разные - через запятую
(defun sc:desig (poss / l)
  (foreach x (vl-remove "-" poss)
    (setq x (if (vl-string-search "-" x) (substr x 1 (vl-string-search "-" x)) x))
    (if (not (member x l)) (setq l (append l (list x)))))
  (bk:join l ", "))
;; высота атрибута ПОЗИЦИЯ блоков схемы в единицах схемы (с учётом масштаба блоков), 0 - нет
;; высота атрибута ПОЗИЦИЯ блоков схемы: параметр «Высота ПОЗИЦИИ блоков», пусто - как текст этажей
(defun sc:pos-h () (if (> (sc:gn "pah") 0) (sc:gn "pah") (sc:gn "th")))
(defun sc:vedom (y0 th lth / rows ws i)
  (if (setq rows (sc:ved-rows))
    (progn
      ;; таблица AutoCAD: заголовок (высота как у текста таблицы), шапка, строки; перенос текста - по ширине колонок
      (setq ws (mapcar '(lambda (w) (* w (/ lth 2.5))) '(10.0 30.0 75.0 50.0 40.0 14.0)) i 0)
      (sc:prim (list "TB" "СХ_ВЕДОМОСТЬ" (list 3.0 y0) lth ws
                     (cons '("№" "Обозначение" "Наименование" "Тип, марка" "Производитель" "Кол.")
                           (mapcar '(lambda (g) (setq i (1+ i))
                                      (list (itoa i) (sc:desig (cddddr g)) (nth 0 (car g)) (nth 1 (car g)) (nth 2 (car g)) (itoa (cadr g))))
                                   rows))
                     (list (+ 3.0 (apply '+ ws)) (- y0 (* 2.0 lth (+ 2 (length rows)))))
                     "Ведомость потребности оборудования")))))

(defun sc:blk-ok (h / r)
  (or (= h "")
      (and (not (member h *sc:pblk*))
           (or (null *sc:bsel*)
               (and (bk:hent h) (not (vl-catch-all-error-p (setq r (vl-catch-all-apply 'sc:bname (list h)))))
                    (member r *sc:bsel*))))))

(defun sc:node-floor (h cabs)
  (cond ((vl-some '(lambda (c) (cond ((= (nth 2 c) h) (nth 4 c)) ((= (nth 3 c) h) (nth 5 c)))) cabs)) ("")))
;; уровень этажа для автопорядка: подвал/паркинг/минусовые отметки - внизу (-6 ниже -3),
;; затем этажи и отметки по возрастанию, техэтаж/чердак, кровля - вверху
(defun sc:num-in (s / i r c st)
  (setq i 1)
  (while (and (null r) (<= i (strlen s)))
    (setq c (substr s i 1))
    (if (wcmatch c "#")
      (progn (setq st i)
             (while (and (<= i (strlen s)) (wcmatch (substr s i 1) "#,.,`,")) (setq i (1+ i)))
             (setq r (atof (vl-string-translate "," "." (substr s st (- i st)))))
             (if (and (> st 1) (= (substr s (1- st) 1) "-")) (setq r (- r))))
      (setq i (1+ i))))
  r)
(defun sc:fl-rank (f / u n)
  (setq u (bk:up f) n (sc:num-in f))
  (cond ((= f "") -100000.0)
        ((wcmatch u "*КРОВЛ*,*КРЫШ*") 100001.0)
        ((wcmatch u "*ЧЕРДАК*,*ТЕХЭТАЖ*,*ТЕХ. ЭТАЖ*,*ТЕХНИЧЕСКИЙ ЭТАЖ*") 100000.0)
        ((wcmatch u "*ПАРКИНГ*,*ПАРК*,*ПОДЗЕМ*") (- -1000.0 (abs (if n n 1))))
        ((wcmatch u "*ПОДВАЛ*,*ТЕХПОДПОЛ*") -500.0)
        ((and n (wcmatch u "*ОТМ*,*+*")) (/ n 3.0))      ; отметка, м -> примерно этаж
        (n n)
        (T 50000.0)))
;; сравнение этажей (для сортировки снизу вверх): "" - в самом низу
(defun sc:fl< (a b) (if (= (sc:fl-rank a) (sc:fl-rank b)) (bk:less a b) (< (sc:fl-rank a) (sc:fl-rank b))))

;; структура этажей пользователя: "flr" = ((значение подпись) ...) сверху вниз
(defun sc:flr () (cdr (assoc "flr" *sc:p*)))
;; итоговый порядок сверху вниз: сначала из структуры, остальные найденные - по автопорядку на свои места
(defun sc:order-floors (found / us rest out)
  (setq us (mapcar 'car (sc:flr))
        rest (vl-sort (vl-remove-if '(lambda (f) (member f us)) found) '(lambda (a b) (sc:fl< b a))))
  (if (null us) rest
    (progn
      (setq out us)
      ;; каждый недостающий - перед первым этажом структуры, который ниже него
      (foreach f rest
        (setq i (vl-position (vl-some '(lambda (u) (if (sc:fl< u f) u)) out) out))
        (setq out (if i (append (bk:sublist out 0 i) (list f) (bk:sublist out i nil)) (append out (list f)))))
      out)))
(defun bk:sublist (l a n / r i)
  (setq i 0)
  (foreach x l (if (and (>= i a) (or (null n) (< i (+ a n)))) (setq r (cons x r))) (setq i (1+ i)))
  (reverse r))
(defun sc:flabel (f / p)
  (cond ((and (setq p (assoc f (sc:flr))) (/= (cadr p) "")) (cadr p))
        ((= f "") "Этаж не указан")
        (T (bk:fmt (sc:g "flab") (list (cons "ЭТАЖ" f)) nil))))

;; найденные в чертеже значения ЭТАЖ (блоки и участки кабелей)
(defun sc:found-floors (/ l v)
  (foreach e (bk:ss->l (ssget "_X" '((0 . "INSERT") (66 . 1) (410 . "Model"))))
    (setq v (bk:attr e "ЭТАЖ")) (if (and (/= v "") (not (member v l))) (setq l (cons v l))))
  l)

(defun sc:flr-fill (sel)
  (start_list "lst")
  (foreach x *sc:fl* (add_list (strcat (car x) "\t" (cadr x) (if (member (car x) *sc:flf*) "" "\t(нет на чертеже)"))))
  (end_list)
  (bk:st "lst" sel))

;; окно структуры этажей: порядок сверху вниз, названия, добавить/удалить
(defun sc:flr-dialog (/ fn id res i x tmp)
  (setq *sc:flf* (sc:found-floors)
        *sc:fl* (sc:flr))
  ;; добавить найденные, которых нет в структуре
  (foreach f (sc:order-floors *sc:flf*) (if (not (assoc f *sc:fl*)) (setq *sc:fl* (append *sc:fl* (list (list f ""))))))
  (if (null (sc:flr)) (setq *sc:fl* (mapcar '(lambda (f) (list f "")) (sc:order-floors *sc:flf*))))
  (setq fn (bk:write-dcl "blok_schema_flr.dcl"
    '("sc_flr : dialog { label = \"Структура этажей схемы (сверху вниз)\";"
      " : list_box { key = \"hdr\"; height = 2; width = 80; tabs = \"30 62\"; is_tab_stop = false; }"
      " : row { : list_box { key = \"lst\"; height = 18; width = 80; tabs = \"30 62\"; }"
      "   : column { : button { key = \"b_up\"; label = \"Выше\"; } : button { key = \"b_dn\"; label = \"Ниже\"; }"
      "              : button { key = \"b_del\"; label = \"Удалить\"; } : button { key = \"b_auto\"; label = \"Автопорядок\"; } : spacer { } } }"
      " : row { : edit_box { key = \"val\"; label = \"Этаж (значение атрибута):\"; edit_width = 16; allow_accept = false; }"
      "         : edit_box { key = \"nm\"; label = \"Название на схеме:\"; edit_width = 24; allow_accept = false; } }"
      " : row { : button { key = \"b_set\"; label = \"Изменить выделенный\"; } : button { key = \"b_add\"; label = \"Добавить выше выделенного\"; } }"
      " : text { label = \"Пустое название - подпись по шаблону (Подпись этажа). Этажи из структуры рисуются всегда, даже пустые.\"; }"
      " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 14; }"
      "         : button { key = \"b_clr\"; label = \"Сбросить структуру\"; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }")))
  (setq id (load_dialog fn))
  (if (new_dialog "sc_flr" id)
    (progn
      (start_list "hdr") (add_list "Этаж (атрибут ЭТАЖ)\tНазвание на схеме") (end_list)
      (sc:flr-fill "0")
      (defun sc:flr-pick (/ x) (if (setq x (nth (atoi (get_tile "lst")) *sc:fl*)) (progn (bk:st "val" (car x)) (bk:st "nm" (cadr x)))))
      (sc:flr-pick)
      (defun sc:flr-swap (d / i a)
        (setq i (atoi (get_tile "lst")))
        (if (and (>= (+ i d) 0) (< (+ i d) (length *sc:fl*)))
          (progn (setq a (nth i *sc:fl*))
                 (setq *sc:fl* (bk:replace-nth i (nth (+ i d) *sc:fl*) *sc:fl*))
                 (setq *sc:fl* (bk:replace-nth (+ i d) a *sc:fl*))
                 (sc:flr-fill (itoa (+ i d))))))
      (action_tile "lst" "(sc:flr-pick)")
      (action_tile "b_up" "(sc:flr-swap -1)")
      (action_tile "b_dn" "(sc:flr-swap 1)")
      (action_tile "b_del" "(setq i (atoi (get_tile \"lst\")) *sc:fl* (append (bk:sublist *sc:fl* 0 i) (bk:sublist *sc:fl* (1+ i) nil))) (sc:flr-fill (itoa (max 0 (1- i)))) (sc:flr-pick)")
      (action_tile "b_auto" "(setq *sc:fl* (vl-sort *sc:fl* '(lambda (a b) (sc:fl< (car b) (car a))))) (sc:flr-fill \"0\")")
      (action_tile "b_set" "(setq i (atoi (get_tile \"lst\"))) (if (and *sc:fl* (/= (bk:trim (get_tile \"val\")) \"\")) (progn (setq *sc:fl* (bk:replace-nth i (list (bk:trim (get_tile \"val\")) (bk:trim (get_tile \"nm\"))) *sc:fl*)) (sc:flr-fill (itoa i))))")
      (action_tile "b_add" "(setq i (if *sc:fl* (atoi (get_tile \"lst\")) 0)) (if (and (/= (bk:trim (get_tile \"val\")) \"\") (not (assoc (bk:trim (get_tile \"val\")) *sc:fl*))) (progn (setq *sc:fl* (append (bk:sublist *sc:fl* 0 i) (list (list (bk:trim (get_tile \"val\")) (bk:trim (get_tile \"nm\")))) (bk:sublist *sc:fl* i nil))) (sc:flr-fill (itoa i))))")
      (action_tile "b_clr" "(setq *sc:fl* nil) (done_dialog 1)")
      (action_tile "accept" "(done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))))
  (unload_dialog id) (vl-file-delete fn)
  (if (= res 1) (sc:set "flr" *sc:fl*))
  (princ))

;; линия связи между узлами отображения a -> b с переходами по стоякам; подпись - на первом горизонтальном участке
(defun sc:draw-edge (key ids li / a b hops pts fa x y lbl al)
  (setq a (assoc (car key) *sc:disp*) b (assoc (cadr key) *sc:disp*) hops (caddr key))
  (setq fa (nth 3 a)
        pts (list (list (nth 1 a) (nth 2 a)) (list (nth 1 a) (ylane fa li))))
  (foreach h hops
    (setq x (xris (car h) li))
    (setq pts (append pts (list (list x (ylane fa li)) (list x (ylane (cadr h) li))))
          fa (cadr h)))
  (setq pts (append pts (list (list (nth 1 b) (ylane fa li)) (list (nth 1 b) (nth 2 b)))))
  (sc:prim (list "P" "СХ_СВЯЗИ" pts *sc:col* "DASHED"))
  (if (= (sc:g "lab") "1")
    (progn
      ;; подпись над линией отвода: от стояка (последний переход) или от прибора начала; одна на отвод и марку
      ;; текст над горизонталью: со стороны, куда уходит линия к прибору
      (setq x (if hops (xris (car (last hops)) li) (nth 1 a))
            al (if (< (nth 1 b) x) 3 4)
            y (list (list (if (= al 3) (- x (* 0.5 (sc:gn "lth"))) (+ x (* 0.5 (sc:gn "lth"))))
                          (+ (ylane fa li) (* 0.4 (sc:gn "lth"))))
                    al)
            lbl (list (rtos (car (car y)) 2 2) (rtos (cadr (car y)) 2 2) al *sc:ckcur*))
      (if (setq x (assoc lbl *sc:lbl*))
        (setq *sc:lbl* (subst (append x ids) x *sc:lbl*))
        (setq *sc:lbl* (append *sc:lbl* (list (append (list lbl y) ids))))))))

;; подпись группы кабелей по шаблону; группировка - одинаковые строки, позиции через запятую
(defun sc:label (ids)
  (bk:pos-ranges (bk:uniq (mapcar '(lambda (id) (bk:f (bk:get (car (bk:segs id))) "pos")) ids))))
(defun sc:label-full (ids / grp d t1 p gr)
  (setq gr (= (sc:g "grp") "1"))
  (foreach id ids
    (setq d (bk:get (car (bk:segs id)))
          t1 (bk:fmt (sc:g "tpl") (bk:cvars id d (if gr "\001" (bk:f d "pos"))) nil))
    (if (and gr (setq p (assoc t1 grp)))
      (setq grp (subst (append p (list (bk:f d "pos"))) p grp))
      (setq grp (append grp (list (list t1 (bk:f d "pos")))))))
  (bk:join (mapcar '(lambda (g) (bk:subst-all (car g) "\001" (bk:mtx (bk:pos-ranges (vl-remove "" (cdr g)))))) grp) "\\P"))

;;; ---------- вывод в файл схемы ----------
(defun sc:target (fn / acad d dbx ver)
  (setq acad (vlax-get-acad-object))
  (vlax-for x (vla-get-Documents acad)
    (if (= (strcase (vla-get-FullName x)) (strcase fn)) (setq d x)))
  ;; не открыт - открыть (или создать) в AutoCAD: запись через ObjectDBX в этой папке не сохраняется
  (if (null d)
    (progn
      (setq d (if (findfile fn)
                (vl-catch-all-apply 'vla-Open (list (vla-get-Documents acad) fn :vlax-false))
                (vl-catch-all-apply 'vla-Add (list (vla-get-Documents acad)))))
      (if (vl-catch-all-error-p d) (setq d nil) (setq *sc:opened* T))
      ;; вернуть активным исходный чертёж (открытый файл становится активным)
      (if *sc:srcdoc* (vl-catch-all-apply 'vla-Activate (list *sc:srcdoc*)))))
  (cond
    (d (list d nil))
    (T
     (setq ver (substr (getvar "ACADVER") 1 2)
           dbx (vl-catch-all-apply 'vla-GetInterfaceObject (list acad (strcat "ObjectDBX.AxDbDocument." ver))))
     (if (vl-catch-all-error-p dbx)
       (progn (alert "Не удалось запустить ObjectDBX. Откройте файл схемы в AutoCAD и повторите.") nil)
       (progn
         (if (findfile fn)
           (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-Open (list dbx fn)))
             (progn (alert (strcat "Не удаётся открыть файл:\n" fn)) (setq dbx nil))))
         (if dbx (list dbx T)))))))

;; сохранение через ObjectDBX: сначала во временный файл, файл схемы освобождается,
;; затем временный копируется на его место. Если файл схемы занят (открыт в другом окне
;; AutoCAD или другим пользователем) - схема сохраняется рядом под именем с датой и временем.
(defun sc:dbx-save (doc fn / tmp alt r)
  (setq tmp (strcat (vl-filename-directory fn) "\\~sc_tmp_" (rtos (getvar "CDATE") 2 0) ".dwg"))
  (setq r (vl-catch-all-apply 'vla-SaveAs (list doc tmp)))
  (vl-catch-all-apply 'vlax-release-object (list doc))
  (gc)
  (cond
    ((vl-catch-all-error-p r)
     (alert (strcat "Не удалось записать в папку:\n" (vl-filename-directory fn)
                    "\n" (vl-catch-all-error-message r))))
    ((and (or (not (findfile fn)) (vl-file-delete fn)) (vl-file-copy tmp fn))
     (vl-file-delete tmp)
     (princ (strcat "\nФайл сохранён: " fn)))
    (T
     (setq alt (strcat (vl-filename-directory fn) "\\" (vl-filename-base fn) "_"
                       (menucmd "M=$(edtime,$(getvar,date),YYYYMODD_HHMMSS)") ".dwg"))
     (if (vl-file-rename tmp alt)
       (alert (strcat "Файл схемы занят (открыт в AutoCAD или другим пользователем):\n" fn
                      "\n\nСхема сохранена в:\n" alt
                      "\n\nЗакройте схема.dwg и повторите, либо откройте схему в этом же окне AutoCAD - тогда она рисуется прямо в открытом файле."))
       (alert (strcat "Не удалось сохранить схему. Временный файл:\n" tmp))))))

;; исходный чертёж (с кабелями) - запоминается до открытия файла схемы
(defun sc:src () (if *sc:srcdoc* *sc:srcdoc* (bk:doc)))

(defun sc:layer (doc name col / l)
  (setq l (vl-catch-all-apply 'vla-Add (list (vla-get-Layers doc) name)))
  (if (and (not (vl-catch-all-error-p l)) col) (vl-catch-all-apply 'vla-put-Color (list l col))))

;; описания блоков и стиль текста - копировать из текущего чертежа, если их нет в файле схемы
(defun sc:copy-def (doc coll-src coll-dst name / o arr)
  (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-Item (list coll-dst name)))
    (if (not (vl-catch-all-error-p (setq o (vl-catch-all-apply 'vla-Item (list coll-src name)))))
      (progn (setq arr (vlax-make-safearray vlax-vbObject '(0 . 0)))
             (vlax-safearray-put-element arr 0 o)
             (vl-catch-all-apply 'vla-CopyObjects (list (sc:src) arr coll-dst))))))

(defun sc:emit (doc s ox oy / ms tp pt o sty n a src lt i r)
  (setq ms (vla-get-ModelSpace doc) sty (sc:g "style") n 0)
  ;; стиль текста по умолчанию - как у атрибута ПОЗИЦИЯ блоков схемы
  (if (= sty "") (setq sty (sc:pos-style)))
  ;; штриховой тип линии для кабелей
  (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-Item (list (vla-get-Linetypes doc) "DASHED")))
    (vl-catch-all-apply 'vla-Load (list (vla-get-Linetypes doc) "DASHED" "acadiso.lin")))
  (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-Item (list (vla-get-Linetypes doc) "DASHED")))) (setq lt "DASHED"))
  (if (/= sty "") (sc:copy-def doc (vla-get-TextStyles (sc:src)) (vla-get-TextStyles doc) sty))
  (foreach l '(("СХ_ПРИБОРЫ" 7) ("СХ_СВЯЗИ" 7) ("СХ_ЭТАЖИ" 8) ("СХ_ТЕКСТ" 7) ("СХ_ПОДПИСИ" 7) ("СХ_РАМКА" 7) ("СХ_ВЕДОМОСТЬ" 7))
    (sc:layer doc (car l) (cadr l)))
  (defun tp (p) (vlax-3d-point (+ ox (* s (car p))) (+ oy (* s (cadr p))) 0.0))
  (foreach x (reverse *sc:out*)
    (setq *sc:stage* (strcat "рисование: " (car x) " " (cadr x)))
    (cond
      ((= (car x) "P")
       (setq o (vlax-invoke ms 'AddLightWeightPolyline
                 (apply 'append (mapcar '(lambda (p) (list (float (+ ox (* s (car p)))) (float (+ oy (* s (cadr p)))))) (caddr x)))))
       (if (nth 3 x) (vla-put-Color o (nth 3 x)))
       (if (and (nth 4 x) lt) (progn (vla-put-Linetype o lt) (vla-put-LinetypeScale o (max 0.01 (sc:gn "lts"))))))
      ((= (car x) "T")
       (setq o (vla-AddText ms (nth 4 x) (tp (caddr x)) (* s (nth 3 x))))
       (cond ((= (nth 5 x) 1) (vla-put-Alignment o acAlignmentBottomCenter) (vla-put-TextAlignmentPoint o (tp (caddr x))))
             ((= (nth 5 x) 2) (vla-put-Alignment o acAlignmentMiddleLeft) (vla-put-TextAlignmentPoint o (tp (caddr x))))
             ((= (nth 5 x) 3) (vla-put-Alignment o acAlignmentBottomRight) (vla-put-TextAlignmentPoint o (tp (caddr x))))
             ((= (nth 5 x) 4) (vla-put-Alignment o acAlignmentBottomLeft) (vla-put-TextAlignmentPoint o (tp (caddr x))))))
      ((= (car x) "M")
       (setq o (vla-AddMText ms (tp (caddr x)) 0.0 (nth 4 x)))
       (vla-put-Height o (* s (nth 3 x)))
       (vla-put-AttachmentPoint o acAttachmentPointBottomCenter)
       (vla-put-InsertionPoint o (tp (caddr x))))
      ((= (car x) "TB")
       ;; (TB слой (x y) h ширины строки угол заголовок)
       (setq o (vla-AddTable ms (tp (caddr x)) (+ 1 (length (nth 5 x))) (length (nth 4 x)) (* s 2.0 (nth 3 x)) (* s (car (nth 4 x)))))
       (vl-catch-all-apply 'vla-put-RegenerateTableSuppressed (list o :vlax-true))
       (setq i 0) (foreach w (nth 4 x) (vla-SetColumnWidth o i (* s w)) (setq i (1+ i)))
       (vla-SetText o 0 0 (nth 7 x))
       (setq r 1)
       (foreach row (nth 5 x)
         (setq i 0) (foreach c row (vla-SetText o r i c) (setq i (1+ i)))
         (setq r (1+ r)))
       (foreach rt (list acTitleRow acHeaderRow acDataRow)
         (vl-catch-all-apply 'vla-SetTextHeight (list o rt (* s (nth 3 x))))
         (if (/= sty "") (vl-catch-all-apply 'vla-SetTextStyle (list o rt sty))))
       ;; аккуратно: поля ячеек 0.3 высоты, строки - минимальные, пустые строки удаляются
       (vl-catch-all-apply 'vla-put-VertCellMargin (list o (* s 0.3 (nth 3 x))))
       (vl-catch-all-apply 'vla-put-HorzCellMargin (list o (* s 0.4 (nth 3 x))))
       (setq r (1- (vla-get-Rows o)))
       (while (> r 1)
         (if (vl-every '(lambda (c) (= (vl-catch-all-apply 'vla-GetText (list o r c)) "")) (bk:range (vla-get-Columns o)))
           (vl-catch-all-apply 'vla-DeleteRows (list o r 1)))
         (setq r (1- r)))
       (setq r 0)
       (repeat (vla-get-Rows o) (vl-catch-all-apply 'vla-SetRowHeight (list o r (* s 1.6 (nth 3 x)))) (setq r (1+ r)))
       (vl-catch-all-apply 'vla-SetAlignment (list o acDataRow acMiddleLeft))
       (vl-catch-all-apply 'vla-SetAlignment (list o acHeaderRow acMiddleCenter))
       (vl-catch-all-apply 'vla-put-RegenerateTableSuppressed (list o :vlax-false))
       (vl-catch-all-apply 'vla-RecomputeTableBlock (list o :vlax-true)))
      ((= (car x) "B")
       (setq src (vlax-ename->vla-object (bk:hent (nth 4 x))) a (sc:bname (nth 4 x)))
       (sc:copy-def doc (vla-get-Blocks (sc:src)) (vla-get-Blocks doc) a)
       (setq o (vl-catch-all-apply 'vla-InsertBlock (list ms (tp (caddr x)) a (* s (nth 3 x)) (* s (nth 3 x)) (* s (nth 3 x)) 0.0)))
       (if (vl-catch-all-error-p o) (setq o nil)
         (progn
           ;; значения атрибутов - как у блока на плане
           (foreach at (vl-catch-all-apply 'vlax-invoke (list o 'GetAttributes))
             ;; высота ПОЗИЦИИ - отдельный параметр; КОЛИЧЕСТВО - число приборов в группе
             (if (= (strcase (vla-get-TagString at)) "ПОЗИЦИЯ") (vl-catch-all-apply 'vla-put-Height (list at (* s (sc:pos-h)))))
             (foreach sa (vlax-invoke src 'GetAttributes)
               (if (= (strcase (vla-get-TagString sa)) (strcase (vla-get-TagString at)))
                 (vla-put-TextString at
                   ;; свёрнутая группа: ПОЗИЦИИ объединяются (S-9.1...S-9.3)
                   (cond ((and (nth 5 x) (= (strcase (vla-get-TagString at)) "ПОЗИЦИЯ")) (nth 5 x))
                         ((and (nth 6 x) (= (strcase (vla-get-TagString at)) "КОЛИЧЕСТВО")) (nth 6 x))
                         (T (vla-get-TextString sa)))))))))))
    (if o
      (progn (vla-put-Layer o (cadr x))
             (if (and (/= sty "") (member (car x) '("T" "M"))) (vl-catch-all-apply 'vla-put-StyleName (list o sty)))
             (setq n (1+ n)))))
  n)

(defun bk:range (n / l) (repeat n (setq l (cons (setq n (1- n)) l))) l)
(defun sc:clear (doc / l)
  (vlax-for o (vla-get-ModelSpace doc) (if (wcmatch (strcase (vla-get-Layer o)) "СХ_*") (setq l (cons o l))))
  (foreach o l (vl-catch-all-apply 'vla-Delete (list o)))
  (length l))

;;; ---------- команда ----------
(defun sc:run (/ *error* st tg doc dbx xs ys s w h fr bw bh ox oy iw ih n fmt)
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*"))
      (princ (strcat "\nОшибка: " m "\n  (этап: " (if *sc:stage* *sc:stage* "-") ") - пришлите эти две строки.")))
    (princ))
  (setq *sc:stage* "окно параметров")
  (if (and (sc:need-kabel) (progn (bk:load-types) (sc:dialog)))
    (progn
      (princ "\nСбор данных кабелей...")
      (setq *sc:stage* "сбор данных")
      (setq st (sc:build))
      (if (and (= (car st) 0) (= (nth 2 st) 0))
        (princ (strcat "\nСхема не построена. Кабелей в чертеже: " (itoa (nth 0 *sc:diag*))
                       ", отмечено в списке кабелей: " (itoa (nth 1 *sc:diag*))
                       ", с выбранными блоками на концах: " (itoa (nth 2 *sc:diag*))
                       (cond ((= (nth 0 *sc:diag*) 0) " - нет кабелей и не выбраны блоки. Выберите блоки в «Блоки на схеме...» - без кабелей схема строится расстановкой оборудования по этажам.")
                             ((= (nth 1 *sc:diag*) 0) " - в окне \"Кабели...\" не отмечен ни один кабель.")
                             (T " - ни у одного кабеля нет начала/конца среди выбранных блоков (окно \"Блоки...\"; концы кабеля - ММ_КАБЕЛЬ_СВОЙСТВА)."))))
        (progn
          ;; габарит схемы
          (foreach x *sc:out*
            (foreach p (cond ((= (car x) "P") (caddr x)) ((= (car x) "TB") (list (caddr x) (nth 6 x))) (T (list (caddr x))))
              (setq xs (cons (car p) xs) ys (cons (cadr p) ys))))
          (setq bw (- (apply 'max xs) (apply 'min xs)) bh (- (apply 'max ys) (apply 'min ys)))
          ;; лист
          (setq fmt (nth (atoi (sc:g "fmt")) *sc:formats*)
                w (if (= (sc:g "orient") "0") (max (cadr fmt) (caddr fmt)) (min (cadr fmt) (caddr fmt)))
                h (if (= (sc:g "orient") "0") (min (cadr fmt) (caddr fmt)) (max (cadr fmt) (caddr fmt)))
                iw (- w 20 5 10) ih (- h 5 5 10)
                s (if (= (sc:g "fit") "1") (min 1.0 (/ iw (max bw 1.0)) (/ ih (max bh 1.0))) 1.0)
                ox (+ (sc:gn "xoff") 20 5 (- (* s (apply 'min xs))))
                oy (- h 5 5 (* s (apply 'max ys))))
          (setq *sc:stage* "открытие файла схемы")
          (setq *sc:opened* nil *sc:srcdoc* (bk:doc))
          (if (setq tg (sc:target (sc:g "file")))
            (progn
              (setq doc (car tg) dbx (cadr tg))
              (if (= (sc:g "clear") "1") (princ (strcat "\nУдалено объектов прежней схемы: " (itoa (sc:clear doc)))))
              (setq *sc:stage* "рисование в файле схемы")
              (setq n (sc:emit doc s ox oy))
              (setq *sc:stage* "рамка и сохранение")
              (if (= (sc:g "frame") "1")
                (progn
                  (foreach r (list (list (sc:gn "xoff") 0 w h) (list (+ (sc:gn "xoff") 20) 5 (- w 25) (- h 10)))
                    ;; координаты - только вещественные (целые числа ActiveX не принимает)
                    (setq r (mapcar 'float r)
                          fr (vlax-invoke (vla-get-ModelSpace doc) 'AddLightWeightPolyline
                               (list (car r) (cadr r) (+ (car r) (caddr r)) (cadr r) (+ (car r) (caddr r)) (+ (cadr r) (cadddr r)) (car r) (+ (cadr r) (cadddr r)))))
                    (vla-put-Closed fr :vlax-true) (vla-put-Layer fr "СХ_РАМКА"))))
              (if dbx
                (progn
                  (sc:dbx-save doc (sc:g "file")))
                (if *sc:opened*
                  ;; файл открыт программой: сохранить (новый - под заданным именем)
                  (if (vl-catch-all-error-p
                        (if (findfile (sc:g "file"))
                          (vl-catch-all-apply 'vla-Save (list doc))
                          (vl-catch-all-apply 'vla-SaveAs (list doc (sc:g "file")))))
                    (princ (strcat "\nСхема построена в файле " (sc:g "file") ", он открыт в AutoCAD - сохраните его вручную."))
                    (princ (strcat "\nСхема построена и сохранена: " (sc:g "file") " (файл открыт в AutoCAD).")))
                  (princ (strcat "\nСхема построена в открытом файле " (sc:g "file") " - сохраните его."))))
              (princ (strcat "\nСхема: кабелей " (itoa (nth 0 st)) ", шлейфов " (itoa (nth 1 st)) ", приборов/групп "
                             (itoa (nth 2 st)) ", этажей " (itoa (nth 3 st)) ", стояков " (itoa (nth 4 st))
                             ", объектов " (itoa n) (if (< s 0.999) (strcat ", масштаб вписывания " (rtos s 2 3)) "") "."))))))))
  (princ))

(defun c:мм_схема () (sc:run))
(defun c:ММ_СХЕМА () (sc:run))
(defun c:MM_SCHEME () (sc:run))

;;; ---------- сообщение при загрузке ----------
(princ "\n==================================================================")
(princ "\n MM_SCHEME.LSP загружен: поэтажная структурная схема по кабелям")
(princ "\n  ММ_СХЕМА (MM_SCHEME) - окно: файл схемы (схема.dwg), формат, рамка,")
(princ "\n    размеры, маска кабелей, сворачивание приборов, подписи кабелей.")
(princ "\n  Нужен blok_kabel.lsp (подгружается сам из той же папки).")
(princ "\n==================================================================")
(princ)
