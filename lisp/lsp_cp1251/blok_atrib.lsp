;;; ======================================================================
;;;  MM_ATTRIB.LSP  —  Этап 4: просмотр и групповая правка атрибутов блоков
;;;  AutoCAD 2024. Кодировка файла: Windows-1251 (ANSI).
;;; ----------------------------------------------------------------------
;;;  КОМАНДЫ:
;;;   ММ_АТРИБ (или MM_ATTRIB) - окно атрибутов блоков чертежа:
;;;     Слева  - фильтр-маска (* ? ,) и список всех блоков с атрибутами
;;;              (все пространства: Модель и Листы), выбор Ctrl/Shift.
;;;              Если блоки были выделены на чертеже до команды - их имена
;;;              в списке уже выделены. Кнопка "Выбрать блоки на чертеже <"
;;;              позволяет выделить экземпляры рамкой, не закрывая работу.
;;;     Справа - атрибуты ТОЛЬКО выделенных в списке блоков: при нескольких
;;;              именах - только общие атрибуты; одинаковое значение
;;;              показывается, различающиеся - как <разные>.
;;;     Правка - щёлкните атрибут справа, введите значение, Enter или
;;;              "Применить". Галочка "Изменять все блоки на чертеже
;;;              с выделенными именами":
;;;                снята  - меняются только блоки, выделенные на чертеже;
;;;                стоит  - все блоки чертежа с выделенными именами.
;;;              (Без выделения на чертеже галочка стоит всегда.)
;;;   Все изменения за один запуск отменяются одним ОТМЕНИТЬ (U).
;;;   Меняется только значение атрибута: цвет, слой, линии блока - прежние.
;;; ======================================================================

(vl-load-com)

(if (not *ba:flt*) (setq *ba:flt* "*"))

;;; ---------- утилиты ----------
(defun ba:trim (s) (vl-string-trim " \t" (if s s "")))

(defun ba:bname (o / r)
  (setq r (vl-catch-all-apply 'vla-get-EffectiveName (list o)))
  (if (vl-catch-all-error-p r) (vla-get-Name o) r))

(defun ba:attrs (e / l)
  (foreach a (vlax-invoke (vlax-ename->vla-object e) 'GetAttributes)
    (setq l (cons (cons (strcase (vla-get-TagString a)) (vla-get-TextString a)) l)))
  (reverse l))

(defun ba:idx (s) (if (and s (/= s "")) (read (strcat "(" s ")"))))

(defun ba:open-dcl (fn / f)
  ;; кодировка DCL по LISPSYS: 1 - UTF-8 с BOM, 0 - ANSI
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0))
    (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  f)

;;; ---------- данные ----------
;; *ba:all*    - список (ename имя атрибуты) всех блоков с атрибутами
;; *ba:picked* - enames, выделенные на чертеже
(defun ba:collect (/ ss i e res)
  (if (setq ss (ssget "_X" '((0 . "INSERT") (66 . 1))))
    (repeat (setq i (sslength ss))
      (setq e (ssname ss (setq i (1- i))))
      (setq res (cons (list e (ba:bname (vlax-ename->vla-object e)) (ba:attrs e)) res))))
  res)

(defun ba:ss->list (ss / i l)
  (if ss (repeat (setq i (sslength ss)) (setq l (cons (ssname ss (setq i (1- i))) l))))
  l)

(defun ba:names (/ names p)
  (foreach r *ba:all*
    (if (setq p (assoc (cadr r) names))
      (setq names (subst (cons (cadr r) (1+ (cdr p))) p names))
      (setq names (cons (cons (cadr r) 1) names))))
  (vl-sort names '(lambda (a b) (< (strcase (car a)) (strcase (car b))))))

(defun ba:picked-count (name / n)
  (setq n 0)
  (foreach r *ba:all*
    (if (and (= (cadr r) name) (member (car r) *ba:picked*)) (setq n (1+ n))))
  n)

;; блоки, которые будут изменены
(defun ba:targets ()
  (vl-remove-if-not
    '(lambda (r) (and (member (cadr r) *ba:selnames*)
                      (or *ba:allmode* (member (car r) *ba:picked*))))
    *ba:all*))

;; общие атрибуты: список (тег . значение|nil), nil = <разные>
(defun ba:common (tg / res)
  (if tg
    (progn
      (setq res (mapcar '(lambda (a) (cons (car a) (cdr a))) (caddr (car tg))))
      (foreach r (cdr tg)
        (setq res (vl-remove-if-not '(lambda (a) (assoc (car a) (caddr r))) res))
        (setq res (mapcar '(lambda (a)
                             (if (and (cdr a) (= (cdr a) (cdr (assoc (car a) (caddr r)))))
                               a (cons (car a) nil)))
                          res)))))
  res)

;;; ---------- окно ----------
(defun ba:write-dcl (/ fn f)
  (setq fn (vl-filename-mktemp "blok_atrib.dcl") f (ba:open-dcl fn))
  (foreach l
    '("ba_dlg : dialog { label = \"Атрибуты блоков\";"
      " : row {"
      "  : column {"
      "   : row { : edit_box { key = \"flt\"; label = \"Фильтр (маска):\"; edit_width = 22; allow_accept = false; }"
      "           : button { key = \"b_flt\"; label = \"Применить\"; width = 12; fixed_width = true; } }"
      "   : list_box { key = \"lst\"; multiple_select = true; height = 24; width = 52; }"
      "   : row { : button { key = \"b_all\"; label = \"Выделить все\"; }"
      "           : button { key = \"b_none\"; label = \"Снять выделение\"; } }"
      "   : button { key = \"b_pick\"; label = \"Выбрать блоки на чертеже <\"; } }"
      "  : column {"
      "   : text { key = \"t_scope\"; width = 72; }"
      "   : list_box { key = \"atr\"; height = 17; width = 72; tabs = \"24\"; }"
      "   : text { key = \"t_tag\"; width = 72; }"
      "   : row { : edit_box { key = \"val\"; label = \"Значение:\"; edit_width = 44; allow_accept = false; }"
      "           : button { key = \"b_apply\"; label = \"Применить\"; width = 14; fixed_width = true; } }"
      "   : toggle { key = \"chk_all\"; label = \"Изменять все блоки на чертеже с выделенными именами\"; }"
      "   : text { key = \"msg\"; width = 72; } } }"
      " : row { : spacer { width = 1; }"
      "         : button { key = \"cancel\"; label = \"Закрыть\"; is_cancel = true; width = 16; fixed_width = true; } } }")
    (write-line l f))
  (close f)
  fn)

;; левый список с сохранением выделения
(defun ba:fill (/ s i n)
  (setq *ba:shown* nil)
  (foreach p *ba:namelist*
    (if (wcmatch (strcase (car p)) (strcase *ba:flt*))
      (setq *ba:shown* (cons p *ba:shown*))))
  (setq *ba:shown* (reverse *ba:shown*)
        *ba:selnames* (vl-remove-if-not '(lambda (nm) (assoc nm *ba:shown*)) *ba:selnames*))
  (start_list "lst")
  (foreach p *ba:shown*
    (setq n (ba:picked-count (car p)))
    (add_list (strcat (car p) "   (" (itoa (cdr p)) " шт."
                      (if (> n 0) (strcat ", выделено " (itoa n)) "") ")")))
  (end_list)
  (setq s "" i 0)
  (foreach p *ba:shown*
    (if (member (car p) *ba:selnames*) (setq s (strcat s (itoa i) " ")))
    (setq i (1+ i)))
  (set_tile "lst" s)
  (ba:right))

(defun ba:lst-changed (v)
  (setq *ba:selnames* (mapcar '(lambda (i) (car (nth i *ba:shown*))) (ba:idx v)))
  (ba:right))

(defun ba:sel-all (on / s i)
  (setq s "" i 0)
  (if on (repeat (length *ba:shown*) (setq s (strcat s (itoa i) " ") i (1+ i))))
  (set_tile "lst" s)
  (ba:lst-changed s))

;; правая часть: атрибуты только выделенных в списке блоков
(defun ba:right (/ tg i)
  (setq *ba:common* nil)
  (start_list "atr")
  (cond
    ((null *ba:selnames*)
     (end_list)
     (set_tile "t_scope" "Выделите блоки в списке слева."))
    ((null (setq tg (ba:targets)))
     (end_list)
     (set_tile "t_scope" "Среди выделенных на чертеже нет блоков с этими именами - поставьте галочку ниже."))
    (T
     (setq *ba:common* (ba:common tg))
     (foreach a *ba:common*
       (add_list (strcat (car a) "\t" (cond ((null (cdr a)) "<разные>")
                                            ((= (cdr a) "") "<пусто>")
                                            (T (cdr a))))))
     (end_list)
     (set_tile "t_scope"
       (strcat (if (cdr *ba:selnames*) "Общие атрибуты. " "Атрибуты. ")
               "Будет изменено блоков: " (itoa (length tg))
               " (имён: " (itoa (length *ba:selnames*)) ")"
               (if *ba:allmode* " - все на чертеже" " - выделенные на чертеже")))))
  ;; сохранить выбранный атрибут, если он есть среди общих
  (if (and *ba:tag* (setq i (vl-position *ba:tag* (mapcar 'car *ba:common*))))
    (progn (set_tile "atr" (itoa i)) (ba:pick-atr i))
    (progn
      (setq *ba:tag* nil)
      (set_tile "t_tag" (if *ba:common* "Щёлкните атрибут в списке для изменения." ""))
      (set_tile "val" "")))
  (mode_tile "val" (if *ba:tag* 0 1))
  (mode_tile "b_apply" (if *ba:tag* 0 1)))

(defun ba:pick-atr (i / a)
  (if (setq a (nth i *ba:common*))
    (progn
      (setq *ba:tag* (car a))
      (set_tile "t_tag" (strcat "Атрибут: " (car a) (if (cdr a) "" "   (значения разные)")))
      (set_tile "val" (if (cdr a) (cdr a) ""))
      (mode_tile "val" 0)
      (mode_tile "b_apply" 0)
      (mode_tile "val" 2))))

(defun ba:apply (/ v tg n o)
  (setq v (get_tile "val") n 0 tg (ba:targets))
  (if (null *ba:tag*)
    (set_tile "msg" "Сначала выберите атрибут.")
    (progn
      (foreach r tg
        (setq o (vlax-ename->vla-object (car r)))
        (foreach a (vlax-invoke o 'GetAttributes)
          (if (= (strcase (vla-get-TagString a)) *ba:tag*)
            (progn (vla-put-TextString a v) (setq n (1+ n))))))
      ;; обновить кэш атрибутов изменённых блоков
      (setq *ba:all* (mapcar '(lambda (r)
                                (if (member r tg) (list (car r) (cadr r) (ba:attrs (car r))) r))
                             *ba:all*))
      (ba:right)
      (set_tile "msg" (strcat *ba:tag* " = \"" v "\": изменено блоков " (itoa n) "."))
      (princ (strcat "\n" *ba:tag* " = \"" v "\": изменено блоков " (itoa n) ".")))))

(defun ba:dialog (/ fn id res ss)
  (setq fn (ba:write-dcl) res 2)
  (while (= res 2)
    (setq id (load_dialog fn))
    (if (not (new_dialog "ba_dlg" id))
      (setq res 0)
      (progn
        (set_tile "flt" *ba:flt*)
        (set_tile "chk_all" (if *ba:allmode* "1" "0"))
        (mode_tile "chk_all" (if *ba:picked* 0 1))   ; без выделения на чертеже - только "все"
        (ba:fill)
        (action_tile "flt"   "(setq *ba:flt* (if (= $value \"\") \"*\" $value)) (ba:fill)")
        (action_tile "b_flt" "(setq *ba:flt* (get_tile \"flt\")) (if (= *ba:flt* \"\") (setq *ba:flt* \"*\")) (ba:fill)")
        (action_tile "lst"   "(ba:lst-changed $value)")
        (action_tile "b_all" "(ba:sel-all T)")
        (action_tile "b_none" "(ba:sel-all nil)")
        (action_tile "atr"   "(ba:pick-atr (atoi $value))")
        (action_tile "val"   "(if (= $reason 1) (ba:apply))")
        (action_tile "b_apply" "(ba:apply)")
        (action_tile "chk_all" "(setq *ba:allmode* (= $value \"1\")) (ba:right)")
        (action_tile "b_pick" "(done_dialog 2)")
        (action_tile "cancel" "(done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (if (= res 2)
          (progn
            (princ "\nВыберите блоки с атрибутами (Enter - вернуться): ")
            (if (setq ss (ssget '((0 . "INSERT") (66 . 1))))
              (progn
                (setq *ba:picked* (ba:ss->list ss)
                      *ba:allmode* nil
                      *ba:flt* "*"
                      *ba:selnames* nil)
                (foreach r *ba:all*
                  (if (and (member (car r) *ba:picked*) (not (member (cadr r) *ba:selnames*)))
                    (setq *ba:selnames* (cons (cadr r) *ba:selnames*))))
                (setq *ba:namelist* (ba:names)))))))))
  (vl-file-delete fn))

;;; ---------- команда ----------
(defun ba:main (/ *error* doc ss)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*"))
      (princ (strcat "\nОшибка: " m)))
    (vla-EndUndoMark doc)
    (princ))
  (setq ss (ssget "_I" '((0 . "INSERT") (66 . 1))))
  (sssetfirst nil nil)
  (setq *ba:all* (ba:collect)
        *ba:picked* (ba:ss->list ss)
        *ba:allmode* (null *ba:picked*)
        *ba:selnames* nil
        *ba:tag* nil)
  (foreach r *ba:all*
    (if (and (member (car r) *ba:picked*) (not (member (cadr r) *ba:selnames*)))
      (setq *ba:selnames* (cons (cadr r) *ba:selnames*))))
  (if *ba:picked* (setq *ba:flt* "*"))
  (setq *ba:namelist* (ba:names))
  (if (null *ba:all*)
    (princ "\nВ чертеже нет блоков с атрибутами.")
    (progn
      (vla-StartUndoMark doc)
      (ba:dialog)
      (vla-EndUndoMark doc)))
  (princ))

(defun c:мм_атриб () (ba:main))
(defun c:ММ_АТРИБ () (ba:main))
(defun c:MM_ATTRIB () (ba:main))

;;; ---------- сообщение при загрузке ----------
(princ "\n==================================================================")
(princ "\n MM_ATTRIB.LSP загружен (Этап 4: атрибуты блоков)")
(princ "\n  ММ_АТРИБ / MM_ATTRIB - окно: фильтр * и список блоков слева,")
(princ "\n    атрибуты выделенных (общие для нескольких) справа.")
(princ "\n    Щелчок по атрибуту -> значение -> Enter/Применить.")
(princ "\n    Галочка: все блоки с этими именами / только выделенные на чертеже.")
(princ "\n==================================================================")
(princ)
