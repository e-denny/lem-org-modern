(in-package :lem-org-modern)

;;; What gets decorated, and with which glyph.
;;;
;;; The replacements keep the character count of what they replace wherever
;;; that is possible (stars, bullets, rules, progress bars), so the editing
;;; grid does not move under the cursor.  Checkboxes are the exception, as in
;;; org-modern: [ ] is three cells, the glyph one.

(defvar *org-modern-stars* '("◉" "○" "◈" "◇" "✳")
  "Replacement glyphs for headline stars, one per nesting level.
The last glyph is reused below the last level.  Every glyph should occupy one
cell; `◉` (U+25C9), `○` (U+25CB), `◈` (U+25C8), `◇` (U+25C7) and `✳` (U+2733)
do in the fonts Lem ships with.")

(defvar *org-modern-star-attributes*
  '(org-modern-star-1-attribute
    org-modern-star-2-attribute
    org-modern-star-3-attribute
    org-modern-star-4-attribute
    org-modern-star-5-attribute)
  "Faces for the headline stars, one per nesting level, deepest reused last.")

(defvar *org-modern-todo-keywords* '("TODO" "NEXT" "WAIT" "HOLD" "STARTED")
  "Headline keywords drawn with the TODO label face.")

(defvar *org-modern-done-keywords* '("DONE" "CANCELLED" "CANCELED")
  "Headline keywords drawn with the DONE label face.")

(defvar *org-modern-bullets*
  '((#\- . "–") (#\+ . "◦") (#\* . "∙"))
  "List bullet replacements, by the bullet character in the buffer.")

(defvar *org-modern-checkboxes*
  '((#\Space . "☐") (#\X . "☑") (#\x . "☑") (#\- . "◐"))
  "Checkbox replacements, by the character inside the brackets.")

(defvar *org-modern-timestamp* t
  "When non-nil, timestamps are drawn as labels.")

(defvar *org-modern-tag* t
  "When non-nil, headline tags are drawn as labels.")

(defvar *org-modern-progress* t
  "When non-nil, progress cookies like [1/3] are drawn as bars.")

;;; Patterns.

(defparameter *headline-pattern* "^(\\*+)(?:[ \\t]+|$)")

(defparameter *todo-pattern* "([A-Z][A-Z0-9-]*)(?:[ \\t]+|$)")

(defparameter *priority-pattern* "\\[#([A-Z])\\]")

(defparameter *progress-pattern* "\\[([0-9]+)/([0-9]+)\\]|\\[([0-9]+)%\\]")

(defparameter *tags-pattern*
  "(?:^|[ \\t])(:[A-Za-z0-9_@#%]+(?::[A-Za-z0-9_@#%]+)*:)[ \\t]*$")

(defparameter *timestamp-pattern*
  "(<|\\[)([0-9]{4}-[0-9]{2}-[0-9]{2})(?:[ \\t]+[A-Za-z]{3})?(?:[ \\t]+([0-9]{1,2}:[0-9]{2}))?(?:[ \\t]+[.+-]?[0-9]+[dwmy])?[>\\]]")

(defparameter *list-item-pattern* "^([ \\t]*)([-+*])([ \\t]+)(\\[[ Xx-]\\])?")

(defparameter *rule-pattern* "^[ \\t]*-{5,}[ \\t]*$")

(defparameter *keyword-pattern* "^([ \\t]*)(#\\+)([A-Za-z0-9_-]+)(:)?")

;;; Helpers.

(defun org-modern--first-non-space (line)
  "The first non-space character of LINE, or NIL for a blank line."
  (let ((position (org-modern--skip-spaces line 0)))
    (and (< position (length line))
         (char line position))))

(defun org-modern--headline-p (line)
  "T when LINE starts a headline."
  (not (null (ppcre:scan *headline-pattern* line))))

(defun org-modern--skip-spaces (line position)
  "The first position at or after POSITION in LINE whose character is not a
space or a tab."
  (loop :for i :from position :below (length line)
        :while (member (char line i) '(#\Space #\Tab))
        :finally (return i)))

(defun org-modern--star (level)
  "The star glyph for nesting LEVEL."
  (nth (min (1- level) (1- (length *org-modern-stars*)))
       *org-modern-stars*))

(defun org-modern--star-attribute (level)
  "The face for nesting LEVEL's star."
  (nth (min (1- level) (1- (length *org-modern-star-attributes*)))
       *org-modern-star-attributes*))

(defun org-modern--todo-keyword-p (keyword)
  "T when KEYWORD is one of the configured headline keywords."
  (or (member keyword *org-modern-todo-keywords* :test #'string=)
      (member keyword *org-modern-done-keywords* :test #'string=)))

(defun org-modern--block-begin-p (line)
  "T when LINE opens a #+begin_ block."
  (not (null (ppcre:scan "(?i)^[ \\t]*#\\+begin_" line))))

(defun org-modern--block-end-p (line)
  "T when LINE closes a #+end_ block."
  (not (null (ppcre:scan "(?i)^[ \\t]*#\\+end_" line))))

;;; Decoration of one line.

(defun org-modern--decorate-line (buffer point in-block)
  "Decorate the line at POINT in BUFFER; return whether a block is open after it.
IN-BLOCK says whether the previous line opened a #+begin_ block.  The body of a
block is left alone: it belongs to the embedded language, not to Org."
  (let* ((line (line-string point))
         (first (org-modern--first-non-space line)))
    (cond
      (in-block
       (when (and first
                  (char= first #\#)
                  (org-modern--block-end-p line))
         (org-modern--decorate-keywords buffer point line))
       nil)
      (t
       (when (and first (char= first #\*))
         (org-modern--decorate-headline buffer point line))
       (when (and first (member first '(#\- #\+ #\*)))
         (org-modern--decorate-list-item buffer point line))
       (when (and first (char= first #\-))
         (org-modern--decorate-rule buffer point line))
       (when (and first (char= first #\#))
         (org-modern--decorate-keywords buffer point line))
       (when (and *org-modern-timestamp*
                  (or (find #\< line) (find #\[ line)))
         (org-modern--decorate-timestamps buffer point line))
       (and first
            (char= first #\#)
            (org-modern--block-begin-p line))))))

(defun org-modern--decorate-headline (buffer point line)
  "Decorate the headline in LINE, if it is one."
  (multiple-value-bind (match-start match-end registers register-ends)
      (ppcre:scan *headline-pattern* line)
    (declare (ignore match-end registers))
    (when match-start
      (let* ((stars-end (aref register-ends 0))
             (level (- stars-end match-start))
             (replacement (concatenate 'string
                                       (org-modern--star level)
                                       (make-string (1- level)
                                                    :initial-element #\Space))))
        (org-modern--decorate buffer point match-start stars-end
                              (org-modern--star-attribute level)
                              replacement)
        (let ((rest (org-modern--skip-spaces line stars-end)))
          (when (< rest (length line))
            (org-modern--decorate-headline-rest buffer point line rest)))))))

(defun org-modern--decorate-headline-rest (buffer point line start)
  "Decorate the keyword, priority, progress cookies and tags of a headline.
START is the offset of the first character after the stars."
  (let ((position start))
    ;; TODO/DONE keyword, directly after the stars.
    (multiple-value-bind (match-start match-end registers register-ends)
        (ppcre:scan *todo-pattern* line :start position)
      (declare (ignore match-end))
      (when (and match-start (= match-start position))
        (let ((keyword (subseq line
                               (aref registers 0)
                               (aref register-ends 0))))
          (when (org-modern--todo-keyword-p keyword)
            (org-modern--decorate
             buffer point
             (aref registers 0) (aref register-ends 0)
             (if (member keyword *org-modern-todo-keywords* :test #'string=)
                 'org-modern-todo-attribute
                 'org-modern-done-attribute))
            (setf position (org-modern--skip-spaces
                            line (aref register-ends 0)))))))
    ;; Priority cookie, directly after the keyword.
    (multiple-value-bind (match-start match-end)
        (ppcre:scan *priority-pattern* line :start position)
      (when (and match-start (= match-start position))
        (org-modern--decorate buffer point match-start match-end
                              'org-modern-priority-attribute)
        (setf position (org-modern--skip-spaces line match-end))))
    (when *org-modern-progress*
      (org-modern--decorate-progress buffer point line position))
    (when *org-modern-tag*
      (org-modern--decorate-tags buffer point line position))))

(defun org-modern--decorate-progress (buffer point line start)
  "Draw progress cookies in LINE from START as bars of the same width."
  (loop :with position := start
        :for (match-start match-end registers register-ends) :=
        (multiple-value-list
         (ppcre:scan *progress-pattern* line :start position))
        :while match-start
        :do (let* ((inner-start (1+ match-start))
                   (inner-end (1- match-end))
                   (width (- inner-end inner-start))
                   (ratio (if (aref registers 0)
                              (/ (parse-integer
                                  line
                                  :start (aref registers 0)
                                  :end (aref register-ends 0))
                                 (max 1 (parse-integer
                                         line
                                         :start (aref registers 1)
                                         :end (aref register-ends 1))))
                              (/ (parse-integer
                                  line
                                  :start (aref registers 2)
                                  :end (aref register-ends 2))
                                 100.0)))
                   (filled (max 0 (min width
                                       (round (* width ratio))))))
              (when (plusp filled)
                (org-modern--decorate
                 buffer point inner-start (+ inner-start filled)
                 'org-modern-progress-complete-attribute
                 (make-string filled :initial-element #\▓)))
              (when (< (+ inner-start filled) inner-end)
                (org-modern--decorate
                 buffer point (+ inner-start filled) inner-end
                 'org-modern-progress-incomplete-attribute
                 (make-string (- inner-end (+ inner-start filled))
                              :initial-element #\░)))
              (setf position (max (1+ match-start) match-end)))))

(defun org-modern--decorate-tags (buffer point line start)
  "Draw the headline tags in LINE, searching from START, as a label."
  (multiple-value-bind (match-start match-end registers register-ends)
      (ppcre:scan *tags-pattern* line :start start)
    (declare (ignore match-end))
    (when (and match-start (aref registers 0))
      (org-modern--decorate buffer point
                            (aref registers 0) (aref register-ends 0)
                            'org-modern-tag-attribute))))

(defun org-modern--decorate-list-item (buffer point line)
  "Replace the bullet and checkbox of the list item in LINE."
  (unless (org-modern--headline-p line)
    (multiple-value-bind (match-start match-end registers register-ends)
        (ppcre:scan *list-item-pattern* line)
      (declare (ignore match-end))
      (when (and match-start (aref registers 1))
        (let* ((bullet-start (aref registers 1))
               (bullet-end (aref register-ends 1))
               (bullet-char (char line bullet-start))
               (replacement (cdr (assoc bullet-char *org-modern-bullets*))))
          ;; A "*" in column zero is a headline, never a list bullet.
          (when (and replacement
                     (or (not (char= bullet-char #\*))
                         (plusp bullet-start)))
            (org-modern--decorate buffer point bullet-start bullet-end
                                  'org-modern-bullet-attribute
                                  replacement))
          (when (aref registers 3)
            (let* ((checkbox-start (aref registers 3))
                   (checkbox-end (aref register-ends 3))
                   (state (char line (1+ checkbox-start)))
                   (glyph (cdr (assoc state *org-modern-checkboxes*)))
                   (attribute (cond
                                ((member state '(#\X #\x))
                                 'org-modern-checkbox-checked-attribute)
                                ((char= state #\-)
                                 'org-modern-checkbox-partial-attribute)
                                (t
                                 'org-modern-checkbox-unchecked-attribute))))
              (when glyph
                (org-modern--decorate buffer point
                                      checkbox-start checkbox-end
                                      attribute glyph)))))))))

(defun org-modern--decorate-rule (buffer point line)
  "Draw a horizontal rule in LINE as a continuous line."
  (when (ppcre:scan *rule-pattern* line)
    (multiple-value-bind (match-start match-end)
        (ppcre:scan "-{5,}" line)
      (org-modern--decorate buffer point match-start match-end
                            'org-modern-rule-attribute
                            (make-string (- match-end match-start)
                                         :initial-element #\─)))))

(defun org-modern--decorate-keywords (buffer point line)
  "Dim the #+ prefix of a keyword line and highlight a block's type name."
  (multiple-value-bind (match-start match-end registers register-ends)
      (ppcre:scan *keyword-pattern* line)
    (declare (ignore match-end))
    (when (and match-start (aref registers 1))
      (let* ((hash-start (aref registers 1))
             (hash-end (aref register-ends 1))
             (name-start (aref registers 2))
             (name-end (aref register-ends 2))
             (name (subseq line name-start name-end)))
        (cond
          ((ppcre:scan "(?i)^begin_" name)
           (org-modern--decorate buffer point hash-start (+ hash-start 8)
                                 'org-modern-keyword-prefix-attribute)
           (org-modern--decorate buffer point (+ hash-start 8) name-end
                                 'org-modern-block-name-attribute))
          ((ppcre:scan "(?i)^end_" name)
           (org-modern--decorate buffer point hash-start (+ hash-start 6)
                                 'org-modern-keyword-prefix-attribute)
           (org-modern--decorate buffer point (+ hash-start 6) name-end
                                 'org-modern-block-name-attribute))
          (t
           (org-modern--decorate buffer point hash-start hash-end
                                 'org-modern-keyword-prefix-attribute)))))))

(defun org-modern--decorate-timestamps (buffer point line)
  "Draw the timestamps in LINE as labels."
  (loop :with position := 0
        :for (match-start match-end registers register-ends) :=
        (multiple-value-list
         (ppcre:scan *timestamp-pattern* line :start position))
        :while match-start
        :do (let* ((active (char= (char line match-start) #\<))
                   (time-start (aref registers 2))
                   (date-attribute (if active
                                       'org-modern-date-active-attribute
                                       'org-modern-timestamp-inactive-attribute))
                   (date-end (or time-start (1- match-end))))
              (org-modern--decorate buffer point match-start date-end
                                    date-attribute)
              (when time-start
                (org-modern--decorate
                 buffer point time-start (1- match-end)
                 (if active
                     'org-modern-time-active-attribute
                     'org-modern-timestamp-inactive-attribute))))
              (setf position (max (1+ match-start) match-end))))
