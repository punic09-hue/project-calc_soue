;;; ======================================================================
;;;  MM_CHECK.LSP  —  Этап 2: проверка атрибутов блоков перед подсчётом
;;;  AutoCAD 2024. Кодировка файла: Windows-1251 (ANSI).
;;; ----------------------------------------------------------------------
;;;  КОМАНДЫ:
;;;   ММ_ПРОВЕРКА (или MM_CHECK) - запрос [Включить/Отключить]:
;;;     Включить  - открывается окно: фильтр-маска над списком всех блоков
;;;                 с атрибутами (напр. СОТ_*, *камера*) -> "Применить";
;;;                 выделите блоки (Ctrl/Shift или "Выделить все");
;;;                 галочки (по умолчанию сняты):
;;;                   [ ] поиск дублей по этажам - одинаковая ПОЗИЦИЯ на разных
;;;                       ЭТАЖАХ не считается дублем;
;;;                   [ ] поиск дублей по блокам - то же для разных БЛОКОВ;
;;;                 -> ОК.
;;;                 Поиск в выбранных блоках:
;;;                 * пустые ПОЗИЦИЯ / НАИМЕНОВАНИЕ / ЭТАЖ; по галочкам -
;;;                   также МАРКА / ПРОИЗВОДИТЕЛЬ / БЛОК (по умолчанию выкл.);
;;;                 * дубли ПОЗИЦИИ (полное значение, напр. AS-12 дважды).
;;;                 Ошибочные блоки обводятся красной рамкой с подписью
;;;                 на отдельном слое "_ПРОВЕРКА_АТРИБУТОВ" (слой не печатается).
;;;                 Сам блок НЕ изменяется (цвет, вес и тип линий прежние).
;;;                 Открывается окно со списком ошибочных блоков и всеми
;;;                 атрибутами; кнопка "Показать" - зумирует на блок.
;;;                 Правка: выделите один или несколько блоков в списке,
;;;                 выберите атрибут (или щёлкните строку атрибута ниже),
;;;                 введите значение -> "Применить к выделенным".
;;;                 Сразу выполняется повторная проверка и обновляется
;;;                 подсветка; исправленные блоки уходят из списка.
;;;                 Правки отменяются командой ОТМЕНИТЬ (U) одним шагом.
;;;     Отключить - удаляет все рамки и подписи проверки.
;;;   Проверяются блоки пространства Модели. Отсутствующий атрибут = пустой.
;;;   Повторное "Включить" сначала удаляет старую подсветку.
;;; ======================================================================

(vl-load-com)

;;; ---------- настройки ----------
(setq *bp:layer*   "_ПРОВЕРКА_АТРИБУТОВ"
      *bp:color*   1                                ; красный
      *bp:tag-pos* "ПОЗИЦИЯ"
      *bp:req*     '("ПОЗИЦИЯ" "НАИМЕНОВАНИЕ" "МАРКА" "ПРОИЗВОДИТЕЛЬ" "ЭТАЖ" "БЛОК"))
(if (not *bp:mask*) (setq *bp:mask* "*"))
;; необязательные проверки на пустоту (галочки в окне): по умолчанию выключены
(setq *bp:opt* '("МАРКА" "ПРОИЗВОДИТЕЛЬ" "БЛОК"))
(if (not *bp:opt-on*) (setq *bp:opt-on* '()))
(defun bp:req-on () (vl-remove-if '(lambda (tg) (and (member tg *bp:opt*) (not (member tg *bp:opt-on*)))) *bp:req*))

;;; ---------- утилиты ----------
(defun bp:trim (s) (vl-string-trim " \t" (if s s "")))

(defun bp:bname (o / r)
  (setq r (vl-catch-all-apply 'vla-get-EffectiveName (list o)))
  (if (vl-catch-all-error-p r) (vla-get-Name o) r))

(defun bp:attrs (o / l)
  (foreach a (append (vlax-invoke o 'GetAttributes)
                     (vlax-invoke o 'GetConstantAttributes))
    (setq l (cons (cons (strcase (vla-get-TagString a))
                        (bp:trim (vla-get-TextString a))) l)))
  (reverse l))

(defun bp:get (tag al / p) (if (setq p (assoc tag al)) (cdr p) ""))

(defun bp:join (lst sep / s)
  (setq s "")
  (foreach x lst (setq s (if (= s "") x (strcat s sep x))))
  s)

;;; ---------- слой подсветки ----------
(defun bp:make-layer (/ doc lay)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq lay (vla-Add (vla-get-Layers doc) *bp:layer*))
  (vla-put-Color lay *bp:color*)
  (vla-put-Plottable lay :vlax-false)
  (vla-put-LayerOn lay :vlax-true)
  (vl-catch-all-apply 'vla-put-Freeze (list lay :vlax-false))
  (vla-put-Lock lay :vlax-false)
  lay)

(defun bp:clear (/ ss i n)
  (setq n 0)
  (if (tblsearch "LAYER" *bp:layer*)
    (progn
      (vl-catch-all-apply 'vla-put-Lock
        (list (vla-Item (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object)))
                        *bp:layer*) :vlax-false))
      (if (setq ss (ssget "_X" (list (cons 8 *bp:layer*))))
        (repeat (setq i (sslength ss))
          (entdel (ssname ss (setq i (1- i))))
          (setq n (1+ n))))))
  n)

;;; ---------- сбор блоков ----------
;; -> список (ename имя attrs p1 p2) по всем блокам с атрибутами в Модели
(defun bp:collect (/ ss i e o mn mx res)
  (if (setq ss (ssget "_X" '((0 . "INSERT") (66 . 1) (410 . "Model"))))
    (repeat (setq i (sslength ss))
      (setq e (ssname ss (setq i (1- i)))
            o (vlax-ename->vla-object e))
      (vla-GetBoundingBox o 'mn 'mx)
      (setq res (cons (list e (bp:bname o) (bp:attrs o)
                            (vlax-safearray->list mn)
                            (vlax-safearray->list mx))
                      res))))
  res)

;;; ---------- запись DCL ----------
;;; Подписи кнопок в DCL нельзя поменять через set_tile, поэтому русские
;;; подписи пишутся прямо в DCL. Кодировка файла DCL согласована с LISPSYS:
;;; LISPSYS=1 (по умолчанию в AutoCAD 2024) - UTF-8 с BOM, LISPSYS=0 - ANSI.
(defun bp:open-dcl (fn / f)
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0))
    (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  f)

;;; ---------- диалог выбора блоков для проверки ----------
(defun bp:write-sel-dcl (/ fn f)
  (setq fn (vl-filename-mktemp "blok_proverka_sel.dcl") f (bp:open-dcl fn))
  (foreach l
    '("bp_sel : dialog { label = \"Проверка атрибутов - выбор блоков\";"
      " : text { key = \"t_flt\"; width = 60; }"
      " : row { : edit_box { key = \"flt\"; edit_width = 45; allow_accept = false; }"
      "         : button { key = \"b_flt\"; label = \"Применить\"; width = 14; fixed_width = true; } }"
      " : text { key = \"t_lst\"; }"
      " : list_box { key = \"lst\"; multiple_select = true; height = 22; width = 60; }"
      " : row { : button { key = \"b_all\"; label = \"Выделить все\"; }"
      "         : button { key = \"b_none\"; label = \"Снять выделение\"; } }"
      " : text { key = \"info\"; }"
      " : boxed_row { label = \"Проверять на пустоту также (ПОЗИЦИЯ, НАИМЕНОВАНИЕ, ЭТАЖ - всегда)\";"
      "   : toggle { key = \"o_mark\"; label = \"МАРКА\"; }"
      "   : toggle { key = \"o_prod\"; label = \"ПРОИЗВОДИТЕЛЬ\"; }"
      "   : toggle { key = \"o_blk\"; label = \"БЛОК\"; } }"
      " : boxed_column { label = \"Поиск дублей ПОЗИЦИИ\";"
      "   : toggle { key = \"chk_floor\"; label = \"Поиск дублей по этажам (одинаковая позиция на разных этажах - не ошибка)\"; }"
      "   : toggle { key = \"chk_block\"; label = \"Поиск дублей по блокам (одинаковая позиция в разных блоках - не ошибка)\"; } }"
      " : row { : button { key = \"accept\"; label = \"OK - проверить\"; is_default = true; width = 18; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 18; } } }")
    (write-line l f))
  (close f)
  fn)

(defun bp:fill ()
  (setq *bp:shown* nil)
  (foreach p *bp:names*
    (if (wcmatch (strcase (car p)) (strcase *bp:mask*))
      (setq *bp:shown* (cons p *bp:shown*))))
  (setq *bp:shown* (reverse *bp:shown*))
  (start_list "lst")
  (foreach p *bp:shown*
    (add_list (strcat (car p) "   (" (itoa (cdr p)) " шт.)")))
  (end_list)
  (set_tile "info" (strcat "Показано блоков: " (itoa (length *bp:shown*))
                           " из " (itoa (length *bp:names*)))))

(defun bp:select-all (on / s i)
  (setq s "" i 0)
  (if on (repeat (length *bp:shown*) (setq s (strcat s (itoa i) " ") i (1+ i))))
  (set_tile "lst" s))

;; -> список выбранных имён блоков или nil
(defun bp:sel-dialog (/ fn id res sel)
  (setq fn (bp:write-sel-dcl) id (load_dialog fn))
  (if (not (new_dialog "bp_sel" id))
    (progn (princ "\nОшибка загрузки диалога.") nil)
    (progn
      (set_tile "t_flt" "Фильтр по имени блока (маска: * ? , #):")
      (set_tile "flt" *bp:mask*)
      (set_tile "t_lst" "Блоки с атрибутами (выделите блоки для проверки):")
      ;; галочки по умолчанию сняты
      (setq *bp:dup-floor* nil *bp:dup-block* nil)
      (set_tile "chk_floor" "0")
      (set_tile "chk_block" "0")
      (set_tile "o_mark" (if (member "МАРКА" *bp:opt-on*) "1" "0"))
      (set_tile "o_prod" (if (member "ПРОИЗВОДИТЕЛЬ" *bp:opt-on*) "1" "0"))
      (set_tile "o_blk" (if (member "БЛОК" *bp:opt-on*) "1" "0"))
      (bp:fill)
      (action_tile "flt"   "(setq *bp:mask* (if (= $value \"\") \"*\" $value)) (bp:fill)")
      (action_tile "b_flt" "(setq *bp:mask* (get_tile \"flt\")) (if (= *bp:mask* \"\") (setq *bp:mask* \"*\")) (bp:fill)")
      (action_tile "b_all"  "(bp:select-all T)")
      (action_tile "b_none" "(bp:select-all nil)")
      (action_tile "accept"
        "(setq sel (get_tile \"lst\") *bp:dup-floor* (= (get_tile \"chk_floor\") \"1\") *bp:dup-block* (= (get_tile \"chk_block\") \"1\") *bp:opt-on* (vl-remove nil (list (if (= (get_tile \"o_mark\") \"1\") \"МАРКА\") (if (= (get_tile \"o_prod\") \"1\") \"ПРОИЗВОДИТЕЛЬ\") (if (= (get_tile \"o_blk\") \"1\") \"БЛОК\")))) (done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)
      (vl-file-delete fn)
      (if (and (= res 1) sel (/= sel ""))
        (mapcar '(lambda (i) (car (nth i *bp:shown*)))
                (read (strcat "(" sel ")")))))))

;;; ---------- анализ ----------
;; -> список (запись . список_ошибок)
;; ключ дубля: ПОЗИЦИЯ [+ ЭТАЖ] [+ БЛОК] в зависимости от галочек
(defun bp:dup-key (al / pos)
  (setq pos (bp:get *bp:tag-pos* al))
  (if (= pos "") ""
    (strcat pos
            (if *bp:dup-floor* (strcat "\n" (bp:get "ЭТАЖ" al)) "")
            (if *bp:dup-block* (strcat "\n" (bp:get "БЛОК" al)) ""))))

(defun bp:check (recs / cnt p pos key errs res)
  ;; счётчик ключей дублей
  (foreach r recs
    (setq key (bp:dup-key (caddr r)))
    (if (/= key "")
      (if (setq p (assoc key cnt))
        (setq cnt (subst (cons key (1+ (cdr p))) p cnt))
        (setq cnt (cons (cons key 1) cnt)))))
  (foreach r recs
    (setq errs nil)
    (foreach tg (bp:req-on)
      (if (= (bp:get tg (caddr r)) "")
        (setq errs (cons (strcat "пусто " tg) errs))))
    (setq pos (bp:get *bp:tag-pos* (caddr r))
          key (bp:dup-key (caddr r)))
    (if (and (/= key "") (> (cdr (assoc key cnt)) 1))
      (setq errs (cons (strcat "дубль " pos " (x" (itoa (cdr (assoc key cnt))) ")") errs)))
    (if errs (setq res (cons (cons r (reverse errs)) res))))
  ;; сортировка по позиции
  (vl-sort res '(lambda (a b) (< (bp:get *bp:tag-pos* (caddr (car a)))
                                 (bp:get *bp:tag-pos* (caddr (car b))))))
  )

;;; ---------- рисование маркера ----------
(defun bp:mark (item / r p1 p2 dx dy pad h sp pl txt a b)
  (setq r (car item) p1 (nth 3 r) p2 (nth 4 r)
        dx (- (car p2) (car p1)) dy (- (cadr p2) (cadr p1))
        pad (max (* 0.15 (max dx dy)) 1.0)
        h   (max (* 0.12 (max dx dy)) 1.5)
        a   (list (- (car p1) pad) (- (cadr p1) pad))
        b   (list (+ (car p2) pad) (+ (cadr p2) pad))
        sp  (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object))))
  ;; рамка - отдельная полилиния на слое проверки (блок не трогаем)
  (setq pl (vlax-invoke sp 'AddLightWeightPolyline
             (list (car a) (cadr a) (car b) (cadr a)
                   (car b) (cadr b) (car a) (cadr b))))
  (vla-put-Closed pl :vlax-true)
  (vla-put-ConstantWidth pl (* h 0.15))
  (vla-put-Layer pl *bp:layer*)
  (vla-put-Color pl 256)                 ; ПоСлою
  ;; подпись над рамкой
  (setq txt (vla-AddText sp (bp:join (cdr item) "; ")
                         (vlax-3d-point (list (car a) (+ (cadr b) (* h 0.5)) 0.0)) h))
  (vla-put-Layer txt *bp:layer*)
  (vla-put-Color txt 256))

;;; ---------- диалог со списком ошибок и правкой атрибутов ----------
(defun bp:write-dcl (/ fn f)
  (setq fn (vl-filename-mktemp "blok_proverka.dcl") f (bp:open-dcl fn))
  (foreach l
    '("bp_dlg : dialog { label = \"Проверка атрибутов - найденные ошибки\";"
      " : text { key = \"t_hdr\"; width = 120; }"
      " : list_box { key = \"lst\"; multiple_select = true; height = 18; width = 120; tabs = \"5 18 60\"; }"
      " : row { : button { key = \"b_all\"; label = \"Выделить все\"; }"
      "         : button { key = \"b_none\"; label = \"Снять выделение\"; }"
      "         : button { key = \"b_show\"; label = \"Показать на чертеже\"; } }"
      " : text { key = \"t_det\"; }"
      " : list_box { key = \"det\"; height = 9; width = 120; tabs = \"22\"; }"
      " : boxed_column { label = \"Изменить атрибут у выделенных блоков\";"
      "   : row { : popup_list { key = \"tag\"; width = 30; fixed_width = true; }"
      "           : edit_box { key = \"val\"; edit_width = 50; allow_accept = false; }"
      "           : button { key = \"b_apply\"; label = \"Применить к выделенным\"; width = 26; fixed_width = true; } }"
      "   : text { key = \"msg\"; width = 110; } }"
      " : row { : spacer { width = 1; }"
      "         : button { key = \"cancel\"; label = \"Закрыть\"; is_cancel = true; width = 16; fixed_width = true; } }"
      "}")
    (write-line l f))
  (close f)
  fn)

;; индексы из строки list_box "0 3 5" -> (0 3 5)
(defun bp:idx (s) (if (and s (/= s "")) (read (strcat "(" s ")"))))

(defun bp:detail (idx / it)
  (start_list "det")
  (if (setq it (nth idx *bp:res*))
    (progn
      (add_list (strcat "Блок:\t" (cadr (car it))))
      (add_list (strcat "Ошибки:\t" (bp:join (cdr it) "; ")))
      (foreach a (caddr (car it))
        (add_list (strcat (car a) ":\t" (if (= (cdr a) "") "<пусто>" (cdr a)))))))
  (end_list))

;; клик по строке атрибута -> подставить тег и значение в поля правки
(defun bp:det-pick (row / it a i)
  (if (and (setq it (nth (cond ((car (bp:idx (get_tile "lst")))) (0)) *bp:res*))
           (>= row 2)
           (setq a (nth (- row 2) (caddr (car it)))))
    (progn
      (if (setq i (vl-position (car a) *bp:tags*)) (set_tile "tag" (itoa i)))
      (set_tile "val" (cdr a)))))

;; список тегов для правки: обязательные + все теги найденных блоков
(defun bp:make-tags (/ l)
  (setq l *bp:req*)
  (foreach it *bp:res*
    (foreach a (caddr (car it))
      (if (not (member (car a) l)) (setq l (append l (list (car a)))))))
  l)

;; записать значение атрибута в блоки; -> (изменено . пропущено)
(defun bp:set-attr (enames tag val / o ok n skip)
  (setq n 0 skip 0)
  (foreach e enames
    (setq ok nil)
    (if (and (entget e) (setq o (vlax-ename->vla-object e)))
      (foreach a (vlax-invoke o 'GetAttributes)
        (if (= (strcase (vla-get-TagString a)) tag)
          (progn (vla-put-TextString a val) (setq ok T)))))
    (if ok (setq n (1+ n)) (setq skip (1+ skip))))
  (cons n skip))

;; повторная проверка: перечитать атрибуты, пересчитать ошибки, перерисовать подсветку
(defun bp:recheck (/ o mn mx lst)
  (foreach r *bp:recs*
    (if (entget (car r))
      (progn
        (setq o (vlax-ename->vla-object (car r)))
        (vla-GetBoundingBox o 'mn 'mx)
        (setq lst (cons (list (car r) (cadr r) (bp:attrs o)
                              (vlax-safearray->list mn) (vlax-safearray->list mx))
                        lst)))))
  (setq *bp:recs* (reverse lst))
  (bp:clear)
  (setq *bp:res* (bp:check *bp:recs*))
  (if *bp:res*
    (progn (bp:make-layer) (foreach it *bp:res* (bp:mark it)))))

(defun bp:fill-list (/ n)
  (setq n 0)
  (start_list "lst")
  (foreach it *bp:res*
    (add_list (strcat (itoa (setq n (1+ n))) "\t"
                      (bp:get *bp:tag-pos* (caddr (car it))) "\t"
                      (cadr (car it)) "\t"
                      (bp:join (cdr it) "; "))))
  (end_list)
  (set_tile "t_hdr" (strcat "Блоков с ошибками: " (itoa (length *bp:res*))
                            " из " (itoa (length *bp:recs*))
                            "   (№ / Позиция / Имя блока / Ошибки)")))

(defun bp:sel-all (on / s i)
  (setq s "" i 0)
  (if on (repeat (length *bp:res*) (setq s (strcat s (itoa i) " ") i (1+ i))))
  (set_tile "lst" s))

(defun bp:dialog (/ fn id res sel tagi val msg enames r n fixed)
  (setq sel "0" res 2 tagi "0" val "" msg "Выделите один или несколько блоков, выберите атрибут, введите значение и нажмите \"Применить\"."
        fn (bp:write-dcl))
  (while (member res '(2 3))
    (setq *bp:tags* (bp:make-tags)
          id (load_dialog fn))
    (if (not (new_dialog "bp_dlg" id))
      (setq res 0)
      (progn
        (set_tile "t_det" "Все атрибуты первого выделенного блока (щелчок по строке - в поле правки):")
        (start_list "tag") (foreach t1 *bp:tags* (add_list t1)) (end_list)
        (bp:fill-list)
        (set_tile "lst" sel)
        (set_tile "tag" tagi)
        (set_tile "val" val)
        (set_tile "msg" msg)
        (bp:detail (cond ((car (bp:idx sel))) (0)))
        (if (null *bp:res*) (mode_tile "b_apply" 1))
        (action_tile "lst"
          "(bp:detail (cond ((car (bp:idx $value))) (0))) (if (= $reason 4) (progn (setq sel $value) (done_dialog 2)))")
        (action_tile "det" "(bp:det-pick (atoi $value))")
        (action_tile "b_all"  "(bp:sel-all T)")
        (action_tile "b_none" "(bp:sel-all nil)")
        (action_tile "b_show" "(setq sel (get_tile \"lst\")) (done_dialog 2)")
        (action_tile "b_apply"
          "(setq sel (get_tile \"lst\") tagi (get_tile \"tag\") val (get_tile \"val\")) (done_dialog 3)")
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (cond
          ;; показать первый выделенный блок
          ((= res 2)
           (if (and (bp:idx sel) (setq r (nth (car (bp:idx sel)) *bp:res*))) (bp:zoom (car r))))
          ;; применить значение атрибута и перепроверить
          ((= res 3)
           (setq enames (mapcar '(lambda (i) (car (car (nth i *bp:res*)))) (bp:idx sel)))
           (if (null enames)
             (setq msg "Не выделено ни одного блока.")
             (progn
               (setq r (bp:set-attr enames (nth (atoi tagi) *bp:tags*) (bp:trim val)))
               (bp:recheck)
               ;; сколько отредактированных блоков теперь без ошибок
               (setq fixed 0 sel "" n 0)
               (foreach e enames
                 (if (not (vl-some '(lambda (it) (eq (car (car it)) e)) *bp:res*))
                   (setq fixed (1+ fixed))))
               ;; оставить выделенными те, что ещё с ошибками
               (foreach it *bp:res*
                 (if (member (car (car it)) enames) (setq sel (strcat sel (itoa n) " ")))
                 (setq n (1+ n)))
               (if (= sel "") (setq sel "0"))
               (setq msg (strcat (nth (atoi tagi) *bp:tags*) " = \"" (bp:trim val) "\": изменено блоков "
                                 (itoa (car r))
                                 (if (> (cdr r) 0) (strcat ", без такого атрибута " (itoa (cdr r))) "")
                                 ". Повторная проверка: исправлено " (itoa fixed)
                                 ", осталось с ошибками " (itoa (- (length enames) fixed)) "."))
               (princ (strcat "\n" msg)))))))))
  (vl-file-delete fn)
  (if (null *bp:res*) (princ "\nВсе проверенные блоки без ошибок, подсветка снята.")))

(defun bp:zoom (r / p1 p2 d)
  (setq p1 (nth 3 r) p2 (nth 4 r)
        d  (* 3.0 (max (- (car p2) (car p1)) (- (cadr p2) (cadr p1)) 1.0)))
  (vla-ZoomWindow (vlax-get-acad-object)
                  (vlax-3d-point (list (- (car p1) d) (- (cadr p1) d) 0.0))
                  (vlax-3d-point (list (+ (car p2) d) (+ (cadr p2) d) 0.0)))
  (sssetfirst nil (ssadd (car r)))
  (getstring "\nБлок показан. Enter - вернуться к списку: ")
  (sssetfirst nil nil))

;;; ---------- включить / отключить ----------
(defun bp:on (/ recs names p sel)
  (bp:clear)
  (setq recs (bp:collect))
  (foreach r recs
    (if (setq p (assoc (cadr r) names))
      (setq names (subst (cons (cadr r) (1+ (cdr p))) p names))
      (setq names (cons (cons (cadr r) 1) names))))
  (setq *bp:names* (vl-sort names '(lambda (a b) (< (strcase (car a)) (strcase (car b))))))
  (cond
    ((null recs) (princ "\nВ пространстве Модели нет блоков с атрибутами."))
    ((null (setq sel (bp:sel-dialog))) (princ "\nБлоки не выбраны, проверка отменена."))
    (T
      (setq *bp:recs* (vl-remove-if-not '(lambda (r) (member (cadr r) sel)) recs))
      (setq *bp:res* (bp:check *bp:recs*))
      (if (null *bp:res*)
        (princ (strcat "\nПроверено блоков: " (itoa (length *bp:recs*)) ". Ошибок не найдено."))
        (progn
          (bp:make-layer)
          (foreach it *bp:res* (bp:mark it))
          (princ (strcat "\nПроверено блоков: " (itoa (length *bp:recs*))
                         ", с ошибками: " (itoa (length *bp:res*))
                         ". Подсветка на слое " *bp:layer* "."))
          (bp:dialog))))))

(defun bp:off (/ n)
  (setq n (bp:clear) *bp:res* nil)
  (princ (strcat "\nПодсветка снята, удалено объектов: " (itoa n) ".")))

(defun bp:main (/ *error* doc k)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*"))
      (princ (strcat "\nОшибка: " m)))
    (vla-EndUndoMark doc)
    (princ))
  (initget "Включить Отключить")
  (setq k (getkword "\nПроверка атрибутов [Включить/Отключить] <Включить>: "))
  (vla-StartUndoMark doc)
  (if (= k "Отключить") (bp:off) (bp:on))
  (vla-EndUndoMark doc)
  (princ))

(defun c:мм_проверка () (bp:main))
(defun c:ММ_ПРОВЕРКА () (bp:main))
(defun c:MM_CHECK () (bp:main))

;;; ---------- сообщение при загрузке ----------
(princ "\n==================================================================")
(princ "\n MM_CHECK.LSP загружен (Этап 2: проверка атрибутов)")
(princ "\n  ММ_ПРОВЕРКА / MM_CHECK [Включить/Отключить]:")
(princ "\n    Включить  - окно выбора блоков (фильтр *) -> ОК -> пустые ПОЗИЦИЯ/НАИМЕНОВАНИЕ/МАРКА/ПРОИЗВОДИТЕЛЬ/")
(princ "\n                ЭТАЖ/БЛОК и дубли ПОЗИЦИЙ -> рамки на слое")
(princ "\n                _ПРОВЕРКА_АТРИБУТОВ (не печатается) + окно списка.")
(princ "\n                В окне: правка атрибута у группы блоков + перепроверка.")
(princ "\n    Отключить - удалить подсветку.")
(princ "\n==================================================================")
(princ)
