;;; ==========================================================================
;;; rooms.lsp - ММ_ЭКСПЛИКАЦИЯ ПОМЕЩЕНИЙ (ГОСТ 21.501) И БЛОКИ ПОМЕЩЕНИЙ (AutoCAD 2024)
;;; Команды:
;;;   ММ_ЭКСПЛИКАЦИЯ (мм_экспликация, MM_ROOM_SCHEDULE) - найти помещения на чертеже по маске
;;;     и вставить таблицу экспликации по ГОСТ 21.501 (Номер помещения /
;;;     Наименование / Площадь, м2 / Кат. помещения), с группировкой по этажам
;;;     и итогами; выгрузка в CSV.
;;;   В том же окне кнопка "Вставить блоки": помещения базы вставляются блоками
;;;     с атрибутами (по умолчанию №, ПОМЕЩЕНИЕ, ПЛОЩАДЬ, ЭТАЖ, КАТЕГОРИЯ; блок -
;;;     свой или ЭКСП_ПОМЕЩЕНИЕ, создаётся сам) ВМЕСТО найденных надписей:
;;;     слой, цвет, стиль, высота и поворот - как у надписи; надписи удаляются.
;;; Где ищется: выделенное до команды, иначе всё текущее пространство:
;;;   однострочный и многострочный текст, атрибуты блоков, тексты внутри блоков
;;;   и блоков в блоках; соседние тексты можно склеивать (номер, имя и площадь
;;;   разными текстами). Блоки, у которых уже есть атрибуты с заданными именами
;;;   (№ / ПОМЕЩЕНИЕ / ПЛОЩАДЬ), читаются напрямую.
;;; Окно: галочки готовых вариантов маски (1. Имя 12.5 / 101 Имя 12,5 / ... м2 /
;;;   1. Имя / 101 Имя / Имя 12.5 / Этаж-№ / Только номер / Любой текст) - маска
;;;   подставляется сама; фильтр "Только тексты: начинается с / заканчивается на /
;;;   содержит символы"; "Показать все тексты" - все надписи, неподходящие целиком
;;;   в наименование. Найденное -> "В базу" (выделенные / все); база помещений
;;;   хранится в чертеже, её строки можно менять, добавлять, удалять; таблица и
;;;   блоки строятся по базе.
;;; Маска (поля в фигурных скобках, остальное - как написано, без учёта регистра):
;;;   {ЭТ} этаж  {N} номер (с цифрой)  {ИМЯ} наименование  {S} площадь (число)
;;;   {КАТ} категория  {*} пропустить что угодно; пробел в маске = любые пробелы;
;;;   варианты через |  - проверяются по порядку, берётся первый подошедший.
;;;   Примеры:  "1. Техн. этаж 812.95"  -> {N}. {ИМЯ} {S}
;;;             "101 Венткамера 12,5 м2" -> {N} {ИМЯ} {S} м2
;;;             "Тамбур"                 -> {ИМЯ}
;;;             несколько форм сразу     -> {N}. {ИМЯ} {S}|{N} {ИМЯ} {S}|{N}. {ИМЯ}
;;; Кодировка файла: cp1251.
;;; ==========================================================================
(vl-load-com)

(defun rm:doc () (vla-get-ActiveDocument (vlax-get-acad-object)))
(defun rm:trim (s) (vl-string-trim " \t" (if s s "")))
(defun rm:up (s) (strcase s))
(defun rm:st (k v) (set_tile k (if v v "")))
(defun rm:fill (k l) (start_list k) (foreach x l (add_list x)) (end_list))
(defun rm:idxs (s) (if (and s (/= s "")) (read (strcat "(" s ")"))))
(defun rm:join (l sep / r) (setq r "") (foreach x l (setq r (if (= r "") x (strcat r sep x)))) r)
(defun rm:cut (s n) (if (> (strlen s) n) (strcat (substr s 1 (1- n)) "~") s))
(defun rm:num (s) (cond ((distof (vl-string-translate "," "." (rm:trim s)) 2)) (0.0)))
(defun rm:bname (o / r) (setq r (vl-catch-all-apply 'vla-get-EffectiveName (list o))) (if (vl-catch-all-error-p r) (vla-get-Name o) r))
(defun rm:split (s sep / i r)
  (while (setq i (vl-string-search sep s)) (setq r (cons (substr s 1 i) r) s (substr s (+ i 1 (strlen sep)))))
  (reverse (cons s r)))
;; "естественное" сравнение: 2 < 10, 1.2 < 1.10
(defun rm:less (a b / na nb)
  (setq na (rm:numpref a) nb (rm:numpref b))
  (if (and na nb (/= na nb)) (< na nb) (< (rm:up a) (rm:up b))))
(defun rm:numpref (s / i) (setq i 1)
  (while (and (<= i (strlen s)) (wcmatch (substr s i 1) "#")) (setq i (1+ i)))
  (if (> i 1) (atoi (substr s 1 (1- i)))))

;;; ---------- текст MTEXT без форматирования ----------
(defun rm:mclean (s / r i c n)
  (setq r "" i 1)
  (while (<= i (strlen s))
    (setq c (substr s i 1))
    (cond
      ((= c "\\")
       (setq n (substr s (1+ i) 1))
       (cond ((member (strcase n) '("P" "~")) (setq r (strcat r " ") i (+ i 2)))
             ((member n '("\\" "{" "}")) (setq r (strcat r n) i (+ i 2)))
             ((wcmatch (strcase n) "[ACFHQTWPOLKSX]")
              (setq i (+ i 2)) (if (not (member (strcase n) '("O" "L" "K")))
                                 (while (and (<= i (strlen s)) (/= (substr s i 1) ";")) (setq i (1+ i))))
              (if (and (<= i (strlen s)) (= (substr s i 1) ";")) (setq i (1+ i))))
             (T (setq i (+ i 2)))))
      ((member c '("{" "}")) (setq i (1+ i)))
      (T (setq r (strcat r c) i (1+ i)))))
  r)
;; свести пробелы, %%c и т.п. оставить как есть
(defun rm:norm (s / r)
  (setq s (vl-string-translate "\t\n\r" "   " s))
  (while (vl-string-search "  " s) (setq s (vl-string-subst " " "  " s)))
  (rm:trim s))

;;; ---------- маска ----------
;; маска -> ((L . "текст") (SP) (F . "N") ...)
(defun rm:parse (m / out lit i c j)
  (setq out nil lit "" i 1)
  (defun flush () (if (/= lit "") (setq out (cons (cons "L" lit) out) lit "")))
  (while (<= i (strlen m))
    (setq c (substr m i 1))
    (cond
      ((and (= c "{") (setq j (vl-string-search "}" m i)))
       (flush) (setq out (cons (cons "F" (rm:up (substr m (1+ i) (- j i)))) out) i (+ j 2)))
      ((= c " ") (flush) (if (not (equal (car out) '("SP"))) (setq out (cons '("SP") out))) (setq i (1+ i)))
      (T (setq lit (strcat lit c) i (1+ i)))))
  (flush)
  (reverse out))

;; символ подходит полю
(defun rm:cok (f c)
  (cond ((= f "S") (wcmatch c "#,`.,`,"))
        ((member f '("N" "ЭТ")) (/= c " "))
        (T T)))
(defun rm:fok (f v)
  (and (/= (rm:trim v) "")
       (cond ((= f "S") (wcmatch v "*#*"))
             ((= f "N") (wcmatch v "*#*"))
             (T T))))

;; сопоставление с перебором: -> ((поле . значение) ...) или 'FAIL
(defun rm:m (tk s i / t1 r j k n v)
  (setq n (strlen s))
  (cond
    ((null tk) (if (> i n) nil 'FAIL))
    ((= (car (car tk)) "SP")                      ; пробел маски - один или несколько пробелов
     (if (and (<= i n) (= (substr s i 1) " "))
       (progn (while (and (<= i n) (= (substr s i 1) " ")) (setq i (1+ i))) (rm:m (cdr tk) s i))
       'FAIL))
    ((= (car (car tk)) "L")
     (setq t1 (cdr (car tk)))
     (if (= (rm:up (substr s i (strlen t1))) (rm:up t1)) (rm:m (cdr tk) s (+ i (strlen t1))) 'FAIL))
    (T
     (setq t1 (cdr (car tk)) j i)
     (while (and (<= j n) (rm:cok t1 (substr s j 1))) (setq j (1+ j)))
     ;; от длинного к короткому
     (setq r 'FAIL k j)
     (while (and (eq r 'FAIL) (> k i))
       (setq v (substr s i (- k i)))
       (if (rm:fok t1 v)
         (progn (setq r (rm:m (cdr tk) s k))
                (if (not (eq r 'FAIL)) (setq r (cons (cons t1 (rm:trim v)) r)))))
       (setq k (1- k)))
     r)))

;; строка -> запись (ЭТ N ИМЯ S КАТ) или nil; маски - через |
(defun rm:match (s / r x best n)
  (setq s (rm:norm s))
  (if (not (rm:fpass s)) (setq s ""))
  ;; из всех вариантов маски - тот, где заполнено больше полей (при равенстве - первый)
  (setq best -1)
  (foreach tk *rm:tks*
    (if (/= s "")
      (progn (setq x (rm:m tk s 1))
             (if (and (not (eq x 'FAIL)) (> (setq n (length (vl-remove-if '(lambda (p) (= (cdr p) "")) x))) best))
               (setq best n r x)))))
  (if r (mapcar '(lambda (f) (cond ((cdr (assoc f r))) (""))) '("ЭТ" "N" "ИМЯ" "S" "КАТ"))))

;; фильтр текстов: *rm:flt* - символы, *rm:fm* - 0 нет, 1 начинается с, 2 заканчивается на, 3 содержит
(defun rm:fpass (s / f u)
  (setq f (rm:up (rm:trim *rm:flt*)) u (rm:up s))
  (cond ((or (= f "") (= *rm:fm* "0")) T)
        ((= *rm:fm* "1") (= (substr u 1 (strlen f)) f))
        ((= *rm:fm* "2") (and (>= (strlen u) (strlen f)) (= (substr u (1+ (- (strlen u) (strlen f)))) f)))
        (T (vl-string-search f u))))

;;; ---------- сбор источников ----------
(defun rm:atts (o / r) (setq r (vl-catch-all-apply 'vlax-invoke (list o 'GetAttributes))) (if (vl-catch-all-error-p r) nil r))
;; тексты блока: атрибуты, тексты определения, вложенные блоки (рекурсивно)
(defun rm:btexts (o depth / l blk)
  (foreach a (rm:atts o)
    (if (= (type a) 'VLA-OBJECT) (setq l (cons (vla-get-TextString a) l))))
  (if (< depth 4)
    (progn
      (setq blk (vl-catch-all-apply 'vla-Item (list (vla-get-Blocks (rm:doc)) (vla-get-Name o))))
      (if (not (vl-catch-all-error-p blk))
        (vlax-for x blk
          (cond ((= (vla-get-ObjectName x) "AcDbText") (setq l (cons (vla-get-TextString x) l)))
                ((= (vla-get-ObjectName x) "AcDbMText") (setq l (cons (rm:mclean (vla-get-TextString x)) l)))
                ((= (vla-get-ObjectName x) "AcDbBlockReference") (setq l (append (reverse (rm:btexts x (1+ depth))) l))))))))
  (reverse l))

;; атрибуты по именам (блок-маркер помещения): запись или nil
(defun rm:bdirect (o / v)
  (foreach a (rm:atts o)
    (if (= (type a) 'VLA-OBJECT) (setq v (cons (cons (rm:up (vla-get-TagString a)) (vla-get-TextString a)) v))))
  ;; маркер помещения - есть и атрибут номера, и атрибут наименования, хоть один заполнен
  (if (and (assoc (rm:up (nth 1 *rm:tags*)) v) (assoc (rm:up (nth 2 *rm:tags*)) v)
           (/= (rm:trim (strcat (cdr (assoc (rm:up (nth 1 *rm:tags*)) v)) (cdr (assoc (rm:up (nth 2 *rm:tags*)) v)))) ""))
    (mapcar '(lambda (tg) (rm:trim (cond ((cdr (assoc (rm:up tg) v))) ("")))) *rm:tags*)))

;; кандидаты: ((строки...) точка (enames...) тип) ; тип T - текст, B - блок
(defun rm:collect (/ l txt e o p d cl used g q)
  (foreach e *rm:ents*
    (setq o (vlax-ename->vla-object e) d (entget e) p (cdr (assoc 10 d)))
    (cond
      ((and (= (cdr (assoc 0 d)) "TEXT") (= *rm:st* "1"))
       (setq txt (cons (list (vla-get-TextString o) p e) txt)))
      ((and (= (cdr (assoc 0 d)) "MTEXT") (= *rm:sm* "1"))
       (setq txt (cons (list (rm:mclean (vla-get-TextString o)) p e) txt)))
      ((and (= (cdr (assoc 0 d)) "INSERT") (= *rm:sb* "1"))
       (setq l (cons (list nil p (list e) "B" o) l)))))
  ;; склейка соседних текстов (сверху вниз, слева направо)
  (if (> *rm:dist* 0)
    (progn
      (setq txt (vl-sort txt '(lambda (a b) (if (equal (cadr (cadr a)) (cadr (cadr b)) 1e-6) (< (car (cadr a)) (car (cadr b))) (> (cadr (cadr a)) (cadr (cadr b)))))))
      (foreach a txt
        (if (not (member (caddr a) used))
          (progn
            (setq g (vl-remove-if-not '(lambda (b) (and (not (member (caddr b) used))
                                                        (<= (distance (cadr a) (cadr b)) *rm:dist*))) txt))
            (foreach b g (setq used (cons (caddr b) used)))
            (setq l (cons (list (list (rm:join (mapcar 'car g) " ")) (cadr a) (mapcar 'caddr g) "T"
                                (mapcar 'car g)) l))))))
    (foreach a txt (setq l (cons (list (list (car a)) (cadr a) (list (caddr a)) "T") l))))
  l)

;; поиск: *rm:rooms* = ((ЭТ N ИМЯ S КАТ) точка enames источник_текст)
(defun rm:find (/ r rec src raw)
  (setq *rm:tks* (mapcar 'rm:parse (vl-remove "" (mapcar 'rm:trim (rm:split *rm:mask* "|")))) *rm:rooms* nil)
  (foreach c (rm:collect)
    (setq rec nil src "" raw nil)
    (cond
      ((= (nth 3 c) "B")
       (if (setq rec (rm:bdirect (nth 4 c)))
         (setq src (strcat "блок " (rm:bname (nth 4 c))))
         (progn
           (setq r (rm:btexts (nth 4 c) 0))
           ;; все тексты блока вместе, затем по одному
           (foreach s (cons (rm:join r " ") r)
             (if (and (null rec) (setq rec (rm:match s))) (setq raw s src (strcat "блок " (rm:bname (nth 4 c)) ": " s)))))))
      (T
       (if (setq rec (rm:match (car (car c)))) (setq src (car (car c)) raw src))
       ;; склейка не подошла - по отдельности
       (if (and (null rec) (nth 4 c) (cdr (nth 4 c)))
         (foreach s (nth 4 c) (if (and (null rec) (setq rec (rm:match s))) (setq src s raw s))))))
    ;; "все тексты": неподходящие - целиком в наименование (если проходят фильтр)
    (if (and (null rec) (= *rm:all* "1"))
      (progn (setq src (rm:norm (if (= (nth 3 c) "B") (rm:join (rm:btexts (nth 4 c) 0) " ") (car (car c)))))
             (if (and (/= src "") (rm:fpass src)) (setq rec (list "" "" src "" "") raw src))))
    (if (and rec (vl-some '(lambda (x) (/= x "")) rec))
      (setq *rm:rooms* (cons (list rec (nth 1 c) (nth 2 c) (rm:norm src) (rm:norm (if raw raw ""))) *rm:rooms*))))
  (rm:sort))

(defun rm:sortl (l)
  (vl-sort l '(lambda (a b / ea eb)
                (setq ea (nth 0 (car a)) eb (nth 0 (car b)))
                (if (/= ea eb) (rm:less ea eb) (rm:less (nth 1 (car a)) (nth 1 (car b)))))))
(defun rm:sort ()
  (setq *rm:rooms* (vl-sort *rm:rooms* '(lambda (a b / ea eb)
                                          (setq ea (nth 0 (car a)) eb (nth 0 (car b)))
                                          (if (/= ea eb) (rm:less ea eb) (rm:less (nth 1 (car a)) (nth 1 (car b))))))))

;;; ---------- окно ----------
(defun rm:write-dcl (lines / fn f)
  (setq fn (vl-filename-mktemp "rooms.dcl"))
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0)) (setq f (vl-catch-all-apply 'open (list fn "w" "utf8-bom"))))
  (if (or (null f) (vl-catch-all-error-p f)) (setq f (open fn "w")))
  (foreach l lines (write-line l f)) (close f) fn)

;; готовые варианты маски: (ключ подпись маска)
(setq *rm:pre*
  '(("p1" "1. Имя 12.5"      "{N}. {ИМЯ} {S}")
    ("p2" "101 Имя 12,5"     "{N} {ИМЯ} {S}")
    ("p3" "... 12,5 м2"      "{N}. {ИМЯ} {S} м2|{N} {ИМЯ} {S} м2|{ИМЯ} {S} м2")
    ("p4" "1. Имя"           "{N}. {ИМЯ}")
    ("p5" "101 Имя"          "{N} {ИМЯ}")
    ("p6" "Имя 12.5"         "{ИМЯ} {S}")
    ("pa" "Имя №101 12.5"    "{ИМЯ} №{N} {S}|{ИМЯ} № {N} {S}|{ИМЯ} №{N}")
    ("p7" "Этаж-№ Имя 12.5"  "{ЭТ}-{N} {ИМЯ} {S}|{ЭТ}.{N} {ИМЯ} {S}")
    ("p8" "Только номер"     "{N}")
    ("p9" "Любой текст"      "{ИМЯ}")))
;; маска из отмеченных вариантов
(defun rm:premask (/ l)
  (foreach p *rm:pre* (if (= (get_tile (car p)) "1") (setq l (append l (list (caddr p))))))
  (set_tile "mask" (rm:join l "|")))

(defun rm:row (r) (strcat (rm:cut (nth 0 (car r)) 8) "\t" (rm:cut (nth 1 (car r)) 10) "\t" (rm:cut (nth 2 (car r)) 40) "\t"
                          (nth 3 (car r)) "\t" (rm:cut (nth 4 (car r)) 6) "\t" (rm:cut (nth 3 r) 50)))
(defun rm:lfill (sel)
  (rm:fill "lst" (mapcar 'rm:row *rm:rooms*)) (set_tile "lst" sel)
  (set_tile "info" (strcat "Найдено: " (itoa (length *rm:rooms*)) "  (просмотрено объектов: " (itoa (length *rm:ents*)) ")")))
(defun rm:bfill (sel / s)
  (rm:fill "bl" (mapcar 'rm:row *rm:base*)) (set_tile "bl" sel)
  (setq s 0.0) (foreach r *rm:base* (setq s (+ s (rm:num (nth 3 (car r))))))
  (set_tile "binfo" (strcat "В базе помещений: " (itoa (length *rm:base*)) ",  сумма площадей: " (rtos s 2 2) " м2")))

;; в базу: выделенные (или все) найденные; повтор по тому же источнику заменяется
(defun rm:tobase (all / sel n)
  (setq sel (rm:idxs (get_tile "lst")) n -1)
  (foreach r *rm:rooms*
    (if (or all (member (setq n (1+ n)) sel))
      (setq *rm:base* (append (vl-remove-if '(lambda (b) (and (nth 2 r) (equal (nth 2 b) (nth 2 r)))) *rm:base*) (list r)))))
  (setq *rm:base* (rm:sortl *rm:base*))
  (rm:bfill ""))

(defun rm:pick (/ i r)
  (if (setq i (car (rm:idxs (get_tile "bl"))))
    (progn (setq r (car (nth i *rm:base*)))
           (mapcar '(lambda (k v) (rm:st k v)) '("e_et" "e_n" "e_nm" "e_s" "e_k") r))))
;; изменить выделенные в базе: для нескольких строк - только заполненные поля
(defun rm:apply (/ sel one v)
  (setq sel (rm:idxs (get_tile "bl")) one (= (length sel) 1))
  (foreach i sel
    (setq v (mapcar '(lambda (x k) (if (or one (/= (get_tile k) "")) (rm:trim (get_tile k)) x))
                    (car (nth i *rm:base*)) '("e_et" "e_n" "e_nm" "e_s" "e_k")))
    (setq *rm:base* (subst (cons v (cdr (nth i *rm:base*))) (nth i *rm:base*) *rm:base*)))
  (rm:bfill (get_tile "bl")))
(defun rm:add ()
  (setq *rm:base* (append *rm:base* (list (list (mapcar '(lambda (k) (rm:trim (get_tile k))) '("e_et" "e_n" "e_nm" "e_s" "e_k"))
                                                nil nil "добавлено вручную" ""))))
  (rm:bfill (itoa (1- (length *rm:base*)))))
;; разобрать строки базы заново по текущей маске (по исходному тексту); без выделения - все
(defun rm:reparse (/ sel n rec)
  (setq *rm:tks* (mapcar 'rm:parse (vl-remove "" (mapcar 'rm:trim (rm:split (get_tile "mask") "|"))))
        sel (rm:idxs (get_tile "bl")) n -1)
  (setq *rm:base* (mapcar '(lambda (r)
                             (setq n (1+ n))
                             (if (and (or (null sel) (member n sel)) (nth 4 r) (/= (nth 4 r) "") (setq rec (rm:match (nth 4 r))))
                               (cons rec (cdr r)) r))
                          *rm:base*))
  (rm:bfill (get_tile "bl")))
(defun rm:del (/ sel n)
  (setq sel (rm:idxs (get_tile "bl")) n -1)
  (setq *rm:base* (vl-remove-if '(lambda (r) (member (setq n (1+ n)) sel)) *rm:base*))
  (rm:bfill ""))

(defun rm:read ()
  (setq *rm:mask* (get_tile "mask") *rm:st* (get_tile "s_t") *rm:sm* (get_tile "s_m") *rm:sb* (get_tile "s_b")
        *rm:dist* (rm:num (get_tile "dist")) *rm:all* (get_tile "all")
        *rm:flt* (get_tile "flt") *rm:fm* (get_tile "fm")
        *rm:prs* (mapcar '(lambda (p) (get_tile (car p))) *rm:pre*)
        *rm:tags* (mapcar '(lambda (k) (rm:trim (get_tile k))) '("t_et" "t_n" "t_nm" "t_s" "t_k"))))

(defun rm:blocks (/ l)
  (vlax-for b (vla-get-Blocks (rm:doc))
    (if (and (= (vla-get-IsLayout b) :vlax-false) (= (vla-get-IsXRef b) :vlax-false) (not (wcmatch (vla-get-Name b) "`**")))
      (setq l (cons (vla-get-Name b) l))))
  (vl-sort l '<))

;; mode: "T" - таблица, "B" - блоки
(defun rm:dialog (/ fn id res sel bsel)
  (setq fn (rm:write-dcl
    (append
      (list "rm : dialog { label = \"Экспликация помещений\";"
        " : boxed_column { label = \"Поиск\";"
        (strcat "  : row { " (apply 'strcat (mapcar '(lambda (p) (strcat ": toggle { key = \"" (car p) "\"; label = \"" (cadr p) "\"; } ")) *rm:pre*)) "}")
        "  : row { : edit_box { key = \"mask\"; label = \"Маска:\"; edit_width = 80; allow_accept = false; }"
        "          : button { key = \"b_find\"; label = \"Найти\"; is_default = true; width = 12; } }"
        "  : text { label = \"Поля: {ЭТ} этаж  {N} номер  {ИМЯ} наименование  {S} площадь  {КАТ} категория  {*} пропустить;  пробел - любые пробелы;  варианты через |\"; }"
        "  : row { : popup_list { key = \"fm\"; label = \"Только тексты:\"; width = 34; }"
        "          : edit_box { key = \"flt\"; label = \"символы:\"; edit_width = 20; allow_accept = false; }"
        "          : toggle { key = \"all\"; label = \"Показать все тексты (неподходящие - целиком в наименование)\"; } }"
        "  : row { : toggle { key = \"s_t\"; label = \"Текст\"; } : toggle { key = \"s_m\"; label = \"Многострочный текст\"; }"
        "          : toggle { key = \"s_b\"; label = \"Блоки (атрибуты, тексты, вложенные блоки)\"; }"
        "          : edit_box { key = \"dist\"; label = \"Склеивать соседние тексты в пределах, ед.:\"; edit_width = 6; allow_accept = false; } } }"
        " : list_box { key = \"hdr\"; height = 2; width = 150; tabs = \"10 22 64 76 84\"; is_tab_stop = false; }"
        " : list_box { key = \"lst\"; label = \"Найдено на чертеже\"; multiple_select = true; height = 10; width = 150; tabs = \"10 22 64 76 84\"; }"
        " : row { : button { key = \"b_tob\"; label = \"В базу выделенные\"; } : button { key = \"b_toall\"; label = \"В базу все найденные\"; }"
        "         : button { key = \"b_show\"; label = \"Показать\"; } : text { key = \"info\"; width = 60; } }"
        " : list_box { key = \"bl\"; label = \"База помещений (для таблицы / блоков)\"; multiple_select = true; height = 10; width = 150; tabs = \"10 22 64 76 84\"; }"
        " : row { fixed_width = true;"
        "   : text { label = \"Этаж\"; fixed_width = true; } : edit_box { key = \"e_et\"; edit_width = 8; fixed_width = true; allow_accept = false; } : spacer { width = 2; }"
        "   : text { label = \"№\"; fixed_width = true; } : edit_box { key = \"e_n\"; edit_width = 10; fixed_width = true; allow_accept = false; } : spacer { width = 2; }"
        "   : text { label = \"Наименование\"; fixed_width = true; } : edit_box { key = \"e_nm\"; edit_width = 40; fixed_width = true; allow_accept = false; } : spacer { width = 2; }"
        "   : text { label = \"Площадь\"; fixed_width = true; } : edit_box { key = \"e_s\"; edit_width = 10; fixed_width = true; allow_accept = false; } : spacer { width = 2; }"
        "   : text { label = \"Кат.\"; fixed_width = true; } : edit_box { key = \"e_k\"; edit_width = 6; fixed_width = true; allow_accept = false; } }"
        " : row { : button { key = \"b_set\"; label = \"Изменить выделенные\"; } : button { key = \"b_add\"; label = \"Добавить новое\"; }"
        "         : button { key = \"b_del\"; label = \"Удалить выделенные\"; } : button { key = \"b_clr\"; label = \"Очистить базу\"; }"
        "         : button { key = \"b_rep\"; label = \"Разобрать по маске\"; }"
        "         : button { key = \"b_bsh\"; label = \"Показать\"; } : button { key = \"b_csv\"; label = \"В CSV...\"; } }"
        " : text { key = \"binfo\"; width = 150; }"
        " : boxed_row { label = \"Имена атрибутов (чтение блоков-маркеров и вставка блоков)\";"
        "   : edit_box { key = \"t_et\"; label = \"Этаж:\"; edit_width = 10; allow_accept = false; }"
        "   : edit_box { key = \"t_n\"; label = \"Номер:\"; edit_width = 10; allow_accept = false; }"
        "   : edit_box { key = \"t_nm\"; label = \"Наименование:\"; edit_width = 12; allow_accept = false; }"
        "   : edit_box { key = \"t_s\"; label = \"Площадь:\"; edit_width = 10; allow_accept = false; }"
        "   : edit_box { key = \"t_k\"; label = \"Категория:\"; edit_width = 10; allow_accept = false; } }")
      (list " : boxed_row { label = \"Таблица (ГОСТ 21.501)\";"
            "   : toggle { key = \"grp\"; label = \"По этажам, итог по этажу\"; } : toggle { key = \"tot\"; label = \"Общий итог\"; }"
            "   : toggle { key = \"kat\"; label = \"Графа «Кат. помещения»\"; }"
            "   : edit_box { key = \"th\"; label = \"Высота текста:\"; edit_width = 6; allow_accept = false; }"
            "   : edit_box { key = \"sc\"; label = \"Масштаб таблицы:\"; edit_width = 6; allow_accept = false; } }"
            " : boxed_row { label = \"Блоки помещений (заменяют найденные надписи; высота, стиль, цвет, слой, поворот - как у надписи)\";"
            "   : popup_list { key = \"blk\"; label = \"Блок:\"; width = 50; } }"
            " : row { : button { key = \"accept\"; label = \"Вставить таблицу (из базы)\"; width = 28; }"
            "         : button { key = \"b_ins\"; label = \"Вставить блоки (из базы)\"; width = 28; }"
            "         : button { key = \"cancel\"; label = \"Закрыть\"; is_cancel = true; width = 14; } } }"))))
  (setq res 2 sel "" bsel "")
  (while (= res 2)
    (setq id (load_dialog fn))
    (if (not (new_dialog "rm" id)) (setq res 0)
      (progn
        (mapcar '(lambda (p v) (rm:st (car p) v)) *rm:pre* *rm:prs*)
        (rm:st "mask" *rm:mask*) (rm:st "s_t" *rm:st*) (rm:st "s_m" *rm:sm*) (rm:st "s_b" *rm:sb*) (rm:st "dist" (rtos *rm:dist* 2 0))
        (rm:fill "fm" '("все" "начинается с символов" "заканчивается на символы" "содержит символы"))
        (rm:st "fm" *rm:fm*) (rm:st "flt" *rm:flt*) (rm:st "all" *rm:all*)
        (mapcar 'rm:st '("t_et" "t_n" "t_nm" "t_s" "t_k") *rm:tags*)
        (rm:fill "hdr" (list "Этаж\t№\tНаименование\tПлощадь\tКат.\tИсточник"))
        (rm:st "grp" *rm:grp*) (rm:st "tot" *rm:tot*) (rm:st "kat" *rm:kat*) (rm:st "th" *rm:th*) (rm:st "sc" *rm:sc*)
        (setq *rm:bl* (cons "<создать ЭКСП_ПОМЕЩЕНИЕ>" (vl-remove "ЭКСП_ПОМЕЩЕНИЕ" (rm:blocks))))
        (rm:fill "blk" *rm:bl*) (set_tile "blk" (itoa (cond ((vl-position *rm:blk* *rm:bl*)) (0))))
        (rm:lfill sel) (rm:bfill bsel)
        (foreach p *rm:pre* (action_tile (car p) "(rm:premask)"))
        (action_tile "b_find" "(rm:read) (rm:find) (rm:lfill \"\")")
        (action_tile "lst" "(setq sel $value) (if (= $reason 4) (progn (setq *rm:zl* *rm:rooms*) (done_dialog 3)))")
        (action_tile "bl" "(setq bsel $value) (rm:pick) (if (= $reason 4) (progn (setq *rm:zl* *rm:base* sel bsel) (done_dialog 3)))")
        (action_tile "b_tob" "(rm:tobase nil)")
        (action_tile "b_toall" "(rm:tobase T)")
        (action_tile "b_show" "(setq sel (get_tile \"lst\") *rm:zl* *rm:rooms*) (rm:read) (done_dialog 3)")
        (action_tile "b_bsh" "(setq bsel (get_tile \"bl\") sel bsel *rm:zl* *rm:base*) (rm:read) (done_dialog 3)")
        (action_tile "b_set" "(rm:apply)")
        (action_tile "b_add" "(rm:add)")
        (action_tile "b_del" "(rm:del)")
        (action_tile "b_clr" "(setq *rm:base* nil) (rm:bfill \"\")")
        (action_tile "b_csv" "(rm:read) (done_dialog 4)")
        (setq *rm:acc* "(rm:read) (setq *rm:grp* (get_tile \"grp\") *rm:tot* (get_tile \"tot\") *rm:kat* (get_tile \"kat\") *rm:th* (get_tile \"th\") *rm:sc* (get_tile \"sc\") *rm:blk* (nth (atoi (get_tile \"blk\")) *rm:bl*)) (if (null *rm:base*) (set_tile \"binfo\" \"База пуста - добавьте помещения кнопками «В базу ...» или «Добавить новое».\")")
        (action_tile "accept" (strcat *rm:acc* " (done_dialog 1))"))
        (action_tile "b_ins" (strcat *rm:acc* " (done_dialog 5))"))
        (action_tile "b_rep" "(rm:reparse)")
        (action_tile "cancel" "(rm:read) (done_dialog 0)")
        (setq res (start_dialog))
        (unload_dialog id)
        (cond ((= res 3) (rm:zoom (car (rm:idxs sel))) (setq res 2 sel (if (eq *rm:zl* *rm:base*) "" sel)))
              ((= res 4) (rm:csv) (setq res 2))))))
  (vl-file-delete fn)
  (rm:save)
  res)

(defun rm:zoom (i / r p d s)
  (if (and i (setq r (nth i *rm:zl*)) (nth 1 r))
    (progn
      (setq p (nth 1 r) d (* 20.0 (max 1.0 (rm:th-def))))
      (vla-ZoomWindow (vlax-get-acad-object) (vlax-3d-point (- (car p) d) (- (cadr p) d) 0.0) (vlax-3d-point (+ (car p) d) (+ (cadr p) d) 0.0))
      (sssetfirst nil (progn (setq s (ssadd)) (foreach e (nth 2 r) (if (and e (entget e)) (ssadd e s))) s))
      (getstring "\nПомещение показано. Enter - вернуться в окно: ")
      (sssetfirst nil nil))))
(defun rm:th-def () (max 1.0 (getvar "TEXTSIZE")))

(defun rm:csv (/ fn f)
  (if (setq fn (getfiled "Экспликация в CSV" (strcat (getvar "DWGPREFIX") "Экспликация.csv") "csv" 1))
    (progn
      (setq f (open fn "w"))
      (write-line "Этаж;Номер помещения;Наименование;Площадь, м2;Кат. помещения" f)
      (foreach r *rm:base* (write-line (rm:join (mapcar '(lambda (x) (vl-string-translate ";" "," x)) (car r)) ";") f))
      (close f) (princ (strcat "\nСохранено: " fn)))))

;;; ---------- настройки ----------
(setq *rm:keys* '(*rm:mask* *rm:st* *rm:sm* *rm:sb* *rm:dist* *rm:tags* *rm:grp* *rm:tot* *rm:kat* *rm:th* *rm:sc* *rm:blk*
                  *rm:all* *rm:flt* *rm:fm* *rm:prs* *rm:del*))
(defun rm:load (/ v)
  (setq v (vlax-ldata-get "RM" "set"))
  (if (and v (listp v)) (mapcar '(lambda (k x) (set k x)) *rm:keys* v))
  (if (not *rm:mask*) (setq *rm:mask* "{N}. {ИМЯ} {S}|{N} {ИМЯ} {S}|{N}. {ИМЯ}"))
  (if (not *rm:st*) (setq *rm:st* "1" *rm:sm* "1" *rm:sb* "1" *rm:dist* 0.0))
  (if (not *rm:tags*) (setq *rm:tags* '("ЭТАЖ" "№" "ПОМЕЩЕНИЕ" "ПЛОЩАДЬ" "КАТЕГОРИЯ")))
  (if (not *rm:grp*) (setq *rm:grp* "1" *rm:tot* "1" *rm:kat* "1" *rm:th* "3.5" *rm:sc* "1" *rm:blk* ""))
  (if (not *rm:all*) (setq *rm:all* "0" *rm:flt* "" *rm:fm* "0"))
  (if (/= (length *rm:prs*) (length *rm:pre*)) (setq *rm:prs* '("1" "1" "0" "1" "0" "1" "1" "0" "0" "0")))
  (if (not *rm:del*) (setq *rm:del* "0"))
  ;; база помещений: в чертеже хранится с хэндлами
  (setq *rm:base* (mapcar '(lambda (r) (list (car r) (cadr r) (vl-remove nil (mapcar 'handent (caddr r))) (cadddr r) (if (nth 4 r) (nth 4 r) "")))
                          (vlax-ldata-get "RM" "base"))))
(defun rm:save ()
  (vlax-ldata-put "RM" "set" (mapcar 'eval *rm:keys*))
  (vlax-ldata-put "RM" "base" (mapcar '(lambda (r) (list (car r) (cadr r)
                                                         (vl-remove nil (mapcar '(lambda (e) (if (and e (entget e)) (cdr (assoc 5 (entget e))))) (caddr r)))
                                                         (cadddr r) (if (nth 4 r) (nth 4 r) "")))
                                      *rm:base*)))

;;; ---------- таблица ГОСТ 21.501 ----------
(defun rm:sum (l / s) (setq s 0.0) (foreach r l (setq s (+ s (rm:num (nth 3 (car r)))))) s)
(defun rm:table (pt / sc th kat rows fls tbl i nc ws r g)
  (setq sc (max 0.001 (rm:num *rm:sc*)) th (* sc (max 0.5 (rm:num *rm:th*))) kat (= *rm:kat* "1")
        ws (mapcar '(lambda (w) (* sc w)) (if kat '(15.0 100.0 25.0 25.0) '(15.0 100.0 25.0))) nc (length ws))
  ;; строки: ("H" текст) - этаж, ("R" запись), ("S" текст сумма) - итог
  (foreach r *rm:base* (if (not (member (nth 0 (car r)) fls)) (setq fls (append fls (list (nth 0 (car r)))))))
  (if (= *rm:grp* "1")
    (foreach f fls
      (setq g (vl-remove-if-not '(lambda (r) (= (nth 0 (car r)) f)) *rm:base*))
      (if (/= f "") (setq rows (append rows (list (list "H" (strcat (if (wcmatch (rm:up f) "*ЭТАЖ*,*ПАРКИНГ*,*ПОДВАЛ*,*ЧЕРДАК*,*КРОВЛ*,*ОТМ*") "" "Этаж ") f))))))
      (foreach r g (setq rows (append rows (list (list "R" r)))))
      (setq rows (append rows (list (list "S" "Итого" (rm:sum g))))))
    (foreach r *rm:base* (setq rows (append rows (list (list "R" r))))))
  (if (= *rm:tot* "1") (setq rows (append rows (list (list "S" "Всего" (rm:sum *rm:base*))))))
  (setq tbl (vla-AddTable (vla-get-ModelSpace (rm:doc)) (vlax-3d-point pt) (+ 2 (length rows)) nc (* 8.0 sc) (car ws)))
  (vla-put-RegenerateTableSuppressed tbl :vlax-true)
  (setq i 0) (foreach w ws (vla-SetColumnWidth tbl i w) (setq i (1+ i)))
  (vla-SetTextHeight tbl 7 th)
  (vla-SetText tbl 0 0 "Экспликация помещений")
  (setq i 0)
  (foreach h (if kat '("Номер помещения" "Наименование" "Площадь, м2" "Кат. помещения") '("Номер помещения" "Наименование" "Площадь, м2"))
    (vla-SetText tbl 1 i h) (setq i (1+ i)))
  (setq i 2)
  (foreach r rows
    (cond
      ((= (car r) "H") (vla-MergeCells tbl i i 0 (1- nc)) (vla-SetText tbl i 0 (cadr r))
                       (vla-SetCellAlignment tbl i 0 acMiddleCenter))
      ((= (car r) "S") (vla-SetText tbl i 1 (cadr r))
                       (vla-SetText tbl i 2 (rtos (caddr r) 2 2)))
      (T (setq r (car (cadr r)))
         (vla-SetText tbl i 0 (nth 1 r)) (vla-SetText tbl i 1 (nth 2 r))
         (vla-SetText tbl i 2 (if (/= (nth 3 r) "") (rtos (rm:num (nth 3 r)) 2 2) ""))
         (if kat (vla-SetText tbl i 3 (nth 4 r)))
         (vla-SetCellAlignment tbl i 1 acMiddleLeft)))
    (setq i (1+ i)))
  (vla-put-RegenerateTableSuppressed tbl :vlax-false)
  tbl)

;;; ---------- блоки помещений ----------
;; описание блока: видимые №, наименование, площадь; этаж и категория - невидимые
(defun rm:make-def (/ y h i)
  (if (not (tblsearch "BLOCK" "ЭКСП_ПОМЕЩЕНИЕ"))
    (progn
      (setq h 2.5 y 0.0 i 0)
      (entmake '((0 . "BLOCK") (2 . "ЭКСП_ПОМЕЩЕНИЕ") (70 . 2) (10 0.0 0.0 0.0)))
      (foreach k '(1 2 3 0 4)
        (if (/= (nth k *rm:tags*) "")
          (progn
            (entmake (list '(0 . "ATTDEF") '(8 . "0") '(62 . 0) (list 10 0.0 y 0.0) (cons 40 h) '(1 . "")
                           (cons 3 (nth k *rm:tags*)) (cons 2 (nth k *rm:tags*)) (cons 70 (if (member k '(0 4)) 1 0))))
            (if (not (member k '(0 4))) (setq y (- y (* 1.6 h)))))))
      (entmake '((0 . "ENDBLK")))))
  "ЭКСП_ПОМЕЩЕНИЕ")

;; свойства исходной надписи: (слой цвет стиль высота поворот) или nil
(defun rm:src-props (enames / o)
  (setq o (vl-some '(lambda (e) (if (and e (entget e) (member (cdr (assoc 0 (entget e))) '("TEXT" "MTEXT"))) (vlax-ename->vla-object e))) enames))
  (if o (list (vla-get-Layer o) (vla-get-TrueColor o) (vla-get-StyleName o) (vla-get-Height o) (vla-get-Rotation o))))

(defun rm:insert-blocks (/ bn o n v sp pr h y own a pt)
  (setq bn (if (or (= *rm:blk* "") (wcmatch *rm:blk* "<*")) (rm:make-def) *rm:blk*) own (= bn "ЭКСП_ПОМЕЩЕНИЕ")
        n 0 sp (if (= (getvar "CVPORT") 1) (vla-get-PaperSpace (rm:doc)) (vla-get-ModelSpace (rm:doc))))
  (foreach r (vl-remove-if-not 'cadr *rm:base*)          ; добавленные вручную (без точки) - не вставляются
    (setq pr (rm:src-props (nth 2 r)) pt (nth 1 r))
    ;; точка: у текста - левый нижний угол первой строки (MTEXT - верх, сдвигаем вниз на высоту)
    (setq o (vl-catch-all-apply 'vla-InsertBlock (list sp (vlax-3d-point pt) bn 1.0 1.0 1.0 (if pr (nth 4 pr) 0.0))))
    (if (not (vl-catch-all-error-p o))
      (progn
        (if pr (progn (vla-put-Layer o (nth 0 pr)) (vla-put-TrueColor o (nth 1 pr))))
        (setq h (if pr (nth 3 pr) 2.5) y 0.0)
        (foreach k (if own '(1 2 3 0 4) '(0 1 2 3 4))
          (foreach a (rm:atts o)
            (if (= (rm:up (vla-get-TagString a)) (rm:up (nth k *rm:tags*)))
              (progn
                (vla-put-TextString a (nth k (car r)))
                (if pr (progn (vl-catch-all-apply 'vla-put-StyleName (list a (nth 2 pr)))
                              (vla-put-Height a h) (vla-put-Layer a (nth 0 pr)) (vla-put-TrueColor a (nth 1 pr))))
                ;; свой блок: видимые строки друг под другом, пустые не занимают места
                (if (and own (not (member k '(0 4))) (/= (nth k (car r)) ""))
                  (progn (vla-put-InsertionPoint a (vlax-3d-point (polar pt (- (if pr (nth 4 pr) 0.0) (/ pi 2)) y)))
                         (vla-put-Rotation a (if pr (nth 4 pr) 0.0))
                         (setq y (+ y (* 1.6 h)))))))))
        (setq n (1+ n))
        ;; блок заменяет надпись: исходные тексты удаляются
        (foreach e (nth 2 r)
          (if (and e (entget e) (member (cdr (assoc 0 (entget e))) '("TEXT" "MTEXT"))) (entdel e)))
        (setq *rm:base* (subst (list (car r) pt (list (vlax-vla-object->ename o)) (strcat "блок " bn) (nth 4 r)) r *rm:base*)))))
  (princ (strcat "\nВставлено блоков " bn ": " (itoa n) " (вместо найденных надписей).")))

;;; ---------- команды ----------
(defun rm:run (/ *error* doc ss i pt res)
  (setq doc (rm:doc))
  (defun *error* (m)
    (if (not (wcmatch (strcase m) "*CANCEL*,*ОТМЕН*,*QUIT*,*BREAK*")) (princ (strcat "\nОшибка: " m)))
    (vla-EndUndoMark doc) (princ))
  (rm:load)
  ;; выделенное до команды - только в нём, иначе всё текущее пространство
  (setq ss (ssget "_I" '((0 . "TEXT,MTEXT,INSERT"))))
  (if ss (princ (strcat "\nПоиск в выделенном: " (itoa (sslength ss)) " объектов."))
    (setq ss (ssget "_X" (list '(0 . "TEXT,MTEXT,INSERT") (cons 410 (getvar "CTAB"))))))
  (sssetfirst nil nil)
  (setq *rm:ents* nil i 0)
  (if ss (repeat (sslength ss) (setq *rm:ents* (cons (ssname ss i) *rm:ents*) i (1+ i))))
  (setq *rm:tks* nil *rm:rooms* nil)
  (rm:find)
  (setq res (rm:dialog))
  (cond
    ((= res 1)
     (if (setq pt (getpoint "\nТочка вставки таблицы (левый верхний угол): "))
       (progn (vla-StartUndoMark doc) (rm:table (trans pt 1 0)) (vla-EndUndoMark doc)
              (princ (strcat "\nЭкспликация: помещений " (itoa (length *rm:base*)) ".")))))
    ((= res 5) (vla-StartUndoMark doc) (rm:insert-blocks) (rm:save) (vla-EndUndoMark doc)))
  (princ))

(defun c:ММ_ЭКСПЛИКАЦИЯ () (rm:run))
(defun c:мм_экспликация () (rm:run))
(defun c:MM_ROOM_SCHEDULE () (rm:run))
(princ "\nrooms.lsp загружен. ММ_ЭКСПЛИКАЦИЯ (MM_ROOM_SCHEDULE) - таблица помещений по ГОСТ 21.501 по маске ({N}. {ИМЯ} {S});")
(princ "\n  в том же окне - «Вставить блоки»: помещения в блоки с атрибутами №, ПОМЕЩЕНИЕ, ПЛОЩАДЬ вместо надписей.")
(princ)
