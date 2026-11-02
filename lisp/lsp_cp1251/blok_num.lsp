;;; ======================================================================
;;;  MM_NUMBERING.LSP  —  Этап 3: автоматическая нумерация блоков по любому атрибуту
;;;  (по умолчанию ПОЗИЦИЯ), с учётом этажа или без
;;;  AutoCAD 2024. Кодировка файла: Windows-1251 (ANSI).
;;; ----------------------------------------------------------------------
;;;  КОМАНДЫ:
;;;   ММ_НУМЕРАЦИЯ (или MM_NUMBERING) - нумерация блоков:
;;;     0. Можно заранее выделить область/блоки на чертеже - тогда в окне
;;;        будут только блоки из выделения. Без выделения - весь текущий лист
;;;        (Модель или текущий Лист).
;;;     1. В окне: "Атрибут" - какой атрибут нумеровать (список атрибутов
;;;        найденных блоков, по умолчанию ПОЗИЦИЯ);
;;;        фильтр-маска по имени блока (* ? ,) -> выделите типы блоков.
;;;     1а. "С учётом этажа": этаж берётся из атрибута (по умолчанию ЭТАЖ);
;;;        блоки нумеруются по этажам (этажи по возрастанию), в маске {Э} -
;;;        номер этажа (AS-{Э}.#  ->  AS-2.1, AS-2.2 ...); галочка "на каждом
;;;        этаже с начала" - нумерация каждого этажа с "Начать с".
;;;        Перед нумерацией проверяется, у всех ли выбранных блоков задан этаж;
;;;        если нет - окно: список блоков без этажа, "Задать выделенным",
;;;        "Задать всем", "Показать"; оставшиеся без этажа не нумеруются.
;;;     2. Формат номера (маска): # - номер, ## - 01, ### - 001.
;;;        Примеры: AS-#   AS-##   КД1.#   #   (без # номер ставится в конец).
;;;        По умолчанию подставляется последний заданный формат (хранится
;;;        в чертеже), иначе - значение ПОЗИЦИИ по умолчанию из блока + "-#".
;;;        "Начать с" / "Шаг" - первый номер и приращение. Если формат не
;;;        менялся, "Начать с" продолжает предыдущую нумерацию.
;;;     3. Способ нумерации:
;;;        - по порядку: слева направо, сверху вниз (по строкам);
;;;        - по порядку: сверху вниз, слева направо (по столбцам);
;;;        - по порядку указания блоков на чертеже (Enter - конец);
;;;        - по полилинии: укажите полилинию (линию, дугу, сплайн); нумеруются
;;;          блоки, лежащие на ней и под ней (в пределах "Допуска").
;;;          Направление: от конца, ближайшего к точке указания / от начала /
;;;          от конца полилинии.
;;;        "Допуск" - расстояние до полилинии, а для нумерации по порядку -
;;;        разброс по высоте (ширине), при котором блоки считаются в одной
;;;        строке (столбце).
;;;     4. Если у блока уже стоит номер, отличный от значения по умолчанию,
;;;        откроется окно решений: Заменить / Оставить - по каждому блоку
;;;        или для всех сразу; "Показать" - зум на блок.
;;;        Галочка "Оставленные ... не занимают номер":
;;;          снята (по умолчанию) - оставленный блок занимает своё место
;;;            в нумерации (AS-4, [AS-5 оставлен], AS-6 ...);
;;;          стоит - нумерация идёт без оставленных блоков, а их номера
;;;            пропускаются, чтобы не было дублей.
;;;   ММ_ЭТАЖИ (MM_FLOORS) - короткие обозначения этажей/отметок для {Э}:
;;;     1 этаж -> 1, паркинг -1 -> П1, подвал -> Пв, чердак -> Ч, кровля -> К;
;;;     правятся в окне, хранятся в чертеже. То же окно - кнопка "Коротко..."
;;;     в окне нумерации. Порядок этажей: паркинг, подвал, 1, 2 ..., чердак, кровля.
;;;   Вся нумерация отменяется одним ОТМЕНИТЬ (U).
;;; ======================================================================

(vl-load-com)

;;; ---------- настройки ----------
(if (not *bn:tag*) (setq *bn:tag* "ПОЗИЦИЯ"))
(setq *bn:dict* "MM_NUMBERING")                    ; словарь в чертеже для настроек
(if (not *bn:fltag*) (setq *bn:fltag* "ЭТАЖ"))
(if (not *bn:flrst*) (setq *bn:flrst* "1"))                    ; словарь в чертеже для настроек
(if (not *bn:flt*)    (setq *bn:flt* "*"))
(if (not *bn:step*)   (setq *bn:step* 1))
(if (not *bn:method*) (setq *bn:method* "m_lr"))
(if (not *bn:dir*)    (setq *bn:dir* "d_near"))
(if (not *bn:tol*)    (setq *bn:tol* 5.0))

;;; ---------- утилиты ----------
(defun bn:trim (s) (vl-string-trim " \t" (if s s "")))

(defun bn:bname (o / r)
  (setq r (vl-catch-all-apply 'vla-get-EffectiveName (list o)))
  (if (vl-catch-all-error-p r) (vla-get-Name o) r))

(defun bn:att (o tag / r)
  (foreach a (vlax-invoke o 'GetAttributes)
    (if (= (strcase (vla-get-TagString a)) (strcase tag)) (setq r a)))
  r)
(defun bn:posatt (o) (bn:att o *bn:tag*))
(defun bn:attval (e tag / a)
  (if (setq a (bn:att (vlax-ename->vla-object e) tag)) (bn:trim (vla-get-TextString a)) ""))
(defun bn:tags (o) (mapcar '(lambda (a) (strcase (vla-get-TagString a))) (vlax-invoke o 'GetAttributes)))

(defun bn:curval (e / a)
  (if (setq a (bn:posatt (vlax-ename->vla-object e))) (bn:trim (vla-get-TextString a)) ""))

;; значение ПОЗИЦИИ по умолчанию из определения блока (кэшируется)
(defun bn:defval (name / p blk r)
  (if (setq p (assoc (strcat name "|" *bn:tag*) *bn:defs*))
    (cdr p)
    (progn
      (setq blk (vl-catch-all-apply 'vla-Item
                  (list (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))) name))
            r "")
      (if (not (vl-catch-all-error-p blk))
        (vlax-for ob blk
          (if (and (= (vla-get-ObjectName ob) "AcDbAttributeDefinition")
                   (= (strcase (vla-get-TagString ob)) *bn:tag*))
            (setq r (bn:trim (vla-get-TextString ob))))))
      (setq *bn:defs* (cons (cons (strcat name "|" *bn:tag*) r) *bn:defs*))
      r)))

;; {Э} в маске -> номер этажа
(defun bn:flvals (recs tag / l v)
  (foreach r recs (setq v (bn:attval (car r) tag)) (if (and (/= v "") (not (member v l))) (setq l (cons v l))))
  l)
(defun bn:flmask (m fl / i)
  (while (setq i (vl-string-search "{Э}" m)) (setq m (strcat (substr m 1 i) fl (substr m (+ i 4)))))
  m)
;; маска -> номер:  "AS-##", 5 -> "AS-05"
(defun bn:fmt (mask n / i j s)
  (if (null (setq i (vl-string-search "#" mask)))
    (strcat mask (itoa n))
    (progn
      (setq j i)
      (while (= (substr mask (+ j 1) 1) "#") (setq j (1+ j)))
      (setq s (itoa n))
      (while (< (strlen s) (- j i)) (setq s (strcat "0" s)))
      (strcat (substr mask 1 i) s (substr mask (+ j 1))))))

(defun bn:open-dcl (fn / f)
  ;; кодировка DCL по LISPSYS: 1 - UTF-8 с BOM, 0 - ANSI
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0))
    (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  f)

(defun bn:write-dcl (name lines / fn f)
  (setq fn (vl-filename-mktemp name) f (bn:open-dcl fn))
  (foreach l lines (write-line l f))
  (close f)
  fn)

(defun bn:idx (s) (if (and s (/= s "")) (read (strcat "(" s ")"))))

(defun bn:2d (p) (list (car p) (cadr p) 0.0))

;;; ---------- сбор блоков ----------
;; запись: (ename имя точка_вставки мин_габарит макс_габарит)
(defun bn:collect (ss / i e o mn mx res)
  (if ss
    (repeat (setq i (sslength ss))
      (setq e (ssname ss (setq i (1- i)))
            o (vlax-ename->vla-object e))
      (if (vlax-invoke o 'GetAttributes)
        (progn
          (foreach tg (bn:tags o) (if (not (member tg *bn:alltags*)) (setq *bn:alltags* (cons tg *bn:alltags*))))
          (vla-GetBoundingBox o 'mn 'mx)
          (setq res (cons (list e (bn:bname o)
                                (bn:2d (cdr (assoc 10 (entget e))))
                                (vlax-safearray->list mn)
                                (vlax-safearray->list mx))
                          res))))))
  res)

;;; ---------- главное окно ----------
(defun bn:main-dcl ()
  (bn:write-dcl "blok_num.dcl"
    '("bn_dlg : dialog { label = \"Нумерация блоков по атрибуту\";"
      " : text { key = \"t_src\"; width = 70; }"
      " : popup_list { key = \"tag\"; label = \"Нумеровать атрибут:\"; width = 50; }"
      " : row { : edit_box { key = \"flt\"; label = \"Фильтр (маска):\"; edit_width = 35; allow_accept = false; }"
      "         : button { key = \"b_flt\"; label = \"Применить\"; width = 14; fixed_width = true; } }"
      " : list_box { key = \"lst\"; multiple_select = true; height = 14; width = 70; }"
      " : row { : button { key = \"b_all\"; label = \"Выделить все\"; }"
      "         : button { key = \"b_none\"; label = \"Снять выделение\"; } }"
      " : boxed_column { label = \"Формат номера\";"
      "   : row { : edit_box { key = \"mask\"; label = \"Маска:\"; edit_width = 18; allow_accept = false; }"
      "           : edit_box { key = \"start\"; label = \"Начать с:\"; edit_width = 6; allow_accept = false; }"
      "           : edit_box { key = \"step\"; label = \"Шаг:\"; edit_width = 4; allow_accept = false; } }"
      "   : text { label = \"# - номер,  ## - 01,  ### - 001.   Примеры: AS-#   КД1.##\"; }"
      "   : text { key = \"t_ex\"; }"
      "   : row { : toggle { key = \"fl_on\"; label = \"С учётом этажа, атрибут:\"; }"
      "           : edit_box { key = \"fl_tag\"; edit_width = 12; allow_accept = false; }"
      "           : toggle { key = \"fl_rst\"; label = \"на каждом этаже с начала\"; }"
      "           : button { key = \"b_sh\"; label = \"Коротко...\"; } }"
      "   : text { label = \"{Э} в маске - короткое обозначение этажа:  S-{Э}.#  ->  S-1.2,  S-П1.2,  S-К.1\"; }"
      "   : toggle { key = \"chk_keep\"; label = \"Оставленные с прежним номером блоки не занимают номер в нумерации\"; } }"
      " : boxed_radio_column { key = \"method\"; label = \"Способ нумерации\";"
      "   : radio_button { key = \"m_lr\"; label = \"По порядку: слева направо, сверху вниз\"; }"
      "   : radio_button { key = \"m_tb\"; label = \"По порядку: сверху вниз, слева направо\"; }"
      "   : radio_button { key = \"m_pick\"; label = \"По порядку указания блоков на чертеже\"; }"
      "   : radio_button { key = \"m_pl\"; label = \"По полилинии (блоки на ней и под ней)\"; } }"
      " : boxed_radio_column { key = \"dir\"; label = \"Направление по полилинии\";"
      "   : radio_button { key = \"d_near\"; label = \"От конца, ближайшего к точке указания полилинии\"; }"
      "   : radio_button { key = \"d_start\"; label = \"От начала полилинии\"; }"
      "   : radio_button { key = \"d_end\"; label = \"От конца полилинии\"; } }"
      " : edit_box { key = \"tol\"; label = \"Допуск (до полилинии / разброс строки), ед. чертежа:\"; edit_width = 8; allow_accept = false; }"
      " : text { key = \"info\"; width = 70; }"
      " : row { : button { key = \"accept\"; label = \"Нумеровать\"; is_default = true; width = 18; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 18; } } }")))

(defun bn:fill ()
  (setq *bn:shown* nil)
  (foreach p *bn:names*
    (if (wcmatch (strcase (car p)) (strcase *bn:flt*))
      (setq *bn:shown* (cons p *bn:shown*))))
  (setq *bn:shown* (reverse *bn:shown*))
  (start_list "lst")
  (foreach p *bn:shown*
    (add_list (strcat (car p) "   (" (itoa (cdr p)) " шт., по умолчанию: "
                      (if (= (bn:defval (car p)) "") "<пусто>" (bn:defval (car p))) ")")))
  (end_list))

(defun bn:sel-all (on / s i)
  (setq s "" i 0)
  (if on (repeat (length *bn:shown*) (setq s (strcat s (itoa i) " ") i (1+ i))))
  (set_tile "lst" s)
  (bn:auto-mask s))

;; пока маску не задавали - подставлять ПОЗИЦИЮ по умолчанию первого выбранного типа
(defun bn:auto-mask (sel / i)
  (if (and (not *bn:mask-set*) (setq i (car (bn:idx sel))))
    (set_tile "mask" (strcat (bn:defval (car (nth i *bn:shown*))) "-#")))
  (bn:example))

(defun bn:example (/ m s)
  (setq m (bn:flmask (get_tile "mask") "2") s (atoi (get_tile "start")))
  (set_tile "t_ex" (if (= m "") ""
                     (strcat "Результат: " (bn:fmt m s) ", " (bn:fmt m (+ s (max 1 (atoi (get_tile "step"))))) ", ..."))))

(defun bn:accept (/ sel m st sp tl)
  (setq sel (bn:idx (get_tile "lst"))
        m   (bn:trim (get_tile "mask"))
        st  (atoi (get_tile "start"))
        sp  (atoi (get_tile "step"))
        tl  (distof (get_tile "tol")))
  (cond
    ((null sel) (set_tile "info" "Выделите хотя бы один тип блока."))
    ((and (= (get_tile "fl_on") "1") (= (bn:trim (get_tile "fl_tag")) "")) (set_tile "info" "Укажите атрибут этажа."))
    ((= m "")   (set_tile "info" "Задайте маску номера."))
    ((< sp 1)   (set_tile "info" "Шаг должен быть целым числом >= 1."))
    ((or (null tl) (< tl 0)) (set_tile "info" "Допуск должен быть числом >= 0."))
    (T
      (setq *bn:sel*    (mapcar '(lambda (i) (car (nth i *bn:shown*))) sel)
            *bn:mask*   m
            *bn:start*  st
            *bn:step*   sp
            *bn:tol*    tl
            *bn:method* (get_tile "method")
            *bn:dir*    (get_tile "dir")
            *bn:keepfree* (= (get_tile "chk_keep") "1")
            *bn:tag*    (nth (atoi (get_tile "tag")) *bn:alltags*)
            *bn:flon*   (= (get_tile "fl_on") "1")
            *bn:fltag*  (strcase (bn:trim (get_tile "fl_tag")))
            *bn:flrst*  (get_tile "fl_rst"))
      (done_dialog 1))))

(defun bn:dialog (srctxt presel / fn id res m nx)
  (if (not (member *bn:tag* *bn:alltags*)) (setq *bn:tag* (if (member "ПОЗИЦИЯ" *bn:alltags*) "ПОЗИЦИЯ" (car *bn:alltags*))))
  ;; последний формат и следующий номер хранятся в чертеже
  (setq m  (vlax-ldata-get *bn:dict* (strcat "mask|" *bn:tag*))
        nx (vlax-ldata-get *bn:dict* (strcat "next|" *bn:tag*))
        *bn:mask-set* (and m (/= m ""))
        *bn:sel* nil)
  (setq fn (bn:main-dcl) id (load_dialog fn))
  (if (not (new_dialog "bn_dlg" id))
    (princ "\nОшибка загрузки диалога.")
    (progn
      (set_tile "t_src" srctxt)
      (set_tile "flt" *bn:flt*)
      (bn:fill)
      (set_tile "mask" (if *bn:mask-set* m ""))
      (set_tile "start" (itoa (if (and *bn:mask-set* nx) nx 1)))
      (set_tile "step" (itoa *bn:step*))
      (set_tile "method" *bn:method*)
      (set_tile "dir" *bn:dir*)
      (mode_tile "dir" (if (= *bn:method* "m_pl") 0 1))
      (set_tile "tol" (rtos *bn:tol* 2 2))
      (set_tile "chk_keep" (if *bn:keepfree* "1" "0"))
      (start_list "tag") (foreach tg *bn:alltags* (add_list tg)) (end_list)
      (set_tile "tag" (itoa (cond ((vl-position *bn:tag* *bn:alltags*)) (0))))
      (set_tile "fl_on" (if *bn:flon* "1" "0"))
      (set_tile "fl_tag" *bn:fltag*)
      (set_tile "fl_rst" *bn:flrst*)
      (mode_tile "fl_tag" (if *bn:flon* 0 1)) (mode_tile "fl_rst" (if *bn:flon* 0 1)) (mode_tile "b_sh" (if *bn:flon* 0 1))
      (action_tile "b_sh" "(bn:short-dialog (bn:flvals *bn:allrecs* (strcase (bn:trim (get_tile \"fl_tag\")))))")
      (action_tile "fl_on" "(mode_tile \"fl_tag\" (if (= $value \"1\") 0 1)) (mode_tile \"fl_rst\" (if (= $value \"1\") 0 1)) (mode_tile \"b_sh\" (if (= $value \"1\") 0 1))")
      (action_tile "tag" "(setq *bn:tag* (nth (atoi $value) *bn:alltags*) *bn:defs* nil) (bn:fill) (if (not *bn:mask-set*) (bn:auto-mask (get_tile \"lst\")))")
      (if presel (bn:sel-all T) (bn:example))
      (action_tile "flt"   "(setq *bn:flt* (if (= $value \"\") \"*\" $value)) (bn:fill)")
      (action_tile "b_flt" "(setq *bn:flt* (get_tile \"flt\")) (if (= *bn:flt* \"\") (setq *bn:flt* \"*\")) (bn:fill)")
      (action_tile "lst"   "(bn:auto-mask $value)")
      (action_tile "b_all" "(bn:sel-all T)")
      (action_tile "b_none" "(bn:sel-all nil)")
      (action_tile "mask"  "(setq *bn:mask-set* T) (bn:example)")
      (action_tile "start" "(bn:example)")
      (action_tile "step"  "(bn:example)")
      (action_tile "method" "(mode_tile \"dir\" (if (= $value \"m_pl\") 0 1))")
      (action_tile "accept" "(bn:accept)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)))
  (vl-file-delete fn)
  (if (= res 1) *bn:sel*))

;;; ---------- упорядочивание ----------
(defun bn:order-xy (recs mode tol)
  (vl-sort recs
    (if (= mode "m_lr")
      '(lambda (a b / pa pb)            ; строки: сверху вниз, в строке слева направо
         (setq pa (caddr a) pb (caddr b))
         (if (> (abs (- (cadr pa) (cadr pb))) tol)
           (> (cadr pa) (cadr pb))
           (< (car pa) (car pb))))
      '(lambda (a b / pa pb)            ; столбцы: слева направо, в столбце сверху вниз
         (setq pa (caddr a) pb (caddr b))
         (if (> (abs (- (car pa) (car pb))) tol)
           (< (car pa) (car pb))
           (> (cadr pa) (cadr pb)))))))

(defun bn:order-pick (recs / es r lst k done)
  (setq k 0)
  (princ "\nУказывайте блоки в порядке нумерации.")
  (while (not done)
    (setvar "ERRNO" 0)
    (setq es (entsel (strcat "\nБлок " (bn:fmt *bn:mask* (+ *bn:start* (* k *bn:step*)))
                             " (Enter - завершить): ")))
    (cond
      ((and (null es) (= (getvar "ERRNO") 7)) (princ "\nПромах, повторите."))
      ((null es) (setq done T))
      ((setq r (vl-some '(lambda (x) (if (eq (car x) (car es)) x)) recs))
       (if (member r lst)
         (princ "\nЭтот блок уже указан.")
         (progn (setq lst (cons r lst) k (1+ k)) (redraw (car r) 3))))
      (T (princ "\nЭто не блок из выбранных типов."))))
  (foreach r lst (redraw (car r) 4))
  (reverse lst))

(defun bn:curve-p (o)
  (not (vl-catch-all-error-p (vl-catch-all-apply 'vlax-curve-getEndParam (list o)))))

(defun bn:order-pl (recs tol / es o pk len rev res cp c d)
  (while (and (null o) (setq es (entsel "\nУкажите полилинию нумерации: ")))
    (if (bn:curve-p (vlax-ename->vla-object (car es)))
      (setq o (vlax-ename->vla-object (car es)) pk (trans (cadr es) 1 0))
      (princ "\nЭто не полилиния / линия / дуга / сплайн.")))
  (if o
    (progn
      (setq len (vlax-curve-getDistAtParam o (vlax-curve-getEndParam o))
            rev (cond ((= *bn:dir* "d_start") nil)
                      ((= *bn:dir* "d_end") T)
                      (T (< (distance (bn:2d pk) (bn:2d (vlax-curve-getEndPoint o)))
                            (distance (bn:2d pk) (bn:2d (vlax-curve-getStartPoint o)))))))
      (foreach r recs
        ;; 1) точка вставки в пределах допуска от полилинии
        (setq cp (vlax-curve-getClosestPointToProjection o (caddr r) '(0.0 0.0 1.0)))
        (if (> (distance (bn:2d cp) (caddr r)) tol)
          ;; 2) полилиния проходит через габарит блока ("под блоком")
          (progn
            (setq c  (bn:2d (mapcar '(lambda (a b) (/ (+ a b) 2.0)) (nth 3 r) (nth 4 r)))
                  cp (vlax-curve-getClosestPointToProjection o c '(0.0 0.0 1.0)))
            (if (not (and (<= (- (car (nth 3 r)) tol) (car cp) (+ (car (nth 4 r)) tol))
                          (<= (- (cadr (nth 3 r)) tol) (cadr cp) (+ (cadr (nth 4 r)) tol))))
              (setq cp nil))))
        (if (and cp (setq d (vlax-curve-getDistAtPoint o cp)))
          (setq res (cons (cons (if rev (- len d) d) r) res))))
      (mapcar 'cdr (vl-sort res '(lambda (a b) (< (car a) (car b))))))))

;;; ---------- окно решений по уже пронумерованным ----------
(defun bn:conf-dcl ()
  (bn:write-dcl "blok_num_conf.dcl"
    '("bn_conf : dialog { label = \"Блоки с уже присвоенным номером\";"
      " : text { key = \"hdr\"; width = 100; }"
      " : list_box { key = \"lst\"; multiple_select = true; height = 18; width = 100; tabs = \"5 22 40 78\"; }"
      " : row { : button { key = \"b_rep\"; label = \"Заменить выделенные\"; }"
      "         : button { key = \"b_keep\"; label = \"Оставить выделенные\"; }"
      "         : button { key = \"b_repall\"; label = \"Заменить все\"; }"
      "         : button { key = \"b_keepall\"; label = \"Оставить все\"; }"
      "         : button { key = \"b_show\"; label = \"Показать\"; } }"
      " : row { : button { key = \"accept\"; label = \"Применить\"; is_default = true; width = 18; }"
      "         : button { key = \"cancel\"; label = \"Отменить нумерацию\"; is_cancel = true; width = 22; } } }")))

;; *bn:conf*: список (запись текущий новый решение), решение T = заменить
(defun bn:conf-fill (sel / n)
  (setq n 0)
  (start_list "lst")
  (foreach c *bn:conf*
    (add_list (strcat (itoa (setq n (1+ n))) "\t" (cadr c) "\t-> " (caddr c) "\t"
                      (cadr (car c)) "\t" (if (cadddr c) "[Заменить]" "[Оставить]"))))
  (end_list)
  (set_tile "lst" sel)
  (set_tile "hdr" (strcat "У " (itoa (length *bn:conf*))
                          " блоков уже есть номер, отличный от значения по умолчанию."
                          (if *bn:keepfree* " Новые номера будут пересчитаны с учётом оставленных." "")
                          "  (№ / текущий / новый / имя блока / решение)")))

(defun bn:conf-set (idx flag / i)
  (setq i 0)
  (setq *bn:conf* (mapcar '(lambda (c)
                             (setq i (1+ i))
                             (if (or (eq idx 'all) (member (1- i) idx))
                               (list (car c) (cadr c) (caddr c) flag)
                               c))
                          *bn:conf*))
  (bn:conf-fill (get_tile "lst")))

(defun bn:zoom (r / p1 p2 d)
  (setq p1 (nth 3 r) p2 (nth 4 r)
        d  (* 3.0 (max (- (car p2) (car p1)) (- (cadr p2) (cadr p1)) 1.0)))
  (vla-ZoomWindow (vlax-get-acad-object)
                  (vlax-3d-point (list (- (car p1) d) (- (cadr p1) d) 0.0))
                  (vlax-3d-point (list (+ (car p2) d) (+ (cadr p2) d) 0.0)))
  (sssetfirst nil (ssadd (car r)))
  (getstring "\nБлок показан. Enter - вернуться к списку: ")
  (sssetfirst nil nil))

;; -> T применить, nil отмена всей нумерации
(defun bn:conf-dialog (/ fn id res sel)
  (setq fn (bn:conf-dcl) res 2 sel "")
  (while (= res 2)
    (setq id (load_dialog fn))
    (if (not (new_dialog "bn_conf" id))
      (setq res 0)
      (progn
        (bn:conf-fill sel)
        (action_tile "lst"       "(setq sel $value) (if (= $reason 4) (done_dialog 2))")
        (action_tile "b_rep"     "(bn:conf-set (bn:idx (get_tile \"lst\")) T)")
        (action_tile "b_keep"    "(bn:conf-set (bn:idx (get_tile \"lst\")) nil)")
        (action_tile "b_repall"  "(bn:conf-set 'all T)")
        (action_tile "b_keepall" "(bn:conf-set 'all nil)")
        (action_tile "b_show"    "(setq sel (get_tile \"lst\")) (done_dialog 2)")
        (action_tile "accept"    "(done_dialog 1)")
        (action_tile "cancel"    "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (if (and (= res 2) (bn:idx sel))
          (bn:zoom (car (nth (car (bn:idx sel)) *bn:conf*)))))))
  (vl-file-delete fn)
  (= res 1))

;;; ---------- этажи ----------
;; сравнение этажей: числа по значению, иначе как строки
(defun bn:fl< (a b / ra rb)
  (setq ra (bn:flrank a) rb (bn:flrank b))
  (if (/= ra rb) (< ra rb) (< a b)))

;;; ---------- короткие обозначения этажей (ldata MM_NUMBERING "flshort": ((значение . коротко) ...)) ----------
;; используются в маске как {Э}:  S-{Э}.#  ->  S-1.2, S-П1.2, S-Ч.1, S-К.1
(defun bn:shorts () (vlax-ldata-get *bn:dict* "flshort"))
(defun bn:num-in (s / i r c)                 ; первое число в строке (с минусом), иначе nil
  (setq i 1)
  (while (and (null r) (<= i (strlen s)))
    (setq c (substr s i 1))
    (if (wcmatch c "#") (setq r (atoi (substr s i))) (setq i (1+ i))))
  (if (and r (> i 1) (= (substr s (1- i) 1) "-")) (- r) r))
;; предложение по умолчанию
(defun bn:short-def (v / u n)
  (setq u (strcase v) n (bn:num-in v))
  (cond ((wcmatch u "*ПАРКИНГ*,*ПАРК*,*АВТОСТОЯН*") (strcat "П" (itoa (abs (if n n 1)))))
        ((wcmatch u "*ПОДВАЛ*") "Пв")
        ((wcmatch u "*ТЕХПОДПОЛ*,*ПОДПОЛ*") "Тп")
        ((wcmatch u "*ЧЕРДАК*,*ТЕХЭТАЖ*,*ТЕХ. ЭТАЖ*") "Ч")
        ((wcmatch u "*КРОВЛ*,*КРЫШ*") "К")
        ((and n (< n 0)) (strcat "П" (itoa (abs n))))
        (n (itoa n))
        (T v)))
(defun bn:short (v / p)
  (cond ((setq p (assoc v (if *bn:shedit* *bn:shtmp* (bn:shorts)))) (cdr p)) (T (bn:short-def v))))
;; порядок этажей: паркинг/подвал (снизу вверх), этажи, чердак, кровля
(defun bn:flrank (v / sh n)
  (setq sh (strcase (bn:short v)) n (bn:num-in sh))
  (cond ((wcmatch sh "П#*") (- 0 (if n n 1) 100))
        ((wcmatch sh "ПВ*,ТП*") -50)
        ((wcmatch sh "Ч*") 10000)
        ((wcmatch sh "К*") 10001)
        (n n)
        (T 5000)))

(defun bn:sh-fill (sel)
  (start_list "lst")
  (foreach v *bn:shv* (add_list (strcat v "\t" (bn:short v) (if (assoc v *bn:shtmp*) "" "  (по умолчанию)"))))
  (end_list)
  (set_tile "lst" sel))

;; окно коротких обозначений; vals - значения этажей
(defun bn:short-dialog (vals / fn id res i)
  (setq *bn:shv* (vl-sort vals 'bn:fl<) *bn:shtmp* (bn:shorts) *bn:shedit* T)
  (setq fn (bn:write-dcl "blok_num_sh.dcl"
    '("bn_sh : dialog { label = \"Короткие обозначения этажей / отметок\";"
      " : text { label = \"Используются в маске нумерации как {Э}:  S-{Э}.#  ->  S-1.2,  S-П1.2,  S-Ч.1,  S-К.1\"; }"
      " : list_box { key = \"lhd\"; height = 2; width = 70; tabs = \"40\"; is_tab_stop = false; }"
      " : list_box { key = \"lst\"; height = 14; width = 70; tabs = \"40\"; }"
      " : row { : edit_box { key = \"sh\"; label = \"Коротко:\"; edit_width = 10; allow_accept = false; }"
      "         : button { key = \"b_set\"; label = \"Задать\"; }"
      "         : button { key = \"b_def\"; label = \"По умолчанию\"; } }"
      " : text { label = \"По умолчанию: число - само число; паркинг / минус - П1, П2; подвал - Пв; чердак - Ч; кровля - К.\"; }"
      " : row { : button { key = \"accept\"; label = \"Сохранить\"; is_default = true; width = 16; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 16; } } }")))
  (setq id (load_dialog fn))
  (if (new_dialog "bn_sh" id)
    (progn
      (start_list "lhd") (add_list "Этаж (значение атрибута)\tКоротко") (end_list)
      (bn:sh-fill "0")
      (if *bn:shv* (set_tile "sh" (bn:short (car *bn:shv*))))
      (action_tile "lst" "(set_tile \"sh\" (bn:short (nth (atoi $value) *bn:shv*)))")
      (action_tile "b_set" "(if (setq i (bn:idx (get_tile \"lst\"))) (progn (setq *bn:shtmp* (cons (cons (nth (car i) *bn:shv*) (bn:trim (get_tile \"sh\"))) (vl-remove (assoc (nth (car i) *bn:shv*) *bn:shtmp*) *bn:shtmp*))) (bn:sh-fill (get_tile \"lst\"))))")
      (action_tile "b_def" "(if (setq i (bn:idx (get_tile \"lst\"))) (progn (setq *bn:shtmp* (vl-remove (assoc (nth (car i) *bn:shv*) *bn:shtmp*) *bn:shtmp*)) (bn:sh-fill (get_tile \"lst\")) (set_tile \"sh\" (bn:short-def (nth (car i) *bn:shv*)))))")
      (action_tile "accept" "(done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))))
  (unload_dialog id) (vl-file-delete fn)
  (setq *bn:shedit* nil)
  (if (= res 1) (vlax-ldata-put *bn:dict* "flshort" *bn:shtmp*))
  (princ))

;; окно блоков без этажа. recs - записи; возврат: T продолжить, nil отмена
(defun bn:fl-dcl ()
  (bn:write-dcl "blok_num_fl.dcl"
    '("bn_fl : dialog { label = \"Блоки без этажа\";"
      " : text { key = \"hdr\"; width = 100; }"
      " : list_box { key = \"lhd\"; height = 2; width = 100; tabs = \"5 40 72\"; is_tab_stop = false; }"
      " : list_box { key = \"lst\"; multiple_select = true; height = 16; width = 100; tabs = \"5 40 72\"; }"
      " : row { : edit_box { key = \"fl\"; label = \"Этаж:\"; edit_width = 8; allow_accept = false; }"
      "         : button { key = \"b_sel\"; label = \"Задать выделенным\"; }"
      "         : button { key = \"b_all\"; label = \"Задать всем\"; }"
      "         : button { key = \"b_show\"; label = \"Показать\"; } }"
      " : text { key = \"info\"; width = 90; }"
      " : row { : button { key = \"accept\"; label = \"Продолжить\"; is_default = true; width = 18; }"
      "         : button { key = \"cancel\"; label = \"Отменить нумерацию\"; is_cancel = true; width = 22; } } }")))

(defun bn:fl-fill (sel / n)
  (setq n 0)
  (start_list "lhd") (add_list "№\tБлок\tПОЗИЦИЯ\tПримечание") (end_list)
  (start_list "lst")
  (foreach r *bn:nofl*
    (add_list (strcat (itoa (setq n (1+ n))) "\t" (cadr r) "\t"
                      (if (= (bn:attval (car r) "ПОЗИЦИЯ") "") "<пусто>" (bn:attval (car r) "ПОЗИЦИЯ"))
                      (if (= *bn:tag* "ПОЗИЦИЯ") "" (strcat "  (" *bn:tag* ": " (bn:attval (car r) *bn:tag*) ")")) "\t"
                      (if (bn:att (vlax-ename->vla-object (car r)) *bn:fltag*) "" "нет атрибута этажа"))))
  (end_list)
  (set_tile "lst" sel)
  (set_tile "hdr" (strcat "Не задан этаж (" *bn:fltag* ") у блоков: " (itoa (length *bn:nofl*))
                          ".  Блоки без этажа не нумеруются.")))

;; задать этаж записям с индексами idx ('all - всем)
(defun bn:fl-set (idx v / i a keep)
  (setq i -1)
  (if (= (bn:trim v) "")
    (set_tile "info" "Введите этаж.")
    (progn
      (foreach r *bn:nofl*
        (setq i (1+ i))
        (if (and (or (eq idx 'all) (member i idx))
                 (setq a (bn:att (vlax-ename->vla-object (car r)) *bn:fltag*)))
          (vla-put-TextString a (bn:trim v))
          (setq keep (cons r keep))))
      (setq *bn:nofl* (reverse keep))
      (set_tile "info" (if (vl-some '(lambda (r) (null (bn:att (vlax-ename->vla-object (car r)) *bn:fltag*))) *bn:nofl*)
                         "У части блоков нет атрибута этажа - добавьте его (ММ_АТРИБ_ИЗМ)." ""))
      (bn:fl-fill ""))))

(defun bn:fl-dialog (/ fn id res sel)
  (setq fn (bn:fl-dcl) res 2 sel "")
  (while (and (= res 2) *bn:nofl*)
    (setq id (load_dialog fn))
    (if (not (new_dialog "bn_fl" id))
      (setq res 0)
      (progn
        (bn:fl-fill sel)
        (action_tile "lst" "(setq sel $value) (if (= $reason 4) (done_dialog 2))")
        (action_tile "b_sel" "(bn:fl-set (bn:idx (get_tile \"lst\")) (get_tile \"fl\"))")
        (action_tile "b_all" "(bn:fl-set 'all (get_tile \"fl\"))")
        (action_tile "b_show" "(setq sel (get_tile \"lst\")) (done_dialog 2)")
        (action_tile "accept" "(done_dialog 1)")
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (if (and (= res 2) (bn:idx sel) (nth (car (bn:idx sel)) *bn:nofl*))
          (bn:zoom (nth (car (bn:idx sel)) *bn:nofl*))))))
  (vl-file-delete fn)
  (or (= res 1) (and (= res 2) (null *bn:nofl*))))

;;; ---------- назначение номеров ----------
;; группы: без этажа - одна; с этажом - по этажам по возрастанию (порядок внутри сохраняется)
(defun bn:groups (ordered / fls)
  (if (not *bn:flon*)
    (list (cons "" ordered))
    (progn
      (foreach r ordered
        (if (not (member (bn:attval (car r) *bn:fltag*) fls)) (setq fls (cons (bn:attval (car r) *bn:fltag*) fls))))
      (mapcar '(lambda (f) (cons f (vl-remove-if-not '(lambda (r) (= (bn:attval (car r) *bn:fltag*) f)) ordered)))
              (vl-sort fls 'bn:fl<)))))

;; -> ((запись новый_номер_или_nil) ...) и *bn:knext* - следующий счётчик
(defun bn:assign (ordered kept keptvals / out k m)
  (setq k 0)
  (foreach g (bn:groups ordered)
    (if (= *bn:flrst* "1") (setq k 0))
    (setq m (bn:flmask *bn:mask* (bn:short (car g))))
    (foreach r (cdr g)
      (if (member (car r) kept)
        (progn (setq out (cons (list r nil) out))
               (if (not *bn:keepfree*) (setq k (1+ k))))
        (progn
          (if *bn:keepfree*
            (while (member (bn:fmt m (+ *bn:start* (* k *bn:step*))) keptvals) (setq k (1+ k))))
          (setq out (cons (list r (bn:fmt m (+ *bn:start* (* k *bn:step*)))) out) k (1+ k))))))
  (setq *bn:knext* k)
  (reverse out))

;;; ---------- команда ----------
(defun bn:run (/ *error* doc ss implied src recs names p sel ordered k plan cur new def
                 nrep nkeep nsame go kept keptvals asg)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*"))
      (princ (strcat "\nОшибка: " m)))
    (vla-EndUndoMark doc)
    (princ))
  (setq *bn:defs* nil *bn:alltags* nil)
  ;; предварительно выделенные блоки или весь текущий лист
  (if (setq ss (ssget "_I" '((0 . "INSERT") (66 . 1))))
    (setq implied T
          src (strcat "Источник: выделенный диапазон (" (itoa (sslength ss)) " блоков с атрибутами)"))
    (setq ss  (ssget "_X" (list '(0 . "INSERT") '(66 . 1) (cons 410 (getvar "CTAB"))))
          src (strcat "Источник: весь " (if (= (getvar "CTAB") "Model") "чертёж (Модель)"
                                            (strcat "лист " (getvar "CTAB"))))))
  (sssetfirst nil nil)
  (setq recs (bn:collect ss) *bn:alltags* (vl-sort *bn:alltags* '<) *bn:allrecs* recs)
  (foreach r recs
    (if (setq p (assoc (cadr r) names))
      (setq names (subst (cons (cadr r) (1+ (cdr p))) p names))
      (setq names (cons (cons (cadr r) 1) names))))
  (setq *bn:names* (vl-sort names '(lambda (a b) (< (strcase (car a)) (strcase (car b))))))
  (vla-StartUndoMark doc)
  (cond
    ((null recs) (princ "\nНет блоков с атрибутами."))
    ((null (setq sel (bn:dialog src implied))) (princ "\nНумерация отменена."))
    (T
      (setq recs (vl-remove-if-not '(lambda (r) (and (member (cadr r) sel) (bn:posatt (vlax-ename->vla-object (car r))))) recs))
      ;; проверка этажей
      (setq go T)
      (if *bn:flon*
        (progn
          (setq *bn:nofl* (vl-remove-if-not '(lambda (r) (= (bn:attval (car r) *bn:fltag*) "")) recs))
          (if *bn:nofl* (setq go (bn:fl-dialog)))
          (setq recs (vl-remove-if '(lambda (r) (= (bn:attval (car r) *bn:fltag*) "")) recs))))
      (setq ordered
        (cond ((not go) nil)
              ((= *bn:method* "m_pick") (bn:order-pick recs))
              ((= *bn:method* "m_pl")   (bn:order-pl recs *bn:tol*))
              (T (bn:order-xy recs *bn:method* *bn:tol*))))
      (cond
        ((not go) (princ "\nНумерация отменена."))
        ((null ordered) (princ (strcat "\nНет блоков для нумерации (с атрибутом " *bn:tag* ").")))
        (T
          ;; 1) предварительный план: блоки с уже присвоенным номером -> окно решений
          (setq plan nil)
          (foreach a (bn:assign ordered nil nil)
            (setq cur (bn:curval (car (car a))) new (cadr a) def (bn:defval (cadr (car a))))
            (if (not (or (= cur "") (= cur def) (= cur new)))
              (setq plan (cons (list (car a) cur new T) plan))))
          (setq *bn:conf* (reverse plan)
                go (if *bn:conf* (bn:conf-dialog) T))
          (if (not go)
            (princ "\nНумерация отменена.")
            (progn
              ;; 2) окончательная нумерация с учётом решений
              (setq kept nil keptvals nil)
              (foreach c *bn:conf*
                (if (not (cadddr c))
                  (setq kept (cons (car (car c)) kept) keptvals (cons (cadr c) keptvals))))
              (setq nrep 0 nkeep 0 nsame 0)
              (foreach a (bn:assign ordered kept keptvals)
                (cond ((null (cadr a)) (setq nkeep (1+ nkeep)))
                      ((= (bn:curval (car (car a))) (cadr a)) (setq nsame (1+ nsame)))
                      (T (vla-put-TextString (bn:posatt (vlax-ename->vla-object (car (car a)))) (cadr a))
                         (setq nrep (1+ nrep)))))
              ;; запомнить формат и следующий номер в чертеже (для своего атрибута)
              (vlax-ldata-put *bn:dict* (strcat "mask|" *bn:tag*) *bn:mask*)
              (vlax-ldata-put *bn:dict* (strcat "next|" *bn:tag*) (+ *bn:start* (* *bn:knext* *bn:step*)))
              (princ (strcat "\nАтрибут " *bn:tag* ": пронумеровано " (itoa nrep)
                             ", оставлено с прежним номером: " (itoa nkeep)
                             (if (and *bn:keepfree* (> nkeep 0)) " (номер не занимают)" "")
                             ", уже с нужным номером: " (itoa nsame)
                             (if *bn:flon* (strcat ", этажей: " (itoa (length (bn:groups ordered)))) "")
                             "."))))))))
  (vla-EndUndoMark doc)
  (princ))

;; при выделенном диапазоне все типы блоков в окне сразу отмечены
(defun c:мм_нумерация () (bn:run))
(defun c:ММ_НУМЕРАЦИЯ () (bn:run))
(defun c:MM_NUMBERING () (bn:run))
;; отдельное окно коротких обозначений этажей (значения - из атрибута ЭТАЖ всех блоков чертежа)
(defun bn:run-sh (/ ss)
  (setq ss (ssget "_X" '((0 . "INSERT") (66 . 1))) *bn:alltags* nil)
  (bn:short-dialog (bn:flvals (bn:collect ss) *bn:fltag*)))
(defun c:ММ_ЭТАЖИ () (bn:run-sh))
(defun c:мм_этажи () (bn:run-sh))
(defun c:MM_FLOORS () (bn:run-sh))

;;; ---------- сообщение при загрузке ----------
(princ "\n==================================================================")
(princ "\n MM_NUMBERING.LSP загружен (Этап 3: нумерация по любому атрибуту, с учётом этажа)")
(princ "\n  ММ_НУМЕРАЦИЯ / MM_NUMBERING:")
(princ "\n    [выделите область] -> окно: атрибут, типы блоков, маска (AS-#, AS-{Э}.#),")
(princ "\n    \"С учётом этажа\": по этажам, {Э} - короткое обозначение этажа (S-П1.2); блоки без этажа - окно задания этажа.")
(princ "\n  ММ_ЭТАЖИ / MM_FLOORS: короткие обозначения этажей (1, П1, Пв, Ч, К).")
(princ "\n    начать с / шаг, способ: по строкам / по столбцам / указанием /")
(princ "\n    по полилинии (+ направление). Уже пронумерованные - окно решений")
(princ "\n    Заменить / Оставить (галочка: оставленные не занимают номер).")
(princ "\n    Отмена - ОТМЕНИТЬ (U).")
(princ "\n==================================================================")
(princ)
