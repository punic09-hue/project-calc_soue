;;; ==========================================================================
;;; blok_change.lsp - ЗАМЕНА БЛОКОВ (AutoCAD 2024)
;;; Команды:
;;;   ММ_ЗАМЕНИТЬ (мм_заменить, MM_REPLACE)
;;;     1. Укажите НОВЫЙ блок (образец) - щелчком на чертеже.
;;;     2. Выбирайте СТАРЫЕ блоки - щелчком или [Рамка], сколько угодно;
;;;        каждый выбор сразу заменяется. Enter - конец работы.
;;;        [Образец] - указать другой новый блок, не выходя из команды.
;;;   При замене сохраняются: точка вставки, поворот, масштаб, слой старого
;;;   блока; значения атрибутов с одинаковыми именами (ПОЗИЦИЯ, ЭТАЖ ...);
;;;   параметры динамического блока с одинаковыми именами. Кабели ММ_КАБЕЛЬ,
;;;   привязанные к старому блоку, привязываются к новому.
;;;   Каждая замена отменяется ОТМЕНИТЬ (U).
;;; Кодировка файла: cp1251.
;;; ==========================================================================
(vl-load-com)

(defun bc:bname (o / r) (setq r (vl-catch-all-apply 'vla-get-EffectiveName (list o))) (if (vl-catch-all-error-p r) (vla-get-Name o) r))
(defun bc:atts (o / r) (setq r (vl-catch-all-apply 'vlax-invoke (list o 'GetAttributes))) (if (vl-catch-all-error-p r) nil r))
(defun bc:dyn (o / r) (setq r (vl-catch-all-apply 'vlax-invoke (list o 'GetDynamicBlockProperties))) (if (vl-catch-all-error-p r) nil r))

(defun bc:pick-new (/ e o)
  (while (null o)
    (setq e (entsel "\nУкажите НОВЫЙ блок (образец): "))
    (cond ((null e) (exit))
          ((= (cdr (assoc 0 (entget (car e)))) "INSERT") (setq o (vlax-ename->vla-object (car e))))
          (T (princ "\nЭто не блок."))))
  (princ (strcat "\nОбразец: " (bc:bname o)))
  o)

;; заменить старый блок old новым по образцу tpl; -> новый объект или nil
(defun bc:replace (old tpl / sp new va dv hold hnew segs)
  (setq sp (vla-ObjectIDToObject (vla-get-ActiveDocument (vlax-get-acad-object)) (vla-get-OwnerID old)))
  (setq new (vl-catch-all-apply 'vla-InsertBlock
              (list sp (vla-get-InsertionPoint old) (bc:bname tpl)
                    (vla-get-XScaleFactor old) (vla-get-YScaleFactor old) (vla-get-ZScaleFactor old) (vla-get-Rotation old))))
  (if (vl-catch-all-error-p new) nil
    (progn
      (vla-put-Layer new (vla-get-Layer old))
      ;; динамические параметры: сначала как у образца, затем - одноимённые у старого
      (foreach p (bc:dyn tpl)
        (if (= (vla-get-ReadOnly p) :vlax-false)
          (foreach q (bc:dyn new) (if (= (vla-get-PropertyName q) (vla-get-PropertyName p)) (vl-catch-all-apply 'vla-put-Value (list q (vla-get-Value p)))))))
      (foreach p (bc:dyn old)
        (if (and (= (vla-get-ReadOnly p) :vlax-false) (/= (vla-get-PropertyName p) "Origin"))
          (foreach q (bc:dyn new) (if (= (vla-get-PropertyName q) (vla-get-PropertyName p)) (vl-catch-all-apply 'vla-put-Value (list q (vla-get-Value p)))))))
      ;; атрибуты: одноимённые - значение старого, остальные - как у образца
      (setq va (mapcar '(lambda (a) (cons (strcase (vla-get-TagString a)) (vla-get-TextString a))) (bc:atts old))
            dv (mapcar '(lambda (a) (cons (strcase (vla-get-TagString a)) (vla-get-TextString a))) (bc:atts tpl)))
      (foreach a (bc:atts new)
        (vla-put-TextString a (cond ((cdr (assoc (strcase (vla-get-TagString a)) va)))
                                    ((cdr (assoc (strcase (vla-get-TagString a)) dv)))
                                    (""))))
      ;; кабели ММ_КАБЕЛЬ: начало/конец на старом блоке -> на новом
      (setq hold (vla-get-Handle old) hnew (vla-get-Handle new))
      (if (and bk:all-segs bk:get bk:put bk:setf bk:f)
        (foreach s (bk:all-segs)
          (setq segs (bk:get s))
          (if (= (bk:f segs "beg") hold) (setq segs (bk:setf segs "beg" hnew)))
          (if (= (bk:f segs "end") hold) (setq segs (bk:setf segs "end" hnew)))
          (bk:put s segs)))
      (vla-Delete old)
      new)))

(defun bc:run (/ *error* doc tpl ss i e l n go tot)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*,*EXIT*")) (princ (strcat "\nОшибка: " m)))
    (vla-EndUndoMark doc) (princ))
  (setq tpl (bc:pick-new) go T tot 0)
  (while go
    (setvar "ERRNO" 0)
    (initget "Рамка Образец")
    (setq e (entsel (strcat "\nСТАРЫЙ блок -> " (bc:bname tpl) " [Рамка/Образец] <конец>: ")) l nil)
    (cond
      ((= e "Образец") (setq tpl (bc:pick-new)))
      ((= e "Рамка")
       (if (setq ss (ssget '((0 . "INSERT"))))
         (progn (setq i 0) (repeat (sslength ss) (setq l (cons (vlax-ename->vla-object (ssname ss i)) l) i (1+ i))))))
      ((and (listp e) e)
       (if (= (cdr (assoc 0 (entget (car e)))) "INSERT") (setq l (list (vlax-ename->vla-object (car e)))) (princ "\nЭто не блок.")))
      ((= (getvar "ERRNO") 7) (princ "\nПромах, повторите."))
      (T (setq go nil)))
    (if l
      (progn
        (vla-StartUndoMark doc)
        (setq n 0)
        (foreach o l
          (if (and (not (equal (vla-get-Handle o) (vla-get-Handle tpl))) (bc:replace o tpl)) (setq n (1+ n))))
        (vla-EndUndoMark doc)
        (setq tot (+ tot n))
        (princ (strcat "\nЗаменено: " (itoa n) " (всего " (itoa tot) ").")))))
  (princ (strcat "\nГотово. Заменено блоков: " (itoa tot) "."))
  (princ))

(defun c:ММ_ЗАМЕНИТЬ () (bc:run))
(defun c:мм_заменить () (bc:run))
(defun c:MM_REPLACE () (bc:run))
(princ "\nblok_change.lsp загружен. ММ_ЗАМЕНИТЬ (MM_REPLACE): новый блок-образец -> старые блоки щелчком или [Рамка], повторно; атрибуты, слой, поворот, масштаб и привязка кабелей сохраняются.")
(princ)
