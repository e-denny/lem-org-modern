(defpackage :lem-org-modern
  (:use :cl :lem)
  (:documentation "A modern style for Org buffers, in the spirit of Emacs org-modern.
Decorations are Lem overlays: attributes (colors, bold, reverse video) for
labels and display replacements for the glyphs a modern Org style swaps in
(headline stars, list bullets, checkboxes, rules).")
  (:export
   ;; knobs
   #:*org-modern-major-modes*
   #:*org-modern-stars*
   #:*org-modern-star-attributes*
   #:*org-modern-todo-keywords*
   #:*org-modern-done-keywords*
   #:*org-modern-bullets*
   #:*org-modern-checkboxes*
   #:*org-modern-progress*
   #:*org-modern-timestamp*
   #:*org-modern-tag*
   ;; commands
   #:org-modern-mode
   #:global-org-modern-mode
   #:org-modern-refresh))
