;;; ======================================================================
;;;  TXT_CHANGE.LSP  —  нумерация текстов (TEXT / MTEXT) по маске
;;;  AutoCAD 2024. Кодировка файла: Windows-1251 (ANSI).
;;; ----------------------------------------------------------------------
;;;  КОМАНДА:
;;;   ММ_ТЕКСТ_ЗАМЕНА (мм_текст_замена, MM_TEXT_REPLACE) - выделите тексты (можно до команды), введите команду.
;;;     В окне: маска, начальное значение, шаг, порядок, что заменять.
;;;     Внизу - предпросмотр "было -> станет". "Заменить" - применить.
;;;     Отмена всей замены - ОТМЕНИТЬ (U).
;;;   МАСКА:
;;;     #  - номер: 1, 2, 3        ## - 01, 02        ### - 001, 002
;;;     @  - буква: A, B ... Z, AA
;;;     *  - прежнее значение (всего текста или заменяемой части)
;;;     остальное - как есть.   Примеры: AS-# -> AS-1;  КД1.## -> КД1.01
;;;   ЧТО ЗАМЕНЯТЬ:
;;;     1) Весь текст - текст целиком заменяется результатом маски.
;;;     2) После найденных символов - в тексте ищется заданный набор
;;;        символов (например "ШС"), и заменяется значение СРАЗУ ЗА НИМ,
;;;        остальной текст сохраняется. Значение за найденным:
;;;          - число (цифры подряд):   "Извещатель ШС12 эт.3" -> "Извещатель ШС1 эт.3"
;;;          - до пробела:             "AS-015А кор.2"  (искать "AS-") -> "AS-1 кор.2"
;;;          - заданное число символов.
;;;        Тексты, где набор символов не найден, не меняются и номер
;;;        не занимают. Поиск без учёта регистра, первое вхождение.
;;;   Порядок: по строкам, по столбцам или в порядке выбора.
;;; ======================================================================

(vl-load-com)

(if (not *tc:mask*)  (setq *tc:mask* "#"))
(if (not *tc:start*) (setq *tc:start* "1"))
(if (not *tc:step*)  (setq *tc:step* "1"))
(if (not *tc:order*) (setq *tc:order* "o_lr"))
(if (not *tc:mode*)  (setq *tc:mode* "p_all" *tc:find* "" *tc:what* "w_num" *tc:wn* "2"))

;;; ---------- утилиты ----------
(defun tc:open-dcl (fn / f)
  ;; кодировка DCL по LISPSYS: 1 - UTF-8 с BOM, 0 - ANSI
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0))
    (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  f)

(defun tc:letters (n / s)                 ; 1 A, 26 Z, 27 AA
  (setq s "")
  (if (< n 1) (setq n 1))
  (while (> n 0)
    (setq n (1- n) s (strcat (chr (+ 65 (rem n 26))) s) n (/ n 26)))
  s)

(defun tc:pad (n len / s)
  (setq s (itoa (abs n)))
  (while (< (strlen s) len) (setq s (strcat "0" s)))
  (if (< n 0) (strcat "-" s) s))

(defun tc:fmt (mask n old / i c j r)
  (setq i 1 r "")
  (while (<= i (strlen mask))
    (setq c (substr mask i 1))
    (cond
      ((= c "#")
       (setq j i)
       (while (= (substr mask (1+ j) 1) "#") (setq j (1+ j)))
       (setq r (strcat r (tc:pad n (1+ (- j i)))) i j))
      ((= c "@") (setq r (strcat r (tc:letters n))))
      ((= c "*") (setq r (strcat r old)))
      (T (setq r (strcat r c))))
    (setq i (1+ i)))
  r)

;; длина значения за позицией b (1-based) по выбранному правилу
(defun tc:value-len (s b / e c)
  (setq e b)
  (cond
    ((= *tc:what* "w_num")
     (while (and (<= e (strlen s)) (wcmatch (substr s e 1) "#")) (setq e (1+ e))))
    ((= *tc:what* "w_word")
     (while (and (<= e (strlen s)) (not (member (substr s e 1) '(" " "\t")))) (setq e (1+ e))))
    (T (setq e (min (1+ (strlen s)) (+ b (max 0 (atoi *tc:wn*)))))))
  (- e b))

;; новое значение текста; nil - набор символов не найден (текст не меняется)
(defun tc:new-text (s n / p b len)
  (if (= *tc:mode* "p_all")
    (tc:fmt *tc:mask* n s)
    (if (and (/= *tc:find* "") (setq p (vl-string-search (strcase *tc:find*) (strcase s))))
      (progn
        (setq b (+ p 1 (strlen *tc:find*))
              len (tc:value-len s b))
        (strcat (substr s 1 (1- b))
                (tc:fmt *tc:mask* n (substr s b len))
                (substr s (+ b len)))))))

;;; ---------- тексты ----------
(defun tc:collect (ss / i e d res)        ; (ename точка высота текст)
  (repeat (setq i (sslength ss))
    (setq e (ssname ss (setq i (1- i))) d (entget e))
    (setq res (cons (list e (cdr (assoc 10 d)) (cdr (assoc 40 d))
                          (vla-get-TextString (vlax-ename->vla-object e)))
                    res)))
  res)

(defun tc:sort (recs order / tol)
  (setq tol (* 0.5 (apply 'max (mapcar 'caddr recs))))
  (cond
    ((= order "o_lr")
     (vl-sort recs '(lambda (a b / pa pb)
                      (setq pa (cadr a) pb (cadr b))
                      (if (> (abs (- (cadr pa) (cadr pb))) tol)
                        (> (cadr pa) (cadr pb)) (< (car pa) (car pb))))))
    ((= order "o_tb")
     (vl-sort recs '(lambda (a b / pa pb)
                      (setq pa (cadr a) pb (cadr b))
                      (if (> (abs (- (car pa) (car pb))) tol)
                        (< (car pa) (car pb)) (> (cadr pa) (cadr pb))))))
    (T recs)))

;; план замены: список (ename было станет); номер занимают только изменяемые
(defun tc:plan (/ k new res)
  (setq k 0)
  (foreach r (tc:sort *tc:recs* *tc:order*)
    (setq new (tc:new-text (nth 3 r) (+ (atoi *tc:start*) (* k (atoi *tc:step*)))))
    (if new (setq k (1+ k)))
    (setq res (cons (list (car r) (nth 3 r) new) res)))
  (setq *tc:count* k)
  (reverse res))

;;; ---------- окно ----------
(defun tc:write-dcl (/ fn f)
  (setq fn (vl-filename-mktemp "txt_change.dcl") f (tc:open-dcl fn))
  (foreach l
    '("tc_dlg : dialog { label = \"Нумерация текста по маске\";"
      " : text { key = \"hdr\"; width = 76; }"
      " : row { : edit_box { key = \"mask\"; label = \"Маска:\"; edit_width = 22; allow_accept = false; }"
      "         : edit_box { key = \"start\"; label = \"Начальное значение:\"; edit_width = 6; allow_accept = false; }"
      "         : edit_box { key = \"step\"; label = \"Шаг:\"; edit_width = 4; allow_accept = false; } }"
      " : boxed_column { label = \"Как задать маску\";"
      "   : text { label = \"#  - номер (1, 2, 3);   ## - 01, 02;   ### - 001, 002;   @ - буква (A, B ... Z, AA)\"; }"
      "   : text { label = \"*  - прежнее значение (всего текста или заменяемой части).  Остальное - как есть.\"; }"
      "   : text { label = \"Примеры:  AS-#  ->  AS-1, AS-2      КД1.##  ->  КД1.01      *-#  ->  Извещатель-1\"; } }"
      " : boxed_column { label = \"Что заменять\";"
      "   : radio_row { key = \"mode\";"
      "     : radio_button { key = \"p_all\"; label = \"Весь текст\"; }"
      "     : radio_button { key = \"p_find\"; label = \"Значение после найденных символов\"; } }"
      "   : edit_box { key = \"find\"; label = \"Искать символы:\"; edit_width = 20; allow_accept = false; }"
      "   : row { : radio_row { key = \"what\";"
      "             : radio_button { key = \"w_num\"; label = \"число за ними\"; }"
      "             : radio_button { key = \"w_word\"; label = \"до пробела\"; }"
      "             : radio_button { key = \"w_n\"; label = \"заданное число символов:\"; } }"
      "           : edit_box { key = \"wn\"; edit_width = 4; allow_accept = false; } }"
      "   : text { label = \"Пример: искать ШС, число за ними, маска # :  Извещатель ШС12 эт.3 -> Извещатель ШС1 эт.3\"; } }"
      " : boxed_radio_row { key = \"order\"; label = \"Порядок нумерации\";"
      "   : radio_button { key = \"o_lr\"; label = \"По строкам\"; }"
      "   : radio_button { key = \"o_tb\"; label = \"По столбцам\"; }"
      "   : radio_button { key = \"o_sel\"; label = \"В порядке выбора\"; } }"
      " : row { : text { key = \"t_prev\"; width = 54; }"
      "         : button { key = \"b_prev\"; label = \"Обновить просмотр\"; width = 20; fixed_width = true; } }"
      " : list_box { key = \"prev\"; height = 14; width = 76; tabs = \"4 36 40\"; }"
      " : text { key = \"info\"; width = 76; }"
      " : row { : button { key = \"accept\"; label = \"Заменить\"; is_default = true; width = 16; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 16; } } }")
    (write-line l f))
  (close f)
  fn)

(defun tc:modes ()
  (foreach k '("find" "what") (mode_tile k (if (= (get_tile "mode") "p_find") 0 1)))
  (mode_tile "wn" (if (and (= (get_tile "mode") "p_find") (= (get_tile "what") "w_n")) 0 1)))

(defun tc:read-tiles (/ m st sp)
  (setq m (get_tile "mask") st (get_tile "start") sp (get_tile "step"))
  (cond
    ((= m "") (set_tile "info" "Задайте маску.") nil)
    ((not (wcmatch st "#*,-#*")) (set_tile "info" "Начальное значение - целое число.") nil)
    ((not (wcmatch sp "#*,-#*")) (set_tile "info" "Шаг - целое число.") nil)
    ((and (= (get_tile "mode") "p_find") (= (get_tile "find") ""))
     (set_tile "info" "Укажите символы, которые нужно найти.") nil)
    (T (setq *tc:mask* m *tc:start* st *tc:step* sp
             *tc:order* (get_tile "order") *tc:mode* (get_tile "mode")
             *tc:find* (get_tile "find") *tc:what* (get_tile "what") *tc:wn* (get_tile "wn"))
       (set_tile "info" "") T)))

(defun tc:preview (/ k skip)
  (if (tc:read-tiles)
    (progn
      (setq *tc:planlist* (tc:plan) k 0 skip 0)
      (start_list "prev")
      (foreach p *tc:planlist*
        (setq k (1+ k))
        (if (null (caddr p)) (setq skip (1+ skip)))
        (add_list (strcat (itoa k) "\t" (cadr p) "\t->\t"
                          (if (caddr p) (caddr p) "(не найдено - без изменений)"))))
      (end_list)
      (set_tile "t_prev" (strcat "Предпросмотр: будет изменено " (itoa *tc:count*)
                                 (if (> skip 0) (strcat ", без изменений " (itoa skip)) ""))))))

(defun tc:dialog (/ fn id res)
  (setq fn (tc:write-dcl) id (load_dialog fn))
  (if (not (new_dialog "tc_dlg" id))
    (princ (strcat "\nОшибка загрузки диалога (" fn ")."))
    (progn
      (set_tile "hdr" (strcat "Выбрано текстов: " (itoa (length *tc:recs*))))
      (set_tile "mask" *tc:mask*)
      (set_tile "start" *tc:start*)
      (set_tile "step" *tc:step*)
      (set_tile "order" *tc:order*)
      (set_tile "mode" *tc:mode*)
      (set_tile "find" *tc:find*)
      (set_tile "what" *tc:what*)
      (set_tile "wn" *tc:wn*)
      (tc:modes)
      (tc:preview)
      ;; просмотр обновляется при выходе из поля / Enter и при переключениях
      (foreach k '("mask" "start" "step" "order" "find" "wn" "b_prev")
        (action_tile k "(tc:preview)"))
      (action_tile "mode" "(tc:modes) (tc:preview)")
      (action_tile "what" "(tc:modes) (tc:preview)")
      (action_tile "accept" "(if (tc:read-tiles) (progn (tc:preview) (done_dialog 1)))")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)))
  (vl-file-delete fn)
  (= res 1))

;;; ---------- команда ----------
(defun c:MM_TEXT_REPLACE () (c:ММ_ТЕКСТ_ЗАМЕНА))
(defun c:мм_текст_замена () (c:ММ_ТЕКСТ_ЗАМЕНА))
(defun c:ММ_ТЕКСТ_ЗАМЕНА (/ *error* doc ss n)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*"))
      (princ (strcat "\nОшибка: " m)))
    (vla-EndUndoMark doc)
    (princ))
  (if (not (setq ss (ssget "_I" '((0 . "TEXT,MTEXT")))))
    (progn
      (princ "\nВыберите тексты для нумерации: ")
      (setq ss (ssget '((0 . "TEXT,MTEXT"))))))
  (sssetfirst nil nil)
  (if ss
    (progn
      (setq *tc:recs* (tc:collect ss))
      (if (tc:dialog)
        (progn
          (vla-StartUndoMark doc)
          (foreach p *tc:planlist*
            (if (caddr p)
              (vl-catch-all-apply 'vla-put-TextString
                (list (vlax-ename->vla-object (car p)) (caddr p)))))
          (vla-EndUndoMark doc)
          (setq n (+ (atoi *tc:start*) (* *tc:count* (atoi *tc:step*))))
          (princ (strcat "\nЗаменено текстов: " (itoa *tc:count*) ". Следующий номер: " (itoa n) "."))
          (setq *tc:start* (itoa n)))           ; продолжить нумерацию в следующий раз
        (princ "\nОтменено."))))
  (princ))

;;; ---------- сообщение при загрузке ----------
(princ "\n==================================================================")
(princ "\n TXT_CHANGE.LSP загружен: нумерация TEXT/MTEXT по маске")
(princ "\n  ММ_ТЕКСТ_ЗАМЕНА (MM_TEXT_REPLACE) - выделите тексты -> маска, начало, шаг, порядок ->")
(princ "\n               предпросмотр -> Заменить.")
(princ "\n  Маска: # номер, ## 01, @ буква, * прежнее значение.")
(princ "\n  Режим \"после найденных символов\": ШС12 -> ШС1, остальной текст сохраняется.")
(princ "\n==================================================================")
(princ)
