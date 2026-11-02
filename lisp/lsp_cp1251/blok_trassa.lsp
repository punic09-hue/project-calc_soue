;;; ======================================================================
;;;  MM_ROUTE.LSP  —  Этап 6: трассы (кабеленесущие системы) на плане
;;;  AutoCAD 2024. Кодировка файла: Windows-1251 (ANSI).
;;; ----------------------------------------------------------------------
;;;  ТРАССА = полилиния (ось трассы) + данные в XDATA "TRASSA":
;;;  тип, наименование/размер, ширина на плане, высота прокладки.
;;;  Тип задаёт слой и тип линии. Для лотков/коробов (и по желанию для
;;;  любых трасс) рисуется КОНТУР ширины - две линии по обе стороны оси,
;;;  которые перестраиваются сами при любой правке оси (ручки, перенос,
;;;  растягивание, копирование, удаление).
;;;  Эти трассы - основа Этапа 7 (автоматическая прокладка кабелей).
;;; ----------------------------------------------------------------------
;;;  КОМАНДЫ:
;;;   ММ_ТРАССА (MM_ROUTE)      - нарисовать трассу:
;;;       окно: тип, наименование (Лоток 100х50), ширина на плане, мм,
;;;       высота прокладки, м, слой, масштаб типа линии -> точки как у
;;;       ПЛИНИЯ. Концы трассы сами "примагничиваются" к концу или к
;;;       середине соседней трассы в пределах допуска (связность для
;;;       прокладки кабелей). Enter - следующая трасса того же типа.
;;;       [Объект] - сделать трассой готовые полилинии/отрезки.
;;;   ММ_ТРАССА_ИЗМ (MM_ROUTE_EDIT)- изменить параметры выбранных трасс
;;;       (поля <разные> не меняются).
;;;   ММ_ТРАССА_ПРОВЕРКА (MM_ROUTE_CHECK) [Включить/Отключить] - проверка связности:
;;;       красный круг   - разрыв: конец трассы рядом с другой трассой,
;;;                        но не соединён (кабель там не пройдёт);
;;;       жёлтый круг    - пересечение трасс без соединения
;;;                        (норма, если трассы на разной высоте).
;;;       Метки на слое "_ПРОВЕРКА_ТРАСС" (не печатается).
;;;   ММ_ТРАССА_ОБНОВИТЬ (MM_ROUTE_UPDATE) - перестроить все контуры и типы линий.
;;;   ММ_ТРАССА_НАСТР (MM_ROUTE_SETTINGS) - допуск примагничивания и радиус поиска разрывов.
;;; ----------------------------------------------------------------------
;;;  Единицы: чертёж в мм (ширина лотка 100 = 100 ед. чертежа).
;;;  Типы линий создаются автоматически (текст в линии, шрифт Arial),
;;;  таблицу типов трасс *tr:types* ниже можно дополнять.
;;; ======================================================================

(vl-load-com)

;;; ---------- справочник типов трасс (можно дополнять) ----------
;; код  название  слой  цвет_слоя  тип_линии  надпись_в_линии(nil-штрих, "-"-сплошная)
;; контур_по_умолчанию  ширина_по_умолч.  наименование_по_умолч.
(setq *tr:types*
  '(("LOTOK"  "Лоток кабельный"                "ТР_ЛОТОК"    30 "TR_LOTOK"  "Л"  T   100 "Лоток перфорированный 100х50")
    ("KOROB"  "Кабель-канал (короб)"           "ТР_КОРОБ"     4 "TR_KOROB"  "К"  T    40 "Кабель-канал 40х25")
    ("GOFRA"  "Гофротруба по потолку / стене"  "ТР_ГОФРА"     3 "TR_GOFRA"  "Тг" nil   20 "Труба гофрированная ПВХ d20")
    ("GOFZP"  "Гофротруба за подвесным потолком" "ТР_ГОФРА_ЗП" 3 "TR_GOFZP" "ЗП" nil   20 "Труба гофрированная ПВХ d20")
    ("POL"    "Труба в полу (в стяжке)"        "ТР_ПОЛ"       6 "TR_POL"    "П"  nil   25 "Труба гофрированная ПНД d25")
    ("TRUBA"  "Труба жёсткая открыто"          "ТР_ТРУБА"     5 "TR_TRUBA"  "Т"  nil   20 "Труба ПВХ жёсткая d20")
    ("MR"     "Металлорукав"                   "ТР_МР"      150 "TR_MR"     "Мр" nil   15 "Металлорукав РЗ-ЦХ 15")
    ("SKR"    "Скрыто в штробе"                "ТР_СКРЫТО"    1 "TR_SKR"    nil  nil    0 "Скрыто в штробе")
    ("TROS"   "На тросе"                       "ТР_ТРОС"    210 "TR_TROS"   "Тр" nil    0 "На тросе")
    ("OTKR"   "Открыто по конструкциям"        "ТР_ОТКРЫТО"   2 "Continuous" "-" nil    0 "Открыто")))

(setq *tr:layer-k* "ТР_КОНТУР"          ; слой контуров ширины
      *tr:layer-chk* "_ПРОВЕРКА_ТРАСС")  ; слой меток проверки
(if (not *tr:tol*)  (setq *tr:tol* 50.0))    ; допуск примагничивания, ед. чертежа
(if (not *tr:near*) (setq *tr:near* 500.0))  ; радиус поиска разрывов
(if (not *tr:par*)  ; код наименование контур(1/0) ширина высота слой масштаб
  (setq *tr:par* (list "LOTOK" "Лоток перфорированный 100х50" "1" "100" "2.8" "ТР_ЛОТОК" "100")))

;;; ---------- утилиты ----------
(defun tr:trim (s) (vl-string-trim " \t" (if s s "")))
(defun tr:doc () (vla-get-ActiveDocument (vlax-get-acad-object)))
(defun tr:space () (vla-get-Block (vla-get-ActiveLayout (tr:doc))))
(defun tr:type (code) (assoc code *tr:types*))
(defun tr:2d (p) (list (car p) (cadr p)))
(defun tr:ss->l (ss / i l)
  (if ss (repeat (setq i (sslength ss)) (setq l (cons (ssname ss (setq i (1- i))) l))))
  l)

(defun tr:open-dcl (fn / f)
  ;; кодировка DCL по LISPSYS: 1 - UTF-8 с BOM, 0 - ANSI
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0))
    (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  f)

(defun tr:write-1251 (fn txt / st)   ; .lin в кодировке 1251 через ADODB.Stream
  (setq st (vlax-create-object "ADODB.Stream"))
  (vlax-put st 'Type 2)
  (vlax-put st 'Charset "windows-1251")
  (vlax-invoke st 'Open)
  (vlax-invoke st 'WriteText txt)
  (vlax-invoke st 'SaveToFile fn 2)
  (vlax-invoke st 'Close)
  (vlax-release-object st))

(defun tr:layer (name color / l)
  (if (not (tblsearch "LAYER" name))
    (progn
      (setq l (vla-Add (vla-get-Layers (tr:doc)) name))
      (if color (vla-put-Color l color))
      l)))

;;; ---------- типы линий ----------
(defun tr:load-lt (code / p txt fn gap)
  (setq p (tr:type code) txt (nth 5 p))
  (cond
    ((or (null p) (= txt "-")) "Continuous")
    ((tblsearch "LTYPE" (nth 4 p)) (nth 4 p))
    (T
      (if (not (tblsearch "STYLE" "TR_LT"))
        (vl-catch-all-apply 'vla-put-FontFile
          (list (vla-Add (vla-get-TextStyles (tr:doc)) "TR_LT") "arial.ttf")))
      (setq fn (strcat (getvar "TEMPPREFIX") "trassa_ltypes.lin"))
      (tr:write-1251 fn
        (strcat "*" (nth 4 p) "," (nth 1 p) "\r\n"
          (if txt
            (progn
              (setq gap (+ 1.5 (* 1.9 (strlen txt))))
              (strcat "A,12,-1,[\"" txt "\",TR_LT,S=2.5,U=0.0,X=0.0,Y=-1.25],-" (rtos gap 2 1) "\r\n"))
            "A,6,-3\r\n")))
      (vl-catch-all-apply 'vla-Load (list (vla-get-Linetypes (tr:doc)) (nth 4 p) fn))
      (if (tblsearch "LTYPE" (nth 4 p)) (nth 4 p) "Continuous"))))

;;; ---------- XDATA ----------
;; TRASSA:   (1000 код)(1000 наименование)(1070 контур)(1040 ширина)(1040 высота)(1005 контур)...
;; TRASSA_K: у линии контура - (1005 хэндл оси)
(defun tr:reg () (regapp "TRASSA") (regapp "TRASSA_K"))
(defun tr:xd (e app / x) (if (setq x (assoc -3 (entget e (list app)))) (cdr (cadr x))))
(defun tr:trace-p (e) (and e (entget e) (tr:xd e "TRASSA")))

;; -> (код наименование контур(1/0) ширина высота (хэндлы_контура))
(defun tr:get (e / l s r)
  (setq l (tr:xd e "TRASSA")
        s (mapcar 'cdr (vl-remove-if-not '(lambda (p) (= (car p) 1000)) l))
        r (mapcar 'cdr (vl-remove-if-not '(lambda (p) (= (car p) 1040)) l)))
  (list (nth 0 s) (nth 1 s) (cond ((cdr (assoc 1070 l))) (0)) (nth 0 r) (nth 1 r)
        (mapcar 'cdr (vl-remove-if-not '(lambda (p) (= (car p) 1005)) l))))

(defun tr:put (e code name outl w h hs)
  (tr:reg)
  (entmod (append (entget e)
            (list (list -3 (append (list "TRASSA" (cons 1000 code) (cons 1000 name)
                                         (cons 1070 outl) (cons 1040 w) (cons 1040 h))
                                   (mapcar '(lambda (x) (cons 1005 x)) hs)))))))

;;; ---------- контур ширины ----------
(defun tr:owner-of (k / x) (if (setq x (assoc 1005 (tr:xd k "TRASSA_K"))) (cdr x)))

;; удалить контуры оси e (только свои - у копий чужие не трогаем)
(defun tr:del-outline (e / h k)
  (setq h (cdr (assoc 5 (entget e))))
  (foreach x (nth 5 (tr:get e))
    (if (and (setq k (handent x)) (entget k) (= (tr:owner-of k) h))
      (entdel k))))

(defun tr:build-outline (e / d o h res r)
  (setq d (tr:get e) h (cdr (assoc 5 (entget e))))
  (tr:del-outline e)
  (if (and (= (nth 2 d) 1) (> (nth 3 d) 0))
    (progn
      (tr:layer *tr:layer-k* 8)
      (setq o (vlax-ename->vla-object e))
      (foreach s (list 0.5 -0.5)
        (setq r (vl-catch-all-apply 'vlax-invoke (list o 'Offset (* s (nth 3 d)))))
        (if (not (vl-catch-all-error-p r))
          (foreach k r
            (vla-put-Layer k *tr:layer-k*)
            (vla-put-Linetype k "ByLayer")
            (vla-put-Color k 256)
            (vl-catch-all-apply 'vla-put-ConstantWidth (list k 0.0))
            (tr:reg)
            (entmod (append (entget (vlax-vla-object->ename k))
                            (list (list -3 (list "TRASSA_K" (cons 1005 h))))))
            (setq res (cons (vla-get-Handle k) res)))))))
  (tr:put e (nth 0 d) (nth 1 d) (nth 2 d) (nth 3 d) (nth 4 d) res))

;;; ---------- применить параметры к оси ----------
;; par: (код наименование контур ширина высота слой масштаб)
(defun tr:apply (e par / o p old)
  (setq o (vlax-ename->vla-object e) p (tr:type (nth 0 par))
        old (if (tr:trace-p e) (nth 5 (tr:get e))))
  (setq *tr:busy* T)
  (tr:layer (nth 5 par) (nth 3 p))
  (vla-put-Layer o (nth 5 par))
  (vla-put-Linetype o (tr:load-lt (nth 0 par)))
  (vla-put-LinetypeScale o (max 0.001 (atof (nth 6 par))))
  (vl-catch-all-apply 'vla-put-ConstantWidth (list o 0.0))
  (tr:put e (nth 0 par) (nth 1 par) (atoi (nth 2 par))
          (atof (nth 3 par)) (atof (vl-string-translate "," "." (nth 4 par))) old)
  (tr:build-outline e)
  (setq *tr:busy* nil)
  (tr:watch e))

;;; ---------- примагничивание концов ----------
(defun tr:all (/ ss) (tr:ss->l (ssget "_X" '((-3 ("TRASSA"))))))

(defun tr:set-end (e which pt / o n)
  (setq o (vlax-ename->vla-object e))
  (cond
    ((= (vla-get-ObjectName o) "AcDbPolyline")
     (setq n (if (= which 0) 0 (fix (vlax-curve-getEndParam o))))
     (vla-put-Coordinate o n (tr:pt2v pt)))
    ((= (vla-get-ObjectName o) "AcDbLine")
     (if (= which 0) (vla-put-StartPoint o (vlax-3d-point pt)) (vla-put-EndPoint o (vlax-3d-point pt))))))

(defun tr:pt2v (p / a)
  (setq a (vlax-make-safearray vlax-vbDouble '(0 . 1)))
  (vlax-safearray-fill a (list (car p) (cadr p)))
  (vlax-make-variant a))

;; найти точку привязки: конец другой трассы, иначе ближайшая точка на ней
(defun tr:snap-pt (e p / best bd o q d)
  (setq bd *tr:tol*)
  (foreach t1 (tr:all)
    (if (not (eq t1 e))
      (progn
        (setq o (vlax-ename->vla-object t1))
        (foreach q (list (vlax-curve-getStartPoint o) (vlax-curve-getEndPoint o))
          (if (<= (setq d (distance (tr:2d q) (tr:2d p))) bd) (setq bd d best q))))))
  (if (not best)
    (foreach t1 (tr:all)
      (if (not (eq t1 e))
        (progn
          (setq q (vlax-curve-getClosestPointToProjection (vlax-ename->vla-object t1) p '(0.0 0.0 1.0)))
          (if (<= (setq d (distance (tr:2d q) (tr:2d p))) bd) (setq bd d best q))))))
  best)

(defun tr:snap-ends (e / o p q n)
  (setq o (vlax-ename->vla-object e) n 0)
  (foreach w '(0 1)
    (setq p (if (= w 0) (vlax-curve-getStartPoint o) (vlax-curve-getEndPoint o)))
    (if (and (setq q (tr:snap-pt e p)) (> (distance (tr:2d p) (tr:2d q)) 1e-6))
      (progn (tr:set-end e w (list (car q) (cadr q) (caddr p))) (setq n (1+ n)))))
  n)

;;; ---------- окно параметров ----------
(defun tr:write-dcl (/ fn f)
  (setq fn (vl-filename-mktemp "blok_trassa.dcl") f (tr:open-dcl fn))
  (foreach l
    '("tr_dlg : dialog { label = \"Параметры трассы\";"
      " : text { key = \"hdr\"; width = 66; }"
      " : popup_list { key = \"type\"; label = \"Тип трассы:\"; width = 66; }"
      " : edit_box { key = \"name\"; label = \"Наименование (размер):\"; edit_width = 44; allow_accept = false; }"
      " : row { : toggle { key = \"outl\"; label = \"Показывать ширину (контур)\"; }"
      "         : edit_box { key = \"width\"; label = \"Ширина на плане, мм:\"; edit_width = 8; allow_accept = false; } }"
      " : edit_box { key = \"h\"; label = \"Высота прокладки от пола, м:\"; edit_width = 8; allow_accept = false; }"
      " : edit_box { key = \"layer\"; label = \"Слой:\"; edit_width = 26; allow_accept = false; }"
      " : edit_box { key = \"lts\"; label = \"Масштаб типа линии:\"; edit_width = 8; allow_accept = false; }"
      " : text { key = \"info\"; width = 66; }"
      " : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 16; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 16; } } }")
    (write-line l f))
  (close f)
  fn)

;; при смене типа - подставить значения по умолчанию
(defun tr:type-changed (i codes / p)
  (if (setq p (tr:type (nth i codes)))
    (progn
      (set_tile "name" (nth 8 p))
      (set_tile "outl" (if (nth 6 p) "1" "0"))
      (set_tile "width" (itoa (nth 7 p)))
      (set_tile "layer" (nth 2 p))
      (mode_tile "width" (if (nth 6 p) 0 1)))))

(defun tr:dialog (par multi hdr / fn id res codes names out)
  (setq codes (mapcar 'car *tr:types*) names (mapcar 'cadr *tr:types*))
  (if multi (setq codes (cons "*" codes) names (cons "<разные - не менять>" names)))
  (setq fn (tr:write-dcl) id (load_dialog fn))
  (if (not (new_dialog "tr_dlg" id))
    (princ (strcat "\nОшибка загрузки диалога (файл " fn "). Проверьте LISPSYS и права на папку TEMP."))
    (progn
      (set_tile "hdr" hdr)
      (start_list "type") (foreach n names (add_list n)) (end_list)
      (set_tile "type" (itoa (cond ((vl-position (nth 0 par) codes)) (0))))
      (set_tile "name" (nth 1 par))
      (set_tile "outl" (if (= (nth 2 par) "0") "0" "1"))
      (set_tile "width" (nth 3 par))
      (set_tile "h" (nth 4 par))
      (set_tile "layer" (nth 5 par))
      (set_tile "lts" (nth 6 par))
      (mode_tile "width" (if (= (nth 2 par) "0") 1 0))
      (if multi (set_tile "info" "Поля со значением <разные> останутся без изменений."))
      (action_tile "type" "(tr:type-changed (atoi $value) codes)")
      (action_tile "outl" "(mode_tile \"width\" (if (= $value \"1\") 0 1))")
      (action_tile "accept"
        (strcat "(setq out (list (nth (atoi (get_tile \"type\")) codes) (tr:trim (get_tile \"name\"))"
                " (get_tile \"outl\") (tr:trim (get_tile \"width\")) (tr:trim (get_tile \"h\"))"
                " (tr:trim (get_tile \"layer\")) (tr:trim (get_tile \"lts\"))))"
                " (cond ((= (nth 5 out) \"\") (set_tile \"info\" \"Укажите слой.\"))"
                " ((and (= (nth 2 out) \"1\") (/= (nth 3 out) \"<разные>\") (<= (atof (nth 3 out)) 0))"
                "  (set_tile \"info\" \"Ширина должна быть больше 0.\"))"
                " (T (done_dialog 1)))"))
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))
      (unload_dialog id)))
  (vl-file-delete fn)
  (if (= res 1) out))

;;; ---------- ТРАССА ----------
(defun tr:cmd-draw (/ par p e last ss n k)
  (if (setq par (tr:dialog *tr:par* nil "После OK рисуйте трассу как полилинию."))
    (progn
      (setq *tr:par* par n 0)
      (while
        (progn
          (initget "Объект")
          (setq p (getpoint (strcat "\n" (nth 1 *tr:par*) ": первая точка [Объект] <выход>: "))))
        (cond
          ((= p "Объект")
           (princ "\nВыберите полилинии/отрезки: ")
           (if (setq ss (ssget '((0 . "LWPOLYLINE,LINE"))))
             (foreach e (tr:ss->l ss)
               (tr:snap-ends e)
               (tr:apply e *tr:par*)
               (setq n (1+ n)))))
          ((listp p)
           (setq last (entlast))
           (command "_.PLINE" p)
           (while (> (getvar "CMDACTIVE") 0) (command pause))
           (setq e (entlast))
           (if (and e (not (eq e last)) (= (cdr (assoc 0 (entget e))) "LWPOLYLINE"))
             (progn
               (setq k (tr:snap-ends e))
               (tr:apply e *tr:par*)
               (if (> k 0) (princ (strcat "\nКонцов присоединено к соседним трассам: " (itoa k))))
               (setq n (1+ n)))))))
      (princ (strcat "\nСоздано трасс: " (itoa n) "."))))
  (princ))

;;; ---------- ТРАССА_ИЗМ ----------
(defun tr:common (vals) (if (vl-every '(lambda (v) (= v (car vals))) vals) (car vals) "<разные>"))

(defun tr:cmd-edit (/ l pars com new)
  (princ "\nВыберите трассы: ")
  (if (setq l (tr:ss->l (ssget '((-3 ("TRASSA"))))))
    (progn
      (setq pars (mapcar '(lambda (e / d o)
                            (setq d (tr:get e) o (vlax-ename->vla-object e))
                            (list (nth 0 d) (nth 1 d) (itoa (nth 2 d)) (rtos (nth 3 d) 2 0)
                                  (rtos (nth 4 d) 2 2) (vla-get-Layer o) (rtos (vla-get-LinetypeScale o) 2 2)))
                         l))
      (setq com (list (if (vl-every '(lambda (p) (= (car p) (car (car pars)))) pars) (car (car pars)) "*")
                      (tr:common (mapcar 'cadr pars))
                      (tr:common (mapcar 'caddr pars))
                      (tr:common (mapcar 'cadddr pars))
                      (tr:common (mapcar '(lambda (p) (nth 4 p)) pars))
                      (tr:common (mapcar '(lambda (p) (nth 5 p)) pars))
                      (tr:common (mapcar '(lambda (p) (nth 6 p)) pars))))
      (if (setq new (tr:dialog com T (strcat "Выбрано трасс: " (itoa (length l)))))
        (progn
          (mapcar '(lambda (e p)
                     (tr:apply e (mapcar '(lambda (nv ov) (if (member nv '("<разные>" "*")) ov nv)) new p)))
                  l pars)
          (princ (strcat "\nИзменено трасс: " (itoa (length l)) "."))))))
  (princ))

;;; ---------- ТРАССА_ПРОВЕРКА ----------
(defun tr:mark (p color txt / r c)
  (setq r (* 0.3 *tr:near*))
  (setq c (vla-AddCircle (tr:space) (vlax-3d-point p) r))
  (vla-put-Layer c *tr:layer-chk*) (vla-put-Color c color)
  (setq c (vla-AddText (tr:space) txt (vlax-3d-point (list (+ (car p) r) (+ (cadr p) r) 0.0)) (* 0.25 r)))
  (vla-put-Layer c *tr:layer-chk*) (vla-put-Color c color))

(defun tr:chk-clear (/ ss)
  (if (and (tblsearch "LAYER" *tr:layer-chk*) (setq ss (ssget "_X" (list (cons 8 *tr:layer-chk*)))))
    (foreach e (tr:ss->l ss) (entdel e))))

(defun tr:near-end-p (p objs tol)
  (vl-some '(lambda (o) (or (< (distance (tr:2d p) (tr:2d (vlax-curve-getStartPoint o))) tol)
                            (< (distance (tr:2d p) (tr:2d (vlax-curve-getEndPoint o))) tol)))
           objs))

(defun tr:cmd-check (/ k all objs gaps cross o p q d dmin l oth pts i)
  (initget "Включить Отключить")
  (setq k (getkword "\nПроверка связности трасс [Включить/Отключить] <Включить>: "))
  (tr:chk-clear)
  (if (/= k "Отключить")
    (progn
      (setq all (tr:all) objs (mapcar 'vlax-ename->vla-object all) gaps 0 cross 0)
      (if (not (tblsearch "LAYER" *tr:layer-chk*))
        (vla-put-Plottable (tr:layer *tr:layer-chk* 1) :vlax-false))
      ;; 1) разрывы: свободный конец близко к другой трассе
      (foreach o objs
        (foreach p (list (vlax-curve-getStartPoint o) (vlax-curve-getEndPoint o))
          (setq oth (vl-remove o objs) dmin nil)
          (foreach o2 oth
            (setq q (vlax-curve-getClosestPointToProjection o2 p '(0.0 0.0 1.0))
                  d (distance (tr:2d p) (tr:2d q)))
            (if (or (null dmin) (< d dmin)) (setq dmin d)))
          (if (and dmin (> dmin 1e-3) (<= dmin *tr:near*))
            (progn (tr:mark p 1 (strcat "разрыв " (rtos dmin 2 0))) (setq gaps (1+ gaps))))))
      ;; 2) пересечения без соединения
      (setq l objs)
      (while l
        (setq o (car l) l (cdr l))
        (foreach o2 l
          (setq pts (vlax-invoke o 'IntersectWith o2 acExtendNone) i 0)
          (while (< i (length pts))
            (setq p (list (nth i pts) (nth (+ i 1) pts) (nth (+ i 2) pts)) i (+ i 3))
            (if (not (tr:near-end-p p (list o o2) 1e-3))
              (progn (tr:mark p 2 "пересечение без соединения") (setq cross (1+ cross)))))))
      (princ (strcat "\nТрасс: " (itoa (length all)) ", разрывов: " (itoa gaps)
                     ", пересечений без соединения: " (itoa cross)
                     (if (> (+ gaps cross) 0) (strcat ". Метки на слое " *tr:layer-chk* ".") "."))))
    (princ "\nМетки проверки удалены."))
  (princ))

;;; ---------- ТРАССА_НАСТР ----------
(defun tr:cmd-setup (/ v)
  (initget 6)
  (if (setq v (getdist (strcat "\nДопуск примагничивания концов трасс <" (rtos *tr:tol* 2 1) ">: ")))
    (setq *tr:tol* v))
  (initget 6)
  (if (setq v (getdist (strcat "\nРадиус поиска разрывов при проверке <" (rtos *tr:near* 2 1) ">: ")))
    (setq *tr:near* v))
  (princ))

;;; ---------- синхронизация контуров (реакторы) ----------
;; при правке оси она попадает в *tr:pending*; по окончании команды контуры
;; перестраиваются; контуры без живой оси удаляются; копии получают свои контуры.
(defun tr:watch (e / o)
  (setq o (vlax-ename->vla-object e))
  (if (not (member o (vlr-owners *tr:oreactor*))) (vlr-owner-add *tr:oreactor* o)))

(defun tr:on-mod (owner r args)
  (if (and (not *tr:busy*) (not (vlax-erased-p owner)))
    (setq *tr:pending* (cons (vlax-vla-object->ename owner) *tr:pending*))))

(defun tr:outline-ok (e / h hs)
  (setq h (cdr (assoc 5 (entget e))) hs (nth 5 (tr:get e)))
  (and hs (vl-every '(lambda (x / k) (and (setq k (handent x)) (entget k) (= (tr:owner-of k) h))) hs)))

(defun tr:sync (full / ss k own d)
  (setq *tr:busy* T)
  ;; контуры без оси
  (if (setq ss (ssget "_X" '((-3 ("TRASSA_K")))))
    (foreach k (tr:ss->l ss)
      (if (not (and (setq own (tr:owner-of k)) (handent own) (entget (handent own))))
        (entdel k))))
  ;; изменённые оси
  (foreach e *tr:pending*
    (if (and (entget e) (tr:trace-p e)) (tr:build-outline e)))
  (setq *tr:pending* nil)
  ;; копии и новые оси: подключить к реактору, построить свои контуры
  (if full
    (foreach e (tr:all)
      (tr:watch e)
      (setq d (tr:get e))
      (if (and (= (nth 2 d) 1) (> (nth 3 d) 0) (not (tr:outline-ok e)))
        (tr:build-outline e))))
  (setq *tr:busy* nil))

(defun tr:on-cmd-end (r c / full)
  (setq full (wcmatch (strcase (car c))
               "COPY,ERASE,U,UNDO,REDO,MREDO,OOPS,PASTECLIP,PASTEORIG,MIRROR,ARRAY*,INSERT,EXPLODE,BREAK,TRIM,EXTEND,JOIN"))
  (if (and (not *tr:busy*) (or *tr:pending* full))
    (vl-catch-all-apply 'tr:sync (list full))))

(if (not *tr:oreactor*)
  (setq *tr:oreactor* (vlr-object-reactor nil "TRASSA" '((:vlr-modified . tr:on-mod)))))
(defun tr:on-lisp-end (r c) (if (and (not *tr:busy*) *tr:pending*) (vl-catch-all-apply 'tr:sync (list nil))))
;; окончание команд AutoCAD - реактор команд, окончание LISP-выражений - отдельный LISP-реактор
(if (not *tr:creactor*)
  (setq *tr:creactor* (vlr-command-reactor "TRASSA" '((:vlr-commandEnded . tr:on-cmd-end)))))
;; (правка ручками тоже завершается командой GRIP_*, поэтому LISP-реактор не нужен)

;;; ---------- обёртка команд ----------
(defun tr:run (fun / *error* doc)
  (setq doc (tr:doc))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*"))
      (princ (strcat "\nОшибка: " m)))
    (setq *tr:busy* nil)
    (vla-EndUndoMark doc)
    (princ))
  (vla-StartUndoMark doc)
  (apply fun nil)
  (vla-EndUndoMark doc)
  (princ))

(defun tr:cmd-refresh (/ n)
  (setq n 0)
  (foreach e (tr:all)
    (tr:apply e (list (nth 0 (tr:get e)) (nth 1 (tr:get e)) (itoa (nth 2 (tr:get e)))
                      (rtos (nth 3 (tr:get e)) 2 3) (rtos (nth 4 (tr:get e)) 2 3)
                      (vla-get-Layer (vlax-ename->vla-object e))
                      (rtos (vla-get-LinetypeScale (vlax-ename->vla-object e)) 2 3)))
    (setq n (1+ n)))
  (tr:sync T)
  (princ (strcat "\nОбновлено трасс: " (itoa n) ".")))

;; Команды. Кириллица объявлена в двух регистрах: в старых режимах LISP
;; (LISPSYS=0) регистр русских букв в именах команд не выравнивается.
(defun c:мм_трасса ()          (tr:run 'tr:cmd-draw))
(defun c:ММ_ТРАССА ()          (tr:run 'tr:cmd-draw))
(defun c:MM_ROUTE ()          (tr:run 'tr:cmd-draw))
(defun c:мм_трасса_изм ()      (tr:run 'tr:cmd-edit))
(defun c:ММ_ТРАССА_ИЗМ ()      (tr:run 'tr:cmd-edit))
(defun c:MM_ROUTE_EDIT ()      (tr:run 'tr:cmd-edit))
(defun c:мм_трасса_проверка () (tr:run 'tr:cmd-check))
(defun c:ММ_ТРАССА_ПРОВЕРКА () (tr:run 'tr:cmd-check))
(defun c:MM_ROUTE_CHECK ()     (tr:run 'tr:cmd-check))
(defun c:мм_трасса_обновить () (tr:run 'tr:cmd-refresh))
(defun c:ММ_ТРАССА_ОБНОВИТЬ () (tr:run 'tr:cmd-refresh))
(defun c:MM_ROUTE_UPDATE ()      (tr:run 'tr:cmd-refresh))
(defun c:мм_трасса_настр ()    (tr:cmd-setup))
(defun c:ММ_ТРАССА_НАСТР ()    (tr:cmd-setup))
(defun c:MM_ROUTE_SETTINGS ()    (tr:cmd-setup))

;; подключить реактор к трассам, уже имеющимся в чертеже
(defun tr:watch-all () (foreach e (tr:all) (tr:watch e)))
(vl-catch-all-apply 'tr:watch-all nil)

;;; ---------- сообщение при загрузке ----------
(princ "\n==================================================================")
(princ "\n MM_ROUTE.LSP загружен (Этап 6: трассы)")
(princ "\n  ММ_ТРАССА / MM_ROUTE                - нарисовать трассу (лоток, короб, гофра...)")
(princ "\n  ММ_ТРАССА_ИЗМ / MM_ROUTE_EDIT        - изменить параметры трасс")
(princ "\n  ММ_ТРАССА_ПРОВЕРКА / MM_ROUTE_CHECK  - разрывы и пересечения без соединения")
(princ "\n  ММ_ТРАССА_ОБНОВИТЬ / MM_ROUTE_UPDATE   - перестроить контуры и типы линий")
(princ "\n  ММ_ТРАССА_НАСТР / MM_ROUTE_SETTINGS    - допуск примагничивания, радиус поиска")
(princ "\n  Контур ширины лотка перестраивается сам при правке оси.")
(princ "\n==================================================================")
(princ)
