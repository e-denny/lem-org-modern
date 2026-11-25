(defsystem "lem-org-modern"
  :description "A modern style for Org buffers, modeled on Emacs org-modern."
  :author "Lem contributors"
  :license "MIT"
  :depends-on ("lem/core" "cl-ppcre")
  :serial t
  :components ((:file "package")
               (:file "faces")
               (:file "core")
               (:file "rules")))
