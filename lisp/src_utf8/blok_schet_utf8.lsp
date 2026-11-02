;;; ======================================================================
;;;  MM_BLOCK_COUNT.LSP  —  Этап 1: ведомость потребности материалов по блокам
;;;  AutoCAD 2024. Кодировка файла: Windows-1251 (ANSI).
;;; ----------------------------------------------------------------------
;;;  КОМАНДЫ:
;;;   ММ_СЧЕТ (или MM_BLOCK_COUNT) - подсчёт блоков с атрибутами:
;;;     1. В диалоге задайте фильтр-маску (напр. СОТ_*, *камера*) -> "Применить".
;;;     2. Выделите нужные блоки (Ctrl/Shift - несколько) или "Выделить все".
;;;     3. "Сформировать" -> укажите высоту текста и точку вставки таблицы.
;;;     Результат: таблица в текущем пространстве + файл <имя_чертежа>.csv
;;;     в папке чертежа (разделитель ";", открывается в Excel).
;;;   Правила сложения: одинаковые блоки с одинаковыми атрибутами суммируются;
;;;     ПОЗИЦИЯ сокращается до знака "-" (AS-12 -> AS).
;;;   Разделы таблицы: по атрибутам ЭТАЖ и БЛОК (ячейки не объединяются).
;;;   Считаются блоки пространства Модели.
;;; ======================================================================

(vl-load-com)

;;; ---------- настройки ----------
(setq *sc:tag-pos*   "ПОЗИЦИЯ"
      *sc:tag-floor* "ЭТАЖ"
      *sc:tag-block* "БЛОК"
      *sc:tag-name*  "НАИМЕНОВАНИЕ"
      *sc:order*     '("ПОЗИЦИЯ" "НАИМЕНОВАНИЕ" "МАРКА" "ПРОИЗВОДИТЕЛЬ"
                       "ЭТАЖ" "БЛОК" "ПРИМ-1" "ПРИМ-2"))
(if (not *sc:th*) (setq *sc:th* 2.5))
(if (not *sc:mask*) (setq *sc:mask* "*"))

;;; ---------- утилиты ----------
(defun sc:trim (s) (vl-string-trim " \t" (if s s "")))

(defun sc:short-pos (s / i)
  (setq s (sc:trim s))
  (if (setq i (vl-string-search "-" s)) (sc:trim (substr s 1 i)) s))

(defun sc:num (s / i n c d)
  (setq i 1 n (strlen s) d "")
  (while (and (<= i n) (not (wcmatch (substr s i 1) "#"))) (setq i (1+ i)))
  (while (and (<= i n) (wcmatch (setq c (substr s i 1)) "#"))
    (setq d (strcat d c) i (1+ i)))
  (if (= d "") nil (atoi d)))

;; "естественное" сравнение: 2 этаж < 10 этаж
(defun sc:less (a b / na nb)
  (setq na (sc:num a) nb (sc:num b))
  (cond ((and na nb (/= na nb)) (< na nb))
        ((and nb (not na)) T)
        ((and na (not nb)) nil)
        (T (< (strcase a) (strcase b)))))

(defun sc:bname (o / r)
  (setq r (vl-catch-all-apply 'vla-get-EffectiveName (list o)))
  (if (vl-catch-all-error-p r) (vla-get-Name o) r))

(defun sc:attrs (o / l)
  (foreach a (append (vlax-invoke o 'GetAttributes)
                     (vlax-invoke o 'GetConstantAttributes))
    (setq l (cons (cons (strcase (vla-get-TagString a))
                        (sc:trim (vla-get-TextString a))) l)))
  (reverse l))

(defun sc:get (tag al / p) (if (setq p (assoc tag al)) (cdr p) ""))

;;; ---------- сбор данных ----------
(defun sc:collect (/ ss i o res)
  (if (setq ss (ssget "_X" '((0 . "INSERT") (66 . 1) (410 . "Model"))))
    (repeat (setq i (sslength ss))
      (setq o (vlax-ename->vla-object (ssname ss (setq i (1- i)))))
      (setq res (cons (cons (sc:bname o) (sc:attrs o)) res))))
  res)

;;; ---------- диалог (DCL создаётся во временной папке) ----------
;;; Подписи кнопок пишутся прямо в DCL (set_tile их не меняет).
(defun sc:write-dcl (/ fn f)
  (setq fn (vl-filename-mktemp "blok_schet.dcl") f nil)
  ;; кодировка DCL по LISPSYS: 1 - UTF-8 с BOM, 0 - ANSI
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0))
    (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  (foreach l
    '("sc_dlg : dialog { label = \"Ведомость потребности - выбор блоков\";"
      " : text { key = \"t_flt\"; width = 60; }"
      " : row { : edit_box { key = \"flt\"; edit_width = 45; allow_accept = false; }"
      "         : button { key = \"b_flt\"; label = \"Применить\"; width = 14; fixed_width = true; } }"
      " : text { key = \"t_lst\"; }"
      " : list_box { key = \"lst\"; multiple_select = true; height = 22; width = 60; }"
      " : row { : button { key = \"b_all\"; label = \"Выделить все\"; }"
      "         : button { key = \"b_none\"; label = \"Снять выделение\"; } }"
      " : text { key = \"info\"; }"
      " : row { : button { key = \"accept\"; label = \"Сформировать\"; is_default = true; width = 18; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 18; } } }")
    (write-line l f))
  (close f)
  fn)

(defun sc:fill (/ i)
  (setq *sc:shown* nil i 0)
  (foreach p *sc:names*
    (if (wcmatch (strcase (car p)) (strcase *sc:mask*))
      (setq *sc:shown* (cons p *sc:shown*))))
  (setq *sc:shown* (reverse *sc:shown*))
  (start_list "lst")
  (foreach p *sc:shown*
    (add_list (strcat (car p) "   (" (itoa (cdr p)) " шт.)")))
  (end_list)
  (set_tile "info" (strcat "Показано блоков: " (itoa (length *sc:shown*))
                           " из " (itoa (length *sc:names*)))))

(defun sc:select-all (on / s i)
  (setq s "" i 0)
  (if on (repeat (length *sc:shown*) (setq s (strcat s (itoa i) " ") i (1+ i))))
  (set_tile "lst" s))

(defun sc:dialog (/ fn id res sel)
  (setq fn (sc:write-dcl) id (load_dialog fn))
  (if (not (new_dialog "sc_dlg" id))
    (progn (princ "\nОшибка загрузки диалога.") nil)
    (progn
      (set_tile "t_flt" "Фильтр по имени блока (маска: * ? , #):")
      (set_tile "flt" *sc:mask*)
      (set_tile "t_lst" "Блоки с атрибутами (выделите нужные):")
      (sc:fill)
      (action_tile "flt"   "(setq *sc:mask* (if (= $value \"\") \"*\" $value)) (sc:fill)")
      (action_tile "b_flt" "(setq *sc:mask* (get_tile \"flt\")) (if (= *sc:mask* \"\") (setq *sc:mask* \"*\")) (sc:fill)")
      (action_tile "b_all"  "(sc:select-all T)")
      (action_tile "b_none" "(sc:select-all nil)")
      (action_tile "accept" "(setq sel (get_tile \"lst\")) (done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)
      (vl-file-delete fn)
      (if (and (= res 1) sel (/= sel ""))
        (mapcar '(lambda (i) (car (nth i *sc:shown*)))
                (read (strcat "(" sel ")")))))))

;;; ---------- обработка ----------
(defun sc:tags (recs / tags)
  (foreach r recs
    (foreach a (cdr r)
      (if (not (member (car a) tags)) (setq tags (cons (car a) tags)))))
  (append (vl-remove-if-not '(lambda (t1) (member t1 tags)) *sc:order*)
          (vl-sort (vl-remove-if '(lambda (t1) (member t1 *sc:order*)) tags) '<)))

;; -> список ((ключ . кол-во)); ключ = (имя_блока знач1 знач2 ...)
(defun sc:group (recs tags / items key p)
  (foreach r recs
    (setq key (cons (car r)
                    (mapcar '(lambda (tg / v)
                               (setq v (sc:get tg (cdr r)))
                               (if (= tg *sc:tag-pos*) (sc:short-pos v) v))
                            tags)))
    (if (setq p (assoc key items))
      (setq items (subst (cons key (1+ (cdr p))) p items))
      (setq items (cons (cons key 1) items))))
  items)

(defun sc:val (item tags tg / i)
  (if (setq i (vl-position tg tags)) (nth (1+ i) (car item)) ""))

(defun sc:sort (items tags)
  (vl-sort items
    '(lambda (a b / fa fb ba bb pa pb)
       (setq fa (sc:val a tags *sc:tag-floor*) fb (sc:val b tags *sc:tag-floor*)
             ba (sc:val a tags *sc:tag-block*) bb (sc:val b tags *sc:tag-block*)
             pa (sc:val a tags *sc:tag-pos*)   pb (sc:val b tags *sc:tag-pos*))
       (cond ((/= fa fb) (sc:less fa fb))
             ((/= ba bb) (sc:less ba bb))
             ((/= pa pb) (sc:less pa pb))
             (T (< (sc:val a tags *sc:tag-name*) (sc:val b tags *sc:tag-name*)))))))

;; строки таблицы: ("S" текст_раздела) или ("D" знач...)
(defun sc:rows (items tags / rows cur sec n)
  (setq cur nil n 0)
  (foreach it items
    (setq sec (strcat "Этаж: " (sc:val it tags *sc:tag-floor*)
                      ";  Блок: " (sc:val it tags *sc:tag-block*)))
    (if (/= sec cur) (setq rows (cons (list "S" sec) rows) cur sec))
    (setq n (1+ n)
          rows (cons (append (list "D" (itoa n))
                             (cdr (car it))
                             (list (itoa (cdr it)) (car (car it))))
                     rows)))
  (reverse rows))

;;; ---------- CSV ----------
(defun sc:csv-cell (s)
  (if (or (vl-string-search ";" s) (vl-string-search "\"" s))
    (strcat "\"" (vl-string-subst "\"\"" "\"" s) "\"")
    s))

(defun sc:csv-line (lst / s)
  (setq s (sc:csv-cell (car lst)))
  (foreach x (cdr lst) (setq s (strcat s ";" (sc:csv-cell x))))
  s)

(defun sc:write-csv (fn head rows / f r)
  ;; при LISPSYS=1 пишем UTF-8 с BOM (Excel читает кириллицу), иначе ANSI
  (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom")))
  (if (or (vl-catch-all-error-p f) (null f)) (setq f (open fn "w")))
  (if (null f)
    (progn (princ (strcat "\nНе удалось записать " fn " (файл открыт в Excel?)")) nil)
    (progn
      (write-line (sc:csv-line head) f)
      (foreach r rows (if (= (car r) "D") (write-line (sc:csv-line (cdr r)) f)))
      (close f)
      T)))

;;; ---------- таблица AutoCAD ----------
(defun sc:table (head rows th pt / doc sp nr nc tbl r c w ci widths)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        sp  (vla-get-Block (vla-get-ActiveLayout doc))
        nc  (length head)
        nr  (+ 2 (length rows))
        ci  (cond ((vl-position *sc:tag-name* head)) (1)))
  (setq widths (mapcar 'strlen head))
  (foreach rw rows
    (if (= (car rw) "D")
      (setq widths (mapcar '(lambda (a b) (max a (strlen b))) widths (cdr rw)))))
  (setq tbl (vla-AddTable sp (vlax-3d-point pt) nr nc (* th 2.2) (* th 10)))
  (vla-put-RegenerateTableSuppressed tbl :vlax-true)
  (vla-SetTextHeight tbl 7 th)
  (setq c 0)
  (foreach w widths
    (vla-SetColumnWidth tbl c (min (* th 60) (max (* th 4) (* th (+ 2 (* 0.8 w))))))
    (setq c (1+ c)))
  (vla-SetText tbl 0 0 "Ведомость потребности материалов")
  (setq c 0)
  (foreach h head (vla-SetText tbl 1 c h) (setq c (1+ c)))
  (setq r 2)
  (foreach rw rows
    (if (= (car rw) "S")
      (vla-SetText tbl r ci (cadr rw))          ; раздел: без объединения ячеек
      (progn
        (setq c 0)
        (foreach v (cdr rw)
          (vla-SetText tbl r c v)
          (vla-SetCellAlignment tbl r c acMiddleCenter)
          (setq c (1+ c)))))
    (setq r (1+ r)))
  (vla-put-RegenerateTableSuppressed tbl :vlax-false)
  tbl)

;;; ---------- команда ----------
(defun sc:main (/ *error* doc recs names p sel tags items rows head fn th pt)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*"))
      (princ (strcat "\nОшибка: " m)))
    (vla-EndUndoMark doc)
    (princ))
  (vla-StartUndoMark doc)
  (if (null (setq recs (sc:collect)))
    (princ "\nВ пространстве Модели нет блоков с атрибутами.")
    (progn
      (foreach r recs
        (if (setq p (assoc (car r) names))
          (setq names (subst (cons (car r) (1+ (cdr p))) p names))
          (setq names (cons (cons (car r) 1) names))))
      (setq *sc:names* (vl-sort names '(lambda (a b) (< (strcase (car a)) (strcase (car b))))))
      (if (setq sel (sc:dialog))
        (progn
          (setq recs  (vl-remove-if-not '(lambda (r) (member (car r) sel)) recs)
                tags  (sc:tags recs)
                items (sc:sort (sc:group recs tags) tags)
                rows  (sc:rows items tags)
                head  (append '("№") tags '("Кол-во, шт." "Имя блока")))
          ;; CSV
          (if (= (getvar "DWGTITLED") 0)
            (princ "\nЧертёж не сохранён — CSV не создан. Сохраните файл и повторите.")
            (progn
              (setq fn (strcat (getvar "DWGPREFIX") (vl-filename-base (getvar "DWGNAME")) ".csv"))
              (if (sc:write-csv fn head rows) (princ (strcat "\nCSV: " fn)))))
          ;; таблица
          (initget 6)
          (if (setq th (getreal (strcat "\nВысота текста таблицы <" (rtos *sc:th* 2 2) ">: ")))
            (setq *sc:th* th))
          (if (setq pt (getpoint "\nТочка вставки таблицы (левый верхний угол): "))
            (progn
              (sc:table head rows *sc:th* pt)
              (princ (strcat "\nГотово: позиций " (itoa (length items))
                             ", блоков " (itoa (length recs)) "."))))))))
  (vla-EndUndoMark doc)
  (princ))

(defun c:мм_счет () (sc:main))
(defun c:ММ_СЧЕТ () (sc:main))
(defun c:MM_BLOCK_COUNT () (sc:main))

;;; ---------- сообщение при загрузке ----------
(princ "\n==================================================================")
(princ "\n MM_BLOCK_COUNT.LSP загружен (Этап 1: ведомость потребности)")
(princ "\n  ММ_СЧЕТ / MM_BLOCK_COUNT - подсчёт блоков с атрибутами:")
(princ "\n    фильтр-маска -> выбор блоков -> таблица + CSV в папке чертежа.")
(princ "\n    ПОЗИЦИЯ сокращается до '-'; разделы по ЭТАЖ и БЛОК.")
(princ "\n==================================================================")
(princ)
