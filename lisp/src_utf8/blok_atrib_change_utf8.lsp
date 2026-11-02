;;; ======================================================================
;;;  BLOK_ATRIB_CHANGE.LSP  —  состав и порядок атрибутов в описаниях блоков
;;;  AutoCAD 2024. Кодировка файла: Windows-1251 (ANSI).
;;; ----------------------------------------------------------------------
;;;  КОМАНДА:
;;;   ММ_АТРИБ_ИЗМ (MM_ATTRIB_EDIT) - окно:
;;;     Слева  - фильтр-маска (* ? ,) и список блоков, содержащих атрибуты
;;;              (атрибутов / вставок). Выделите один или несколько блоков
;;;              (Ctrl/Shift): изменения применяются ко ВСЕМ выделенным.
;;;     Справа - атрибуты первого выделенного блока в порядке описания блока
;;;              (без значений): имя, видимость, стиль, слой, высота.
;;;     Действия с выбранным атрибутом:
;;;       Вверх / Вниз        - поменять местами с соседним (и порядок, и
;;;                             положение на чертеже блока);
;;;       Добавить после      - новые атрибуты (можно через запятую:
;;;                             ВЫСОТА,ПОМЕЩЕНИЕ) - копия выбранного
;;;                             (стиль, слой, высота, выравнивание) ниже него;
;;;       Удалить             - убрать атрибут из блока;
;;;       Применить к атрибуту - имя (тег), подсказка, стиль, слой,
;;;                             высота, невидимый, значение по умолчанию.
;;;     Галочка "Сдвигать соседние" - при добавлении атрибуты столбца ниже
;;;       выбранного сдвигаются вниз на шаг строки, при удалении - вверх.
;;;     Изменения копятся списком (видно в окне), "Отменить последнее",
;;;       "Сбросить все". Для других выделенных блоков те же действия
;;;       повторяются по именам атрибутов (нет атрибута - действие пропуск).
;;;     "Записать в блоки" - меняются описания блоков, затем АТРСИНХР
;;;       (ATTSYNC) обновляет все вставки. Значения атрибутов сохраняются
;;;       (при переименовании - переносятся в новое имя), новые - пустые.
;;;     "Обновить блоки на чертеже" - АТРСИНХР выделенных блоков без записи
;;;       изменений (вставки приводятся к текущему описанию блока).
;;;   Значение по умолчанию получают новые атрибуты во вставках; у
;;;     существующих атрибутов значения во вставках не меняются.
;;;   Пример: блоки с ...ЭТАЖ, БЛОК, ПРИМ-1, ПРИМ-2 -> выделить блоки,
;;;     выбрать БЛОК, в поле "Новые" ввести ВЫСОТА,ПОМЕЩЕНИЕ, "Добавить
;;;     после" (галочка "Сдвигать" стоит) -> ПРИМ-1, ПРИМ-2 уйдут ниже.
;;;   Всё за один запуск записи отменяется одним ОТМЕНИТЬ (U).
;;;   Как в БАТРМЕН (BATTMAN), но сразу для многих блоков и со вставкой
;;;   "после" с раздвижкой столбца.
;;; ======================================================================

(vl-load-com)
(if (not *ac:flt*) (setq *ac:flt* "*"))

;;; ---------- утилиты ----------
(defun ac:trim (s) (vl-string-trim " \t" (if s s "")))
(defun ac:doc () (vla-get-ActiveDocument (vlax-get-acad-object)))
(defun ac:st (k v) (set_tile k (cond ((null v) "") ((numberp v) (rtos v 2 2)) (T v))))
(defun ac:ss->l (ss / i l)
  (if ss (repeat (setq i (sslength ss)) (setq l (cons (ssname ss (setq i (1- i))) l))))
  l)
(defun ac:rnth (n v l / i) (setq i -1) (mapcar '(lambda (x) (if (= (setq i (1+ i)) n) v x)) l))
(defun ac:ins (n v l / i r)                        ; вставить v на позицию n
  (setq i 0)
  (foreach x l (if (= i n) (setq r (cons v r))) (setq r (cons x r) i (1+ i)))
  (if (>= n (length l)) (setq r (cons v r)))
  (reverse r))
(defun ac:del (n l / i) (setq i -1) (vl-remove-if '(lambda (x) (= (setq i (1+ i)) n)) l))
(defun ac:idxs (s) (if (and s (/= s "")) (read (strcat "(" s ")"))))
(defun ac:split (s / i l)                          ; "А,Б" -> ("А" "Б")
  (while (setq i (vl-string-search "," s))
    (setq l (cons (substr s 1 i) l) s (substr s (+ i 2))))
  (reverse (cons s l)))
(defun ac:tagfix (s) (vl-string-translate " " "_" (strcase (ac:trim s))))
(defun ac:obj (h / e) (if (and h (setq e (handent h)) (entget e)) (vlax-ename->vla-object e)))

(defun ac:open-dcl (fn / f)
  ;; кодировка DCL по LISPSYS: 1 - UTF-8 с BOM, 0 - ANSI
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0))
    (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  f)

(defun ac:bname (o / r)
  (setq r (vl-catch-all-apply 'vla-get-EffectiveName (list o)))
  (if (vl-catch-all-error-p r) (vla-get-Name o) r))

;;; ---------- чтение описаний блоков ----------
;; запись атрибута:
;; (0 тег 1 подсказка 2 высота 3 стиль 4 слой 5 невидимый 6 x 7 y 8 хэндл 9 источник 10 исх.x 11 исх.y 12 по_умолчанию)
(defun ac:pt (o)
  (if (= (vla-get-Alignment o) acAlignmentLeft) (vlax-get o 'InsertionPoint) (vlax-get o 'TextAlignmentPoint)))

(defun ac:read (name / blk l p)
  (setq blk (vl-catch-all-apply 'vla-Item (list (vla-get-Blocks (ac:doc)) name)))
  (if (not (vl-catch-all-error-p blk))
    (vlax-for o blk
      (if (= (vla-get-ObjectName o) "AcDbAttributeDefinition")
        (setq p (ac:pt o)
              l (cons (list (strcase (vla-get-TagString o)) (vla-get-PromptString o) (vla-get-Height o)
                            (vla-get-StyleName o) (vla-get-Layer o) (= (vla-get-Invisible o) :vlax-true)
                            (car p) (cadr p) (vla-get-Handle o) nil (car p) (cadr p) (vla-get-TextString o))
                      l)))))
  (reverse l))

;; все блоки с атрибутами: (имя число_атрибутов число_вставок)
(defun ac:blocks (/ cnt l n p nm)
  (foreach e (ac:ss->l (ssget "_X" '((0 . "INSERT"))))
    (setq nm (strcase (ac:bname (vlax-ename->vla-object e))))
    (if (setq p (assoc nm cnt)) (setq cnt (subst (cons nm (1+ (cdr p))) p cnt)) (setq cnt (cons (cons nm 1) cnt))))
  (vlax-for b (vla-get-Blocks (ac:doc))
    (if (and (= (vla-get-IsLayout b) :vlax-false) (= (vla-get-IsXRef b) :vlax-false)
             (not (wcmatch (vla-get-Name b) "`**")))
      (progn
        (setq n 0)
        (vlax-for o b (if (= (vla-get-ObjectName o) "AcDbAttributeDefinition") (setq n (1+ n))))
        (if (> n 0)
          (setq l (cons (list (vla-get-Name b) n (cond ((cdr (assoc (strcase (vla-get-Name b)) cnt))) (0))) l))))))
  (vl-sort l '(lambda (a b) (< (strcase (car a)) (strcase (car b))))))

;;; ---------- модель: действия над списком атрибутов ----------
(defun ac:idx (L tag / i r)
  (setq i 0)
  (foreach x L (if (and (null r) (= (car x) tag)) (setq r i)) (setq i (1+ i)))
  r)

(defun ac:setxy (r x y) (ac:rnth 7 y (ac:rnth 6 x r)))

;; атрибут j в том же столбце, что i (одинаковый x в пределах половины высоты)
(defun ac:col-p (ri rj) (< (abs (- (nth 6 ri) (nth 6 rj))) (* 0.5 (max 0.001 (nth 2 ri)))))

;; шаг строки: расстояние до ближайшего атрибута столбца ниже (или выше)
(defun ac:step (L i / r best d j)
  (setq r (nth i L) j -1)
  (foreach x L
    (setq j (1+ j))
    (if (and (/= j i) (ac:col-p r x) (> (setq d (- (nth 7 r) (nth 7 x))) 1e-6) (or (null best) (< d best)))
      (setq best d)))
  (if (null best)
    (progn (setq j -1)
      (foreach x L
        (setq j (1+ j))
        (if (and (/= j i) (ac:col-p r x) (> (setq d (- (nth 7 x) (nth 7 r))) 1e-6) (or (null best) (< d best)))
          (setq best d)))))
  (if best best (* 1.5 (nth 2 r))))

;; сдвинуть по y атрибуты столбца ниже точки r на dy
(defun ac:shift (L r dy)
  (mapcar '(lambda (x) (if (and (ac:col-p r x) (< (nth 7 x) (- (nth 7 r) 1e-6))) (ac:rnth 7 (+ (nth 7 x) dy) x) x)) L))

;; действие: ("up" тег) ("dn" тег) ("del" тег сдвиг) ("add" после новый сдвиг)
;;           ("set" тег новый_тег подсказка высота стиль слой невидимый по_умолчанию)  nil - не менять
(defun ac:apply (L op / i j a b r st n)
  (setq i (ac:idx L (cadr op)))
  (cond
    ((null i) L)
    ((= (car op) "up")
     (if (> i 0)
       (progn (setq a (nth i L) b (nth (1- i) L))
              (ac:rnth i (ac:setxy b (nth 6 a) (nth 7 a)) (ac:rnth (1- i) (ac:setxy a (nth 6 b) (nth 7 b)) L)))
       L))
    ((= (car op) "dn")
     (if (< i (1- (length L)))
       (progn (setq a (nth i L) b (nth (1+ i) L))
              (ac:rnth i (ac:setxy b (nth 6 a) (nth 7 a)) (ac:rnth (1+ i) (ac:setxy a (nth 6 b) (nth 7 b)) L)))
       L))
    ((= (car op) "del")
     (setq r (nth i L) st (ac:step L i) L (ac:del i L))
     (if (caddr op) (ac:shift L r st) L))
    ((= (car op) "add")
     (if (ac:idx L (caddr op))
       L
       (progn
         (setq r (nth i L) st (ac:step L i))
         (if (cadddr op) (setq L (ac:shift L r (- st))))
         (setq n (list (caddr op) (caddr op) (nth 2 r) (nth 3 r) (nth 4 r) (nth 5 r)
                       (nth 6 r) (- (nth 7 r) st) nil (if (nth 8 r) (nth 8 r) (nth 9 r)) nil nil ""))
         (ac:ins (1+ i) n L))))
    ((= (car op) "set")
     (if (and (nth 2 op) (ac:idx L (nth 2 op)))
       L
       (progn
         (setq r (nth i L) j 0)
         (foreach k '((2 . 0) (3 . 1) (4 . 2) (5 . 3) (6 . 4))  ; поле операции . поле записи
           (if (nth (car k) op) (setq r (ac:rnth (cdr k) (nth (car k) op) r))))
         (if (nth 7 op) (setq r (ac:rnth 5 (= (nth 7 op) "1") r)))
         (if (nth 8 op) (setq r (ac:rnth 12 (nth 8 op) r)))
         (ac:rnth i r L))))
    (T L)))

(defun ac:model (name / L)
  (setq L (ac:read name))
  (foreach op *ac:ops* (setq L (ac:apply L op)))
  L)

(defun ac:op-text (op)
  (cond ((= (car op) "up") (strcat (cadr op) " вверх"))
        ((= (car op) "dn") (strcat (cadr op) " вниз"))
        ((= (car op) "del") (strcat "удалить " (cadr op)))
        ((= (car op) "add") (strcat "добавить " (caddr op) " после " (cadr op)))
        (T (strcat "изменить " (cadr op) (if (nth 2 op) (strcat " -> " (nth 2 op)) "")
                   (if (nth 8 op) (strcat ", по умолчанию \"" (nth 8 op) "\"") "")))))

;;; ---------- окно ----------
(defun ac:bfill (/ m)
  (setq m (strcase (if (= *ac:flt* "") "*" *ac:flt*))
        *ac:bl* (vl-remove-if-not '(lambda (b) (wcmatch (strcase (car b)) m)) *ac:all*))
  (start_list "blk")
  (foreach b *ac:bl* (add_list (strcat (car b) "\t" (itoa (cadr b)) "\t" (itoa (caddr b)))))
  (end_list)
  ;; восстановить выделение по именам
  (ac:st "blk" (apply 'strcat (mapcar '(lambda (n / i) (if (setq i (vl-position n (mapcar 'car *ac:bl*))) (strcat (itoa i) " ") ""))
                                      *ac:sel*)))
  (ac:st "binfo" (strcat "Блоков с атрибутами: " (itoa (length *ac:bl*)) " из " (itoa (length *ac:all*))))
  (ac:afill))

(defun ac:bpick (v)
  (setq *ac:sel* (mapcar '(lambda (i) (car (nth i *ac:bl*))) (ac:idxs v)))
  (ac:afill))

(defun ac:afill (/ i)
  (setq *ac:L* (if *ac:sel* (ac:model (car *ac:sel*))))
  (ac:st "atitle" (if *ac:sel*
                    (strcat "Атрибуты блока " (car *ac:sel*) "   (изменения - для выделенных блоков: "
                            (itoa (length *ac:sel*)) ")")
                    "Выделите блок(и) в списке слева"))
  (start_list "att")
  (setq i 0)
  (foreach r *ac:L*
    (add_list (strcat (itoa (setq i (1+ i))) "\t" (car r) "\t" (if (nth 5 r) "скрыт" "да") "\t"
                      (nth 3 r) "\t" (nth 4 r) "\t" (rtos (nth 2 r) 2 2) "\t" (nth 12 r)
                      (if (nth 8 r) "" "\t(новый)"))))
  (end_list)
  (setq i (if *ac:cur* (ac:idx *ac:L* *ac:cur*)))
  (if (and (null i) *ac:L*) (setq i 0 *ac:cur* (car (car *ac:L*))))
  (if i (progn (ac:st "att" (itoa i)) (ac:apick i)))
  (ac:st "ops" (strcat "Изменений: " (itoa (length *ac:ops*))
                       (if *ac:ops* (strcat "   последнее: " (ac:op-text (last *ac:ops*))) ""))))

(defun ac:apick (i / r)
  (if (setq r (nth i *ac:L*))
    (progn
      (setq *ac:cur* (car r))
      (ac:st "tag" (car r)) (ac:st "prm" (nth 1 r)) (ac:st "hgt" (rtos (nth 2 r) 2 2))
      (ac:st "sty" (itoa (cond ((vl-position (strcase (nth 3 r)) (mapcar 'strcase *ac:stys*))) (0))))
      (ac:st "lay" (itoa (cond ((vl-position (strcase (nth 4 r)) (mapcar 'strcase *ac:lays*))) (0))))
      (ac:st "inv" (if (nth 5 r) "1" "0"))
      (ac:st "dval" (nth 12 r)))))

(defun ac:do (op)
  (if (and *ac:sel* *ac:cur*)
    (progn (setq *ac:ops* (append *ac:ops* (list op))) (ac:afill) (ac:st "info" ""))
    (ac:st "info" "Выделите блок и атрибут.")))

(defun ac:do-add (/ tags after bad)
  (setq tags (vl-remove "" (mapcar 'ac:tagfix (ac:split (get_tile "ntag")))) after *ac:cur*)
  (cond
    ((null tags) (ac:st "info" "Введите имя нового атрибута (несколько - через запятую)."))
    ((setq bad (vl-some '(lambda (t2) (if (ac:idx *ac:L* t2) t2)) tags))
     (ac:st "info" (strcat "Атрибут " bad " уже есть в блоке.")))
    (T
     (foreach t2 tags
       (setq *ac:ops* (append *ac:ops* (list (list "add" after t2 (= (get_tile "shift") "1")))) after t2))
     (setq *ac:cur* after)
     (ac:st "ntag" "")
     (ac:afill))))

(defun ac:do-set (/ r nt h sty lay inv dv)
  (if (setq r (nth (ac:idx *ac:L* *ac:cur*) *ac:L*))
    (progn
      (setq nt (ac:tagfix (get_tile "tag")) h (atof (vl-string-translate "," "." (get_tile "hgt")))
            sty (nth (atoi (get_tile "sty")) *ac:stys*) lay (nth (atoi (get_tile "lay")) *ac:lays*)
            inv (get_tile "inv") dv (get_tile "dval"))
      (cond
        ((= nt "") (ac:st "info" "Имя атрибута не может быть пустым."))
        ((and (/= nt (car r)) (ac:idx *ac:L* nt)) (ac:st "info" (strcat "Атрибут " nt " уже есть.")))
        (T
         (ac:do (list "set" (car r)
                      (if (/= nt (car r)) nt)
                      (if (/= (get_tile "prm") (nth 1 r)) (get_tile "prm"))
                      (if (and (> h 0) (not (equal h (nth 2 r) 1e-6))) h)
                      (if (/= (strcase sty) (strcase (nth 3 r))) sty)
                      (if (/= (strcase lay) (strcase (nth 4 r))) lay)
                      (if (/= (= inv "1") (nth 5 r)) inv)
                      (if (/= dv (nth 12 r)) dv)))
         (if (/= nt (car r)) (progn (setq *ac:cur* nt) (ac:afill))))))))

(defun ac:dialog (/ fn f id res)
  (setq fn (vl-filename-mktemp "blok_atrib_change.dcl") f (ac:open-dcl fn))
  (foreach l
    '("bk_ac : dialog { label = \"Атрибуты блоков: состав и порядок (ММ_АТРИБ_ИЗМ)\";"
      " : row {"
      "  : column {"
      "   : edit_box { key = \"flt\"; label = \"Фильтр (маска * ? ,):\"; edit_width = 22; allow_accept = false; }"
      "   : list_box { key = \"hb\"; height = 2; width = 46; tabs = \"30 38\"; is_tab_stop = false; }"
      "   : list_box { key = \"blk\"; multiple_select = true; height = 24; width = 46; tabs = \"30 38\"; }"
      "   : row { : button { key = \"b_all\"; label = \"Выделить все\"; } : button { key = \"b_none\"; label = \"Снять\"; } }"
      "   : text { key = \"binfo\"; width = 46; } }"
      "  : column {"
      "   : text { key = \"atitle\"; width = 80; }"
      "   : list_box { key = \"ha\"; height = 2; width = 80; tabs = \"4 24 31 46 62 70\"; is_tab_stop = false; }"
      "   : list_box { key = \"att\"; height = 12; width = 80; tabs = \"4 24 31 46 62 70\"; }"
      "   : row { : button { key = \"b_up\"; label = \"Вверх\"; width = 10; }"
      "           : button { key = \"b_dn\"; label = \"Вниз\"; width = 10; }"
      "           : button { key = \"b_del\"; label = \"Удалить\"; width = 12; } }"
      "   : row { : edit_box { key = \"ntag\"; label = \"Новые (через запятую):\"; edit_width = 26; allow_accept = false; }"
      "           : button { key = \"b_add\"; label = \"Добавить после выбранного\"; } }"
      "   : toggle { key = \"shift\"; label = \"Сдвигать соседние атрибуты столбца при добавлении / удалении\"; value = \"1\"; }"
      "   : boxed_column { label = \"Выбранный атрибут\";"
      "     : row { : edit_box { key = \"tag\"; label = \"Имя (тег):\"; edit_width = 18; allow_accept = false; }"
      "             : edit_box { key = \"prm\"; label = \"Подсказка:\"; edit_width = 24; allow_accept = false; } }"
      "     : row { : popup_list { key = \"sty\"; label = \"Стиль:\"; width = 34; }"
      "             : popup_list { key = \"lay\"; label = \"Слой:\"; width = 38; } }"
      "     : row { : edit_box { key = \"hgt\"; label = \"Высота:\"; edit_width = 7; allow_accept = false; }"
      "             : toggle { key = \"inv\"; label = \"Невидимый\"; } }"
      "     : row { : edit_box { key = \"dval\"; label = \"Значение по умолчанию:\"; edit_width = 40; allow_accept = false; }"
      "             : button { key = \"b_set\"; label = \"Применить к атрибуту\"; } } }"
      "   : text { key = \"ops\"; width = 80; }"
      "   : row { : button { key = \"b_undo\"; label = \"Отменить последнее\"; }"
      "           : button { key = \"b_reset\"; label = \"Сбросить все\"; } } } }"
      " : text { key = \"info\"; width = 128; }"
      " : row { : button { key = \"accept\"; label = \"Записать в блоки\"; is_default = true; width = 22; }"
      "         : button { key = \"b_sync\"; label = \"Обновить блоки на чертеже\"; width = 28; }"
      "         : button { key = \"cancel\"; label = \"Закрыть\"; is_cancel = true; width = 14; } } }")
    (write-line l f))
  (close f)
  (setq id (load_dialog fn) res 0)
  (if (new_dialog "bk_ac" id)
    (progn
      (start_list "hb") (add_list "Блок\tАтриб.\tВставок") (end_list)
      (start_list "ha") (add_list "№\tИмя (тег)\tВидим.\tСтиль\tСлой\tВысота\tПо умолчанию") (end_list)
      (start_list "sty") (foreach s *ac:stys* (add_list s)) (end_list)
      (start_list "lay") (foreach s *ac:lays* (add_list s)) (end_list)
      (ac:st "flt" *ac:flt*)
      (ac:bfill)
      (action_tile "flt" "(setq *ac:flt* $value) (ac:bfill)")
      (action_tile "blk" "(ac:bpick $value)")
      (action_tile "b_all" "(setq *ac:sel* (mapcar 'car *ac:bl*)) (ac:bfill)")
      (action_tile "b_none" "(setq *ac:sel* nil) (ac:bfill)")
      (action_tile "att" "(ac:apick (atoi $value))")
      (action_tile "b_up" "(ac:do (list \"up\" *ac:cur*))")
      (action_tile "b_dn" "(ac:do (list \"dn\" *ac:cur*))")
      (action_tile "b_del" "(ac:do (list \"del\" *ac:cur* (= (get_tile \"shift\") \"1\"))) (setq *ac:cur* nil) (ac:afill)")
      (action_tile "b_add" "(ac:do-add)")
      (action_tile "b_set" "(ac:do-set)")
      (action_tile "b_undo" "(setq *ac:ops* (reverse (cdr (reverse *ac:ops*)))) (ac:afill)")
      (action_tile "b_reset" "(setq *ac:ops* nil) (ac:afill)")
      (action_tile "accept" "(if (and *ac:sel* *ac:ops*) (done_dialog 1) (ac:st \"info\" \"Нет изменений или не выделены блоки.\"))")
      (action_tile "b_sync" "(if *ac:sel* (done_dialog 3) (ac:st \"info\" \"Выделите блоки в списке.\"))")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id))
    (princ (strcat "\nОшибка загрузки диалога (" fn ").")))
  (vl-file-delete fn)
  res)

;;; ---------- запись в описание блока ----------
;; переименовать атрибуты во всех вставках блока (значения сохраняются)
(defun ac:rename-refs (name pairs / o p)
  (foreach e (ac:ss->l (ssget "_X" '((0 . "INSERT") (66 . 1))))
    (setq o (vlax-ename->vla-object e))
    (if (= (strcase (ac:bname o)) (strcase name))
      (foreach a (vlax-invoke o 'GetAttributes)
        (if (setq p (assoc (strcase (vla-get-TagString a)) pairs))
          (vl-catch-all-apply 'vla-put-TagString (list a (cdr p))))))))

(defun ac:move (o x0 y0 x1 y1)
  (if (or (> (abs (- x1 x0)) 1e-9) (> (abs (- y1 y0)) 1e-9))
    (vla-Move o (vlax-3d-point x0 y0 0.0) (vlax-3d-point x1 y1 0.0))))

(defun ac:props (o r)
  (vla-put-TagString o (car r))
  (vla-put-PromptString o (nth 1 r))
  (if (> (nth 2 r) 0) (vla-put-Height o (nth 2 r)))
  (if (tblsearch "STYLE" (nth 3 r)) (vla-put-StyleName o (nth 3 r)))
  (if (tblsearch "LAYER" (nth 4 r)) (vla-put-Layer o (nth 4 r)))
  (vla-put-Invisible o (if (nth 5 r) :vlax-true :vlax-false))
  (vla-put-TextString o (if (nth 12 r) (nth 12 r) "")))

(defun ac:write (name L / orig o src sr ren n c keep)
  (setq orig (ac:read name) n 0)
  ;; 1. переименования во вставках - через временные имена (на случай обмена именами)
  (foreach r L
    (if (and (nth 8 r) (setq sr (vl-some '(lambda (x) (if (= (nth 8 x) (nth 8 r)) x)) orig)) (/= (car sr) (car r)))
      (setq ren (cons (list (car sr) (strcat "AC_TMP_" (itoa (setq n (1+ n)))) (car r)) ren))))
  (if ren
    (progn (ac:rename-refs name (mapcar '(lambda (x) (cons (car x) (cadr x))) ren))
           (ac:rename-refs name (mapcar '(lambda (x) (cons (cadr x) (caddr x))) ren))))
  ;; 2. новые - копии атрибута-источника
  (setq L (mapcar '(lambda (r)
                     (if (nth 8 r) r
                       (progn
                         (setq src (ac:obj (nth 9 r))
                               sr (vl-some '(lambda (x) (if (= (nth 8 x) (nth 9 r)) x)) orig))
                         (if (and src sr)
                           (progn (setq c (vla-Copy src))
                                  (vla-put-TextString c "")
                                  (ac:move c (nth 10 sr) (nth 11 sr) (nth 6 r) (nth 7 r))
                                  (ac:props c r)
                                  (ac:rnth 8 (vla-get-Handle c) (ac:rnth 10 (nth 6 r) (ac:rnth 11 (nth 7 r) r))))
                           r))))
                  L))
  ;; 3. существующие: свойства и положение
  (foreach r L
    (if (and (nth 10 r) (setq o (ac:obj (nth 8 r))))
      (progn (ac:props o r) (ac:move o (nth 10 r) (nth 11 r) (nth 6 r) (nth 7 r)))))
  ;; 4. удалённые
  (setq keep (mapcar '(lambda (r) (nth 8 r)) L))
  (foreach x orig (if (and (not (member (nth 8 x) keep)) (setq o (ac:obj (nth 8 x)))) (vla-Delete o)))
  ;; 5. порядок атрибутов в описании = порядок списка (копия в конец, оригинал удалить)
  (foreach r L
    (if (setq o (ac:obj (nth 8 r)))
      (progn (vla-Copy o) (vla-Delete o))))
  T)

(defun ac:sync (name / m)
  (setq m (getvar "CMDECHO")) (setvar "CMDECHO" 0)
  (vl-cmdf "_.ATTSYNC" "_N" name)
  (setvar "CMDECHO" m))

;;; ---------- команда ----------
(defun ac:run (/ *error* doc res nb cnt)
  (setq doc (ac:doc))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*")) (princ (strcat "\nОшибка: " m)))
    (vla-EndUndoMark doc) (princ))
  (setq *ac:ops* nil *ac:cur* nil res 2)
  (while (= res 2)
    (setq *ac:all* (ac:blocks) *ac:stys* nil *ac:lays* nil)
    (vlax-for s (vla-get-TextStyles doc) (setq *ac:stys* (cons (vla-get-Name s) *ac:stys*)))
    (vlax-for s (vla-get-Layers doc) (if (not (wcmatch (vla-get-Name s) "*|*")) (setq *ac:lays* (cons (vla-get-Name s) *ac:lays*))))
    (setq *ac:stys* (vl-sort *ac:stys* '<) *ac:lays* (vl-sort *ac:lays* '<))
    (if (null *ac:all*)
      (setq res 0)
      (progn
        (setq res (ac:dialog))
        (if (= res 1)
          (progn
            (vla-StartUndoMark doc)
            (setq nb 0 cnt 0)
            (foreach name *ac:sel*
              (ac:write name (ac:model name))
              (if (> (caddr (assoc name *ac:all*)) 0) (ac:sync name))
              (setq nb (1+ nb) cnt (+ cnt (caddr (assoc name *ac:all*)))))
            (vla-EndUndoMark doc)
            (princ (strcat "\nИзменено описаний блоков: " (itoa nb) ", обновлено вставок (АТРСИНХР): " (itoa cnt)
                           ". Отмена - ОТМЕНИТЬ (U)."))
            (setq *ac:ops* nil res 2)))
        ;; только синхронизировать вставки с описанием (АТРСИНХР), без записи изменений
        (if (= res 3)
          (progn
            (vla-StartUndoMark doc)
            (setq nb 0)
            (foreach name *ac:sel*
              (if (> (caddr (assoc name *ac:all*)) 0) (progn (ac:sync name) (setq nb (1+ nb)))))
            (vla-EndUndoMark doc)
            (princ (strcat "\nОбновлено (АТРСИНХР) блоков: " (itoa nb)
                           (if *ac:ops* ". Несохранённые изменения в окне остались - запишите их кнопкой \"Записать в блоки\"." ".")))
            (setq res 2))))))
  (if (null *ac:all*) (princ "\nВ чертеже нет блоков с атрибутами."))
  (princ))

(defun c:мм_атриб_изм () (ac:run))
(defun c:ММ_АТРИБ_ИЗМ () (ac:run))
(defun c:MM_ATTRIB_EDIT () (ac:run))

;;; ---------- сообщение при загрузке ----------
(princ "\n==================================================================")
(princ "\n BLOK_ATRIB_CHANGE.LSP загружен: состав и порядок атрибутов блоков")
(princ "\n  ММ_АТРИБ_ИЗМ (MM_ATTRIB_EDIT) - окно: фильтр блоков, атрибуты в порядке блока;")
(princ "\n    Вверх/Вниз, Добавить после (через запятую), Удалить, имя/подсказка/стиль/слой/")
(princ "\n    высота/невидимый; изменения - для всех выделенных блоков; запись + АТРСИНХР,")
(princ "\n    значения атрибутов сохраняются; значение по умолчанию; кнопка \"Обновить блоки")
(princ "\n    на чертеже\" - АТРСИНХР выделенных. Отмена - ОТМЕНИТЬ (U).")
(princ "\n==================================================================")
(princ)
