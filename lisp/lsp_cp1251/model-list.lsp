;;; ==========================================================================
;;; model-list.lsp - ЛИСТЫ ИЗ ЧЕРТЕЖЕЙ В МОДЕЛИ (AutoCAD 2024)
;;; Команды:
;;;   ММ_МОДЕЛЬ_ЛИСТ (мм_модель_лист, MM_MODEL_LAYOUT) - выделите в модели чертежи (рамки
;;;     и всё, что в них) - можно до команды. В окне выберите:
;;;       - принтер / плоттер, формат бумаги, таблицу стилей печати (монохром и др.);
;;;       (перед окном укажите щелчком рамку чертежа; динамические блоки -
;;;        по исходному имени, все такие рамки из выделения);
;;;       - масштаб: "вписать в лист" или 1:1 (рамка нарисована в мм);
;;;       - имя листа: номер 1, 2, 3... или значение атрибута блока рамки
;;;         (напр. НОМЕР_ЛИСТА); пустой атрибут - номер; повтор - "(2)".
;;;     Для каждой рамки создаётся отдельный ЛИСТ: видовой экран на всю
;;;     печатаемую область показывает рамку, параметры печати - выбранные,
;;;     ориентация - по рамке (альбомная / книжная), экран заблокирован.
;;;     Порядок листов: сверху вниз, слева направо. Имена 1, 2, 3...;
;;;     если в чертеже уже есть листы - предлагается маска и номер, занятые
;;;     имена пропускаются. Все изменения отменяются одним ОТМЕНИТЬ (U).
;;; Кодировка файла: cp1251.
;;; ==========================================================================
(vl-load-com)

(defun ml:doc () (vla-get-ActiveDocument (vlax-get-acad-object)))
(defun ml:bname (o / r) (setq r (vl-catch-all-apply 'vla-get-EffectiveName (list o))) (if (vl-catch-all-error-p r) (vla-get-Name o) r))
(defun ml:lst (v) (cond ((null v) nil) ((listp v) v) (T (vl-catch-all-apply 'vlax-safearray->list (list (vlax-variant-value v))))))
(defun ml:inv (o m / r) (setq r (vl-catch-all-apply 'vlax-invoke (list o m))) (if (vl-catch-all-error-p r) nil (ml:lst r)))
(defun ml:fill (k l) (start_list k) (foreach x l (add_list x)) (end_list))
(defun ml:idx (x l) (cond ((vl-position x l)) (0)))
(defun ml:fmt (m n / i j s)
  (if (null (setq i (vl-string-search "#" m))) (strcat m (itoa n))
    (progn (setq j i) (while (= (substr m (+ j 1) 1) "#") (setq j (1+ j)))
           (setq s (itoa n)) (while (< (strlen s) (- j i)) (setq s (strcat "0" s)))
           (strcat (substr m 1 i) s (substr m (+ j 1))))))

(defun ml:write-dcl (lines / fn f)
  (setq fn (vl-filename-mktemp "model_list.dcl"))
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0)) (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  (foreach l lines (write-line l f)) (close f) fn)

;; теги атрибутов блока рамки (по первому вхождению в выделении)
(defun ml:tags (bn / o r)
  (setq o (vl-some '(lambda (x) (if (= (ml:bname x) bn) x)) *ml:ins*))
  (if o (foreach a (ml:inv o 'GetAttributes) (setq r (cons (strcase (vla-get-TagString a)) r))))
  (reverse r))
(defun ml:att (o tag / r)
  (foreach a (ml:inv o 'GetAttributes) (if (= (strcase (vla-get-TagString a)) tag) (setq r (vla-get-TextString a))))
  (vl-string-trim " " (if r r "")))
;; недопустимые в имени листа символы -> _
(defun ml:clean (s) (vl-string-translate "<>/\\\":;?*|,=`" "_____________" s))
(defun ml:nmfill (bn)
  (setq *ml:tg* (ml:tags bn))
  (ml:fill "nm" (cons "<номер: 1, 2, 3...>" (mapcar '(lambda (t2) (strcat "атрибут " t2)) *ml:tg*)))
  (set_tile "nm" (itoa (cond ((vl-position (nth 5 *ml:set*) *ml:tg*) (1+ (vl-position (nth 5 *ml:set*) *ml:tg*))) (0)))))

;; вернуть настройки печати листа "Модель"
(defun ml:restore ()
  (if (and *ml:tmp* *ml:sv*)
    (progn (vl-catch-all-apply 'vla-put-ConfigName (list *ml:tmp* (nth 0 *ml:sv*)))
           (vl-catch-all-apply 'vla-RefreshPlotDeviceInfo (list *ml:tmp*))
           (vl-catch-all-apply 'vla-put-CanonicalMediaName (list *ml:tmp* (nth 1 *ml:sv*)))
           (vl-catch-all-apply 'vla-put-StyleSheet (list *ml:tmp* (nth 2 *ml:sv*)))))
  (setq *ml:tmp* nil *ml:sv* nil))
;; списки форматов для принтера (на временном листе)
(defun ml:media (dev / c)
  (vl-catch-all-apply 'vla-put-ConfigName (list *ml:tmp* dev))
  (vl-catch-all-apply 'vla-RefreshPlotDeviceInfo (list *ml:tmp*))
  (setq *ml:can* (ml:inv *ml:tmp* 'GetCanonicalMediaNames)
        *ml:loc* (mapcar '(lambda (c) (cond ((vl-catch-all-apply 'vla-GetLocaleMediaName (list *ml:tmp* c))) (c))) *ml:can*))
  (setq *ml:loc* (mapcar '(lambda (x) (if (= (type x) 'STR) x "?")) *ml:loc*)))

(defun ml:dialog (names / fn id res dev)
  (setq fn (ml:write-dcl
    '("ml : dialog { label = \"Листы из чертежей в модели\";"
      " : popup_list { key = \"dev\"; label = \"Принтер / плоттер:\"; width = 70; }"
      " : popup_list { key = \"med\"; label = \"Формат бумаги:\"; width = 70; }"
      " : popup_list { key = \"sty\"; label = \"Таблица стилей печати:\"; width = 70; }"
      " : popup_list { key = \"blk\"; label = \"Блок рамки (указан):\"; width = 70; is_enabled = false; }"
      " : popup_list { key = \"nm\"; label = \"Имя листа:\"; width = 70; }"
      " : radio_row { key = \"scl\"; : radio_button { key = \"fit\"; label = \"Вписать в лист\"; }"
      "                              : radio_button { key = \"one\"; label = \"1:1 (рамка в мм)\"; } }"
      " : text { key = \"info\"; width = 70; }"
      " : row { : button { key = \"accept\"; label = \"Создать листы\"; is_default = true; width = 18; }"
      "         : button { key = \"cancel\"; label = \"Отмена\"; is_cancel = true; width = 14; } } }")))
  (setq id (load_dialog fn))
  (if (new_dialog "ml" id)
    (progn
      (ml:fill "dev" *ml:devs*) (ml:fill "sty" *ml:stys*) (ml:fill "blk" names)
      (set_tile "dev" (itoa (ml:idx (nth 0 *ml:set*) *ml:devs*)))
      (ml:media (nth (atoi (get_tile "dev")) *ml:devs*)) (ml:fill "med" *ml:loc*)
      (set_tile "med" (itoa (ml:idx (nth 1 *ml:set*) *ml:can*)))
      (set_tile "sty" (itoa (ml:idx (nth 2 *ml:set*) *ml:stys*)))
      (set_tile "blk" (itoa (ml:idx (nth 3 *ml:set*) names)))
      (set_tile "scl" (if (= (nth 4 *ml:set*) "one") "one" "fit"))
      (ml:nmfill (nth (atoi (get_tile "blk")) names))
      (action_tile "blk" "(ml:nmfill (nth (atoi $value) names))")
      (set_tile "info" (strcat "Блоков в выделении: " (itoa (length *ml:ins*))))
      (action_tile "dev" "(ml:media (nth (atoi $value) *ml:devs*)) (ml:fill \"med\" *ml:loc*) (set_tile \"med\" \"0\")")
      (action_tile "accept"
        "(if (null *ml:can*) (set_tile \"info\" \"У принтера нет форматов - выберите другой.\") (progn (setq *ml:set* (list (nth (atoi (get_tile \"dev\")) *ml:devs*) (nth (atoi (get_tile \"med\")) *ml:can*) (nth (atoi (get_tile \"sty\")) *ml:stys*) (nth (atoi (get_tile \"blk\")) names) (get_tile \"scl\") (if (= (get_tile \"nm\") \"0\") \"\" (nth (1- (atoi (get_tile \"nm\"))) *ml:tg*)))) (done_dialog 1)))")
      (action_tile "cancel" "(done_dialog 0)")
      (setq res (start_dialog))))
  (unload_dialog id) (vl-file-delete fn)
  (= res 1))

;; габарит объекта: (мин макс); nil - не удалось
(defun ml:bb1 (o / mn mx r)
  (setq r (vl-catch-all-apply '(lambda () (vla-GetBoundingBox o 'mn 'mx) (list (vlax-safearray->list mn) (vlax-safearray->list mx)))))
  (if (vl-catch-all-error-p r) nil r))
;; блок: прямой габарит, иначе (динамические рамки) - по разбитой копии: элементы
;; получаются как отдельные объекты, их габарит объединяется, копии удаляются
(defun ml:bbox (o / r parts b x1 y1 x2 y2)
  (cond
    ((setq r (ml:bb1 o)) r)
    ((not (vl-catch-all-error-p (setq parts (vl-catch-all-apply 'vlax-invoke (list o 'Explode)))))
     (foreach p parts
       (if (and (/= (vla-get-ObjectName p) "AcDbAttributeDefinition") (setq b (ml:bb1 p)))
         (setq x1 (if x1 (min x1 (car (car b))) (car (car b))) y1 (if y1 (min y1 (cadr (car b))) (cadr (car b)))
               x2 (if x2 (max x2 (car (cadr b))) (car (cadr b))) y2 (if y2 (max y2 (cadr (cadr b))) (cadr (cadr b)))))
       (vl-catch-all-apply 'vla-Delete (list p)))
     (if x1 (list (list x1 y1 0.0) (list x2 y2 0.0))))))

;; один лист для рамки (mn mx - габарит в модели)
(defun ml:make (name mn mx / doc lay pw ph m1 m2 fw fh land rot w h s vp c)
  ;; лист создаётся командой (надёжнее, чем Layouts.Add)
  (setq doc (ml:doc) c (getvar "CMDECHO"))
  (setvar "CMDECHO" 0) (command "_.-LAYOUT" "_N" name) (setvar "CMDECHO" c)
  (setq *ml:step* "создание листа")
  (setq lay (vla-Item (vla-get-Layouts doc) name))
  (setq *ml:step* "параметры печати")
  (vla-put-ConfigName lay (nth 0 *ml:set*))
  (vla-RefreshPlotDeviceInfo lay)
  (vla-put-CanonicalMediaName lay (nth 1 *ml:set*))
  (if (/= (nth 2 *ml:set*) "") (vl-catch-all-apply 'vla-put-StyleSheet (list lay (nth 2 *ml:set*))))
  (vla-put-PaperUnits lay acMillimeters)
  (vla-put-PlotType lay acLayout)
  (vla-put-StandardScale lay ac1_1)
  (vl-catch-all-apply 'vla-put-CenterPlot (list lay :vlax-true))
  (vla-GetPaperSize lay 'pw 'ph)
  (setq fw (- (car mx) (car mn)) fh (- (cadr mx) (cadr mn)) land (> fw fh))
  ;; ориентация по рамке
  (setq rot (if (eq land (> pw ph)) ac0degrees ac90degrees))
  (vla-put-PlotRotation lay rot)
  (vla-GetPaperMargins lay 'm1 'm2)
  (setq m1 (vlax-safearray->list m1) m2 (vlax-safearray->list m2)
        w (- pw (car m1) (car m2)) h (- ph (cadr m1) (cadr m2)))
  (if (= rot ac90degrees) (setq c w w h h c))
  (setq s (if (= (nth 4 *ml:set*) "one") 1.0 (min (/ w fw) (/ h fh))))
  ;; сделать лист текущим (иначе видовой экран не включится), убрать экран по умолчанию
  (setq *ml:step* "видовой экран")
  (setvar "CTAB" name)
  (vlax-for o (vla-get-Block lay) (if (= (vla-get-ObjectName o) "AcDbViewport") (vl-catch-all-apply 'vla-Delete (list o))))
  (setq vp (vla-AddPViewport (vla-get-PaperSpace doc)
             (vlax-3d-point (/ w 2.0) (/ h 2.0) 0.0) (* s fw) (* s fh)))
  (vla-put-ViewportOn vp :vlax-true)
  (vla-Display vp :vlax-true)
  (vla-put-MSpace doc :vlax-true)
  (vla-put-ActivePViewport doc vp)
  (vla-ZoomWindow (vlax-get-acad-object) (vlax-3d-point (car mn) (cadr mn) 0.0) (vlax-3d-point (car mx) (cadr mx) 0.0))
  (vla-put-MSpace doc :vlax-false)
  (vla-put-CustomScale vp s)
  (vla-put-DisplayLocked vp :vlax-true)
  name)

(defun ml:run (/ bb r *error* fr e doc ss i o names frames mn mx exist mask n nm res cnt)
  (setq doc (ml:doc))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*"))
      (princ (strcat "\nОшибка: " m "\n  (этап: " (if *ml:stage* *ml:stage* "-") ") - пришлите эти строки.")))
    (ml:restore)
    (vla-EndUndoMark doc) (princ))
  (if (/= (getvar "CTAB") "Model") (setvar "CTAB" "Model"))
  (if (null (setq ss (ssget "_I" '((0 . "INSERT")))))
    (progn (princ "\nВыделите чертежи (рамки) в модели: ") (setq ss (ssget '((0 . "INSERT"))))))
  (sssetfirst nil nil)
  (if (null ss) (progn (princ "\nНичего не выделено.") (exit)))
  (setq *ml:ins* nil i 0)
  (repeat (sslength ss) (setq *ml:ins* (cons (vlax-ename->vla-object (ssname ss i)) *ml:ins*) i (1+ i)))
  ;; рамка - указать на чертеже (динамические блоки - по исходному имени)
  (while (null fr)
    (setq e (entsel "\nУкажите рамку чертежа: "))
    (cond ((null e) (exit))
          ((= (cdr (assoc 0 (entget (car e)))) "INSERT") (setq fr (vlax-ename->vla-object (car e))))
          (T (princ "\nЭто не блок."))))
  (setq names (list (ml:bname fr)))
  (if (not (member fr *ml:ins*)) (setq *ml:ins* (cons fr *ml:ins*)))
  (princ (strcat "\nРамка: " (car names) ", таких в выделении: "
                 (itoa (length (vl-remove-if-not '(lambda (o) (= (ml:bname o) (car names))) *ml:ins*)))))
  (setq *ml:stage* "начало") (vla-StartUndoMark doc)
  ;; для списков принтеров/форматов
  ;; временная конфигурация печати (не лист) - для списков принтеров/форматов
  ;; списки берутся у листа "Модель"; его настройки печати восстанавливаются после окна
  (setq *ml:tmp* (vla-get-Layout (vla-get-ModelSpace doc))
        *ml:sv* (mapcar '(lambda (f / r) (setq r (vl-catch-all-apply f (list *ml:tmp*))) (if (vl-catch-all-error-p r) "" r))
                        '(vla-get-ConfigName vla-get-CanonicalMediaName vla-get-StyleSheet)))
  (setq *ml:stage* "список принтеров")
  (vl-catch-all-apply 'vla-RefreshPlotDeviceInfo (list *ml:tmp*))
  (setq *ml:devs* (ml:inv *ml:tmp* 'GetPlotDeviceNames)
        *ml:stys* (cons "" (ml:inv *ml:tmp* 'GetPlotStyleTableNames)))
  (if (and *ml:set* (< (length *ml:set*) 6)) (setq *ml:set* (append *ml:set* '(""))))
  (if (not *ml:set*) (setq *ml:set* (cond ((vlax-ldata-get "ML" "set")) ((list "" "" "monochrome.ctb" "" "fit" "")))))
  (setq *ml:stage* "окно") (setq res (ml:dialog names))
  (ml:restore)
  (if res
    (progn
      (vlax-ldata-put "ML" "set" *ml:set*) (setq *ml:stage* "создание листов")
      ;; рамки выбранного блока: сверху вниз, слева направо
      (foreach o *ml:ins*
        (if (= (ml:bname o) (nth 3 *ml:set*))
          (if (setq bb (ml:bbox o))
            (setq frames (cons (list (car bb) (cadr bb) o) frames))
            (princ "\nРамка пропущена: не удалось определить габарит."))))
      (setq *ml:stage* "нумерация")
      (setq frames (vl-sort frames '(lambda (a b / ha)
                                      (setq ha (* 0.5 (- (cadr (cadr a)) (cadr (car a)))))
                                      (if (> (abs (- (cadr (cadr a)) (cadr (cadr b)))) ha)
                                        (> (cadr (cadr a)) (cadr (cadr b)))
                                        (< (car (car a)) (car (car b)))))))
      ;; нумерация
      ;; имена листов - через (layoutlist), без перебора коллекции ActiveX
      (setq exist (mapcar 'strcase (layoutlist)))
      (setq mask "#" n 1)
      (if (and exist (= (nth 5 *ml:set*) ""))
        (progn
          (princ (strcat "\nВ чертеже уже есть листы: " (itoa (length exist))))
          (setq nm (getstring T "\nМаска имени листа (# - номер, например Лист-#) <#>: "))
          (if (/= nm "") (setq mask nm))
          (setq n (cond ((getint (strcat "\nНачальный номер <" (itoa (1+ (length exist))) ">: "))) ((1+ (length exist)))))))
      (setq cnt 0)
      (foreach f frames
        (setq nm (if (/= (nth 5 *ml:set*) "") (ml:clean (ml:att (caddr f) (nth 5 *ml:set*))) ""))
        (if (= nm "")
          (progn (while (member (strcase (ml:fmt mask n)) exist) (setq n (1+ n)))
                 (setq nm (ml:fmt mask n)))
          ;; имя из атрибута занято - добавить (2), (3)...
          (progn (setq i 2 o nm)
                 (while (member (strcase nm) exist) (setq nm (strcat o " (" (itoa i) ")") i (1+ i)))))
        (setq *ml:stage* (strcat "лист " nm))
        (if (vl-catch-all-error-p (setq r (vl-catch-all-apply 'ml:make (list nm (car f) (cadr f)))))
          (princ (strcat "\nЛист " nm ": ошибка (" (if *ml:step* *ml:step* "") "): " (vl-catch-all-error-message r)))
          (setq cnt (1+ cnt) exist (cons (strcase nm) exist)))
        (setq n (1+ n)))
      (setvar "CTAB" "Model")
      (princ (strcat "\nСоздано листов: " (itoa cnt) " (рамок \"" (nth 3 *ml:set*) "\": " (itoa (length frames)) ")."))))
  (vla-EndUndoMark doc)
  (princ))

(defun c:ММ_МОДЕЛЬ_ЛИСТ () (ml:run))
(defun c:мм_модель_лист () (ml:run))
(defun c:MM_MODEL_LAYOUT () (ml:run))
(princ "\nmodel-list.lsp загружен. ММ_МОДЕЛЬ_ЛИСТ (MM_MODEL_LAYOUT): выделите чертежи в модели -> принтер, формат, стили печати, блок рамки -> по листу на каждую рамку (1, 2, 3...; при существующих листах - маска).")
(princ)
