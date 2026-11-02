;;; ==========================================================================
;;; blok_menu.lsp - ОДНО ОКНО ДЛЯ ВСЕХ КОМАНД ММ_*
;;; Команды:
;;;   ММ (мм, MM) - открыть меню команд
;;; Как пользоваться:
;;;   - группы слева, команды справа; строка "Фильтр" ищет по названию и описанию;
;;;   - двойной щелчок или кнопка "Выполнить" - запуск команды;
;;;   - если нужный lsp не загружен, меню загрузит его само (файлы должны лежать
;;;     в той же папке, что и blok_menu.lsp, или в путях поиска AutoCAD);
;;;   - меню запоминает последнюю группу и команду.
;;; Кодировка файла: cp1251.
;;; ==========================================================================

(setq *bm:list*
 '(("Кабели" "ММ_КАБЕЛЬ" "blok_kabel" "Нарисовать кабель от блока к блоку")
   ("Кабели" "ММ_КАБЕЛЬ_ТРАССИРОВКА" "blok_kabel" "Кабель по существующим кабелям-трассам")
   ("Кабели" "ММ_КАБЕЛЬ_ТРАССИРОВКА_УСТРОЙСТВО" "blok_kabel" "Новый кабель к устройству по пути существующего кабеля")
   ("Кабели" "ММ_КАБЕЛЬ_ТРАССИРОВКА_ГРУППА" "blok_kabel" "Новые кабели к нескольким устройствам по пути существующего")
   ("Кабели" "ММ_КАБЕЛЬ_ИЗ_ЛИНИИ" "blok_kabel" "Кабель из полилинии / линии")
   ("Кабели" "ММ_КАБЕЛЬ_УЧАСТОК" "blok_kabel" "Способ прокладки участка (всех кабелей в сечении)")
   ("Кабели" "ММ_КАБЕЛЬ_СВОЙСТВА" "blok_kabel" "Свойства кабеля, участки, опуски, этажи")
   ("Кабели" "ММ_КАБЕЛЬ_ВСЕ" "blok_kabel" "Список всех кабелей")
   ("Кабели" "ММ_КАБЕЛЬ_ПЕРЕИМЕНОВАТЬ" "blok_kabel" "Переименовать кабели выделенных устройств по маске")
   ("Кабели" "ММ_КАБЕЛЬ_ПЕРЕСОБРАТЬ" "blok_kabel" "Пересобрать кабель из сегментов")
   ("Кабели" "ММ_КАБЕЛЬ_ЭЛ" "blok_kabel" "Электрический расчёт, падение напряжения")
   ("Выноски" "ММ_КАБЕЛЬ_ВЫНОСКА" "blok_kabel" "Выноска кабелей")
   ("Выноски" "ММ_КАБЕЛЬ_ВЫНОСКА_ПРОКЛ" "blok_kabel" "Выноска способа прокладки")
   ("Выноски" "ММ_КАБЕЛЬ_ВЫНОСКА_СТОЯК" "blok_kabel" "Выноска стояка")
   ("Выноски" "ММ_КАБЕЛЬ_ВЫНОСКА_ПАРАМ" "blok_kabel" "Параметры выносок: высота, кружок, привязка")
   ("Выноски" "ММ_КАБЕЛЬ_ВЫНОСКА_ФОРМАТ" "blok_kabel" "Формат текста выносок")
   ("Выноски" "ММ_КАБЕЛЬ_ОБНОВИТЬ" "blok_kabel" "Обновить выноски и таблицы")
   ("Оформление" "ММ_КАБЕЛЬ_ТИПЫ" "blok_kabel" "Способы прокладки: линии, цвета, заполнение")
   ("Оформление" "ММ_КАБЕЛЬ_ЛИНИИ" "blok_kabel" "Вид и цвет линий кабелей")
   ("Оформление" "ММ_КАБЕЛЬ_ЛЕГЕНДА" "blok_kabel" "Легенда обозначений")
   ("Оформление" "ММ_КАБЕЛЬ_СПРАВОЧНИК" "blok_kabel" "Справочник кабелей (cable_type.csv)")
   ("Таблицы" "ММ_КАБЕЛЬ_ЖУРНАЛ" "blok_kabel" "Кабельный журнал")
   ("Таблицы" "ММ_КАБЕЛЬ_ЕЩЕ" "blok_kabel" "Спецификация и экспорт")
   ("Таблицы" "ММ_СЧЕТ" "blok_schet" "Подсчёт блоков")
   ("Схема" "ММ_СХЕМА" "blok_schema" "Структурная схема в схема.dwg")
   ("Блоки" "ММ_НУМЕРАЦИЯ" "blok_num" "Нумерация блоков по любому атрибуту, с учётом этажа")
   ("Блоки" "ММ_ЭТАЖИ" "blok_num" "Короткие обозначения этажей (1, П1, Ч, К) для нумерации")
   ("Блоки" "ММ_ЗАМЕНИТЬ" "blok_change" "Замена блоков на другой (атрибуты, слой, поворот сохраняются)")
   ("Блоки" "ММ_ПРОВЕРКА" "blok_proverka" "Проверка блоков")
   ("Блоки" "ММ_АТРИБ" "blok_atrib" "Атрибуты блоков")
   ("Блоки" "ММ_АТРИБ_ИЗМ" "blok_atrib_change" "Добавить / удалить / изменить атрибуты")
   ("Листы" "ММ_МОДЕЛЬ_ЛИСТ" "model-list" "Листы из чертежей в модели: принтер, формат, стили печати")
   ("Таблицы" "ММ_ЭКСПЛИКАЦИЯ" "rooms" "Экспликация помещений по ГОСТ 21.501 по маске; блоки помещений вместо надписей")
   ("Текст" "ММ_ТЕКСТ_ЗАМЕНА" "txt_change" "Нумерация / замена текста по маске")))

(setq *bm:dir* (if (findfile "blok_menu.lsp") (vl-filename-directory (findfile "blok_menu.lsp"))))

(defun bm:groups (/ r) (foreach x *bm:list* (if (not (member (car x) r)) (setq r (append r (list (car x)))))) (cons "Все" r))

(defun bm:filter (grp flt / r)
  (setq flt (strcase flt))
  (foreach x *bm:list*
    (if (and (or (= grp "Все") (= grp (car x)))
             (or (= flt "") (vl-string-search flt (strcase (strcat (cadr x) " " (cadddr x))))))
      (setq r (append r (list x)))))
  r)

(defun bm:fill (key l)
  (start_list key) (foreach x l (add_list x)) (end_list))

(defun bm:show (/ gl) 
  (setq *bm:cur* (bm:filter (nth *bm:g* (bm:groups)) (get_tile "flt")))
  (bm:fill "cmd" (mapcar '(lambda (x) (strcat (cadr x) "\t" (cadddr x))) *bm:cur*))
  (if *bm:cur* (set_tile "cmd" "0")))

(defun bm:load (x / f)
  (if (not (eval (read (strcat "c:" (cadr x)))))
    (progn
      (setq f (cond ((and *bm:dir* (findfile (strcat *bm:dir* "\\" (caddr x) ".lsp"))))
                    ((findfile (strcat (caddr x) ".lsp")))))
      (if f (load f) (alert (strcat "Не найден файл " (caddr x) ".lsp.\nПоложите его рядом с blok_menu.lsp."))))))

(defun bm:dialog (/ fn f id res i x)
  (setq fn (vl-filename-mktemp "bm.dcl"))
  (setq f (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0)) (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  (foreach l '("bm : dialog { label = \"Команды БЛОК\";"
               " : row {"
               "  : list_box { key = \"grp\"; label = \"Группа\"; width = 16; height = 18; }"
               "  : column {"
               "   : edit_box { key = \"flt\"; label = \"Фильтр:\"; edit_width = 30; }"
               "   : list_box { key = \"cmd\"; label = \"Команда (двойной щелчок - выполнить)\"; width = 80; height = 16; tabs = \"36\"; }"
               "  } }"
               " : row { : button { key = \"accept\"; label = \"Выполнить\"; is_default = true; }"
               "         : button { key = \"cancel\"; label = \"Закрыть\"; is_cancel = true; } } }")
    (write-line l f))
  (close f)
  (setq id (load_dialog fn))
  (if (not *bm:g*) (setq *bm:g* 0))
  (new_dialog "bm" id)
  (bm:fill "grp" (bm:groups)) (set_tile "grp" (itoa *bm:g*))
  (bm:show)
  (if (and *bm:c* (setq i (vl-position *bm:c* (mapcar 'cadr *bm:cur*)))) (set_tile "cmd" (itoa i)))
  (action_tile "grp" "(setq *bm:g* (atoi $value)) (bm:show)")
  (action_tile "flt" "(bm:show)")
  (action_tile "cmd" "(if (= $reason 4) (done_dialog 1))")
  (action_tile "accept" "(done_dialog 1)")
  (setq x nil)
  (setq res (progn (action_tile "cmd" "(setq *bm:i* (atoi $value)) (if (= $reason 4) (done_dialog 1))")
                   (setq *bm:i* (atoi (get_tile "cmd")))
                   (action_tile "accept" "(setq *bm:i* (atoi (get_tile \"cmd\"))) (done_dialog 1)")
                   (start_dialog)))
  (unload_dialog id) (vl-file-delete fn)
  (if (and (= res 1) (setq x (nth *bm:i* *bm:cur*)))
    (progn (setq *bm:c* (cadr x))
           (bm:load x)
           (if (eval (read (strcat "c:" (cadr x))))
             (vla-SendCommand (vla-get-ActiveDocument (vlax-get-acad-object)) (strcat (cadr x) " ")))))
  (princ))

(vl-load-com)
(defun c:ММ () (bm:dialog))
(defun c:мм () (bm:dialog))
(defun c:MM () (bm:dialog))
(princ "\nblok_menu загружен. Команда: ММ (мм, MM) - меню всех команд ММ_*: группы, фильтр, двойной щелчок - запуск.")
(princ)
