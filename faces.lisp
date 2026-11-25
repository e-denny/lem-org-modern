(in-package :lem-org-modern)

;;; Faces.
;;;
;;; Colors are the theme's base00..base0F palette, the same names organ-mode's
;;; own attributes use, so every base16 theme restyles the extension along with
;;; the rest of the editor.  Lem attributes have no box or font-size scaling,
;;; so a "label" here is a background plus a foreground and weight, not a box.

(define-attribute org-modern-star-1-attribute
  (t :foreground :base0f :bold t))

(define-attribute org-modern-star-2-attribute
  (t :foreground :base0e :bold t))

(define-attribute org-modern-star-3-attribute
  (t :foreground :base0d :bold t))

(define-attribute org-modern-star-4-attribute
  (t :foreground :base0c :bold t))

(define-attribute org-modern-star-5-attribute
  (t :foreground :base0b :bold t))

(define-attribute org-modern-todo-attribute
  (t :foreground :base00 :background :base08 :bold t))

(define-attribute org-modern-done-attribute
  (t :foreground :base00 :background :base0b :bold t))

(define-attribute org-modern-tag-attribute
  (t :foreground :base0d :background :base02 :bold t))

(define-attribute org-modern-priority-attribute
  (t :foreground :base00 :background :base0a :bold t))

(define-attribute org-modern-date-active-attribute
  (t :foreground :base06 :background :base02))

(define-attribute org-modern-time-active-attribute
  (t :foreground :base09 :background :base02 :bold t))

(define-attribute org-modern-timestamp-inactive-attribute
  (t :foreground :base03))

(define-attribute org-modern-checkbox-unchecked-attribute
  (t :foreground :base04))

(define-attribute org-modern-checkbox-checked-attribute
  (t :foreground :base0b :bold t))

(define-attribute org-modern-checkbox-partial-attribute
  (t :foreground :base0a :bold t))

(define-attribute org-modern-bullet-attribute
  (t :foreground :base09))

(define-attribute org-modern-rule-attribute
  (t :foreground :base03))

(define-attribute org-modern-keyword-prefix-attribute
  (t :foreground :base03))

(define-attribute org-modern-block-name-attribute
  (t :foreground :base0d :bold t))

(define-attribute org-modern-progress-complete-attribute
  (t :foreground :base0b))

(define-attribute org-modern-progress-incomplete-attribute
  (t :foreground :base02))
